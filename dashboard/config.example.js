/**
 * FormBridge Analytics Dashboard - Configuration
 *
 * RENAME THIS FILE TO config.js AND UPDATE THE SETTINGS BELOW
 * This file contains configuration for the analytics dashboard.
 * Copy this file to config.js and customize for your environment.
 *
 * IMPORTANT: config.js is not committed to version control for security.
 * Keep sensitive data (API keys) out of version control.
 */

export const CONFIG = {
    /**
     * API_URL: Base URL of your FormBridge analytics endpoint
     *
     * Development (Local):
     *   - Local Docker: http://127.0.0.1:3000
     *   - LocalStack: http://127.0.0.1:3001
     *
     * Production (AWS):
     *   - API Gateway URL: https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod
     *   - Or custom domain: https://api.example.com
     */
    API_URL: 'http://127.0.0.1:3000',

    /**
     * API_KEY: Optional API key for authentication
     *
     * Leave empty ('') if no authentication is required (development).
     * For production, set this to your API Gateway API key.
     *
     * SECURITY WARNING: This is visible in the browser!
     * Only use keys with read-only analytics permissions.
     * Consider using a separate read-only key for the dashboard.
     *
     * Example (do not commit with real key):
     *   API_KEY: 'YOUR_READ_ONLY_API_KEY_HERE'
     */
    API_KEY: '',

    /**
     * DEFAULT_FORM_ID: Form ID to load on page load
     *
     * Set to empty string ('') to require manual entry.
     * Set to a form ID (e.g., 'contact-form', 'newsletter-signup') to auto-load.
     *
     * Examples:
     *   DEFAULT_FORM_ID: 'portfolio-contact'  // Auto-load this form
     *   DEFAULT_FORM_ID: ''                    // Require manual selection
     */
    DEFAULT_FORM_ID: 'portfolio-contact'
};

/**
 * Configuration Guide
 *
 * DEVELOPMENT SETUP:
 * 1. Ensure your FormBridge backend is running:
 *    - Local: npm run dev (or docker-compose up)
 *    - Check http://127.0.0.1:3000 is accessible
 *
 * 2. Set API_URL to your local endpoint:
 *    - API_URL: 'http://127.0.0.1:3000'
     *
 * 3. Leave API_KEY empty (no auth in development):
 *    - API_KEY: ''
 *
 * 4. Set a default form ID (optional):
 *    - DEFAULT_FORM_ID: 'portfolio-contact'
 *
 * PRODUCTION SETUP:
 * 1. Deploy FormBridge to AWS (see README_PRODUCTION.md)
 *
 * 2. Get your API Gateway URL:
 *    - Format: https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod
 *    - Or: https://api.example.com (if using custom domain)
 *
 * 3. Create a read-only API key in API Gateway:
 *    - Go to API Gateway > Your API > API Keys
 *    - Create new API key (limit to analytics operations)
 *    - Associate with Usage Plan (read-only tier)
 *
 * 4. Update configuration:
 *    - API_URL: 'https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod'
 *    - API_KEY: 'YOUR_READ_ONLY_API_KEY'
 *
 * 5. Keep config.js out of version control:
 *    - git rm --cached config.js
 *    - Add to .gitignore: config.js
 *
 * DEPLOYMENT (GitHub Pages):
 * 1. Copy entire dashboard/ folder to your GitHub Pages repo
 * 2. Create config.js from config.example.js
 * 3. Set API_URL to production endpoint
 * 4. Set API_KEY to read-only key
 * 5. Push to GitHub (config.js not included)
 *
 * CORS ISSUES:
 * If you see "Network error. Check your API URL and CORS settings":
 * 1. Ensure API_URL is correct
 * 2. Verify your backend allows CORS from the dashboard origin
 * 3. For AWS API Gateway: Enable CORS in the console
 * 4. For local testing: Disable CORS checks in browser (development only)
 *
 * SECURITY:
 * - This dashboard is a static single-page application
 * - API keys are visible in the browser
 * - Only use read-only or limited-scope API keys
 * - Consider IP whitelisting on your API Gateway
 * - Monitor API Gateway for unusual access patterns
 * - Use CloudWatch alarms for analytics endpoint errors
 */
