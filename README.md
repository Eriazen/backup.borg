# Automated Borg Backup Script

This script streamlines the setup of fast and easy automated [Borg](https://www.borgbackup.org/) backups to a local disk using systemd services.

> [!NOTE]
> This script was developed and tested on **Ubuntu 24.04**. While it is designed to work on other Debian-based distributions, slight modifications may be required depending on your specific environment.

## Requirements

Ensure BorgBackup is installed on your system:

```bash
sudo apt update
sudo apt install borgbackup
```

## Initial Setup

You should have a separate physical disk, or at least a separate partition, dedicated to your backups.

### 1. Gather Disk Information

Before running the setup, you need to gather specific identifiers for your storage.

**Find the Partition Table UUID (PTUUID):**
```bash
lsblk --fs -o +PTUUID /dev/YOUR_DISK
```

**Find the Filesystem UUID:**
If you haven't formatted your disk yet, now is the time. Then, find the UUID of the partition where backups will be stored:
```bash
lsblk -o+uuid,label
```

### 2. Initialize the Borg Repository

Mount your backup filesystem (temporarily) to initialize the repo:

```bash
sudo mount /dev/disk/by-uuid/YOUR_UUID /path/to/mountpoint
```

Initialize the Borg repository:

```bash
borg init --encryption repokey /path/to/mountpoint
```
> [!NOTE]
> For more information on `borg init` arguments, see the [Borg Quickstart Guide](https://borgbackup.readthedocs.io/en/stable/quickstart.html).

### 3. Configuration

Open `src/backup.conf` and input the values you gathered above:

1.  **PTUUID:** The partition table ID from Step 1.
2.  **UUID:** The filesystem UUID from Step 1.
3.  **MOUNTPOINT:** The path where you want the disk to mount.
4.  **PASSPHRASE:** The Borg passphrase you chose in Step 2.

> [!IMPORTANT]
> **Security Warning:** This script requires storing your Borg passphrase in the plain text configuration file (`src/backup.conf`). Ensure this file is readable only by the root user or the specific backup user to prevent unauthorized access.

## Usage

Once `src/backup.conf` is configured, make the script executable and run it as sudo (required for systemd service setup):

```bash
chmod +x setup.sh
sudo ./setup.sh
```

The script will configure the systemd service, enable the timer, and trigger the first backup immediately.

## Troubleshooting

After running the setup, you can verify the status of the service and the timer:

```bash
# Check service status
sudo systemctl status automatic-backup.service

# Check timer status
sudo systemctl status automatic-backup.timer
```

To view the real-time backup logs:

```bash
journalctl -fu automatic-backup.service
```

## Acknowledgements

This setup is heavily based on the official Borg documentation for automated local backups, see [BorgBackup - Automated backups to local hard drive](https://borgbackup.readthedocs.io/en/stable/deployment/automated-local.html)

## To-do

- uninstall.sh
- add backup options to config
- add timer options
