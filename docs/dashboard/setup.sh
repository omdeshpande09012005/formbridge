#!/bin/bash
# FormBridge Analytics Dashboard - Quick Setup Script
# Run this script to set up the analytics dashboard

set -e

echo "📊 FormBridge Analytics Dashboard - Quick Setup"
echo "================================================"
echo ""

# Check if config.js exists
if [ -f "dashboard/config.js" ]; then
    echo "✅ dashboard/config.js already exists"
    read -p "Do you want to recreate it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping config creation"
        echo ""
        exit 0
    fi
fi

# Copy config template
echo "📋 Creating dashboard/config.js from template..."
cp dashboard/config.example.js dashboard/config.js
echo "✅ Created: dashboard/config.js"
echo ""

# Determine OS and open editor
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🔧 Opening config.js in default editor (macOS)..."
    open dashboard/config.js
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🔧 Opening config.js in default editor (Linux)..."
    xdg-open dashboard/config.js
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "🔧 Opening config.js in VS Code (Windows)..."
    code dashboard/config.js
else
    echo "⚠️  Open dashboard/config.js in your text editor"
fi

echo ""
echo "📝 Next steps:"
echo "1. Update API_URL in config.js:"
echo "   - Development: http://127.0.0.1:3000"
echo "   - Production: https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/Prod"
echo ""
echo "2. Set DEFAULT_FORM_ID to your form ID (e.g., 'portfolio-contact')"
echo ""
echo "3. Optional: Add API_KEY if using production authentication"
echo ""
echo "4. Save and open dashboard in browser:"
echo "   open dashboard/index.html"
echo ""
echo "📖 See docs/DASHBOARD_README.md for detailed configuration"
