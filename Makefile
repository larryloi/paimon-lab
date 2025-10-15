include Makefile.env

# Default values
ct ?=
IMAGE ?= flink:1.20-paimon-1.2.0
COMPOSE_FILE ?= docker-compose.yml
DOCKER_PLATFORM ?= linux/amd64

# Helper to conditionally add container argument
CONTAINER_ARG = $(if $(ct),$(ct),)

# Colors for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Disable echoing of commands
.SILENT:

##@ Help

.PHONY: help
help: ## Display available commands
	echo "Available commands:"
	awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	echo ""
	echo "Environment variables:"
	echo "  ct=<container>    Target specific container (e.g., make up ct=minio)"
	echo "  IMAGE=<image>     Override Docker image name"
	echo "  DOCKER_PLATFORM=<platform>  Override Docker platform"

##@ Docker Build

.PHONY: build
build: ## Build the Flink Docker image
	echo "$(BLUE)Building Docker image: $(IMAGE)$(NC)"
	docker build --platform $(DOCKER_PLATFORM) -t $(IMAGE) ./
	echo "$(GREEN)✓ Build completed$(NC)"

.PHONY: build.nocache
build.nocache: ## Build the Flink Docker image without cache
	echo "$(BLUE)Building Docker image without cache: $(IMAGE)$(NC)"
	docker build --no-cache --platform $(DOCKER_PLATFORM) -t $(IMAGE) ./
	echo "$(GREEN)✓ Build completed$(NC)"

.PHONY: pull
pull: ## Pull all images defined in docker-compose
	echo "$(BLUE)Pulling Docker images...$(NC)"
	docker compose pull
	echo "$(GREEN)✓ Images pulled$(NC)"

##@ Container Management

.PHONY: up
up: ## Start services (use ct=<service> for specific service)
	echo "$(BLUE)Starting services$(if $(ct), ($(ct)),)...$(NC)"
	docker compose up -d $(CONTAINER_ARG)
	echo "$(GREEN)✓ Services started$(NC)"
	make ps

.PHONY: up.build
up.build: ## Start services and rebuild images
	echo "$(BLUE)Starting services with build$(if $(ct), ($(ct)),)...$(NC)"
	docker compose up -d --build $(CONTAINER_ARG)
	echo "$(GREEN)✓ Services started$(NC)"
	make ps

.PHONY: stop
stop: ## Stop services (use ct=<service> for specific service)
	echo "$(BLUE)Stopping services$(if $(ct), ($(ct)),)...$(NC)"
	docker compose stop $(CONTAINER_ARG)
	echo "$(GREEN)✓ Services stopped$(NC)"

.PHONY: restart
restart: ## Restart services (use ct=<service> for specific service)
	echo "$(BLUE)Restarting services$(if $(ct), ($(ct)),)...$(NC)"
	docker compose restart $(CONTAINER_ARG)
	echo "$(GREEN)✓ Services restarted$(NC)"

.PHONY: down
down: ## Stop and remove services (use ct=<service> for specific service)
	echo "$(BLUE)Stopping and removing services$(if $(ct), ($(ct)),)...$(NC)"
	docker compose down $(CONTAINER_ARG)
	echo "$(GREEN)✓ Services stopped and removed$(NC)"

.PHONY: down.all
down.all: ## Stop and remove all services, networks, and volumes
	echo "$(YELLOW)Stopping and removing all services, networks, and volumes...$(NC)"
	docker compose down --volumes --remove-orphans
	echo "$(GREEN)✓ Everything cleaned up$(NC)"

##@ Monitoring

.PHONY: ps
ps: ## Show running containers
	echo "$(BLUE)Container Status:$(NC)"
	docker compose ps -a

.PHONY: status
status: ## Show detailed status of all services
	echo "$(BLUE)=== Service Status ===$(NC)"
	docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	echo ""
	echo "$(BLUE)=== Resource Usage ===$(NC)"
	docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $$(docker compose ps -q) 2>/dev/null || echo "No running containers"

.PHONY: logs
logs: ## Follow logs (use ct=<service> for specific service)
	if [ -z "$(ct)" ]; then \
		echo "$(BLUE)Following logs for all services (use Ctrl+C to exit):$(NC)"; \
		docker compose logs -f; \
	else \
		echo "$(BLUE)Following logs for $(ct) (use Ctrl+C to exit):$(NC)"; \
		docker compose logs -f $(ct); \
	fi

.PHONY: logs.tail
logs.tail: ## Show last 100 lines of logs (use ct=<service> for specific service)
	echo "$(BLUE)Showing recent logs$(if $(ct), for $(ct),):$(NC)"
	docker compose logs --tail=100 $(CONTAINER_ARG)

##@ Access

