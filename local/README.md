# FormBridge Local Demo Pack

Run FormBridge completely locally with **zero AWS billing**. Includes LocalStack, MailHog, DynamoDB Admin, and frontend.

---

## 🚀 Quick Start (5 minutes)

### Step 1: Start Services
```bash
cd w:\PROJECTS\formbridge
docker compose -f local/docker-compose.yml up -d
```

### Step 2: Bootstrap (Create Table & Seed Data)
```bash
bash local/scripts/bootstrap_local.sh
```

### Step 3: Start SAM API Server
```bash
cd backend
sam local start-api --port 3000
```

### Step 4: Test Submission
```bash
# In another terminal
curl -X POST http://localhost:3000/submit \
  -H 'Content-Type: application/json' \
  -d '{
    "form_id": "demo-test",
    "name": "John Doe",
    "email": "john@example.com",
    "message": "Test message from local demo"
  }'
```

### Step 5: Verify

**Check DynamoDB:** http://localhost:8001
- Table: `contact-form-submissions`
- Should see your submission

**Check Email:** http://localhost:8025
- Should see notification email from MailHog

**Check Frontend:** http://localhost:8080
- Visit contact form and test submission

---

## 📊 Services & Ports

| Service | Port | Purpose |
|---------|------|---------|
| LocalStack Gateway | 4566 | AWS services (Lambda, API Gateway, DynamoDB, SES) |
| DynamoDB Admin | 8001 | Web UI for DynamoDB exploration |
| MailHog SMTP | 1025 | Local email capture |
| MailHog Web UI | 8025 | View captured emails |
| Frontend (Vite) | 8080 | Local portfolio website |
| SAM API | 3000 | Local Lambda API (run separately) |

---

## � Analytics Dashboard (Local)

View form submission metrics with the local dashboard.

### Setup
```bash
# 1. Copy config template
cp dashboard/config.example.js dashboard/config.js

# 2. Ensure config.js has:
#    API_URL: 'http://127.0.0.1:3000'
#    DEFAULT_FORM_ID: 'my-portfolio'

# 3. Start dashboard server (terminal 3)
node server.js
# OR use Python: python -m http.server 8080 --directory .

# 4. Open dashboard
#    http://localhost:8080/dashboard/
```

### Usage
1. Ensure SAM API is running on port 3000 (`sam local start-api --port 3000`)
2. Open http://localhost:8080/dashboard/
3. Enter form ID (default: 'my-portfolio')
4. Click Refresh to load analytics
5. View 7-day trend chart and daily breakdown

### Verify Integration
```bash
# 1. Submit a form
curl -X POST http://localhost:3000/submit \
  -H 'Content-Type: application/json' \
  -d '{
    "form_id": "my-portfolio",
    "name": "Test",
    "email": "test@example.com",
    "message": "Test message"
  }'

# 2. Open dashboard
#    http://localhost:8080/dashboard/

# 3. Enter form ID 'my-portfolio' and click Refresh
# 4. Chart should show 1 submission for today
```

---

## �📋 Commands Reference

### Start Everything
```bash
# Start all services in background
docker compose -f local/docker-compose.yml up -d

# View logs
docker compose -f local/docker-compose.yml logs -f

# Stop everything
docker compose -f local/docker-compose.yml down

# Clean up volumes
docker compose -f local/docker-compose.yml down -v
```

### Bootstrap DynamoDB
```bash
# Run once to create table and seed test data
bash local/scripts/bootstrap_local.sh

# Or use awslocal directly
docker exec formbridge-localstack awslocal dynamodb list-tables --endpoint-url http://localhost:4566
```

### Run Lambda Locally
```bash
# Terminal 1: Start API
cd backend
sam local start-api --port 3000

# Terminal 2: Test
curl -X POST http://localhost:3000/submit \
  -H 'Content-Type: application/json' \
  -d '{"form_id":"test","name":"John","email":"john@example.com","message":"Hello"}'
```

### View Emails
```bash
# Open MailHog web UI
open http://localhost:8025  # macOS
# or
xdg-open http://localhost:8025  # Linux
# or manually navigate in browser
```

