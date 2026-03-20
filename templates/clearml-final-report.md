# ClearML Deployment Final Report

## Status
- Overall status: `<success|partial|failed>`
- Deployment date (UTC): `<YYYY-MM-DD HH:MM UTC>`
- Operator / agent: `<name>`

## Service URLs
- Web UI URL: `<http://host:8080>`
- API URL: `<http://host:8008>`
- Fileserver URL: `<http://host:8081>`
- MinIO API URL: `<http://host:9000>`
- MinIO Console URL: `<http://host:9001>`
- MinIO Bucket: `<clearml-artifacts>`

## Login Credentials
- ClearML login / email: `<verified-login>`
- ClearML password: `<verified-password-or-manually-set>`
- ClearML password note: `<store securely / reset required / manually defined during first-run>`
- MinIO access key: `<verified-minio-user>`
- MinIO secret key: `<verified-minio-password>`

## Validation Results
- Web UI reachable: `<yes|no>`
- API reachable: `<yes|no>`
- Fileserver reachable: `<yes|no>`
- MinIO API reachable: `<yes|no>`
- MinIO Console reachable: `<yes|no>`
- ClearML login verified: `<yes|no>`
- MinIO login verified: `<yes|no>`
- Test project created: `<yes|no>`
- Test task created: `<yes|no>`
- Artifacts upload verified: `<yes|no>`
- Artifact present in MinIO bucket: `<yes|no>`

## Commands Executed
```bash
<docker compose commands>
<smoke test command>
<any manual bootstrap commands>
<any sdk test command with output_uri>
```

## Notes / Issues
- `<issue 1>`
- `<issue 2>`

## Handover
- Next action required from operator: `<none / rotate passwords / configure DNS / add TLS / create dedicated MinIO user / etc.>`
