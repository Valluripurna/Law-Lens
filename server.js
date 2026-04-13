const express = require('express');
const cors = require('cors');
const path = require('path');
const multer = require('multer');
const pdfParse = require('pdf-parse');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const admin = require('firebase-admin');

const app = express();
app.use(cors());
app.use(express.json());

// Root Route
app.get('/', (req, res) => {
  res.send(`
    <div style="font-family: sans-serif; padding: 20px;">
      <h1 style="color: #1E2A38;">Law Lens API is Operational 🛡️</h1>
      <p>Status: <span style="color: green;">Online</span></p>
      <hr/>
      <p>Go to <a href="/api/health">/api/health</a> to check your API Keys.</p>
    </div>
  `);
});

// Deep Health Check for Diagnostics
app.get('/api/health', (req, res) => {
  const health = {
    uptime: process.uptime(),
    timestamp: Date.now(),
    env: {
      gemini_key_exists: !!process.env.GEMINI_API_KEY,
      service_account_exists: !!process.env.SERVICE_ACCOUNT_JSON,
      port: process.env.PORT || 3000
    },
    firebase_initialized: admin.apps.length > 0
  };
  res.json(health);
});

// List Models Diagnostic
app.get('/api/models', async (req, res) => {
  try {
    const models = await genAI.listModels();
    res.json(models);
  } catch (error) {
    res.json({ error: error.message });
  }
});

// Initialize Firebase Admin
let firestore;
try {
  const serviceAccount = process.env.SERVICE_ACCOUNT_JSON 
    ? JSON.parse(process.env.SERVICE_ACCOUNT_JSON)
    : require('./service-account.json');

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
  }
  firestore = admin.firestore();
} catch (e) {
  console.error("Firebase Init Error:", e.message);
}

// API KEY Setup
if (!process.env.GEMINI_API_KEY || process.env.GEMINI_API_KEY.length < 20) {
  console.error("🚨 CRITICAL ERROR: GEMINI_API_KEY environment variable is missing or invalid!");
  console.error("Please add a valid Google AI Studio API key to your Render.com Environment Dashboard.");
  process.exit(1); // Force crash the server so it doesn't fail silently later
}

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Optimized RAG Helper
const findRelevantLawsFirestore = async (query) => {
  const start = Date.now();
  console.log(`[RAG] Starting search for: "${query}"`);

  const lowercaseQuery = query.toLowerCase();
  const words = lowercaseQuery.split(/\s+/).filter(w => w.length > 2);
  if (words.length === 0) return [];

  const sectionMatch = lowercaseQuery.match(/section\s+(\d+)/) || lowercaseQuery.match(/(\d+)/);
  const targetSection = sectionMatch ? sectionMatch[1] : null;

  try {
    const lawsRef = firestore.collection('legal_data');
    const snapshot = await lawsRef.get();
    
    let matchedLaws = [];
    snapshot.forEach(doc => {
      const law = doc.data();
      let score = 0;
      
      const keywords = (law.keywords || "").toLowerCase();
      const title = (law.title || "").toLowerCase();
      const content = (law.content || "").toLowerCase();
      const sectionStr = (law.section || "").toLowerCase();

      if (targetSection && sectionStr.includes(targetSection)) score += 10;

      words.forEach(word => {
        if (keywords.includes(word)) score += 3;
        if (title.includes(word)) score += 2;
        if (content.includes(word)) score += 1;
      });

      if (score > 0) matchedLaws.push({ ...law, score });
    });

    matchedLaws.sort((a, b) => b.score - a.score);
    const results = matchedLaws.slice(0, 3);
    console.log(`[RAG] Finished in ${Date.now() - start}ms. Found ${results.length} matches.`);
    return results;
  } catch (error) {
    console.error("[RAG] Error:", error.message);
    return [];
  }
};

