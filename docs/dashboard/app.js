/**
 * FormBridge Analytics Dashboard - Main Application
 *
 * Reads configuration from config.js (ES module) and displays analytics for a given form_id.
 * Supports both development (local) and production (AWS) APIs.
 *
 * Configuration:
 * - API_URL: Base URL of the analytics endpoint (e.g., http://127.0.0.1:3000 or https://api.example.com)
 * - API_KEY: Optional API key for production environments (e.g., from API Gateway)
 * - DEFAULT_FORM_ID: Default form ID to load on page load
 */

import { CONFIG } from './config.js';

let analyticsChart = null;

/**
 * Initialize the dashboard on page load
 */
document.addEventListener('DOMContentLoaded', async () => {
    updateEnvBadge();
    setupEventListeners();
    
    // Load default form ID if set
    const formIdInput = document.getElementById('formIdInput');
    if (CONFIG.DEFAULT_FORM_ID) {
        formIdInput.value = CONFIG.DEFAULT_FORM_ID;
        await loadAnalytics();
    }
});

/**
 * Update environment badge based on API URL
 */
function updateEnvBadge() {
    const badge = document.getElementById('envBadge');
    const isDev = CONFIG.API_URL.includes('localhost') || CONFIG.API_URL.includes('127.0.0.1');
    
    badge.textContent = isDev ? 'DEV' : 'PROD';
    badge.className = 'env-badge ' + (isDev ? 'dev' : 'prod');
}

/**
 * Setup event listeners
 */
function setupEventListeners() {
    const formIdInput = document.getElementById('formIdInput');
    
    // Allow Enter key to submit
    formIdInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            loadAnalytics();
        }
    });
}

/**
 * Load and display analytics for the selected form ID
 */
async function loadAnalytics() {
    const formIdInput = document.getElementById('formIdInput');
    const formId = formIdInput.value.trim();
    
    if (!formId) {
        showToast('Please enter a form ID', 'info');
        return;
    }
    
    const refreshBtn = document.getElementById('refreshBtn');
    const kpiGrid = document.getElementById('kpiGrid');
    
    // Disable button and show loading state
    refreshBtn.disabled = true;
    refreshBtn.innerHTML = '<span class="loading-spinner"></span> Loading...';
    kpiGrid.classList.add('loading');
    
    try {
        const response = await fetch(`${CONFIG.API_URL}/analytics`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(CONFIG.API_KEY && { 'X-Api-Key': CONFIG.API_KEY })
            },
            body: JSON.stringify({ form_id: formId })
        });
        
        if (!response.ok) {
            const errorData = await response.text();
            
            if (response.status === 403) {
                showToast('API key required/invalid. Check your config.js', 'error');
            } else if (response.status === 404) {
                showToast('Form ID not found. No submissions yet.', 'info');
                clearDashboard();
            } else if (response.status >= 500) {
                showToast(`Server error (${response.status}). Please try again.`, 'error');
            } else {
                showToast(`Error: ${response.status} - ${errorData}`, 'error');
            }
            clearDashboard();
            return;
        }
        
        const data = await response.json();
        
        // Validate response structure
        if (!data.form_id || !Array.isArray(data.last_7_days)) {
            throw new Error('Invalid response structure from API');
        }
        
        // Update dashboard with data
        updateDashboard(data);
        showToast(`Loaded data for form: ${formId}`, 'success');
        
    } catch (error) {
        console.error('Error loading analytics:', error);
        
        // Distinguish between network errors and others
        if (error instanceof TypeError && error.message.includes('fetch')) {
            showToast('Network error. Check your API URL and CORS settings.', 'error');
        } else if (error.message.includes('CORS')) {
            showToast('CORS error. API may not allow requests from this origin.', 'error');
        } else {
            showToast('Error loading analytics: ' + error.message, 'error');
        }
        
        clearDashboard();
    } finally {
        // Re-enable button
        refreshBtn.disabled = false;
        refreshBtn.textContent = 'Refresh';
        kpiGrid.classList.remove('loading');
    }
}

/**
 * Update dashboard with analytics data
 */
function updateDashboard(data) {
    // Update KPIs
    document.getElementById('totalSubmissions').textContent = 
        (data.total_submissions || 0).toLocaleString();
    
    document.getElementById('latestId').textContent = 
        data.latest_id || '—';
    
    document.getElementById('lastSubmissionTime').textContent = 
        data.last_submission_ts 
            ? formatDateTime(data.last_submission_ts)
            : '—';
    
    // Update chart
    updateChart(data.last_7_days);
    
    // Update table
    updateTable(data.last_7_days);
}

/**
 * Update the line chart with data
 */
function updateChart(last7Days) {
    const ctx = document.getElementById('analyticsChart').getContext('2d');
    
    // Destroy existing chart if it exists
    if (analyticsChart) {
        analyticsChart.destroy();
    }
    
    const labels = last7Days.map(item => item.date);
    const dataPoints = last7Days.map(item => item.count);
    
    analyticsChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Submissions',
                data: dataPoints,
                borderColor: '#667eea',
                backgroundColor: 'rgba(102, 126, 234, 0.1)',
                borderWidth: 3,
                fill: true,
                tension: 0.4,
                pointRadius: 6,
                pointBackgroundColor: '#667eea',
                pointBorderColor: '#fff',
                pointBorderWidth: 2,
                pointHoverRadius: 8,
                pointHoverBackgroundColor: '#764ba2'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: true,
                    position: 'top'
                },
                filler: {
                    propagate: true
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 1,
                        callback: function(value) {
                            return Math.round(value);
                        }
                    }
                }
            }
        }
    });
}

/**
 * Update the table with daily breakdown
 */
function updateTable(last7Days) {
    const tableBody = document.getElementById('tableBody');
    
    if (!last7Days || last7Days.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="2" class="empty-state">No data available</td></tr>';
        return;
    }
    
    tableBody.innerHTML = last7Days.map(item => `
        <tr>
            <td>${item.date}</td>
            <td>${item.count}</td>
        </tr>
    `).join('');
}

/**
 * Clear dashboard to empty state
 */
function clearDashboard() {
    document.getElementById('totalSubmissions').textContent = '—';
    document.getElementById('latestId').textContent = '—';
    document.getElementById('lastSubmissionTime').textContent = '—';
    
    const tableBody = document.getElementById('tableBody');
    tableBody.innerHTML = '<tr><td colspan="2" class="empty-state">No data. Check your form ID and API configuration.</td></tr>';
    
    if (analyticsChart) {
        analyticsChart.destroy();
        analyticsChart = null;
    }
    
    const canvas = document.getElementById('analyticsChart');
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
}

/**
 * Show a toast notification
 */
function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    toast.setAttribute('role', 'status');
    toast.setAttribute('aria-live', 'polite');
    
    document.body.appendChild(toast);
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        toast.classList.add('hide');
        setTimeout(() => toast.remove(), 300);
    }, 5000);
}

/**
 * Format ISO timestamp to readable format
 */
function formatDateTime(isoString) {
    try {
        const date = new Date(isoString);
        return date.toLocaleString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    } catch (error) {
        return isoString;
    }
}
