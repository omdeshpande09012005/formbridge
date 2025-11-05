.PHONY: help local-up local-down local-bootstrap local-test local-logs local-ps clean route-seed-local webhook-seed-local

help:
	@echo "FormBridge Local Development Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  local-up            Start all local services (LocalStack, MailHog, DynamoDB Admin, Frontend)"
	@echo "  local-down          Stop all local services"
	@echo "  local-ps            Show running containers"
	@echo "  local-logs          View logs from all services"
	@echo "  local-bootstrap     Bootstrap DynamoDB table and seed data"
	@echo "  route-seed-local    Bootstrap form routing config (formbridge-config table)"
	@echo "  webhook-seed-local  Bootstrap webhook configurations for all forms"
	@echo "  local-test          Run test submissions against local API"
	@echo "  local-clean         Remove stopped containers and volumes"
	@echo ""
	@echo "Development:"
	@echo "  sam-api             Start SAM local API server (port 3000)"
	@echo "  help                Show this help message"

# Start all services
local-up:
	@echo "🚀 Starting FormBridge local services..."
	docker compose -f local/docker-compose.yml up -d
	@echo ""
	@echo "✅ Services started!"
	@echo ""
	@echo "📊 Access:"
	@echo "   Frontend:      http://localhost:8080"
	@echo "   DynamoDB:      http://localhost:8001"
	@echo "   MailHog:       http://localhost:8025"
	@echo "   LocalStack:    http://localhost:4566"
	@echo ""
	@echo "⏳ Waiting for LocalStack..."
	@sleep 2
	@make local-bootstrap

# Stop all services
local-down:
	@echo "🛑 Stopping FormBridge local services..."
	docker compose -f local/docker-compose.yml down
	@echo "✅ Services stopped"

# Show container status
local-ps:
	@echo "📦 FormBridge containers:"
	docker compose -f local/docker-compose.yml ps

# View logs
local-logs:
	docker compose -f local/docker-compose.yml logs -f

# Bootstrap DynamoDB table
local-bootstrap:
	@echo "📋 Bootstrapping DynamoDB..."
	bash local/scripts/bootstrap_local.sh

# Bootstrap form routing config table
route-seed-local:
	@echo "📋 Bootstrapping form routing config (formbridge-config)..."
	@echo "Checking if LocalStack is running..."
	@if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then \
		echo "✅ LocalStack is running"; \
		echo ""; \
		echo "Creating formbridge-config table..."; \
		aws dynamodb create-table \
			--table-name formbridge-config \
			--attribute-definitions \
				AttributeName=pk,AttributeType=S \
				AttributeName=sk,AttributeType=S \
			--key-schema \
				AttributeName=pk,KeyType=HASH \
				AttributeName=sk,KeyType=RANGE \
			--billing-mode PAY_PER_REQUEST \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 2>/dev/null || echo "Table may already exist"; \
		echo ""; \
		echo "Seeding form configurations..."; \
		aws dynamodb put-item \
			--table-name formbridge-config \
			--item '{ \
				"pk": {"S": "FORM#contact-us"}, \
				"sk": {"S": "CONFIG#v1"}, \
				"recipients": {"L": [{"S": "admin@mailhog.local"}]}, \
				"subject_prefix": {"S": "[Contact]"}, \
				"brand_primary_hex": {"S": "#6D28D9"}, \
				"dashboard_url": {"S": "http://localhost:8000/dashboard?form=contact-us"} \
			}' \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 && echo "✓ Seeded: contact-us"; \
		aws dynamodb put-item \
			--table-name formbridge-config \
			--item '{ \
				"pk": {"S": "FORM#careers"}, \
				"sk": {"S": "CONFIG#v1"}, \
				"recipients": {"L": [{"S": "hr@mailhog.local"}]}, \
				"subject_prefix": {"S": "[Careers]"}, \
				"brand_primary_hex": {"S": "#0EA5E9"}, \
				"dashboard_url": {"S": "http://localhost:8000/dashboard?form=careers"} \
			}' \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 && echo "✓ Seeded: careers"; \
		aws dynamodb put-item \
			--table-name formbridge-config \
			--item '{ \
				"pk": {"S": "FORM#support"}, \
				"sk": {"S": "CONFIG#v1"}, \
				"recipients": {"L": [{"S": "support@mailhog.local"}]}, \
				"subject_prefix": {"S": "[Support]"}, \
				"brand_primary_hex": {"S": "#10B981"}, \
				"dashboard_url": {"S": "http://localhost:8000/dashboard?form=support"} \
			}' \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 && echo "✓ Seeded: support"; \
		echo ""; \
		echo "✅ Form routing config ready!"; \
	else \
		echo "❌ LocalStack is not running"; \
		echo "Start it with: make local-up"; \
		exit 1; \
	fi

# Bootstrap webhook configurations
webhook-seed-local:
	@echo "📋 Bootstrapping webhook configurations (formbridge-webhook-queue)..."
	@echo "Checking if LocalStack is running..."
	@if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then \
		echo "✅ LocalStack is running"; \
		echo ""; \
		echo "Creating formbridge-webhook-queue..."; \
		aws sqs create-queue \
			--queue-name formbridge-webhook-queue \
			--attributes VisibilityTimeout=60,MessageRetentionPeriod=345600 \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 2>/dev/null || echo "Queue may already exist"; \
		echo ""; \
		echo "Creating formbridge-webhook-dlq..."; \
		aws sqs create-queue \
			--queue-name formbridge-webhook-dlq \
			--attributes VisibilityTimeout=60,MessageRetentionPeriod=1209600 \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 2>/dev/null || echo "DLQ may already exist"; \
		echo ""; \
		echo "Seeding webhook configurations for forms..."; \
		aws dynamodb put-item \
			--table-name formbridge-config \
			--item '{ \
				"pk": {"S": "FORM#contact-us"}, \
				"sk": {"S": "CONFIG#v1"}, \
				"recipients": {"L": [{"S": "admin@mailhog.local"}]}, \
				"subject_prefix": {"S": "[Contact]"}, \
				"brand_primary_hex": {"S": "#6D28D9"}, \
				"dashboard_url": {"S": "http://localhost:8000/dashboard?form=contact-us"}, \
				"webhooks": {"L": [{"M": {"type": {"S": "generic"}, "url": {"S": "https://webhook.site/contact-us-test"}}}]} \
			}' \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 && echo "✓ Seeded: contact-us (generic webhook)"; \
		aws dynamodb put-item \
			--table-name formbridge-config \
			--item '{ \
				"pk": {"S": "FORM#careers"}, \
				"sk": {"S": "CONFIG#v1"}, \
				"recipients": {"L": [{"S": "hr@mailhog.local"}]}, \
				"subject_prefix": {"S": "[Careers]"}, \
				"brand_primary_hex": {"S": "#0EA5E9"}, \
				"dashboard_url": {"S": "http://localhost:8000/dashboard?form=careers"}, \
				"webhooks": {"L": [{"M": {"type": {"S": "generic"}, "url": {"S": "https://webhook.site/careers-test"}}}]} \
			}' \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 && echo "✓ Seeded: careers (generic webhook)"; \
		aws dynamodb put-item \
			--table-name formbridge-config \
			--item '{ \
				"pk": {"S": "FORM#support"}, \
				"sk": {"S": "CONFIG#v1"}, \
				"recipients": {"L": [{"S": "support@mailhog.local"}]}, \
				"subject_prefix": {"S": "[Support]"}, \
				"brand_primary_hex": {"S": "#10B981"}, \
				"dashboard_url": {"S": "http://localhost:8000/dashboard?form=support"}, \
				"webhooks": {"L": [{"M": {"type": {"S": "generic"}, "url": {"S": "https://webhook.site/support-test"}}}]} \
			}' \
			--endpoint-url http://localhost:4566 \
			--region ap-south-1 && echo "✓ Seeded: support (generic webhook)"; \
		echo ""; \
		echo "📌 Note: webhook.site endpoints are for testing only"; \
		echo "   To add real Slack/Discord webhooks:"; \
		echo "   1. Get Slack/Discord webhook URLs"; \
		echo "   2. Update DynamoDB items with actual URLs"; \
		echo "   3. Set type to 'slack' or 'discord'"; \
		echo ""; \
		echo "✅ Webhook configurations ready!"; \
	else \
		echo "❌ LocalStack is not running"; \
		echo "Start it with: make local-up"; \
		exit 1; \
	fi

# Run test submissions
local-test:
	@echo "🧪 Running test submissions..."
	@echo ""
	@echo "Test 1: Simple submission"
	curl -X POST http://localhost:3000/submit \
		-H 'Content-Type: application/json' \
		-d '{ \
			"form_id": "portfolio-contact", \
			"name": "Alice Johnson", \
			"email": "alice@example.com", \
			"message": "I am interested in your portfolio services" \
		}' || echo "API not running. Start with: sam local start-api --port 3000"
	@echo ""
	@echo ""
	@echo "Test 2: Analytics query"
	curl -X POST http://localhost:3000/analytics \
		-H 'Content-Type: application/json' \
		-d '{"form_id": "portfolio-contact"}' || echo "API not running"
	@echo ""
	@echo ""
	@echo "✅ Check results:"
	@echo "   DynamoDB:  http://localhost:8001"
	@echo "   MailHog:   http://localhost:8025"

# Start SAM API server
sam-api:
	@echo "🚀 Starting SAM local API (port 3000)..."
	@echo "Make sure LocalStack is running: make local-up"
	@echo ""
	cd backend && sam local start-api --port 3000

# Clean up
local-clean:
	@echo "🧹 Cleaning up Docker resources..."
	docker compose -f local/docker-compose.yml down -v
	@echo "✅ Cleaned up"

# Quick start: up + bootstrap + api
.PHONY: start
start: local-up sam-api

# Stop everything
.PHONY: stop
stop: local-down
