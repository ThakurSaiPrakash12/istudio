const fs = require('fs');
const path = require('path');
const multer = require('multer');
const { randomBytes } = require('crypto');

const uploadDir = path.join(__dirname, '..', '..', 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase() || '.jpg';
    cb(null, `${Date.now()}-${randomBytes(16).toString('hex')}${ext}`);
  },
});

const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.pdf'];
const allowedMimeTypes = new Set([
  'image/jpeg',
  'image/jpg',
  'image/pjpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'application/pdf',
]);

const fileFilter = (_req, file, cb) => {
  const ext = path.extname(file.originalname || '').toLowerCase();
  const isImageOrPdfMime = allowedMimeTypes.has(file.mimetype) ||
    file.mimetype === 'application/octet-stream' ||
    !file.mimetype;
  const isAllowedExt = allowedExtensions.includes(ext);

  if (isImageOrPdfMime && isAllowedExt) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file format. Please upload an image or PDF file (.jpg, .jpeg, .png, .webp, .pdf).'));
  }
};

const uploadMiddleware = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter,
});

function hasSupportedImageSignature(filePath) {
  const bytes = fs.readFileSync(filePath);
  if (bytes.length < 4) return false;
  const isJpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const isPng = bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from('\x89PNG\r\n\x1a\n', 'binary'));
  const isGif = bytes.length >= 6 && (bytes.subarray(0, 6).toString('ascii') === 'GIF87a' || bytes.subarray(0, 6).toString('ascii') === 'GIF89a');
  const isWebp = bytes.length >= 12 && bytes.subarray(0, 4).toString('ascii') === 'RIFF' &&
    bytes.subarray(8, 12).toString('ascii') === 'WEBP';
  const isPdf = bytes.subarray(0, 4).toString('ascii') === '%PDF';
  return isJpeg || isPng || isGif || isWebp || isPdf;
}

// Accepts single file under field 'logo', 'image', 'avatar', or 'profileImage'
const uploadLogo = uploadMiddleware.single('logo');
const uploadProfileImage = uploadMiddleware.single('image');
const uploadPaymentProof = uploadMiddleware.single('proof');

module.exports = {
  uploadMiddleware,
  uploadLogo,
  uploadProfileImage,
  uploadPaymentProof,
  hasSupportedImageSignature,
};

