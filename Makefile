.PHONY: help local-up local-down local-bootstrap local-test local-logs local-ps clean

help:
	@echo "FormBridge Local Development Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  local-up         Start all local services (LocalStack, MailHog, DynamoDB Admin, Frontend)"
	@echo "  local-down       Stop all local services"
	@echo "  local-ps         Show running containers"
	@echo "  local-logs       View logs from all services"
	@echo "  local-bootstrap  Bootstrap DynamoDB table and seed data"
	@echo "  local-test       Run test submissions against local API"
	@echo "  local-clean      Remove stopped containers and volumes"
	@echo ""
	@echo "Development:"
	@echo "  sam-api          Start SAM local API server (port 3000)"
	@echo "  help             Show this help message"

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
