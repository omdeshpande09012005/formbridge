import os
import json
import uuid
import boto3
from botocore.exceptions import ClientError
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
ses = boto3.client("ses")

DDB_TABLE = os.environ.get("DDB_TABLE")
SES_RECIPIENT = os.environ.get("SES_RECIPIENT")  # main receiver
# comma separated allowed senders (emails you verified)
SES_ALLOWED_SENDERS = os.environ.get("SES_ALLOWED_SENDERS", "")
ALLOWED_SENDERS = {e.strip().lower() for e in SES_ALLOWED_SENDERS.split(",") if e.strip()}

table = dynamodb.Table(DDB_TABLE)

def lambda_handler(event, context):
    print("Event:", event)
    # If API Gateway proxy integration: body is a JSON string in event['body']
    try:
        body = event.get("body", event) if isinstance(event, dict) else event
        if isinstance(body, str):
            payload = json.loads(body)
        else:
            payload = body
    except Exception:
        return response(400, {"error": "Invalid JSON payload"})

    name = (payload.get("name") or "").strip()
    email = (payload.get("email") or "").strip().lower()
    message = (payload.get("message") or "").strip()

    if not (name and email and message):
        return response(400, {"error": "name, email and message are required"})

    # Optional: enforce allowed senders
    if ALLOWED_SENDERS and email not in ALLOWED_SENDERS:
        return response(403, {"error": "Sender not allowed"})

    # Save to DynamoDB
    item_id = str(uuid.uuid4())
    item = {
        "submissionId": item_id,
        "name": name,
        "email": email,
        "message": message,
        "createdAt": datetime.utcnow().isoformat() + "Z"
    }
    try:
        table.put_item(Item=item)
    except ClientError as e:
        print("DDB put_item failed:", e)
        return response(500, {"error": "internal error storing submission"})

    # Send email via SES
    subject = f"New contact form submission from {name}"
    body_text = f"From: {name} <{email}>\n\nMessage:\n{message}\n\nID: {item_id}"
    body_html = f"""
    <html><body>
      <h3>New contact form submission</h3>
      <p><strong>From:</strong> {name} &lt;{email}&gt;</p>
      <p><strong>Message:</strong></p>
      <pre>{message}</pre>
      <p><small>ID: {item_id}</small></p>
    </body></html>
    """

    try:
        # SES send_email (simple)
        ses.send_email(
            Source=email,                      # must be a verified FROM in SES sandbox
            Destination={"ToAddresses": [SES_RECIPIENT]},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {
                    "Text": {"Data": body_text, "Charset": "UTF-8"},
                    "Html": {"Data": body_html, "Charset": "UTF-8"},
                },
            },
        )
    except ClientError as e:
        # If SEND fails, log and optionally retry or fallback to using SES_RECIPIENT as Source
        print("SES send_email failed:", e)
        # fallback: try sending from the verified main address (SES_RECIPIENT) and include original sender in body
        try:
            ses.send_email(
                Source=SES_RECIPIENT,
                Destination={"ToAddresses": [SES_RECIPIENT]},
                Message={
                    "Subject": {"Data": f"[Forwarded] {subject}", "Charset": "UTF-8"},
                    "Body": {"Text": {"Data": body_text, "Charset": "UTF-8"}}
                },
            )
        except ClientError as e2:
            print("SES fallback failed:", e2)
            # We saved to DB already, return 202 or 500 per your choice
            return response(500, {"error": "failed to send email"})

    return response(200, {"id": item_id})


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }
