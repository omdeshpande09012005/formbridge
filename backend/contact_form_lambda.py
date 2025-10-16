import os
import json
import logging
from uuid import uuid4
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# use env vars
DDB_TABLE = os.environ.get('DDB_TABLE', 'contact-form-submissions-local')
SES_SENDER = os.environ.get('SES_SENDER', 'no-reply@example.com')
SES_RECIPIENT = os.environ.get('SES_RECIPIENT', 'admin@example.com')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

# create clients lazily (SAM local provides AWS creds if configured)
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
ses = boto3.client('ses', region_name=AWS_REGION)

def validate_payload(payload):
    if not isinstance(payload, dict):
        return False, "Invalid JSON body"
    name = payload.get('name')
    email = payload.get('email')
    message = payload.get('message')
    if not name or not email or not message:
        return False, "Missing required fields: name, email, message"
    return True, None

def lambda_handler(event, context):
    """
    Expects event from API Gateway proxy (POST /submit with JSON body).
    Stores submission in DynamoDB and sends an email via SES.
    When running locally (SAM), SES send is logged but not required to succeed.
    """
    logger.info("Received event: %s", event)

    # API Gateway proxy integration provides body as a string
    body_raw = event.get('body') or '{}'
    try:
        body = json.loads(body_raw)
    except Exception:
        return {"statusCode": 400, "body": json.dumps({"error": "Invalid JSON"})}

    ok, err = validate_payload(body)
    if not ok:
        return {"statusCode": 400, "body": json.dumps({"error": err})}

    submission_id = str(uuid4())
    item = {
        "submissionId": submission_id,
        "name": body['name'],
        "email": body['email'],
        "message": body['message'],
        "createdAt": datetime.utcnow().isoformat()
    }

    # Write to DynamoDB
    try:
        table = dynamodb.Table(DDB_TABLE)
        table.put_item(Item=item)
        logger.info("Stored submission %s in DynamoDB table %s", submission_id, DDB_TABLE)
    except Exception as e:
        logger.exception("Failed to write to DynamoDB: %s", e)
        return {"statusCode": 500, "body": json.dumps({"error": "Failed to store submission"})}

    # Send email via SES (when deployed). Locally we'll log and skip if SES isn't available.
    try:
        # If running in SAM local without AWS creds, this may fail; catch that gracefully.
        subject = f"New contact form submission from {body['name']}"
        body_text = f"From: {body['name']} <{body['email']}>\n\n{body['message']}\n\nSubmission ID: {submission_id}"
        # In production this actually sends; in local dev it may raise, which we catch and log.
        ses.send_email(
            Source=SES_SENDER,
            Destination={'ToAddresses': [SES_RECIPIENT]},
            Message={
                'Subject': {'Data': subject},
                'Body': {'Text': {'Data': body_text}}
            }
        )
        logger.info("SES send_email succeeded for submission %s", submission_id)
    except Exception as e:
        logger.warning("SES send skipped or failed in local environment: %s", e)

    return {"statusCode": 200, "body": json.dumps({"id": submission_id})}
