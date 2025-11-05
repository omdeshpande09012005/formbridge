/**
 * Code snippet tabs with copy-to-clipboard
 */

document.addEventListener('DOMContentLoaded', function() {
  initCodeTabs();
});

function initCodeTabs() {
  document.querySelectorAll('[data-code-tabs]').forEach(tabsContainer => {
    const tabButtons = tabsContainer.querySelectorAll('[data-tab-button]');
    const tabContents = tabsContainer.querySelectorAll('[data-tab-content]');

    tabButtons.forEach(btn => {
      btn.addEventListener('click', (e) => {
        const tabName = btn.getAttribute('data-tab-button');
        
        // Hide all tabs
        tabContents.forEach(content => {
          content.classList.add('hidden');
        });

        // Remove active class from all buttons
        tabButtons.forEach(b => {
          b.classList.remove('border-blue-600', 'text-blue-600', 'font-semibold');
          b.classList.add('border-gray-300', 'text-gray-700');
        });

        // Show selected tab
        const selectedContent = tabsContainer.querySelector(`[data-tab-content="${tabName}"]`);
        if (selectedContent) {
          selectedContent.classList.remove('hidden');
        }

        // Highlight button
        btn.classList.remove('border-gray-300', 'text-gray-700');
        btn.classList.add('border-blue-600', 'text-blue-600', 'font-semibold');
      });
    });

    // Setup copy buttons
    tabContents.forEach(content => {
      const copyBtn = content.querySelector('[data-copy-btn]');
      if (copyBtn) {
        copyBtn.addEventListener('click', async (e) => {
          const code = content.querySelector('code').textContent;
          try {
            await navigator.clipboard.writeText(code);
            const originalText = copyBtn.textContent;
            copyBtn.textContent = 'Copied!';
            copyBtn.classList.add('bg-green-500');
            setTimeout(() => {
              copyBtn.textContent = originalText;
              copyBtn.classList.remove('bg-green-500');
            }, 2000);
          } catch (err) {
            console.error('Failed to copy:', err);
          }
        });
      }
    });
  });
}
