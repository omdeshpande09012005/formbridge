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

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")

# Configuration from environment
DDB_TABLE = os.environ.get("DDB_TABLE")
SES_SENDER = os.environ.get("SES_SENDER")  # verified sender email
SES_RECIPIENTS = os.environ.get("SES_RECIPIENTS", "")  # comma-separated recipients
FRONTEND_ORIGIN = os.environ.get("FRONTEND_ORIGIN", "https://omdeshpande09012005.github.io")

# HMAC signature configuration
HMAC_ENABLED = os.environ.get("HMAC_ENABLED", "false").lower() == "true"
HMAC_SECRET = os.environ.get("HMAC_SECRET", "")
HMAC_SKEW_SECS = int(os.environ.get("HMAC_SKEW_SECS", "300"))

# Email provider configuration
SES_PROVIDER = os.environ.get("SES_PROVIDER", "ses")  # "ses" or "mailhog"
MAILHOG_HOST = os.environ.get("MAILHOG_HOST", "localhost")
MAILHOG_PORT = int(os.environ.get("MAILHOG_PORT", "1025"))

# Parse recipients into list
RECIPIENTS = [r.strip() for r in SES_RECIPIENTS.split(",") if r.strip()]

table = dynamodb.Table(DDB_TABLE)


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
    
    if not HMAC_SECRET:
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
            HMAC_SECRET.encode('utf-8'),
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
    # Build plain-text email with all fields
    email_subject = f"New contact form submission from {name}"
    email_body_text = (
        f"Form ID: {form_id}\n"
        f"Submission ID: {submission_id}\n"
        f"Timestamp: {ts}\n\n"
        f"From: {name}\n"
        f"Email: {email}\n"
        f"Page: {page}\n\n"
        f"Message:\n{message}\n"
    )
    
    email_body_html = f"""
    <html><body style="font-family:sans-serif;color:#333;">
      <h2>New Contact Form Submission</h2>
      <p><strong>Form ID:</strong> {form_id}</p>
      <p><strong>Submission ID:</strong> {submission_id}</p>
      <p><strong>Timestamp:</strong> {ts}</p>
      <hr>
      <p><strong>From:</strong> {name}</p>
      <p><strong>Email:</strong> {email}</p>
      <p><strong>Page:</strong> {page}</p>
      <hr>
      <p><strong>Message:</strong></p>
      <pre style="background:#f5f5f5;padding:12px;border-radius:4px;">{message}</pre>
    </body></html>
    """
    
    # Send email if recipients are configured
    email_sent = False
    if RECIPIENTS and SES_SENDER:
        email_sent = send_email(
            subject=email_subject,
            body_text=email_body_text,
            body_html=email_body_html,
            recipients=RECIPIENTS,
            sender=SES_SENDER,
            reply_to=email
        )
        if not email_sent:
            # Tolerant: log but don't fail the submission since DynamoDB write succeeded
            print(f"Warning: Email notification failed for submission {submission_id}")
    else:
        print("Email not configured (missing SES_SENDER or SES_RECIPIENTS)")
    
    # Return success with submission ID
    return response(200, {"id": submission_id})
