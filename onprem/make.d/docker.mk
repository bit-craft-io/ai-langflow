-include make.d/.env
export
SHELL := /bin/bash
SERVICES := langflow firecrawl pgvector searxng ollama voicevox bridge

# ========================================
# menu
# ----------------------------------------
TASKS += \
	docker-up:全サービスを起動 \
	docker-down:全サービスを停止 \
	docker-purge:コンテナ・ボリュームを削除 \
	docker-build:全サービスをビルド(キャッシュ無視)して起動 \
	docker-one-build:指定サービスのみビルドして再起動 \
	docker-one-restart:指定サービスのみ再起動
# ========================================
# command
# ----------------------------------------
LANGFLOW_COMPOSE  := $(__DOCKER_ROOT_LANGFLOW)
PGVECTOR_COMPOSE  := $(__DOCKER_ROOT_PGVECTOR)
FIRECRAWL_COMPOSE := $(__DOCKER_ROOT_FIRECRAWL)
SEARXNG_COMPOSE   := $(__DOCKER_ROOT_SEARXNG)
OLLAMA_COMPOSE    := $(__DOCKER_ROOT_OLLAMA)
VOICEVOX_COMPOSE  := $(__DOCKER_ROOT_VOICEVOX)
BRIDGE_COMPOSE    := $(__DOCKER_ROOT_BRIDGE)
COMMON_ENV        := make.d/.env

# $(1)=project name $(2)=compose dir $(3)=action(up -d / down)
define compose_action
	@service=$(1); \
	root=$(2); \
	action="$(3)"; \
	base="$$root/docker-compose.yaml"; \
	if [ -f "$$base" ]; then \
		cmd="docker compose -p $$service --env-file $(COMMON_ENV)"; \
		[ -f "$$root/.env" ] && cmd="$$cmd --env-file $$root/.env"; \
		cmd="$$cmd --file $$base"; \
		ovr="docker/override.d/$$service/docker-compose.override.yaml"; \
		dev="docker/override.d/$$service/docker-compose.dev.yaml"; \
		[ -f "$$ovr" ] && cmd="$$cmd --file $$ovr"; \
		[ "$(__DEV_CONTAINER)" = "true" ] && [ -f "$$dev" ] && cmd="$$cmd --file $$dev"; \
		$$cmd $$action; \
	fi
endef

define select_service
	if [ -z "$(SERVICE)" ]; then \
		echo "----------------------------------------" >&2; \
		echo "> rebuild a service:" >&2; \
		echo "----------------------------------------" >&2; \
		echo "$(SERVICES)" | tr ' ' '\n' | nl -w2 -s') ' | sed 's/^/  /' >&2; \
		trap 'echo cancelled >&2; exit 0' INT; \
		read -p "> number: " num < /dev/tty; \
		echo $(SERVICES) | cut -d' ' -f"$$num"; \
	else \
		echo "$(SERVICE)"; \
	fi
endef

.PHONY: docker-one-build
docker-one-build:
	@docker network inspect sandbox >/dev/null 2>&1 \
		&& echo "network sandbox already exists" \
		|| (docker network create sandbox >/dev/null && echo "network sandbox created")
	@service=$$($(call select_service)); \
	if [ -z "$$service" ]; then \
		echo "Error: SERVICE parameter is required. (e.g. make docker-rebuild SERVICE=bridge)"; \
		exit 0; \
	fi; \
	$(MAKE) --no-print-directory _docker-one-build SERVICE="$$service"

.PHONY: _docker-one-build
_docker-one-build:
	$(eval SERVICE_UPPER := $(shell echo $(SERVICE) | tr 'a-z' 'A-Z'))
	$(call compose_action,$(SERVICE),$($(SERVICE_UPPER)_COMPOSE),up -d --build --force-recreate)

.PHONY: docker-one-restart
docker-one-restart:
	@service=$$($(call select_service)); \
	if [ -z "$$service" ]; then \
		echo "Error: SERVICE parameter is restart. (e.g. make docker-rebuild SERVICE=bridge)"; \
		exit 0; \
	fi; \
	$(MAKE) --no-print-directory _docker-one-restart SERVICE="$$service"

.PHONY: _docker-one-restart
_docker-one-restart:
	$(eval SERVICE_UPPER := $(shell echo $(SERVICE) | tr 'a-z' 'A-Z'))
	$(call compose_action,$(SERVICE),$($(SERVICE_UPPER)_COMPOSE),restart)

.PHONY: docker-up
docker-up:
	@docker network inspect sandbox >/dev/null 2>&1 \
		&& echo "network sandbox already exists" \
		|| (docker network create sandbox >/dev/null && echo "network sandbox created")
	$(call compose_action,langflow,$(LANGFLOW_COMPOSE),up -d)
	$(call compose_action,pgvector,$(PGVECTOR_COMPOSE),up -d)
	$(call compose_action,firecrawl,$(FIRECRAWL_COMPOSE),up -d)
	$(call compose_action,searxng,$(SEARXNG_COMPOSE),up -d)
	$(call compose_action,ollama,$(OLLAMA_COMPOSE),up -d)
	$(call compose_action,voicevox,$(VOICEVOX_COMPOSE),up -d)
	$(call compose_action,bridge,$(BRIDGE_COMPOSE),up -d)

.PHONY: docker-down
docker-down:
	$(call compose_action,bridge,$(BRIDGE_COMPOSE),down)
	$(call compose_action,voicevox,$(VOICEVOX_COMPOSE),down)
	$(call compose_action,ollama,$(OLLAMA_COMPOSE),down)
	$(call compose_action,searxng,$(SEARXNG_COMPOSE),down)
	$(call compose_action,firecrawl,$(FIRECRAWL_COMPOSE),down)
	$(call compose_action,pgvector,$(PGVECTOR_COMPOSE),down)
	$(call compose_action,langflow,$(LANGFLOW_COMPOSE),down)
	@docker network inspect sandbox >/dev/null 2>&1 \
		&& (docker network rm sandbox >/dev/null && echo "network sandbox removed") \
		|| echo "network sandbox not found"

.PHONY: docker-build
docker-build:
	# Dockerfile
	$(call compose_action,bridge,$(BRIDGE_COMPOSE),build --no-cache)

.PHONY: docker-purge
docker-purge:
	@read -p "docker compose down -v [y/N]: " ans; \
	if [ "$$ans" != "y" ] && [ "$$ans" != "yes" ]; then \
	   echo "Cancelled."; \
	   exit 0; \
	fi;
	$(call compose_action,bridge,$(BRIDGE_COMPOSE),down -v)
	$(call compose_action,voicevox,$(VOICEVOX_COMPOSE),down -v)
	$(call compose_action,ollama,$(OLLAMA_COMPOSE),down -v)
	$(call compose_action,searxng,$(SEARXNG_COMPOSE),down -v)
	$(call compose_action,firecrawl,$(FIRECRAWL_COMPOSE),down -v)
	$(call compose_action,pgvector,$(PGVECTOR_COMPOSE),down -v)
	$(call compose_action,langflow,$(LANGFLOW_COMPOSE),down -v)
	@docker network inspect sandbox >/dev/null 2>&1 \
		&& (docker network rm sandbox >/dev/null && echo "network sandbox removed") \
		|| echo "network sandbox not found"