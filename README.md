# log-service

Centralised log aggregation stack based on **Vector** + **OpenObserve** with **SeaweedFS** (S3-compatible) as the object storage backend.

```
[ Any Docker container ] ──► (stdout)
          │
          ▼
    [ Docker daemon ]
          │
          ▼
       [ Vector ]          – collects logs via Docker socket
          │  HTTP
          ▼
    [ OpenObserve ]        – indexes, stores, search UI
          │  S3 API
          ▼
     [ SeaweedFS ]         – Parquet files, long-term storage
```

## Requirements

- Docker + Docker Compose v2
- A running S3-compatible object store, e.g. the `seaweedfs-infra` project (shares the `ndvi-go-net` docker network)

## Setup

### 1. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

| Variable | Description |
|---|---|
| `ZO_ROOT_USER_EMAIL` | OpenObserve admin login (email format) |
| `ZO_ROOT_USER_PASSWORD` | Min 8 chars, must include upper, lower, digit and special char |
| `S3_ENDPOINT` | Full S3 gateway URL, e.g. `http://seaweed:8333` |
| `S3_ACCESS_KEY` | S3 access key |
| `S3_SECRET_KEY` | S3 secret key |
| `OO_BUCKET` | Bucket name for log storage (default: `openobserve-logs`) |
| `HOST_PORT_OO` | Host port to expose OpenObserve UI (default: `5080`) |
| `LOG_RETENTION_DAYS` | How long to keep logs in days (default: `90`) |

### 2. Create the S3 bucket

The `oo-init` service creates the bucket matching `OO_BUCKET` automatically on `docker compose up` — no manual step needed.

### 3. Start the stack

```bash
make up
# or: docker compose up -d
```

### 4. Open the UI

```
http://localhost:5080
```

Log in with the credentials from `.env`.

## Tagging your services

Vector routes logs to separate streams based on the `logging.service` Docker label.  
Add the label to each service you want to track:

```yaml
# docker-compose.yml of your service
services:
  myapp:
    image: ...
    labels:
      logging.service: "myapp"
```

To exclude a container from log collection entirely:

```yaml
labels:
  logging.exclude: "true"
```

### Built-in streams

| Stream | Matches |
|---|---|
| `go-ndvi` | `logging.service: gogeoapp` |
| `php-softfarm` | `logging.service: soft-farm` or container name `sf_app` |
| `s3` | `logging.service: seaweedfs` |
| `other` | everything else |

To add a new dedicated stream, add a route + sink pair in `vector.toml`.

## Viewing logs

1. Go to **http://localhost:5080** → **Logs**
2. Select a stream from the dropdown (`go-ndvi`, `php-softfarm`, `s3`, `other`)
3. Use the search bar to filter — examples:
   - `service = 'gogeoapp'` — one specific service
   - `level = 'error'` — errors only
   - Full-text search works too

## Log retention

Logs older than `LOG_RETENTION_DAYS` (default 90 days) are automatically purged by OpenObserve's compaction job.  
Per-stream retention can also be configured in the UI under **Settings → Data Retention**.

## Useful commands

```bash
make up       # start the stack
make down     # stop the stack
make ps       # show container status
make logs     # tail all logs
```

## Adding PHP / Yii2 stdout logging

By default Yii2 writes logs to files. To also send them to stdout (so Vector picks them up), add a second log target to your `config/local.php`:

```php
'log' => [
    'targets' => [
        // keep the existing file target as-is
        [...],
        // add this target for Vector
        [
            'class' => yii\log\FileTarget::class,
            'levels' => ['error', 'warning', 'info'],
            'logFile' => 'php://stdout',
            'enableRotation' => false,
            'exportInterval' => 1,
        ],
    ],
],
```
