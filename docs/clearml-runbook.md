# ClearML Docker Compose Runbook for Codex

## Purpose
This runbook is the executable operating procedure for a local Codex agent that will deploy, validate, and hand over a ClearML stack using Docker Compose.

## Deliverables
After a successful run the agent must provide:
- Web UI URL
- API URL
- Fileserver URL
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
- Adjust port bindings if `8080`, `8008`, or `8081` are already busy.
- Reduce `CLEARML_ES_JAVA_OPTS` to `-Xms512m -Xmx512m` if the host has less than 8 GB RAM.

Validate host prerequisites:

```bash
docker --version
docker compose version
docker info >/dev/null
ss -ltn '( sport = :8080 or sport = :8008 or sport = :8081 )'
```

## Phase 2. Validate configuration

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml config >/tmp/clearml.compose.rendered.yml
```

Review the rendered file if needed:

```bash
sed -n '1,220p' /tmp/clearml.compose.rendered.yml
```

## Phase 3. Start ClearML

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml pull
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml up -d
```

Wait for the services to initialize:

```bash
watch -n 5 'docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml ps'
```

Stop watching when all services are healthy or at least `Up`.

## Phase 4. Basic verification

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml ps
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml logs --tail=100
curl -I "$(awk -F= '/^CLEARML_WEB_EXTERNAL_URL=/{print $2}' deploy/clearml/.env)"
curl -I "$(awk -F= '/^CLEARML_API_EXTERNAL_URL=/{print $2}' deploy/clearml/.env)"
curl -I "$(awk -F= '/^CLEARML_FILESERVER_URL=/{print $2}' deploy/clearml/.env)"
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

## Phase 6. Smoke test
Run the smoke-test script after the UI and API are reachable:

```bash
bash scripts/clearml-smoke-test.sh deploy/clearml/.env
```

If credentials and SDK keys are available, extend validation by:
- logging into the UI,
- creating a test project,
- generating API credentials,
- submitting a tiny SDK task from a separate environment.

## Phase 7. Troubleshooting

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

## Phase 8. Shutdown / restart

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml down
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml up -d
```

To remove everything including volumes for a fresh test:

```bash
docker compose --env-file deploy/clearml/.env -f deploy/clearml/docker-compose.yml down -v
```

## Phase 9. Final handover
Fill in `templates/clearml-final-report.md` only after:
- the URLs respond,
- login is verified,
- the smoke test passes,
- and any manual steps are recorded.
