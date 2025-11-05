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
     *   DEFAULT_FORM_ID: 'my-portfolio'  // Auto-load this form
     *   DEFAULT_FORM_ID: ''               // Require manual selection
     */
    DEFAULT_FORM_ID: 'my-portfolio'
};
