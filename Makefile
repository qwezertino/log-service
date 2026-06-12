.PHONY: up down ps logs

up:
	docker compose up -d --build

down:
	docker compose down

## ps: show container status
ps:
	docker compose ps

## logs: tail MinIO logs
logs:
	docker compose logs -f