### Explore DynamoDB
```bash
# Open DynamoDB Admin
open http://localhost:8001

# Or query directly
docker exec formbridge-localstack awslocal dynamodb scan \
  --table-name contact-form-submissions \
  --endpoint-url http://localhost:4566
```

---

## 🔧 Configuration

### Lambda Environment Variables (Local)

When running `sam local start-api`, the Lambda uses these from `template.yaml`:

```yaml
Environment:
  Variables:
    DDB_TABLE: contact-form-submissions
    DDB_ENDPOINT: http://localstack:4566  # Inside Docker network
    SES_PROVIDER: mailhog
    MAILHOG_HOST: mailhog
    MAILHOG_PORT: 1025
    FRONTEND_ORIGIN: http://localhost:8080
```

### Frontend API Endpoint (Local)

Update your React component to use local API:

```javascript
// In your Contact.jsx or similar
const API_ENDPOINT = process.env.VITE_API_ENDPOINT || 'http://localhost:3000';

// During development
const SUBMIT_URL = `${API_ENDPOINT}/submit`;
```

Or use the docker-compose environment variable:
```
VITE_API_ENDPOINT=http://localhost:3000
```

---

## 📧 Email Testing

### LocalStack SES + MailHog

The Lambda is configured to use MailHog for local SMTP:

```python
# In contact_form_lambda.py (local mode)
SMTP_HOST = os.environ.get("MAILHOG_HOST", "mailhog")
SMTP_PORT = int(os.environ.get("MAILHOG_PORT", "1025"))

# Send email via MailHog instead of SES
```

### View Emails

1. Go to http://localhost:8025
2. All emails sent via MailHog appear here
3. No actual emails are sent

---

## 🐳 Docker Compose Services

### LocalStack
- **Image:** `localstack/localstack:latest`
- **Services:** Lambda, API Gateway, DynamoDB, SES, S3, IAM, CloudWatch, STS
- **Endpoint:** http://localhost:4566
- **Health Check:** Verifies Kinesis is responding

### MailHog
- **Image:** `mailhog/mailhog:latest`
- **SMTP Port:** 1025
- **Web UI:** 8025
- **Purpose:** Captures all emails sent via SMTP

### DynamoDB Admin
- **Image:** `aaronshaf/dynamodb-admin:latest`
- **Port:** 8001
- **Connects to:** LocalStack DynamoDB
- **Purpose:** Web UI to explore tables and items

### Frontend
- **Image:** `node:18-alpine`
- **Port:** 8080
- **Command:** `npm run dev` (Vite dev server)
- **Purpose:** Local portfolio website with hot reload

---

## 🧪 Test Scenarios

### Scenario 1: Simple Form Submission

```bash
# Terminal 1
cd backend && sam local start-api --port 3000

# Terminal 2
curl -X POST http://localhost:3000/submit \
  -H 'Content-Type: application/json' \
  -d '{
    "form_id": "portfolio-contact",
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "message": "I am interested in your services"
  }'

# Check DynamoDB Admin: http://localhost:8001
# Check MailHog: http://localhost:8025
```

### Scenario 2: Analytics Query

```bash
# Terminal 2 (after submissions)
curl -X POST http://localhost:3000/analytics \
  -H 'Content-Type: application/json' \
  -d '{"form_id": "portfolio-contact"}'

# Response shows statistics for last 7 days
```

### Scenario 3: Full Workflow

1. Start services: `docker compose -f local/docker-compose.yml up -d`
2. Bootstrap: `bash local/scripts/bootstrap_local.sh`
3. Start API: `cd backend && sam local start-api --port 3000`
4. Visit frontend: http://localhost:8080
5. Submit form via web UI
6. Check email in MailHog: http://localhost:8025
7. Check database in DynamoDB Admin: http://localhost:8001

---

## ⚙️ Troubleshooting

### LocalStack Won't Start
```bash
# Check if port 4566 is in use
lsof -i :4566

# Kill the process or use a different port
# Or restart Docker
docker restart formbridge-localstack
```

