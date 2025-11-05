import os
import json
import uuid
import time
import boto3
import smtplib
import hmac
import hashlib
import csv
import io
from botocore.exceptions import ClientError
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
from secrets_loader import get_param, get_secret

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")
sqs = boto3.client("sqs")

# Configuration from environment (with SSM/Secrets fallback)
DDB_TABLE = os.environ.get("DDB_TABLE")
FORM_CONFIG_TABLE = os.environ.get("FORM_CONFIG_TABLE", "formbridge-config")
SES_SENDER = os.environ.get("SES_SENDER")  # verified sender email
FRONTEND_ORIGIN = os.environ.get("FRONTEND_ORIGIN", "https://omdeshpande09012005.github.io/formbridge/")
WEBHOOK_QUEUE_URL = os.environ.get("WEBHOOK_QUEUE_URL", "")  # optional SQS queue for webhooks
STAGE = os.environ.get("STAGE", "prod")  # Environment stage for SSM/Secrets paths
HMAC_VERSION = int(os.environ.get("HMAC_VERSION", "1"))  # For cache invalidation

# Configuration holders (loaded lazily)
_config_cache = {}


def load_config():
    """Load secure configuration from SSM/Secrets Manager with fallbacks."""
    global _config_cache
    
    if _config_cache:  # Already loaded
        return _config_cache
    
    # Load SES recipients from SSM or env var
    ses_recipients_str = get_param(
        f"/formbridge/{STAGE}/ses/recipients",
        decrypt=False,
        fallback_env="SES_RECIPIENTS"
    ) or os.environ.get("SES_RECIPIENTS", "")
    
    # Load brand configuration from SSM or env vars
    brand_name = get_param(
        f"/formbridge/{STAGE}/brand/name",
        decrypt=False,
        fallback_env="BRAND_NAME"
    ) or os.environ.get("BRAND_NAME", "FormBridge")
    
    brand_logo_url = get_param(
        f"/formbridge/{STAGE}/brand/logo_url",
        decrypt=False,
        fallback_env="BRAND_LOGO_URL"
    ) or os.environ.get("BRAND_LOGO_URL", "https://omdeshpande09012005.github.io/formbridge/assets/logo.svg")
    
    brand_primary_hex = get_param(
        f"/formbridge/{STAGE}/brand/primary_hex",
        decrypt=False,
        fallback_env="BRAND_PRIMARY_HEX"
    ) or os.environ.get("BRAND_PRIMARY_HEX", "#6D28D9")
    
    dashboard_url = get_param(
        f"/formbridge/{STAGE}/dashboard/url",
        decrypt=False,
        fallback_env="DASHBOARD_URL"
    ) or os.environ.get("DASHBOARD_URL", "https://omdeshpande09012005.github.io/formbridge/")
    
    # Load HMAC secret from Secrets Manager or env var
    hmac_secret = get_secret(
        f"formbridge/{STAGE}/HMAC_SECRET",
        fallback_env="HMAC_SECRET"
    ) or os.environ.get("HMAC_SECRET", "")
    
    # Parse recipients into list
    recipients = [r.strip() for r in ses_recipients_str.split(",") if r.strip()]
    
    _config_cache = {
        "ses_recipients": ses_recipients_str,
        "recipients": recipients,
        "brand_name": brand_name,
        "brand_logo_url": brand_logo_url,
        "brand_primary_hex": brand_primary_hex,
        "dashboard_url": dashboard_url,
        "hmac_secret": hmac_secret,
    }
    
    return _config_cache


# Configuration from environment
SES_RECIPIENTS = os.environ.get("SES_RECIPIENTS", "")

# HMAC signature configuration
HMAC_ENABLED = os.environ.get("HMAC_ENABLED", "false").lower() == "true"
HMAC_SKEW_SECS = int(os.environ.get("HMAC_SKEW_SECS", "300"))

# Email provider configuration
SES_PROVIDER = os.environ.get("SES_PROVIDER", "ses")  # "ses" or "mailhog"
MAILHOG_HOST = os.environ.get("MAILHOG_HOST", "localhost")
MAILHOG_PORT = int(os.environ.get("MAILHOG_PORT", "1025"))

