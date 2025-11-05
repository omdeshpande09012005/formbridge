import os
import json
import uuid
import boto3
from botocore.exceptions import ClientError
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")

# Configuration from environment
DDB_TABLE = os.environ.get("DDB_TABLE")
SES_SENDER = os.environ.get("SES_SENDER")  # verified sender email
SES_RECIPIENTS = os.environ.get("SES_RECIPIENTS", "")  # comma-separated recipients
FRONTEND_ORIGIN = os.environ.get("FRONTEND_ORIGIN", "https://omdeshpande09012005.github.io")

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


def response(status_code, body, headers=None):
    """Build HTTP response with CORS headers."""
    default_headers = {
        "Access-Control-Allow-Origin": FRONTEND_ORIGIN,
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
        "Content-Type": "application/json",
    }
    if headers:
        default_headers.update(headers)
    
    return {
        "statusCode": status_code,
        "headers": default_headers,
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    """
    Handle contact form submissions with richer contract and metadata capture.
    
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
    print(f"Received event: {json.dumps(event, default=str)}")
    
    # Parse request body
    try:
        body = event.get("body", event)
        if isinstance(body, str):
            payload = json.loads(body)
        else:
            payload = body
    except Exception as e:
        print(f"JSON parse error: {e}")
        return response(400, {"error": "Invalid JSON payload"})
    
    # Extract and validate fields
    form_id = (payload.get("form_id") or "default").strip()
    name = (payload.get("name") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    message = (payload.get("message") or "").strip()
    page = (payload.get("page") or "").strip()
    
    # Validate: message is required
    if not message:
        return response(400, {"error": "message required"})
    
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
    }
    
    # Persist to DynamoDB
    try:
        table.put_item(Item=item)
        print(f"Stored submission {submission_id} to DynamoDB")
    except ClientError as e:
        print(f"DynamoDB put_item failed: {e}")
        return response(500, {"error": "internal error storing submission"})
    
    # Send email notification via SES
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
        try:
            ses_params = {
                "Source": SES_SENDER,
                "Destination": {"ToAddresses": RECIPIENTS},
                "Message": {
                    "Subject": {"Data": email_subject, "Charset": "UTF-8"},
                    "Body": {
                        "Text": {"Data": email_body_text, "Charset": "UTF-8"},
                        "Html": {"Data": email_body_html, "Charset": "UTF-8"},
                    },
                },
            }
            
            # Add Reply-To if submitter email is present
            if email:
                ses_params["ReplyToAddresses"] = [email]
            
            ses.send_email(**ses_params)
            print(f"Email sent successfully for submission {submission_id}")
            email_sent = True
        except ClientError as e:
            print(f"SES send_email failed: {e}")
            # Tolerant: log but don't fail the submission since DynamoDB write succeeded
    else:
        print("SES not configured (missing SES_SENDER or SES_RECIPIENTS)")
    
    # Return success with submission ID
    return response(200, {"id": submission_id})
