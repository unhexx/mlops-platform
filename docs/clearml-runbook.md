# ClearML Docker Compose Runbook for Codex

## Purpose
This runbook is the executable operating procedure for a local Codex agent that will deploy, validate, and hand over a ClearML stack using Docker Compose.

## Architecture summary
The stack now includes two storage layers:
- `clearml-fileserver` for ClearML's built-in file-serving workflow.
- `minio` for S3-compatible storage of model checkpoints, artifacts, and charts when projects/tasks are configured with an `s3://` output URI.

MinIO is included because the original stack did not contain an object storage product dedicated to artifact and checkpoint retention.

## Deliverables
After a successful run the agent must provide:
- Web UI URL
- API URL
- Fileserver URL
- MinIO API URL
- MinIO Console URL
- Verified login account
- Verified password or password reset instruction
- Final status: `success`, `partial`, or `failed`

## Repository Files
- Compose stack: `deploy/clearml/docker-compose.yml`
- Environment template: `deploy/clearml/.env.example`
- Smoke test template: `scripts/clearml-smoke-test.sh`
- Final report template: `templates/clearml-final-report.md`

## Phase 1. Prepare host
Run from the repository root:

```bash
cp deploy/clearml/.env.example deploy/clearml/.env
```

Edit `deploy/clearml/.env`:
- Replace `localhost` with the real DNS name or IP if the stack is remote.
- Adjust port bindings if `8080`, `8008`, `8081`, `9000`, or `9001` are already busy.
- Replace the default `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` before production use.
- Reduce `CLEARML_ES_JAVA_OPTS` to `-Xms512m -Xmx512m` if the host has less than 8 GB RAM.

Validate host prerequisites:

```bash
docker --version
docker compose version
docker info >/dev/null
ss -ltn '( sport = :8080 or sport = :8008 or sport = :8081 or sport = :9000 or sport = :9001 )'
```

## Phase 2. Validate configuration

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml config >/tmp/clearml.compose.rendered.yml
```

Review the rendered file if needed:

```bash
sed -n '1,260p' /tmp/clearml.compose.rendered.yml
```

## Phase 3. Start ClearML and MinIO

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml pull
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml up -d
```

Wait for the services to initialize:

```bash
watch -n 5 'docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml ps'
```

Stop watching when all services are healthy or at least `Up`, and verify `minio-init` exited with code `0`.

## Phase 4. Basic verification

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml ps
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs --tail=100
curl -I "$(awk -F= '/^CLEARML_WEB_EXTERNAL_URL=/{print $2}' deploy/clearml/.env)"
curl -I "$(awk -F= '/^CLEARML_API_EXTERNAL_URL=/{print $2}' deploy/clearml/.env)"
curl -I "$(awk -F= '/^CLEARML_FILESERVER_URL=/{print $2}' deploy/clearml/.env)"
curl -I "$(awk -F= '/^MINIO_ENDPOINT=/{print $2}' deploy/clearml/.env)"
curl -I "$(awk -F= '/^MINIO_CONSOLE_URL=/{print $2}' deploy/clearml/.env)"
```

Check that the artifact bucket exists:

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs minio-init --tail=50
```

## Phase 5. First login / account bootstrap
Because bootstrap behavior can differ by image version, the agent must verify the login flow instead of guessing credentials.

### Preferred path
1. Open the web UI URL.
2. Check whether the first-run flow offers registration for the first admin.
3. If registration is available, create the admin interactively and record the verified login.
4. If registration is not available, inspect the logs for initialization hints:

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs apiserver --tail=200
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs webserver --tail=200
```

### Rules
- Never invent a login or password.
- Only publish credentials after they have been validated by an actual login.
- If the password is manually chosen during setup, state that clearly in the final report.

## Phase 6. Configure MinIO for artifact storage
ClearML can continue using the built-in fileserver, but MinIO should be used for checkpoints, large artifacts, and charts that need S3-compatible retention.

### Verify MinIO login
- Open the MinIO Console URL.
- Sign in using `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `deploy/clearml/.env`.
- Confirm that the `MINIO_BUCKET` bucket exists.

### Recommended ClearML usage pattern
1. In ClearML UI create API credentials for the operator or automation user.
2. On the machine that will run training jobs, configure ClearML SDK with the generated access key and secret key.
3. Add S3 settings to `~/clearml.conf` or environment variables for the agent/job runtime:

```yaml
sdk {
  aws {
    s3 {
      key: "<MINIO_ROOT_USER>"
      secret: "<MINIO_ROOT_PASSWORD>"
      region: "<MINIO_REGION>"
      host: "<MINIO_ENDPOINT host:port without scheme if required by SDK version>"
      secure: false
      verify: false
      multipart: true
      bucket: "<MINIO_BUCKET>"
    }
  }
}
```

4. Set `output_uri` for projects or tasks to `s3://<MINIO_BUCKET>/...`.
5. Run a test task that uploads an artifact and verify the object appears in MinIO.

## Phase 7. Smoke test
Run the smoke-test script after the UI, API, fileserver, and MinIO are reachable:

```bash
bash scripts/clearml-smoke-test.sh deploy/clearml/.env
```

If credentials and SDK keys are available, extend validation by:
- logging into the UI,
- creating a test project,
- generating API credentials,
- submitting a tiny SDK task with `output_uri="s3://$MINIO_BUCKET/smoke-test"` from a separate environment.

## Phase 8. Troubleshooting

### Elasticsearch keeps restarting
```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs elasticsearch --tail=200
free -h
```
If memory is low, reduce `CLEARML_ES_JAVA_OPTS` and restart.

### UI opens but API is broken
```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs apiserver --tail=200
curl -v "$(awk -F= '/^CLEARML_API_EXTERNAL_URL=/{print $2}' deploy/clearml/.env)"
```
Check MongoDB, Redis, Elasticsearch reachability and environment values.

### Fileserver is unreachable
```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs fileserver --tail=200
```
Verify the published port and persistent volume state.

### MinIO is unreachable or the bucket is missing
```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs minio --tail=200
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs minio-init --tail=200
```
Verify the published ports, credentials, and the `MINIO_BUCKET` name.

## Phase 9. Shutdown / restart

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml down
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml up -d
```

To remove everything including volumes for a fresh test:

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml down -v
```

## Phase 10. Final handover
Fill in `templates/clearml-final-report.md` only after:
- the URLs respond,
- login is verified,
- the smoke test passes,
- MinIO access is verified,
- a test artifact reaches the configured bucket,
- and any manual steps are recorded.