# Initialize tables (these are always from env, not secrets)
table = dynamodb.Table(DDB_TABLE)
config_table = dynamodb.Table(FORM_CONFIG_TABLE)


def extract_ip_from_event(event):
    """Extract IP address from event context or headers."""
    # Try requestContext.http.sourceIp (ALB/API Gateway v2)
    request_context = event.get("requestContext", {})
    if request_context.get("http", {}).get("sourceIp"):
        return request_context["http"]["sourceIp"]
    
    # Try X-Forwarded-For header (CloudFront, proxy)
    headers = event.get("headers", {})
    x_forwarded_for = headers.get("X-Forwarded-For") or headers.get("x-forwarded-for")
    if x_forwarded_for:
        return x_forwarded_for.split(",")[0].strip()
    
    return ""


def extract_user_agent(event):
    """Extract User-Agent from headers."""
    headers = event.get("headers", {})
    return headers.get("User-Agent") or headers.get("user-agent") or ""


def send_email_via_ses(subject, body_text, body_html, recipients, sender, reply_to=None):
    """Send email via AWS SES."""
    try:
        ses_params = {
            "Source": sender,
            "Destination": {"ToAddresses": recipients},
            "Message": {
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {
                    "Text": {"Data": body_text, "Charset": "UTF-8"},
                    "Html": {"Data": body_html, "Charset": "UTF-8"},
                },
            },
        }
        
        if reply_to:
            ses_params["ReplyToAddresses"] = [reply_to]
        
        ses.send_email(**ses_params)
        print(f"Email sent via SES to {recipients}")
        return True
    except ClientError as e:
        print(f"SES send_email failed: {e}")
        return False


def send_email_via_mailhog(subject, body_text, body_html, recipients, sender, reply_to=None):
    """Send email via MailHog SMTP (for local development)."""
    try:
        # Create message
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = sender
        msg["To"] = ", ".join(recipients)
        if reply_to:
            msg["Reply-To"] = reply_to
        
        # Attach both plain text and HTML
        msg.attach(MIMEText(body_text, "plain"))
        msg.attach(MIMEText(body_html, "html"))
        
        # Send via SMTP
        with smtplib.SMTP(MAILHOG_HOST, MAILHOG_PORT) as server:
            # MailHog doesn't require authentication
            server.sendmail(sender, recipients, msg.as_string())
        
        print(f"Email sent via MailHog SMTP to {recipients}")
        return True
    except Exception as e:
        print(f"MailHog SMTP send_email failed: {e}")
        return False


def send_email(subject, body_text, body_html, recipients, sender, reply_to=None):
    """
    Send email using configured provider (SES or MailHog).
    
    Returns True if sent successfully, False otherwise.
    """
    if SES_PROVIDER == "mailhog":
        return send_email_via_mailhog(subject, body_text, body_html, recipients, sender, reply_to)
    else:
        # Default to SES
        return send_email_via_ses(subject, body_text, body_html, recipients, sender, reply_to)



def response(status_code, body, headers=None, is_csv=False):
    """Build HTTP response with CORS headers."""
    if is_csv:
        default_headers = {
            "Access-Control-Allow-Origin": FRONTEND_ORIGIN,
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, X-Api-Key, X-Timestamp, X-Signature",
            "Content-Type": "text/csv; charset=utf-8",
            "Content-Disposition": body.get("filename", "attachment; filename=export.csv"),
        }
        if headers:
            default_headers.update(headers)
        
        return {
            "statusCode": status_code,
            "headers": default_headers,
            "body": body.get("csv_data", ""),
            "isBase64Encoded": False,
        }
    else:
        default_headers = {
            "Access-Control-Allow-Origin": FRONTEND_ORIGIN,
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, X-Api-Key, X-Timestamp, X-Signature",
            "Content-Type": "application/json",
        }
        if headers:
            default_headers.update(headers)
        
        return {
            "statusCode": status_code,
            "headers": default_headers,
            "body": json.dumps(body),
        }


