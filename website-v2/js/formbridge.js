/**
 * FormBridge API wrapper with HMAC support
 * Handles form submissions, error handling, and success notifications
 */

class FormBridge {
  constructor(config = window.CONFIG) {
    this.config = config;
    this.toastContainer = this.createToastContainer();
  }

  createToastContainer() {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'fixed top-4 right-4 z-50 space-y-2 pointer-events-none';
      document.body.appendChild(container);
    }
    return container;
  }

  async submitForm(formData) {
    try {
      const headers = {
        'Content-Type': 'application/json'
      };

      // Add API Key if configured
      if (this.config.API_KEY) {
        headers['X-Api-Key'] = this.config.API_KEY;
      }

      let body = {
        form_id: this.config.FORM_ID,
        ...formData
      };

      // Add HMAC signature if enabled
      if (this.config.HMAC_ENABLED && this.config.HMAC_SECRET) {
        const timestamp = Math.floor(Date.now() / 1000);
        const rawBody = JSON.stringify(body);
        const signature = await this.generateHMAC(timestamp, rawBody);
        
        headers['X-Timestamp'] = timestamp.toString();
        headers['X-Signature'] = signature;
      }

      const response = await fetch(`${this.config.API_URL}/submit`, {
        method: 'POST',
        headers,
        body: JSON.stringify(body)
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(this.getErrorMessage(response.status, errorData));
      }

      const result = await response.json();
      this.showToast(`✓ Sent! ID: ${result.id}`, 'success', result.id);
      return result;
    } catch (error) {
      this.showToast(`✗ ${error.message}`, 'error');
      throw error;
    }
  }

  async generateHMAC(timestamp, rawBody) {
    // Simple HMAC-SHA256 generation
    // For production, use a proper crypto library
    const message = `${timestamp}\n${rawBody}`;
    const enc = new TextEncoder();
    const keyBuf = enc.encode(this.config.HMAC_SECRET);
    const msgBuf = enc.encode(message);
    
    const key = await crypto.subtle.importKey('raw', keyBuf, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const signature = await crypto.subtle.sign('HMAC', key, msgBuf);
    
    return Array.from(new Uint8Array(signature))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  }

  getErrorMessage(status, errorData) {
    const messages = {
      400: errorData.error || 'Invalid request',
      401: 'API key required or invalid',
      403: 'Access denied - check API key',
      404: 'Endpoint not found',
      429: 'Rate limited - please try again later',
      500: 'Server error - please try again',
      503: 'Service temporarily unavailable'
    };

    return messages[status] || (errorData.error ? `Error: ${errorData.error}` : 'Request failed');
  }

  showToast(message, type = 'info', submissionId = null) {
    const toast = document.createElement('div');
    const bgColor = {
      success: 'bg-green-500',
      error: 'bg-red-500',
      info: 'bg-blue-500'
    }[type] || 'bg-gray-500';

    let html = `
      <div class="${bgColor} text-white px-4 py-3 rounded-lg shadow-lg pointer-events-auto max-w-sm">
        <p>${message}</p>
    `;

    if (submissionId && this.config.DASHBOARD_URL) {
      html += `<a href="${this.config.DASHBOARD_URL}?form_id=${this.config.FORM_ID}" class="text-white underline text-sm mt-2 inline-block hover:opacity-80">View in Dashboard</a>`;
    }

    html += '</div>';
    toast.innerHTML = html;

    this.toastContainer.appendChild(toast);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transition = 'opacity 0.3s';
      setTimeout(() => toast.remove(), 300);
    }, 5000);
  }
}

// Export for global use
window.FormBridge = FormBridge;
