/**
 * FormBridge Website - Core JavaScript
 * Handles: Navigation, mobile menu, smooth scroll, form submission, HMAC signing
 */

// ============================================================================
// Mobile Menu Toggle
// ============================================================================

function initMobileMenu() {
  const menuButton = document.getElementById('mobile-menu-btn');
  const closeButton = document.getElementById('mobile-menu-close');
  const mobileMenu = document.getElementById('mobile-menu');
  const mobileLinks = document.querySelectorAll('#mobile-menu a');

  if (!menuButton || !mobileMenu) return;

  // Open menu
  menuButton.addEventListener('click', () => {
    mobileMenu.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
  });

  // Close menu
  closeButton.addEventListener('click', () => {
    mobileMenu.classList.add('hidden');
    document.body.style.overflow = 'auto';
  });

  // Close on link click
  mobileLinks.forEach(link => {
    link.addEventListener('click', () => {
      mobileMenu.classList.add('hidden');
      document.body.style.overflow = 'auto';
    });
  });

  // Close on outside click
  mobileMenu.addEventListener('click', (e) => {
    if (e.target === mobileMenu) {
      mobileMenu.classList.add('hidden');
      document.body.style.overflow = 'auto';
    }
  });
}

// ============================================================================
// Navbar Sticky Scroll Effect
// ============================================================================

function initStickyNav() {
  const navbar = document.getElementById('navbar');
  if (!navbar) return;

  let lastScrollY = 0;
  let ticking = false;

  function updateNav() {
    if (window.scrollY > 50) {
      navbar.classList.add('shadow-md', 'bg-white/95', 'backdrop-blur');
    } else {
      navbar.classList.remove('shadow-md', 'bg-white/95', 'backdrop-blur');
    }
    ticking = false;
  }

  window.addEventListener('scroll', () => {
    lastScrollY = window.scrollY;
    if (!ticking) {
      window.requestAnimationFrame(updateNav);
      ticking = true;
    }
  });
}

// ============================================================================
// Smooth Scroll for Anchor Links
// ============================================================================

function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      e.preventDefault();
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        target.scrollIntoView({ behavior: 'smooth' });
      }
    });
  });
}

// ============================================================================
// Toast Notifications
// ============================================================================

function showToast(message, type = 'success', duration = 3000) {
  const toastId = 'toast-' + Date.now();
  const bgColor = type === 'success' ? 'bg-green-500' : type === 'error' ? 'bg-red-500' : 'bg-blue-500';
  const icon = type === 'success' ? '✅' : type === 'error' ? '❌' : 'ℹ️';

  const toast = document.createElement('div');
  toast.id = toastId;
  toast.className = `fixed bottom-4 right-4 ${bgColor} text-white px-6 py-4 rounded-lg shadow-lg animate-pulse z-50 max-w-xs`;
  toast.innerHTML = `<div class="flex items-center gap-2"><span>${icon}</span><span>${message}</span></div>`;

  document.body.appendChild(toast);

  setTimeout(() => {
    const el = document.getElementById(toastId);
    if (el) {
      el.style.animation = 'fadeOut 0.3s ease-out forwards';
      setTimeout(() => el.remove(), 300);
    }
  }, duration);
}

// ============================================================================
// HMAC-SHA256 Signing (Web Crypto API)
// ============================================================================

async function signRequest(body, secret) {
  try {
    const timestamp = Math.floor(Date.now() / 1000).toString();
    const message = timestamp + '\n' + body;

    // Import secret as key
    const encoder = new TextEncoder();
    const key = await window.crypto.subtle.importKey(
      'raw',
      encoder.encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    // Sign message
    const signature = await window.crypto.subtle.sign(
      'HMAC',
      key,
      encoder.encode(message)
    );

    // Convert to hex
    const signatureHex = Array.from(new Uint8Array(signature))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return { timestamp, signature: signatureHex };
  } catch (error) {
    console.error('HMAC signing failed:', error);
    throw error;
  }
}

// ============================================================================
// Contact Form Submission
// ============================================================================

async function initContactForm() {
  const form = document.getElementById('contact-form');
  if (!form) return;

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const submitBtn = form.querySelector('button[type="submit"]');
    const originalText = submitBtn.textContent;
    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending...';

    try {
      // Collect form data
      const name = document.getElementById('contact-name')?.value || '';
      const email = document.getElementById('contact-email')?.value || '';
      const message = document.getElementById('contact-message')?.value || '';

      if (!name || !email || !message) {
        showToast('Please fill in all fields', 'error');
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
        return;
      }

      // Build request payload
      const payload = {
        name,
        email,
        message,
        form_id: window.CONFIG?.FORM_ID || 'website-contact'
      };

      const body = JSON.stringify(payload);
      const headers = {
        'Content-Type': 'application/json'
      };

      // Add API key if available
      if (window.CONFIG?.API_KEY) {
        headers['X-Api-Key'] = window.CONFIG.API_KEY;
      }

      // Add HMAC signature if enabled
      if (window.CONFIG?.HMAC_ENABLED && window.CONFIG?.HMAC_SECRET) {
        try {
          const { timestamp, signature } = await signRequest(body, window.CONFIG.HMAC_SECRET);
          headers['X-Timestamp'] = timestamp;
          headers['X-Signature'] = signature;
        } catch (err) {
          showToast('HMAC signing failed: ' + err.message, 'error');
          submitBtn.disabled = false;
          submitBtn.textContent = originalText;
          return;
        }
      }

      // Submit to API
      const response = await fetch(`${window.CONFIG?.API_URL || 'http://127.0.0.1:3000'}/submit`, {
        method: 'POST',
        headers,
        body
      });

      const result = await response.json();

      if (!response.ok) {
        showToast(`Error: ${result.error || response.statusText}`, 'error', 4000);
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
        return;
      }

      // Success!
      showToast(`✅ Sent! ID: ${result.id || result.message_id || 'OK'}`, 'success', 4000);
      form.reset();

      // Show success message
      const successDiv = document.getElementById('form-success');
      if (successDiv) {
        successDiv.classList.remove('hidden');
        setTimeout(() => successDiv.classList.add('hidden'), 4000);
      }

      submitBtn.disabled = false;
      submitBtn.textContent = originalText;
    } catch (error) {
      console.error('Form submission error:', error);
      showToast(`Error: ${error.message}`, 'error', 4000);
      submitBtn.disabled = false;
      submitBtn.textContent = originalText;
    }
  });
}

// ============================================================================
// Initialize on DOM Ready
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
  initMobileMenu();
  initStickyNav();
  initSmoothScroll();
  initContactForm();
});