def verify_hmac_signature(event, raw_body):
    """
    Verify HMAC-SHA256 signature if enabled.
    
    Returns (is_valid, error_message).
    - If HMAC_ENABLED=false: returns (True, None) (no verification)
    - If valid: returns (True, None)
    - If invalid/missing: returns (False, error_message)
    """
    if not HMAC_ENABLED:
        return True, None
    
    config = load_config()
    hmac_secret = config.get("hmac_secret", "")
    
    if not hmac_secret:
        print("HMAC enabled but HMAC_SECRET not set")
        return False, "HMAC not properly configured"
    
    # Extract headers (case-insensitive)
    headers = event.get("headers", {})
    x_timestamp = None
    x_signature = None
    
    # Headers in API Gateway are lowercase
    for key, value in headers.items():
        if key.lower() == "x-timestamp":
            x_timestamp = value
        elif key.lower() == "x-signature":
            x_signature = value
    
    # Check for required headers
    if not x_timestamp:
        return False, "stale or missing timestamp"
    if not x_signature:
        return False, "missing signature"
    
    # Validate timestamp format and skew
    try:
        ts_int = int(x_timestamp)
        now = int(time.time())
        skew = abs(now - ts_int)
        
        if skew > HMAC_SKEW_SECS:
            print(f"Timestamp skew {skew}s exceeds threshold {HMAC_SKEW_SECS}s")
            return False, "stale or missing timestamp"
    except ValueError:
        print(f"Invalid timestamp format: {x_timestamp}")
        return False, "stale or missing timestamp"
    
    # Compute expected signature: hex(HMAC_SHA256(secret, timestamp + '\n' + body))
    try:
        message = f"{x_timestamp}\n{raw_body}".encode('utf-8')
        computed_sig = hmac.new(
            hmac_secret.encode('utf-8'),
            message,
            hashlib.sha256
        ).hexdigest()
        
        # Constant-time comparison
        if not hmac.compare_digest(computed_sig, x_signature.lower()):
            print("HMAC signature mismatch")
            return False, "invalid signature"
        
        print("HMAC signature verified successfully")
        return True, None
    except Exception as e:
        print(f"HMAC verification error: {e}")
        return False, "invalid signature"


def get_form_config(form_id):
    """
    Get per-form routing configuration from DynamoDB config table.
    
    Query: pk=FORM#<form_id>, sk=CONFIG#v1
    
    Returns merged config with defaults:
    {
        "recipients": ["email1@...","email2@..."],
        "subject_prefix": "[Prefix]",
        "brand_primary_hex": "#6D28D9",
        "dashboard_url": "https://...",
        "webhooks": [
            {"type": "slack", "url": "..."},
            {"type": "generic", "url": "...", "hmac_secret": "...", "hmac_header": "..."}
        ]
    }
    
    Falls back to global env defaults if config not found or table missing.
    """
    # Start with global defaults (loaded from SSM/Secrets or env)
    global_config = load_config()
    config = {
        "recipients": global_config.get("recipients", []),
        "subject_prefix": "",
        "brand_primary_hex": global_config.get("brand_primary_hex", "#6D28D9"),
        "dashboard_url": global_config.get("dashboard_url", "https://omdeshpande09012005.github.io/formbridge/"),
        "webhooks": [],
    }
    
    try:
        # Try to fetch form-specific config
        response = config_table.get_item(
            Key={
                "pk": f"FORM#{form_id}",
                "sk": "CONFIG#v1"
            }
        )
        
        item = response.get("Item", {})
        if item:
            # Merge config-table values over defaults
            if "recipients" in item and isinstance(item["recipients"], list):
                config["recipients"] = item["recipients"]
            if "subject_prefix" in item and isinstance(item["subject_prefix"], str):
                config["subject_prefix"] = item["subject_prefix"]
            if "brand_primary_hex" in item and isinstance(item["brand_primary_hex"], str):
                config["brand_primary_hex"] = item["brand_primary_hex"]
            if "dashboard_url" in item and isinstance(item["dashboard_url"], str):
                config["dashboard_url"] = item["dashboard_url"]
            if "webhooks" in item and isinstance(item["webhooks"], list):
                config["webhooks"] = item["webhooks"]
            
            print(f"Found form config for {form_id}: recipients={len(config['recipients'])}, webhooks={len(config['webhooks'])}, prefix={config['subject_prefix']}")
        else:
            print(f"No form config found for {form_id}, using global defaults")
    
    except Exception as e:
        print(f"Warning: Failed to fetch form config for {form_id}: {e}. Using global defaults.")
    
    return config







