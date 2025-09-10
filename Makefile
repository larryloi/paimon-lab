include Makefile.env

ct ?=
# Helper to conditionally add container argument
CONTAINER_ARG = $(if $(ct),$(ct),)

IMAGE=flink:1.20-paimon-1.2.0

build:
	docker build -t $(IMAGE) ./

volume.rm.all:
	docker volume rm $$(docker volume ls -qf dangling=true)

volume.list:
	docker volume ls

ps:
	$(print_vars)
	docker compose ps -a

up:
	$(print_vars)
	docker compose up -d $(CONTAINER_ARG)

stop:
	docker compose stop $(CONTAINER_ARG)

down:
	docker compose down $(CONTAINER_ARG)


logs:
	docker compose logs -f $(CONTAINER_ARG)

shell:
	docker compose exec $(CONTAINER_ARG) bash