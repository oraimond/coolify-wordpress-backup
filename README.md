# Coolify WordPress Backup

Backup service for WordPress installations on Coolify

## Setup Instructions

Follow these steps to set up automated WordPress backups in Coolify:

### 1. Deploy the Service

- Deploy this repository as a service in Coolify by selecting Public Repository and entering the URL: `https://github.com/oraimond/coolify-wordpress-backup`.
- Select `Dockerfile` as the **Build Pack**.
- Leave the base directory as the default `/`.

### 2. Mount the Docker Socket

- In your service settings, select **Persistent Storage** and add a volume:
  - **Name:** `docker-socket`
  - **Source:** `/var/run/docker.sock`
  - **Target:** `/var/run/docker.sock`
  - This allows the backup script to interact with Docker on the host.

### 3. Configure a Scheduled Task

- Go to the **Scheduled Tasks** section in your service settings.
- Add a new scheduled task with your desired schedule (e.g., `0 2 * * *` for daily at 2am).
- Set the command to:
  ```sh
  backup
  ```
  - For a dry run/test, use: `DRY_RUN=1 backup`
- Save and redeploy your service.

### 4. Set Environment Variables (Optional)

- Go to the **Environment Variables** section in your service settings.
- Add variables as needed:
  - `DRY_RUN=0` (default: enable real backups)
  - `DRY_RUN=1` (dry run, no actual backups)
- You can change these at any time to control backup behavior.

### 5. Deploy

- Click the **Deploy** button to start the service.
- Monitor the logs to ensure the service is running correctly.
- The service will run a dry run on startup and then sleep for the scheduled tasks.

---
