const cloudinary = require('cloudinary').v2;
const fs = require('fs');

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true,
});

/**
 * Uploads a local file to Cloudinary and deletes the temp file.
 * @param {string} filePath - Local path of the uploaded file
 * @param {object} options - Cloudinary upload options
 * @returns {Promise<object>} - Cloudinary upload result
 */
async function uploadToCloudinary(filePath, options = {}) {
  try {
    if (!process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
      throw new Error('Cloudinary environment variables are missing. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET.');
    }

    const uploadOptions = {
      folder: 'lumen_studio/profiles',
      resource_type: 'auto',
      transformation: [
        { width: 800, height: 800, crop: 'limit', quality: 'auto' },
      ],
      ...options,
    };

    const result = await cloudinary.uploader.upload(filePath, uploadOptions);

    if (!result || (!result.secure_url && !result.url)) {
      throw new Error('Cloudinary upload returned no secure_url.');
    }

    return result;
  } finally {
    // Always clean up local temp file
    if (fs.existsSync(filePath)) {
      try {
        fs.unlinkSync(filePath);
      } catch (err) {
        console.warn('Failed to delete temp file:', err.message);
      }
    }
  }
}

module.exports = {
  cloudinary,
  uploadToCloudinary,
};
