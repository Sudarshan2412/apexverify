require('dotenv').config();
const express = require('express');
const cors = require('cors');
const uploadRoute = require('./routes/upload');
const frameRoute = require('./routes/frame');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());
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