require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const uploadRoute = require('./routes/upload');
const frameRoute = require('./routes/frame');

const app = express();
const PORT = process.env.PORT || 3001;

const CORS_ORIGIN = (process.env.CORS_ORIGIN || '').trim();

// Ensure required runtime directories exist (multer writes to uploads/).
fs.mkdirSync(path.join(process.cwd(), 'uploads'), { recursive: true });

app.use(
  cors({
    origin: CORS_ORIGIN || true,
    methods: ['GET', 'POST', 'OPTIONS'],
  }),
);
app.use(express.json());

app.get('/', (req, res) => {
  res.status(200).json({
    name: 'apexverify-backend',
    status: 'ok',
    endpoints: {
      health: '/health',
      upload: '/api/upload',
      frame: '/api/frame?url=<videoUrl>&t=<seconds>',
    },
  });
});

app.use('/api', uploadRoute);
app.use('/api', frameRoute);

app.get('/health', (req, res) => {
  res.json({ status: 'OCR server is running', port: PORT });
});

app.listen(PORT, () => {
  console.log(`\n OCR Server running at http://localhost:${PORT}`);
  console.log(' POST /api/upload  — send a document to OCR');
  console.log(' GET  /health      — check server status\n');
});