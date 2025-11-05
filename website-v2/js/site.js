/**
 * Site-wide utilities: navigation, smooth scroll, analytics
 */

document.addEventListener('DOMContentLoaded', function() {
  initNavigation();
  initSmoothScroll();
  initMobileMenu();
  updateActiveLinks();
  setupPageBaseLinks();
});

function initNavigation() {
  const mobileMenuBtn = document.getElementById('mobile-menu-btn');
  const mobileMenu = document.getElementById('mobile-menu');
  const navLinks = document.querySelectorAll('nav a[data-nav-link]');

  if (mobileMenuBtn && mobileMenu) {
    mobileMenuBtn.addEventListener('click', () => {
      mobileMenu.classList.toggle('hidden');
    });

    // Close menu on link click
    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        mobileMenu.classList.add('hidden');
      });
    });
  }
}

function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      const href = this.getAttribute('href');
      if (href === '#') return;
      
      const target = document.querySelector(href);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });
}

function initMobileMenu() {
  const closeBtn = document.getElementById('mobile-menu-close');
  const mobileMenu = document.getElementById('mobile-menu');
  
  if (closeBtn) {
    closeBtn.addEventListener('click', () => {
      mobileMenu.classList.add('hidden');
    });
  }

  // Close menu when clicking outside
  document.addEventListener('click', (e) => {
    const nav = document.querySelector('nav');
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    
    if (mobileMenu && !mobileMenu.contains(e.target) && !mobileMenuBtn.contains(e.target)) {
      if (!mobileMenu.classList.contains('hidden')) {
        mobileMenu.classList.add('hidden');
      }
    }
  });
}

function updateActiveLinks() {
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('nav a[data-nav-link]').forEach(link => {
    const href = link.getAttribute('href');
    if (href.endsWith(currentPage) || (currentPage === '' && href.endsWith('index.html'))) {
      link.classList.add('text-blue-600', 'font-semibold');
      link.classList.remove('text-gray-700');
    }
  });
}

function setupPageBaseLinks() {
  const base = window.CONFIG?.PAGES_BASE || '';
  if (!base) return;

  document.querySelectorAll('a[data-internal]').forEach(link => {
    let href = link.getAttribute('href');
    if (href.startsWith('/')) {
      href = href.substring(1);
    }
    if (!href.startsWith(base)) {
      link.href = base + '/' + href;
    }
  });
}

// Analytics ping (optional)
function trackPageView() {
  if (window.CONFIG?.ENABLE_ANALYTICS) {
    // Send a ping to your analytics endpoint
    const url = new URL(`${window.CONFIG.API_URL}/analytics`);
    navigator.sendBeacon(url.toString(), JSON.stringify({
      form_id: 'site-analytics',
      page: window.location.pathname,
      timestamp: Math.floor(Date.now() / 1000)
    }));
  }
}

// Call on page load
trackPageView();