def render_email_html(context):
    """
    Render branded HTML email template with submission data.
    
    Args:
        context (dict): Template variables:
            - form_id, name, email, message, excerpt
            - page, id, ts, ip, ua
            - dashboard_url, brand_name, brand_logo_url, brand_primary_hex
    
    Returns:
        str: Rendered HTML email (with placeholders replaced)
        Returns plain text fallback if template not found or rendering fails
    """
    try:
        # Try to load template from package
        template_path = Path(__file__).parent / "email_templates" / "base.html"
        
        if not template_path.exists():
            print(f"Email template not found at {template_path}, using fallback HTML")
            return build_fallback_html(context)
        
        with open(template_path, 'r', encoding='utf-8') as f:
            template_html = f.read()
        
        # Replace placeholders with escaped values
        html = template_html
        for key, value in context.items():
            placeholder = f"{{{{{key}}}}}"
            # Escape HTML special characters
            escaped_value = str(value).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&#39;')
            html = html.replace(placeholder, escaped_value)
        
        print("Email template rendered successfully")
        return html
    
    except Exception as e:
        print(f"Error rendering email template: {e}")
        return build_fallback_html(context)


def build_fallback_html(context):
    """
    Build fallback HTML email if template rendering fails.
    Simple but professional HTML structure.
    """
    try:
        name = context.get('name', 'User')
        email = context.get('email', '')
        excerpt = context.get('excerpt', context.get('message', ''))
        dashboard_url = context.get('dashboard_url', '#')
        brand_name = context.get('brand_name', 'FormBridge')
        
        return f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial, sans-serif; background: #f8f9fa; padding: 20px; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; padding: 40px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
        <h2 style="color: #1a202c; margin-top: 0;">New {brand_name} Submission</h2>
        <p><strong>From:</strong> {name}</p>
        <p><strong>Email:</strong> {email}</p>
        <p><strong>Message:</strong></p>
        <p style="background: #f5f5f5; padding: 12px; border-radius: 4px;">{excerpt}</p>
        <p style="margin-top: 24px;">
            <a href="{dashboard_url}" style="display: inline-block; padding: 12px 28px; background: #6D28D9; color: white; text-decoration: none; border-radius: 6px; font-weight: bold;">View in Dashboard</a>
        </p>
        <p style="font-size: 12px; color: #64748b; margin-top: 24px; border-top: 1px solid #e2e8f0; padding-top: 12px;">
            This is an automated notification from {brand_name}. Please do not reply to this email.
        </p>
    </div>
