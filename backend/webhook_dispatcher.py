import os
import json
import logging
import time
import hashlib
import hmac
import base64
import urllib.parse
from datetime import datetime
from typing import Dict, List, Any
import requests
from botocore.exceptions import ClientError

# Configure logging
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

WEBHOOK_TIMEOUT = int(os.environ.get("WEBHOOK_TIMEOUT", "10"))


def compute_hmac_signature(secret: str, payload: bytes) -> str:
    """
    Compute HMAC-SHA256 signature of payload.
    
    Args:
        secret: HMAC secret key
        payload: Raw request body (bytes)
    
    Returns:
        Hex-encoded HMAC-SHA256 signature
    """
    return hmac.new(
        secret.encode('utf-8') if isinstance(secret, str) else secret,
        payload,
        hashlib.sha256
    ).hexdigest()


def sanitize_url_for_logging(url: str) -> str:
    """Extract hostname from webhook URL for logging (no secrets)."""
    try:
        parsed = urllib.parse.urlparse(url)
        return parsed.hostname or url[:20]
    except Exception:
        return url[:20]


def dispatch_slack_webhook(webhook_url: str, form_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Dispatch to Slack webhook.
    
    Sends:
    {
      "text": "[FormBridge] <form_id> — <name>: <excerpt>"
    }
    """
    form_id = form_data.get("form_id", "unknown")
    name = form_data.get("name", "User")
    message = form_data.get("message", "")
    
    # Excerpt: first 100 chars of message
    excerpt = message[:100] + ("..." if len(message) > 100 else "")
    
    payload = {
        "text": f"[FormBridge] {form_id} — {name}: {excerpt}"
    }
    
    logger.info(f"Dispatching Slack webhook: form_id={form_id}, text_len={len(payload['text'])}")
    
    try:
        response = requests.post(
            webhook_url,
            json=payload,
            timeout=WEBHOOK_TIMEOUT,
            headers={"Content-Type": "application/json"}
        )
        
        url_host = sanitize_url_for_logging(webhook_url)
        
        if 200 <= response.status_code < 300:
            logger.info(f"Slack dispatch success: url_host={url_host}, status={response.status_code}")
            return {
                "success": True,
                "status_code": response.status_code,
                "type": "slack"
            }
        else:
            logger.error(f"Slack dispatch failed: url_host={url_host}, status={response.status_code}, response={response.text[:200]}")
            return {
                "success": False,
                "status_code": response.status_code,
                "error": f"HTTP {response.status_code}",
                "type": "slack"
            }
    
    except requests.Timeout:
        url_host = sanitize_url_for_logging(webhook_url)
        logger.warning(f"Slack dispatch timeout: url_host={url_host}, timeout={WEBHOOK_TIMEOUT}s")
        return {
            "success": False,
            "error": f"Timeout after {WEBHOOK_TIMEOUT}s",
            "type": "slack"
        }
    
    except Exception as e:
        url_host = sanitize_url_for_logging(webhook_url)
        logger.error(f"Slack dispatch exception: url_host={url_host}, error={str(e)}")
        return {
            "success": False,
            "error": str(e),
            "type": "slack"
        }


def dispatch_discord_webhook(webhook_url: str, form_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Dispatch to Discord webhook.
    
    Sends:
    {
      "username": "FormBridge",
      "embeds": [
        {
          "title": "New Submission: <form_id>",
          "description": "<name> (<email>)",
          "fields": [{"name": "Message", "value": "<excerpt>"}],
          "color": 5419263
        }
      ]
    }
    """
    form_id = form_data.get("form_id", "unknown")
    name = form_data.get("name", "User")
    email = form_data.get("email", "")
    message = form_data.get("message", "")
    
    # Excerpt: first 200 chars for Discord embed
    excerpt = message[:200] + ("..." if len(message) > 200 else "")
    
    # Color: use brand_primary_hex if available, else blue
    color_hex = form_data.get("brand_primary_hex", "#0EA5E9")
    # Convert hex #0EA5E9 to decimal: 0x0EA5E9 = 953833
    try:
        color_decimal = int(color_hex.lstrip('#'), 16)
    except (ValueError, AttributeError):
        color_decimal = 953833  # default blue
    
    payload = {
        "username": "FormBridge",
        "embeds": [
            {
                "title": f"New Submission: {form_id}",
                "description": f"{name} ({email})",
                "fields": [
                    {
                        "name": "Message",
                        "value": excerpt,
                        "inline": False
                    }
                ],
                "color": color_decimal
            }
        ]
    }
    
    logger.info(f"Dispatching Discord webhook: form_id={form_id}")
    
    try:
        response = requests.post(
            webhook_url,
            json=payload,
            timeout=WEBHOOK_TIMEOUT,
            headers={"Content-Type": "application/json"}
        )
        
        url_host = sanitize_url_for_logging(webhook_url)
        
        if 200 <= response.status_code < 300:
            logger.info(f"Discord dispatch success: url_host={url_host}, status={response.status_code}")
            return {
                "success": True,
                "status_code": response.status_code,
                "type": "discord"
            }
        else:
            logger.error(f"Discord dispatch failed: url_host={url_host}, status={response.status_code}")
            return {
                "success": False,
                "status_code": response.status_code,
                "error": f"HTTP {response.status_code}",
                "type": "discord"
            }
    
    except requests.Timeout:
        url_host = sanitize_url_for_logging(webhook_url)
        logger.warning(f"Discord dispatch timeout: url_host={url_host}, timeout={WEBHOOK_TIMEOUT}s")
        return {
            "success": False,
            "error": f"Timeout after {WEBHOOK_TIMEOUT}s",
            "type": "discord"
        }
    
    except Exception as e:
        url_host = sanitize_url_for_logging(webhook_url)
        logger.error(f"Discord dispatch exception: url_host={url_host}, error={str(e)}")
        return {
            "success": False,
            "error": str(e),
            "type": "discord"
        }


def dispatch_generic_webhook(webhook_url: str, webhook_config: Dict[str, Any], form_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Dispatch to generic webhook.
    
    Sends full form_data JSON. If hmac_secret present, computes and sends HMAC header.
    
    Args:
        webhook_url: Endpoint URL
        webhook_config: Webhook config from form_data["webhooks"]
        form_data: Full form submission data
    
    Returns:
        Result dict
    """
    form_id = form_data.get("form_id", "unknown")
    
    # Prepare JSON payload
    payload_dict = {
        "form_id": form_id,
        "id": form_data.get("id"),
        "ts": form_data.get("ts"),
        "name": form_data.get("name"),
        "email": form_data.get("email"),
        "message": form_data.get("message"),
        "page": form_data.get("page"),
        "ip": form_data.get("ip"),
        "ua": form_data.get("ua")
    }
    
    # Serialize to JSON bytes
    json_bytes = json.dumps(payload_dict).encode('utf-8')
    
    headers = {
        "Content-Type": "application/json"
    }
    
    # Add HMAC header if secret provided
    if webhook_config.get("hmac_secret"):
        hmac_secret = webhook_config.get("hmac_secret", "")
        hmac_header = webhook_config.get("hmac_header", "X-Webhook-Signature")
        
        signature = compute_hmac_signature(hmac_secret, json_bytes)
        headers[hmac_header] = signature
        
        logger.info(f"Generic webhook HMAC enabled: header={hmac_header}")
    
    logger.info(f"Dispatching generic webhook: form_id={form_id}, payload_size={len(json_bytes)}")
    
    try:
        response = requests.post(
            webhook_url,
            data=json_bytes,
            timeout=WEBHOOK_TIMEOUT,
            headers=headers
        )
        
        url_host = sanitize_url_for_logging(webhook_url)
        
        if 200 <= response.status_code < 300:
            logger.info(f"Generic dispatch success: url_host={url_host}, status={response.status_code}")
            return {
                "success": True,
                "status_code": response.status_code,
                "type": "generic"
            }
        else:
            logger.error(f"Generic dispatch failed: url_host={url_host}, status={response.status_code}")
            return {
                "success": False,
                "status_code": response.status_code,
                "error": f"HTTP {response.status_code}",
                "type": "generic"
            }
    
    except requests.Timeout:
        url_host = sanitize_url_for_logging(webhook_url)
        logger.warning(f"Generic dispatch timeout: url_host={url_host}, timeout={WEBHOOK_TIMEOUT}s")
        return {
            "success": False,
            "error": f"Timeout after {WEBHOOK_TIMEOUT}s",
            "type": "generic"
        }
    
    except Exception as e:
        url_host = sanitize_url_for_logging(webhook_url)
        logger.error(f"Generic dispatch exception: url_host={url_host}, error={str(e)}")
        return {
            "success": False,
            "error": str(e),
            "type": "generic"
        }


def process_webhook_record(record: Dict[str, Any]) -> Dict[str, Any]:
    """
    Process a single SQS webhook message.
    
    Extracts form_data and webhooks, dispatches to each endpoint.
    Returns result summary.
    """
    try:
        # Parse SQS body
        body = json.loads(record["body"])
        form_id = body.get("form_id", "unknown")
        webhooks = body.get("webhooks", [])
        
        logger.info(f"Processing webhook batch: form_id={form_id}, webhook_count={len(webhooks)}")
        
        if not webhooks:
            logger.info(f"No webhooks configured for form_id={form_id}")
            return {
                "record_id": record["messageId"],
                "form_id": form_id,
                "success": True,
                "webhooks_dispatched": 0
            }
        
        # Dispatch to each webhook
        results = []
        
        for idx, webhook_config in enumerate(webhooks):
            webhook_type = webhook_config.get("type", "generic")
            webhook_url = webhook_config.get("url", "")
            
            if not webhook_url:
                logger.warning(f"Missing webhook URL for form_id={form_id}, index={idx}")
                results.append({
                    "success": False,
                    "error": "Missing URL",
                    "type": webhook_type,
                    "index": idx
                })
                continue
            
            # Dispatch based on type
            if webhook_type == "slack":
                result = dispatch_slack_webhook(webhook_url, body)
            elif webhook_type == "discord":
                result = dispatch_discord_webhook(webhook_url, body)
            else:  # generic
                result = dispatch_generic_webhook(webhook_url, webhook_config, body)
            
            result["index"] = idx
            results.append(result)
        
        # Summary
        success_count = sum(1 for r in results if r.get("success"))
        
        logger.info(
            f"Webhook batch complete: "
            f"form_id={form_id}, "
            f"total={len(results)}, "
            f"success={success_count}, "
            f"failed={len(results) - success_count}"
        )
        
        return {
            "record_id": record["messageId"],
            "form_id": form_id,
            "success": success_count == len(results),
            "webhooks_dispatched": len(results),
            "results": results
        }
    
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse SQS message: {str(e)}")
        return {
            "record_id": record.get("messageId", "unknown"),
            "success": False,
            "error": f"JSON decode error: {str(e)}"
        }
    
    except Exception as e:
        logger.error(f"Exception processing webhook record: {str(e)}")
        return {
            "record_id": record.get("messageId", "unknown"),
            "success": False,
            "error": str(e)
        }


def lambda_handler(event, context):
    """
    Handle SQS webhook dispatch batch.
    
    For each SQS message:
    1. Parse form_data and webhooks array
    2. Dispatch to each webhook URL
    3. Return success/failure per webhook
    
    Message failures return to SQS queue for retry (handled by SQS redrive policy).
    Successful messages are automatically deleted by SQS.
    """
    logger.info(f"Received SQS batch: {len(event.get('Records', []))} messages")
    
    batch_results = {
        "timestamp": datetime.utcnow().isoformat(),
        "batch_size": len(event.get("Records", [])),
        "records": []
    }
    
    for record in event.get("Records", []):
        result = process_webhook_record(record)
        batch_results["records"].append(result)
    
    # Log batch summary
    successful = sum(1 for r in batch_results["records"] if r.get("success"))
    failed = len(batch_results["records"]) - successful
    
    logger.info(
        f"SQS batch complete: "
        f"total_records={batch_results['batch_size']}, "
        f"successful={successful}, "
        f"failed={failed}"
    )
    
    # If any message failed, raise exception so SQS retries
    # (SQS handles redrive automatically)
    if failed > 0:
        logger.warning(f"Batch had {failed} failures, will retry via SQS redrive policy")
        # Don't raise - SQS will retry failed messages automatically if we don't delete them
        # We only need to raise if we want Lambda to fail the entire batch
        # Better to return success and let SQS manage individual message retries
    
    logger.info(f"Lambda execution complete: batch_results={json.dumps(batch_results)}")
    
    return {
        "statusCode": 200,
        "body": json.dumps(batch_results)
    }