.PHONY: shell
shell: ## Access shell in container (requires ct=<service>)
	if [ -z "$(ct)" ]; then \
		echo "$(RED)Error: Please specify container with ct=<service>$(NC)"; \
		echo "Available services: $$(docker compose config --services | tr '\n' ' ')"; \
		exit 1; \
	fi
	echo "$(BLUE)Opening shell in $(ct)...$(NC)"
	docker compose exec $(ct) bash || docker compose exec $(ct) sh

.PHONY: sql-cli
sql-cli: ## Access Flink SQL CLI (via client container)
	echo "$(BLUE)Opening Flink SQL CLI...$(NC)"
	docker compose exec client /opt/flink/bin/sql-client.sh

.PHONY: flink-cli
flink-cli: ## Access Flink CLI (via client container)
	echo "$(BLUE)Opening Flink CLI...$(NC)"
	docker compose exec client /opt/flink/bin/flink

##@ Volume Management

.PHONY: volume.list
volume.list: ## List all Docker volumes
	echo "$(BLUE)Docker Volumes:$(NC)"
	docker volume ls

.PHONY: volume.inspect
volume.inspect: ## Inspect project volumes
	echo "$(BLUE)Project Volume Details:$(NC)"
	docker volume inspect $$(docker compose config --volumes 2>/dev/null) 2>/dev/null || echo "No volumes found"

.PHONY: volume.rm.dangling
volume.rm.dangling: ## Remove dangling volumes
	echo "$(YELLOW)Removing dangling volumes...$(NC)"
	docker volume rm $$(docker volume ls -qf dangling=true) 2>/dev/null || echo "No dangling volumes found"
	echo "$(GREEN)✓ Dangling volumes cleaned$(NC)"

.PHONY: volume.backup
volume.backup: ## Backup MinIO data volume
	echo "$(BLUE)Backing up MinIO data...$(NC)"
	mkdir -p ./backups
	docker run --rm -v paimon-lab_minio_data:/source -v $$(pwd)/backups:/backup alpine tar czf /backup/minio_data_$$(date +%Y%m%d_%H%M%S).tar.gz -C /source .
	echo "$(GREEN)✓ Backup completed in ./backups/$(NC)"

##@ Health & Diagnostics

.PHONY: health
health: ## Check health of all services
	echo "$(BLUE)Health Check Summary:$(NC)"
	docker compose ps --format "table {{.Name}}\t{{.Status}}"
	echo ""
	echo "$(BLUE)Checking service endpoints:$(NC)"
	echo "MinIO Console: http://localhost:9001 (root/Abcd1234)"
	curl -s -o /dev/null -w "MinIO API: %{http_code}\n" http://localhost:9000/minio/health/live || echo "MinIO API: Not accessible"
	curl -s -o /dev/null -w "Iceberg REST: %{http_code}\n" http://localhost:8181/v1/config || echo "Iceberg REST: Not accessible"
	curl -s -o /dev/null -w "Flink Web UI: %{http_code}\n" http://localhost:28081 || echo "Flink Web UI: Not accessible"

.PHONY: urls
urls: ## Show service URLs
	echo "$(GREEN)Service URLs:$(NC)"
	echo "  MinIO Console:   http://localhost:9001 (root/Abcd1234)"
	echo "  MinIO API:       http://localhost:9000"
	echo "  Iceberg REST:    http://localhost:8181"
	echo "  Flink Web UI:    http://localhost:28081"

##@ Development

.PHONY: config
config: ## Show resolved docker-compose configuration
	echo "$(BLUE)Docker Compose Configuration:$(NC)"
	docker compose config

.PHONY: clean
clean: ## Clean up containers, networks, and volumes
	echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker compose down --volumes --remove-orphans
	docker system prune -f
	echo "$(GREEN)✓ Cleanup completed$(NC)"

.PHONY: reset
reset: clean pull ## Reset environment (clean + pull fresh images)
	echo "$(GREEN)✓ Environment reset completed$(NC)"

.PHONY: dev
dev: ## Start development environment with essential services
	echo "$(BLUE)Starting development environment...$(NC)"
	make up ct="minio rest"
	echo "$(GREEN)✓ Development environment ready$(NC)"
	make urls

.PHONY: full
full: ## Start full environment (all services)
	echo "$(BLUE)Starting full environment...$(NC)"
	make up
	echo "$(GREEN)✓ Full environment ready$(NC)"
	make urls

##@ Utilities

.PHONY: env
env: ## Show environment variables
	echo "$(BLUE)Environment Variables:$(NC)"
	echo "  IMAGE: $(IMAGE)"
	echo "  COMPOSE_FILE: $(COMPOSE_FILE)"
	echo "  DOCKER_PLATFORM: $(DOCKER_PLATFORM)"
	echo "  CONTAINER_ARG: $(CONTAINER_ARG)"

.PHONY: services
services: ## List all available services
	echo "$(BLUE)Available Services:$(NC)"
	docker compose config --services