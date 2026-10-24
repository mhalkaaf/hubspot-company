# Task 2 — application deployment

These steps assume Task 1 is healthy and the repository changes have been pushed to `https://github.com/mhalkaaf/hubspot-company`.

## 1. Push the prepared files from your Mac

Review the changes first. The Word requirement file is intentionally separate from the application commit unless you decide to include it.

```bash
cd /Users/mhalkaaf/Haeckal/Repositories/hubspot-company
git status --short
git diff --check
git diff
git add app.py .dockerignore .gitignore .env.example docker/Dockerfile.staging \
  requirements/requirements-prod.txt requirements/requirements-stage.txt \
  .github/workflows/deploy.yml docs/nomad-assessment \
  tests/test_api_format.py tools/company_seeder.py tools/permission_tester.py
git commit -m "Prepare Nomad application deployment"
git push origin main
```

## 2. Clone or update the repository on Ubuntu

```bash
cd /opt
git clone https://github.com/mhalkaaf/hubspot-company.git
cd /opt/hubspot-company
```

If it already exists, use `git -C /opt/hubspot-company status` before pulling so local server changes are not overwritten.

## 3. Create persistent storage and Consul configuration

```bash
sudo mkdir -p /opt/assessment/data/postgres
sudo chown 70:70 /opt/assessment/data/postgres

export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
set +x
DB_PASSWORD=$(openssl rand -hex 24)
APP_SECRET=$(openssl rand -hex 32)
printf 'POSTGRES_USER=hubspot\nPOSTGRES_PASSWORD=%s\nPOSTGRES_DB=hubspot\n' \
  "$DB_PASSWORD" | consul kv put assessment/postgres-env -
printf 'DATABASE_URL=postgresql://hubspot:%s@127.0.0.1:5432/hubspot\nSECRET_KEY=%s\n' \
  "$DB_PASSWORD" "$APP_SECRET" | consul kv put assessment/app-env -
unset DB_PASSWORD APP_SECRET
```

Only generate these credentials once. PostgreSQL applies its environment credentials only when the data directory is first initialized.

## 4. Deploy PostgreSQL

```bash
export NOMAD_ADDR=http://127.0.0.1:4646
cd /opt/hubspot-company
nomad job validate docs/nomad-assessment/jobs/postgres.nomad.hcl
nomad job plan docs/nomad-assessment/jobs/postgres.nomad.hcl
nomad job run docs/nomad-assessment/jobs/postgres.nomad.hcl
nomad job status postgres
```

Copy the allocation ID from `nomad job status postgres`, then verify it:

```bash
nomad alloc status POSTGRES_ALLOCATION_ID
nomad alloc exec -task postgres POSTGRES_ALLOCATION_ID \
  pg_isready -U hubspot -d hubspot
```

Expected: `accepting connections`.

## 5. Build and deploy the application locally once

```bash
cd /opt/hubspot-company
sudo docker build -f docker/Dockerfile.staging -t hubspot-company:rehearsal .
nomad job validate -var='image=hubspot-company:rehearsal' \
  docs/nomad-assessment/jobs/app.nomad.hcl
nomad job plan -var='image=hubspot-company:rehearsal' \
  docs/nomad-assessment/jobs/app.nomad.hcl
nomad job run -var='image=hubspot-company:rehearsal' \
  docs/nomad-assessment/jobs/app.nomad.hcl
nomad job status hubspot
```

Verify the application, Prometheus endpoint, Consul health and DNS:

```bash
curl -fsS http://127.0.0.1:5104/ready | jq
curl -fsS http://127.0.0.1:5104/metrics | sed -n '1,15p'
curl -fsS 'http://127.0.0.1:8500/v1/health/service/hubspot?passing=true' | jq
dig @127.0.0.1 -p 8600 hubspot.service.consul A +short
dig @127.0.0.1 -p 8600 hubspot.service.consul SRV +short
```

## 6. Configure GitHub Actions

Create these repository Actions secrets:

| Secret | Value |
|---|---|
| `DEPLOY_HOST` | `188.166.237.10` |
| `DEPLOY_USER` | `root` |
| `SSH_PRIVATE_KEY` | A dedicated deployment private key |
| `SSH_KNOWN_HOSTS` | The verified SSH host-key entry for the server |

If the GHCR package is private, log the Nomad host into GHCR using a token that has `read:packages` permission:

```bash
sudo docker login ghcr.io --username mhalkaaf
```

Enter the token at the prompt. Do not put it in a job file or commit it.

Push a commit or manually run **Build and deploy staging** in GitHub Actions. The workflow builds `docker/Dockerfile.staging`, publishes an immutable GHCR image, smoke-tests it with PostgreSQL, and deploys that exact image digest through SSH.

## Completion gate

- GitHub Actions run is green.
- `nomad job status hubspot` shows a running allocation.
- `/ready` returns HTTP 200 with a healthy database.
- `/metrics` returns Prometheus data.
- Consul reports the `hubspot` service as passing.
- Consul DNS returns both an A record and an SRV record.
- `/docs/` is accessible through the SSH tunnel.