</body>
</html>"""
    except Exception as e:
        print(f"Error building fallback HTML: {e}")
        return ""


def lambda_handler(event, context):
    """
    Route requests to /submit, /analytics, or /export endpoint.
    
    /submit: Handle contact form submissions
    /analytics: Return basic stats per form_id
    /export: Export submissions as CSV
    """
    print(f"Received event: {json.dumps(event, default=str)}")
    
    # Detect endpoint path (handle both API Gateway v1 and v2 formats)
    resource = event.get("resource") or event.get("rawPath", "")
    http_method = event.get("httpMethod") or event.get("requestContext", {}).get("http", {}).get("method", "")
    
    print(f"Route: {http_method} {resource}")
    
    # Route to appropriate handler
    if resource.endswith("/export") or "/export" in resource:
        return handle_export(event, context)
    elif resource.endswith("/analytics") or "/analytics" in resource:
        return handle_analytics(event, context)
    elif resource.endswith("/submit") or "/submit" in resource:
        return handle_submit(event, context)
    else:
        # Default to submit for backward compatibility
        return handle_submit(event, context)


def parse_request_body(event):
    """Parse JSON request body from event."""
    try:
        body = event.get("body", event)
        if isinstance(body, str):
            return json.loads(body)
        else:
            return body
    except Exception as e:
        print(f"JSON parse error: {e}")
        return None


def handle_analytics(event, context):
    """
    Handle POST /analytics - return form submission statistics.
    
    Request body:
    {
      "form_id": "contact-us"
    }
    
    Response:
    {
      "form_id": "contact-us",
      "total_submissions": 123,
      "last_7_days": [
        {"date":"YYYY-MM-DD","count":N},
        ...
      ],
      "latest_id": "uuid-or-null",
      "last_submission_ts": "ISO-or-null"
    }
    """
    print("Analytics request received")
    
    # Verify HMAC if enabled
    raw_body = event.get("body", "")
    if isinstance(raw_body, dict):
        raw_body = json.dumps(raw_body)
    
    is_valid, error_msg = verify_hmac_signature(event, raw_body)
    if not is_valid:
        return response(401, {"error": error_msg})
    
    # Parse request body
    payload = parse_request_body(event)
    if payload is None:
        return response(400, {"error": "Invalid JSON payload"})
    
    # Extract and validate form_id
    form_id = (payload.get("form_id") or "").strip()
    if not form_id:
        return response(400, {"error": "form_id required"})
    
    print(f"Fetching analytics for form_id: {form_id}")
    
    try:
        # Query DynamoDB for all submissions with this form_id
        # pk = FORM#{form_id}, sk begins with SUBMIT#
        # Paginate to avoid huge scans; cap at 10K items
        items = []
        last_evaluated_key = None
        max_items = 10000  # Cap for first pass; TODO: add GSI for better analytics queries
        
        while len(items) < max_items:
            query_params = {
                "KeyConditionExpression": "pk = :pk AND begins_with(sk, :sk_prefix)",
                "ExpressionAttributeValues": {
                    ":pk": f"FORM#{form_id}",
                    ":sk_prefix": "SUBMIT#",
                },
                "Limit": 100,  # Page size
            }
            
            if last_evaluated_key:
                query_params["ExclusiveStartKey"] = last_evaluated_key
            
            response_obj = table.query(**query_params)
            items.extend(response_obj.get("Items", []))
            
            last_evaluated_key = response_obj.get("LastEvaluatedKey")
            if not last_evaluated_key:
                break
            
            if len(items) >= max_items:
                print(f"Reached item limit of {max_items}; stopping pagination")
                break
        
        print(f"Retrieved {len(items)} submissions for {form_id}")
        
        # Compute statistics
        total_submissions = len(items)
        
        # Build 7-day window (UTC calendar days)
        from datetime import timedelta
        today_utc = datetime.utcnow().date()
        day_counts = {}
        for i in range(7):
            day = today_utc - timedelta(days=i)
            day_counts[day.isoformat()] = 0
        
        # Count submissions per day
        for item in items:
            ts_str = item.get("ts", "")
            try:
                # Parse ISO timestamp (e.g., "2025-11-05T12:00:32.069092Z")
                item_date = datetime.fromisoformat(ts_str.replace("Z", "+00:00")).date()
                date_key = item_date.isoformat()
                if date_key in day_counts:
                    day_counts[date_key] += 1
            except Exception as e:
                print(f"Error parsing timestamp {ts_str}: {e}")
        
        # Build last_7_days array (most recent first, chronological in response)
        last_7_days = []
        for i in range(6, -1, -1):  # 6 days ago to today
            day = today_utc - timedelta(days=i)
            day_key = day.isoformat()
            last_7_days.append({"date": day_key, "count": day_counts[day_key]})
        
        # Find latest submission (items are sorted by sk ascending, so last item is newest)
        latest_id = None
        last_submission_ts = None
        if items:
            latest_item = items[-1]  # Last item in list (highest sk)
            latest_id = latest_item.get("id")
            last_submission_ts = latest_item.get("ts")
        
        # Build response
        analytics_data = {
            "form_id": form_id,
            "total_submissions": total_submissions,
            "last_7_days": last_7_days,
            "latest_id": latest_id,
            "last_submission_ts": last_submission_ts,
        }
        
        return response(200, analytics_data)
    
    except ClientError as e:
        print(f"DynamoDB query failed: {e}")
        return response(500, {"error": "internal error querying analytics"})
    except Exception as e:
        print(f"Unexpected error in analytics: {e}")
        return response(500, {"error": "internal error"})


def handle_export(event, context):
    """
    Handle POST /export - export submissions as CSV.
    
    Request body:
    {
      "form_id": "contact-us",
      "days": 7
    }
    
    Response: text/csv with submissions
    """
    print("Export request received")
    
    # Verify HMAC if enabled
    raw_body = event.get("body", "")
    if isinstance(raw_body, dict):
        raw_body = json.dumps(raw_body)
    
    is_valid, error_msg = verify_hmac_signature(event, raw_body)
    if not is_valid:
        return response(401, {"error": error_msg})
    
    # Parse request body
    payload = parse_request_body(event)
    if payload is None:
        return response(400, {"error": "Invalid JSON payload"})
    
    # Extract and validate form_id
    form_id = (payload.get("form_id") or "").strip()
    if not form_id:
        return response(400, {"error": "form_id required"})
    
    # Extract days parameter (default 7, max 90)
    try:
        days = int(payload.get("days", 7))
        days = min(max(days, 1), 90)  # Clamp to [1, 90]
    except (ValueError, TypeError):
        days = 7
    
    print(f"Exporting {days} days for form_id: {form_id}")
    
    try:
        # Query DynamoDB for submissions
        items = []
        last_evaluated_key = None
        max_items = 10000  # Cap for CSV export
        cutoff_ts = datetime.utcnow() - timedelta(days=days)
        
        while len(items) < max_items:
            query_params = {
                "KeyConditionExpression": "pk = :pk AND begins_with(sk, :sk_prefix)",
                "ExpressionAttributeValues": {
                    ":pk": f"FORM#{form_id}",
                    ":sk_prefix": "SUBMIT#",
                },
                "Limit": 100,
            }
            
            if last_evaluated_key:
                query_params["ExclusiveStartKey"] = last_evaluated_key
            
            response_obj = table.query(**query_params)
            items.extend(response_obj.get("Items", []))
            
            last_evaluated_key = response_obj.get("LastEvaluatedKey")
            if not last_evaluated_key:
                break
            
            if len(items) >= max_items:
                print(f"Reached item limit of {max_items}; stopping pagination")
                break
        
        print(f"Retrieved {len(items)} submissions for export")
        
        # Filter by date range
        filtered_items = []
        for item in items:
            ts_str = item.get("ts", "")
            try:
                item_dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                if item_dt >= cutoff_ts:
                    filtered_items.append(item)
            except Exception as e:
                print(f"Error parsing timestamp {ts_str}: {e}")
        
        print(f"After date filter: {len(filtered_items)} submissions")
        
        # Build CSV
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Headers
        headers = ["id", "form_id", "name", "email", "message", "page", "ip", "ua", "ts"]
        writer.writerow(headers)
        
        # Rows
        for item in sorted(filtered_items, key=lambda x: x.get("ts", "")):  # Sort by timestamp
            writer.writerow([
                item.get("id", ""),
                item.get("form_id", ""),
                item.get("name", ""),
                item.get("email", ""),
                item.get("message", ""),
                item.get("page", ""),
                item.get("ip", ""),
                item.get("ua", ""),
                item.get("ts", ""),
            ])
        
        csv_data = output.getvalue()
        output.close()
        
        # Build filename
        now_str = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"attachment; filename=formbridge_{form_id}_{days}d_{now_str}.csv"
        
        response_headers = {}
        if len(filtered_items) >= max_items:
            response_headers["X-Row-Cap"] = str(max_items)
        
        return response(
            200,
            {
                "csv_data": csv_data,
                "filename": filename,
            },
            headers=response_headers,
            is_csv=True
        )
    
    except ClientError as e:
        print(f"DynamoDB query failed: {e}")
        return response(500, {"error": "internal error querying data"})
    except Exception as e:
        print(f"Unexpected error in export: {e}")
        return response(500, {"error": "internal error"})


def enqueue_webhooks(form_id, submission_data, webhooks_config):
    """
    Enqueue webhook dispatch job to SQS.
    
    Args:
        form_id: Form identifier
        submission_data: Form submission data (name, email, message, page, ip, ua, etc)
        webhooks_config: List of webhook configs [{type, url, hmac_secret?, ...}]
    
    Returns:
        bool: True if enqueued successfully or no webhooks; False if SQS error
    """
    if not WEBHOOK_QUEUE_URL:
        print("WEBHOOK_QUEUE_URL not configured, skipping webhook enqueue")
        return True  # Not an error - webhooks optional
    
    if not webhooks_config or len(webhooks_config) == 0:
        print(f"No webhooks configured for form_id={form_id}")
        return True  # Not an error
    
    try:
        # Build SQS message payload
        # Includes full submission data + webhooks array
        message_body = {
            "form_id": form_id,
            "id": submission_data.get("id"),
            "ts": submission_data.get("ts"),
            "name": submission_data.get("name"),
            "email": submission_data.get("email"),
            "message": submission_data.get("message"),
            "page": submission_data.get("page"),
            "ip": submission_data.get("ip"),
            "ua": submission_data.get("ua"),
            "brand_primary_hex": submission_data.get("brand_primary_hex"),
            "webhooks": webhooks_config,
        }
        
        # Send to SQS
        response = sqs.send_message(
            QueueUrl=WEBHOOK_QUEUE_URL,
            MessageBody=json.dumps(message_body),
            MessageAttributes={
                "form_id": {"StringValue": form_id, "DataType": "String"},
                "webhook_count": {"StringValue": str(len(webhooks_config)), "DataType": "Number"},
            }
        )
        
        message_id = response.get("MessageId")
        print(f"Enqueued webhooks: form_id={form_id}, webhooks={len(webhooks_config)}, message_id={message_id}")
        return True
    
    except Exception as e:
        print(f"Warning: Failed to enqueue webhooks for form_id={form_id}: {e}. Continuing without webhook dispatch.")
        return False  # Log but don't fail the submission


def handle_submit(event, context):
    """
    Handle POST /submit - store contact form submissions.
    
    Request body:
    {
      "form_id": "default",
      "name": "John Doe",
      "email": "john@example.com",
      "message": "Your message here",
      "page": "https://example.com/contact"
    }
    
    Returns: {"id": "<submission-id>"}
    """
    print("Submit request received")
    
    # Verify HMAC if enabled
    raw_body = event.get("body", "")
    if isinstance(raw_body, dict):
        raw_body = json.dumps(raw_body)
    
    is_valid, error_msg = verify_hmac_signature(event, raw_body)
    if not is_valid:
        return response(401, {"error": error_msg})
    
    # Parse request body
    payload = parse_request_body(event)
    if payload is None:
        return response(400, {"error": "Invalid JSON payload"})
    
    # Extract and validate fields
    form_id = (payload.get("form_id") or "default").strip()
    name = (payload.get("name") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    message = (payload.get("message") or "").strip()
    page = (payload.get("page") or "").strip()
    
    # Validate: all core fields required
    if not name:
        return response(400, {"error": "name required"})
    if not email:
        return response(400, {"error": "email required"})
    if not message:
        return response(400, {"error": "message required"})
    
    # Basic email validation
    if "@" not in email or "." not in email.split("@")[-1]:
        return response(400, {"error": "invalid email format"})
    
    # Capture request metadata
    ip = extract_ip_from_event(event)
    ua = extract_user_agent(event)
    
    # Generate submission identifiers
    ts = datetime.utcnow().isoformat() + "Z"
    submission_id = str(uuid.uuid4())
    
    # TODO: Add analytics fields for future /analytics endpoint
    # - form_id: track which form instance
    # - page: track referrer page
    # - ts: track submission time for analytics queries
    # - ua: track user agent for browser/device analytics
    # - ip: track geography/source (consider PII implications)
    
    # Build DynamoDB item with richer schema
    item = {
        "pk": f"FORM#{form_id}",
        "sk": f"SUBMIT#{ts}#{submission_id}",
        "id": submission_id,
        "form_id": form_id,
        "name": name,
        "email": email,
        "message": message,
        "page": page,
        "ua": ua,
        "ip": ip,
        "ts": ts,
        "ttl": int(time.time()) + (90 * 86400),  # Auto-delete after 90 days
    }
    
    # Persist to DynamoDB
    try:
        table.put_item(Item=item)
        print(f"Stored submission {submission_id} to DynamoDB")
    except ClientError as e:
        print(f"DynamoDB put_item failed: {e}")
        return response(500, {"error": "internal error storing submission"})
    
    # Send email notification via SES or MailHog
    # Get per-form routing config (fallback to global defaults)
    form_config = get_form_config(form_id)
    global_config = load_config()
    
    configured_recipients = form_config.get("recipients", global_config.get("recipients", []))
    subject_prefix = form_config.get("subject_prefix", "")
    configured_brand_hex = form_config.get("brand_primary_hex", global_config.get("brand_primary_hex", "#6D28D9"))
    configured_dashboard_url = form_config.get("dashboard_url", global_config.get("dashboard_url", "https://omdeshpande09012005.github.io/formbridge/"))
    brand_name = global_config.get("brand_name", "FormBridge")
    brand_logo_url = global_config.get("brand_logo_url", "https://omdeshpande09012005.github.io/formbridge/assets/logo.svg")
    
    # Build plain-text email (fallback for all clients)
    subject_prefix_str = f"{subject_prefix} " if subject_prefix else ""
    email_subject = f"{subject_prefix_str}[{brand_name}] New submission on {form_id} — {name}"
    email_body_text = (
        f"Form ID: {form_id}\n"
        f"Submission ID: {submission_id}\n"
        f"Timestamp: {ts}\n\n"
        f"From: {name}\n"
        f"Email: {email}\n"
        f"Page: {page}\n\n"
        f"Message:\n{message}\n"
    )
    
    # Build HTML email using branded template
    email_body_html = ""
    if configured_recipients and SES_SENDER:
        try:
            # Create excerpt (first ~240 chars, no newlines)
            excerpt = message.replace('\n', ' ').replace('\r', ' ')
            if len(excerpt) > 240:
                excerpt = excerpt[:240] + "..."
            
            # Build template context (with form-specific branding and routing)
            template_context = {
                'form_id': form_id,
                'name': name,
                'email': email,
                'message': message,
                'excerpt': excerpt,
                'page': page,
                'id': submission_id,
                'ts': ts,
                'ip': ip,
                'ua': ua,
                'dashboard_url': configured_dashboard_url,
                'brand_name': brand_name,
                'brand_logo_url': brand_logo_url,
                'brand_primary_hex': configured_brand_hex,  # Per-form color
                'subject_prefix': subject_prefix,  # For badge display
            }
            
            # Render branded HTML
            email_body_html = render_email_html(template_context)
        except Exception as e:
            print(f"Error rendering branded email template: {e}")
            # Fall back to basic HTML if rendering fails
            email_body_html = ""
    
    # Send email if recipients are configured
    email_sent = False
    if configured_recipients and SES_SENDER:
        email_sent = send_email(
            subject=email_subject,
            body_text=email_body_text,
            body_html=email_body_html,
            recipients=configured_recipients,
            sender=SES_SENDER,
            reply_to=email
        )
        if not email_sent:
            # Tolerant: log but don't fail the submission since DynamoDB write succeeded
            print(f"Warning: Email notification failed for submission {submission_id}")
    else:
        print("Email not configured (missing SES_SENDER or recipients for this form)")
    
    # Enqueue webhooks if configured for this form
    # This happens asynchronously via SQS, so doesn't block the response
    webhooks_config = form_config.get("webhooks", [])
    if webhooks_config:
        submission_data = {
            "id": submission_id,
            "ts": ts,
            "name": name,
            "email": email,
            "message": message,
            "page": page,
            "ip": ip,
            "ua": ua,
            "brand_primary_hex": configured_brand_hex,
        }
        enqueue_webhooks(form_id, submission_data, webhooks_config)
    
    # Return success with submission ID
    return response(200, {"id": submission_id})
