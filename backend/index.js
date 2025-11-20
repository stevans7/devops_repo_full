require('dotenv').config();

const express = require('express');
const cors = require('cors');
const nodemailer = require('nodemailer');
const path = require('path');
const mongoose = require('mongoose');
const promClient = require('prom-client');
const fs = require('fs');

// Prometheus metrics setup
const collectDefaultMetrics = promClient.collectDefaultMetrics;
const Registry = promClient.Registry;
const register = new Registry();
collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});

const appointmentCounter = new promClient.Counter({
  name: 'appointments_created_total',
  help: 'Total number of appointments created',
  registers: [register]
});

const app = express();
const port = process.env.PORT || 3000;
app.use(cors());
app.use(express.json());

// Serve frontend statically when available (local dev convenience)
const staticDir = path.resolve(__dirname, '../frontend/public');
if (fs.existsSync(staticDir)) {
  app.use(express.static(staticDir));
  // SPA-friendly fallback for non-API routes
  app.get(/^(?!\/api|\/metrics|\/health|\/healthz).*/, (req, res) => {
    res.sendFile(path.join(staticDir, 'index.html'));
  });
} else {
  console.warn('Static directory not found:', staticDir);
}

// MongoDB connection
const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/rdv';
mongoose.connect(MONGO_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
}).then(() => {
  console.log('📊 Connected to MongoDB');
}).catch(err => {
  console.error('❌ MongoDB connection error:', err);
});

// Import models
const Appointment = require('./models/appointment');

// Middleware to count HTTP requests
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal.inc({
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status: res.statusCode
    });
  });
  next();
});

// Serve static frontend disabled (frontend is served separately via NGINX/ALB)

// Simple in-memory rate limiter to avoid spam during demo
let lastSubmission = 0;

// Configure transporter using environment variables
const mailUser = process.env.MAIL_USER || '';
const mailPass = process.env.MAIL_PASS || '';
const mailTo   = process.env.MAIL_TO || mailUser; // receive at same user by default

if (!mailUser || !mailPass) {
  console.warn('⚠️ MAIL_USER or MAIL_PASS not set. Emails will fail until configured.');
}

const transporter = nodemailer.createTransport({
  service: process.env.MAIL_SERVICE || 'gmail',
  auth: {
    user: mailUser,
    pass: mailPass
  }
});

// Health endpoint
app.get('/health', async (req, res) => {
  const dbStatus = mongoose.connection.readyState === 1 ? 'UP' : 'DOWN';
  res.json({ 
    status: 'UP',
    database: dbStatus,
    timestamp: new Date().toISOString()
  });
});
app.get('/healthz', (req, res) => res.send('ok'));
// Alias for ALB path-based tests hitting /api/healthz
app.get('/api/healthz', (req, res) => res.send('ok'));

// Metrics endpoint (Prometheus)
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  const metrics = await register.metrics();
  res.end(metrics);
});

// Create appointment
app.post('/api/appointment', async (req, res) => {
  try {
    const now = Date.now();
    if (now - lastSubmission < 3000) {
      return res.status(429).json({ error: 'Too many requests, please wait a few seconds.' });
    }

    const { nom, prenom, email, tel, motif, date } = req.body || {};
    if (!nom || !prenom || !motif || !date) {
      return res.status(400).json({ error: 'Tous les champs sont requis' });
    }

    // Save to MongoDB
    const appointment = new Appointment({ nom, prenom, email, tel, motif, date });
    await appointment.save();
    appointmentCounter.inc();

    const mailOptions = {
      from: mailUser,
      to: mailTo,
      subject: '📅 Nouveau rendez-vous reçu',
      text: `Nouveau rendez-vous :\nNom : ${nom}\nPrénom : ${prenom}\nEmail : ${email || 'Non renseigné'}\nTéléphone : ${tel || 'Non renseigné'}\nMotif : ${motif}\nDate : ${date}`
    };

    if (!mailUser || !mailPass) {
      console.error('Mail credentials not set; skipping sendMail (demo mode).');
      lastSubmission = now;
      return res.json({ message: "Rendez-vous enregistré (mode demo, mail non envoyé). Vérifiez les variables d'environnement." });
    }

    await transporter.sendMail(mailOptions);
    lastSubmission = now;
    res.json({ message: 'Rendez-vous enregistré et email envoyé ✅' });
  } catch (err) {
    console.error('Error:', err);
    res.status(500).json({ error: 'Erreur lors du traitement de la demande' });
  }
});

// Get all appointments
app.get('/api/appointments', async (req, res) => {
  try {
    const appointments = await Appointment.find().sort({ createdAt: -1 });
    res.json(appointments);
  } catch (err) {
    console.error('Error fetching appointments:', err);
    res.status(500).json({ error: 'Erreur lors de la récupération des rendez-vous' });
  }
});

// No catch-all fallback; frontend served separately

// Export for testing
module.exports = app;

// ------------------
// Démarrage du serveur
// ------------------
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log('API listening on', PORT));
}
