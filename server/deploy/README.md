# Droplet deployment

The repository deploys the server to one Ubuntu Droplet whenever a commit is pushed to `develop`. GitHub Actions connects over SSH, checks out that exact commit, builds the API image, applies SQLite migrations, seeds test accounts when temporary mode is enabled, starts the API and Caddy, and checks the health endpoint. Docker restart policies keep both containers running after a reboot.

## One-time Droplet setup

1. Generate a dedicated key pair on your computer with `ssh-keygen -t ed25519 -f youki-droplet-deploy -C github-actions-youki` (leave it without a passphrase for the non-interactive workflow). SSH to the Droplet once and create the deploy user. Install Git, Docker Engine, and the Docker Compose plugin, then give the deploy user Docker access. Add `youki-droplet-deploy.pub` to the deploy user's `authorized_keys`. Treat the private key like a server-admin credential because Docker access can control the host.
2. Configure a DigitalOcean Cloud Firewall to allow SSH from your IP and TCP ports 80 and 443 from the internet. Do not open port 3000 publicly.
3. Point an A record such as `api.example.com` at the Droplet's public IPv4 address. Caddy needs the domain to resolve to this Droplet and ports 80/443 reachable to issue and renew HTTPS certificates.
4. Clone this repository's `develop` branch to `/opt/youki`, owned by the deploy user:

   ```sh
   sudo -u deploy git clone --branch develop https://github.com/youki-jp/Youki-Sun-Tracker.git /opt/youki
   ```

5. As the `deploy` user, create `/opt/youki/server/deploy/.env` with the domain. For example, `sudo -u deploy nano /opt/youki/server/deploy/.env`:

   ```dotenv
   API_DOMAIN=api.example.com
   ```

6. Create `/opt/youki/server/.env.production` for temporary test login. No Apple Developer account, Apple keys, or encryption key is required in this mode:

   ```sh
   nano /opt/youki/server/.env.production
   ```

   Enter:

   ```dotenv
   AUTH_MODE=temporary
   YOOKI_TEST_USER_PASSWORD=YOUR_GENERATED_PASSWORD
   ```

   Generate the password with `openssl rand -base64 32`, replace `YOUR_GENERATED_PASSWORD` with its output, and share it only with your testers. Production requires 24 to 128 characters. Protect both env files with `chmod 600 server/.env.production server/deploy/.env`. Do not commit them.

   Temporary mode enables only the four seeded Free/Pro test accounts; it disables the Apple challenge and sign-in routes. Sessions, quotas, logout, refresh, and test-account deletion still use SQLite. This is a shared test login, not public account registration. The server reports the available login method at `GET /api/v1/auth/config`, which the updated iOS client uses to show the test-account password form.

   To enable real Apple sign-in later, switch to `AUTH_MODE=apple` and supply the five `APPLE_*` values documented in the [account guide](../../docs/auth-implementation.md). Seeding then skips test accounts and their login route is disabled.

7. As the deploy user, perform the initial migration and start:

   ```sh
   cd /opt/youki
   docker compose --env-file server/deploy/.env -f server/deploy/compose.yaml build api
   docker compose --env-file server/deploy/.env -f server/deploy/compose.yaml run --rm api bun scripts/migrate.ts
   docker compose --env-file server/deploy/.env -f server/deploy/compose.yaml run --rm api bun scripts/seed-test-users.ts --if-temporary
   docker compose --env-file server/deploy/.env -f server/deploy/compose.yaml up -d
   ```

   Compose stores SQLite in a named Docker volume, so rebuilding containers does not replace the database. Set up regular off-Droplet backups before using real accounts.

## GitHub configuration

In the repository's **Settings → Secrets and variables → Actions → Secrets**, add these repository secrets:

- `DROPLET_HOST`: the Droplet's public IP or SSH hostname.
- `DROPLET_USER`: `deploy` (or the user configured above).

- `DROPLET_SSH_PRIVATE_KEY`: private key whose public key is authorized for the deploy user.
- `DROPLET_SSH_KNOWN_HOSTS`: the verified SSH host-key line for the Droplet. Verify its fingerprint from the Droplet console before storing it; the workflow enforces strict host-key checking.

Copy the contents of `youki-droplet-deploy` (the **private** key) into `DROPLET_SSH_PRIVATE_KEY`; install `youki-droplet-deploy.pub` on the Droplet. To prepare the known-hosts value, get the host key with `ssh-keyscan -H YOUR_DROPLET_HOST`, then compare its fingerprint with `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` from the Droplet console before saving it.

After the workflow is merged to `develop`, every push to `develop` deploys that exact commit. You can also use **Actions → Deploy Youki server to Droplet → Run workflow** for an initial deployment or manual redeploy. Check the **Actions** tab for build, migration, restart, and health-check results. The workflow skips an older queued commit if `develop` has already advanced.

Verify the public endpoint with:

```sh
curl --fail https://api.example.com/api/v1/health/ready
curl --fail https://api.example.com/api/v1/auth/config
```

The iOS Release build must also use this HTTPS hostname in `AppConfig.defaultServerURLString`; deploying the API does not change an already-installed app's URL.

## Existing Droplet with placeholder Apple credentials

After these code changes are merged to `develop`, replace the contents of `server/.env.production` with just `AUTH_MODE=temporary` and `YOOKI_TEST_USER_PASSWORD` as above. Remove all placeholder `APPLE_*` lines. Run the workflow on the latest `develop` commit from the Actions tab, or push a new commit to `develop`.

Seeding is idempotent and preserves existing account IDs and sessions. A deleted test account is recreated on the next deployment that seeds accounts. The four accounts share the configured password and their account quotas are shared between testers using the same account. Test login is limited to 30 attempts per minute for the server. Keep port 3000 bound to loopback and access the API over Caddy HTTPS.
