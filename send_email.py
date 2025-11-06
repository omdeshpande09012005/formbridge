#!/usr/bin/env python3
"""
FormBridge Email Sender
Sends an email using AWS SES with the base.html template
"""

import boto3
import sys
import json
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path

# Configuration
SENDER_EMAIL = "omdeshpande123456789@gmail.com"
# Note: In AWS SES sandbox mode, both sender and recipient must be verified
# Using verified sender as recipient for testing
RECIPIENT_EMAIL = "omdeshpande123456789@gmail.com"  # Change this to om.deshpande@mitwpu.edu.in once verified in SES
TEMPLATE_PATH = Path(__file__).parent / "email_templates" / "base.html"

# AWS Configuration
AWS_REGION = "ap-south-1"  # Update to your region
SUBJECT = "FormBridge Email Template Test"

def load_template():
    """Load the HTML email template"""
    try:
        with open(TEMPLATE_PATH, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        print(f"Error: Template not found at {TEMPLATE_PATH}")
        sys.exit(1)

def send_email(sender, recipient, subject, html_body):
    """
    Send email using AWS SES
    
    Args:
        sender: Sender email address
        recipient: Recipient email address
        subject: Email subject
        html_body: HTML email body
    
    Returns:
        bool: True if email sent successfully, False otherwise
    """
    try:
        # Initialize SES client
        ses_client = boto3.client('ses', region_name=AWS_REGION)
        
        print(f"📧 Sending email...")
        print(f"   From: {sender}")
        print(f"   To: {recipient}")
        print(f"   Subject: {subject}")
        print(f"   Region: {AWS_REGION}")
        print()
        
        # Send email
        response = ses_client.send_email(
            Source=sender,
            Destination={'ToAddresses': [recipient]},
            Message={
                'Subject': {'Data': subject, 'Charset': 'utf-8'},
                'Body': {'Html': {'Data': html_body, 'Charset': 'utf-8'}}
            }
        )
        
        message_id = response['MessageId']
        print("✅ Email sent successfully!")
        print(f"📬 Message ID: {message_id}")
        print()
        
        return True
        
    except Exception as e:
        print(f"❌ Error sending email: {str(e)}")
        print()
        print("Troubleshooting tips:")
        print("1. Ensure AWS credentials are configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)")
        print("2. Verify the sender email is verified in AWS SES")
        print("3. If recipient is not in production, add it to SES approved recipients")
        print("4. Check AWS SES is in the correct region")
        return False

def main():
    """Main function"""
    print("🚀 FormBridge Email Sender")
    print("=" * 50)
    print()
    
    # Load template
    print("📄 Loading email template...")
    html_template = load_template()
    print(f"✓ Template loaded ({len(html_template)} characters)")
    print()
    
    # Send email
    success = send_email(
        sender=SENDER_EMAIL,
        recipient=RECIPIENT_EMAIL,
        subject=SUBJECT,
        html_body=html_template
    )
    
    if success:
        print("🎉 Email delivery initiated!")
        print(f"   Check {RECIPIENT_EMAIL} for the email")
        sys.exit(0)
    else:
        print("⚠️  Email sending failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