// Firestore Save Chat Helper
const saveChatHistory = async (userId, question, answer, useVanishMode) => {
  if (!useVanishMode && userId) {
    try {
      await firestore.collection('chats').add({
        user_id: userId,
        question: question,
        answer: answer,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      console.error("Error saving chat:", error.message);
    }
  }
};

// Auth - Signup
app.post('/api/signup', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: "Email/password required" });

  try {
    const userRef = firestore.collection('users').doc(email);
    const doc = await userRef.get();
    if (doc.exists) return res.status(400).json({ error: "Email exists" });

    await userRef.set({ email, password, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    res.json({ token: "tk_" + email, userId: email, email });
  } catch (error) {
    res.status(500).json({ error: "Signup Failed" });
  }
});

// Auth - Login
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const doc = await firestore.collection('users').doc(email).get();
    if (!doc.exists || doc.data().password !== password) return res.status(401).json({ error: "Invalid credentials" });
    res.json({ token: "tk_" + email, userId: email, email });
  } catch (error) {
    res.status(500).json({ error: "Login Failed" });
  }
});

// Text Chat (Latency Optimized)
app.post('/api/chat', async (req, res) => {
  const start = Date.now();
  const { userId, question, useVanishMode, language = "English" } = req.body;
  if (!question) return res.status(400).json({ error: "Question required" });

  console.log(`[API] /api/chat received from ${userId}`);

  try {
    // 1. RAG
    const relevantLaws = await findRelevantLawsFirestore(question);
    const contextString = relevantLaws.length > 0 
      ? relevantLaws.map(l => `Title: ${l.title}\nSection: ${l.section}\nContent: ${l.content}\nFine: ${l.fine}`).join("\n\n")
      : "No exact law found. Provide general helpful guidance based on Indian Law.";

    // 2. Direct GEMINI Connection (Clean & Simple)
    console.log(`[Gemini] Requesting response from gemini-1.5-flash...`);
    const geminiStart = Date.now();
    
    const prompt = `You are a legal assistant for Law Lens. Explain the law in simple language for an Indian citizen.
Rules:
- Keep the answer short and practical. Mention fines if applicable.
- Respond strictly in ${language}.
- Include end disclaimer: "This is general information and not legal advice."

User Question: ${question}
Context: ${contextString}
Answer:`;

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const answerText = response.text();
    
    console.log(`[Gemini] Responded in ${Date.now() - geminiStart}ms`);

    // 3. Save History (Async)
    saveChatHistory(userId, question, answerText, useVanishMode);

    console.log(`[API] Total request handled in ${Date.now() - start}ms`);
    res.json({ answer: answerText });
  } catch (error) {
    console.error("[API] Error:", error.message);
    res.json({ answer: `GEMINI_ERROR: ${error.message}. Please verify your API Key in Render environment variables.` });
  }
});

// Image Upload (Vision)
app.post('/api/upload-image', upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: "No image file provided" });
  const { userId, question = "Explain this legally.", language = "English", useVanishMode } = req.body;

  try {
    const prompt = `Analyze this legal document/scene. Question: ${question}. Reply in ${language}.`;

    const imagePart = {
      inlineData: {
        data: req.file.buffer.toString("base64"),
        mimeType: req.file.mimetype
      }
    };

    console.log("[Gemini] Requesting Vision Analysis natively on gemini-1.5-flash...");
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const result = await model.generateContent([prompt, imagePart]);
    const response = await result.response;
    const answerText = response.text();

    saveChatHistory(userId, question, answerText, useVanishMode);
    res.json({ answer: answerText });
  } catch (error) {
    console.error(`[Vision] Error:`, error.message);
    res.json({ answer: `GEMINI_ERROR (Vision): ${error.message}` });
  }
});

// History Endpoint
app.get('/api/history', async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error: "Missing userId" });

  try {
    const snapshot = await firestore.collection('chats')
      .where('user_id', '==', userId)
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();
    
    const history = [];
    snapshot.forEach(doc => history.push({ id: doc.id, ...doc.data() }));
    res.json(history);
  } catch (error) {
    console.error("History Error:", error.message);
    res.status(500).json({ error: "Database error" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Law Lens backend running on port ${PORT}`);
});
