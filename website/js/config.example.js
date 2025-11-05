/**
 * FormBridge Website Configuration
 * 
 * Instructions:
 * 1. Copy this file to config.js
 * 2. Update API_URL and API_KEY based on your deployment
 * 3. Reference in HTML: <script src="js/config.js"></script>
 */

window.CONFIG = {
  // API endpoint (local dev or production)
  API_URL: "http://127.0.0.1:3000",
  
  // API key for authentication (optional, leave empty for dev)
  // For production: get from AWS Secrets Manager
  API_KEY: "",
  
  // Form ID for tracking in analytics
  FORM_ID: "website-contact",
  
  // Enable optional HMAC-SHA256 request signing
  // Set to true for additional security validation
  HMAC_ENABLED: false,
  
  // HMAC secret (only used if HMAC_ENABLED=true)
  // WARNING: Exposing secrets on static sites is a security risk!
  // This is demo-only; in production, use a backend proxy to sign requests.
  HMAC_SECRET: ""
};