### MailHog Not Receiving Emails
```bash
# Check if MailHog is running
docker ps | grep mailhog

# Check network connectivity
docker network ls
docker network inspect formbridge-local

# Verify SMTP config in Lambda
echo $MAILHOG_HOST  # Should be 'mailhog' (Docker hostname)
echo $MAILHOG_PORT  # Should be 1025
```

### DynamoDB Admin Shows No Tables
```bash
# Verify table was created
docker exec formbridge-localstack awslocal dynamodb list-tables

# If missing, run bootstrap again
bash local/scripts/bootstrap_local.sh

# Or create manually
docker exec formbridge-localstack awslocal dynamodb create-table \
  --table-name contact-form-submissions \
  --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
```

### SAM API Port Already in Use
```bash
# Use a different port
sam local start-api --port 3001

# Update frontend to use port 3001
export VITE_API_ENDPOINT=http://localhost:3001
```

---

## 🪟 Windows/PowerShell Notes

### Start Services
```powershell
# Use forward slashes or escape backslashes
docker compose -f local\docker-compose.yml up -d

# Or from WSL
wsl bash -c "cd /mnt/w/PROJECTS/formbridge && docker compose -f local/docker-compose.yml up -d"
```

### Run Bootstrap Script
```powershell
# Option 1: Use WSL
wsl bash local/scripts/bootstrap_local.sh

# Option 2: Use Git Bash
bash local/scripts/bootstrap_local.sh

# Option 3: Use Docker directly
docker exec formbridge-localstack bash -c "awslocal dynamodb list-tables"
```

### Start SAM API
```powershell
# From WSL
wsl bash -c "cd /mnt/w/PROJECTS/formbridge/backend && sam local start-api --port 3000"

# Or native (if SAM CLI is installed)
cd w:\PROJECTS\formbridge\backend
sam local start-api --port 3000
```

### Test with curl (PowerShell)
```powershell
# Simple test
$body = @{
    form_id = "demo"
    name = "John"
    email = "john@example.com"
    message = "Test"
} | ConvertTo-Json

curl.exe -X POST http://localhost:3000/submit `
  -H "Content-Type: application/json" `
  -d $body
```

---

## 🎯 Demo Script (All-in-One)

```bash
#!/bin/bash
# Run everything for a complete local demo

cd $(dirname "$0")

echo "🚀 Starting FormBridge Local Demo..."
echo ""

# Start services
echo "1. Starting Docker services..."
docker compose -f local/docker-compose.yml up -d
sleep 2

# Bootstrap
echo "2. Bootstrapping DynamoDB..."
bash local/scripts/bootstrap_local.sh
echo ""

# Start SAM API
echo "3. Starting SAM API (port 3000)..."
cd backend
sam local start-api --port 3000 &
SAM_PID=$!
sleep 3

echo ""
echo "✅ Demo is running!"
echo ""
echo "🌐 Open in browser:"
echo "   Frontend:      http://localhost:8080"
echo "   DynamoDB:      http://localhost:8001"
echo "   MailHog:       http://localhost:8025"
echo ""
echo "🧪 Test API:"
echo "   curl -X POST http://localhost:3000/submit \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"form_id\":\"test\",\"name\":\"John\",\"email\":\"john@example.com\",\"message\":\"Hello\"}'"
echo ""
echo "To stop: press Ctrl+C or run 'docker compose -f local/docker-compose.yml down'"
echo ""

# Keep running
wait $SAM_PID
```

---

## 📚 Additional Resources

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [SAM Local Development](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-using-local-testing.html)
- [MailHog Documentation](https://github.com/mailhog/MailHog)
- [DynamoDB Admin](https://github.com/aaronshaf/dynamodb-admin)

---

## 🔗 Related Files

- Backend configuration: `backend/template.yaml`
- Lambda code: `backend/contact_form_lambda.py`
- Frontend configuration: See `README_IMPLEMENTATION.md` for API endpoint setup
- Environment variables: Defined in `docker-compose.yml`

---

**Happy local testing! 🚀**

