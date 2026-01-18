#!/bin/bash


echo "::: Welcome to the backup.borg setup script"

# Validate user input
CONF_FILE="src/backup.conf"

echo "::: Validating user configuration"
if [ -f "$CONF_FILE" ]; then
    source "$CONF_FILE"
else
    echo "!!! ERROR: Configuration file not found at $CONF_FILE"
    exit 1
fi

if ! lsblk -no PTUUID | grep -q "$PTUUID"; then
    echo "!!! ERROR: Partition Table UUID '$PTUUID' not found on any connected disk"
    echo "!!! Please check 'src/backup.conf' and run 'lsblk --fs -o +PTUUID' to verify"
    exit 1
fi

if ! blkid -U "$UUID" >/dev/null 2>&1; then
    echo "!!! ERROR: Filesystem UUID '$UUID' not found"
    echo "!!! Please check 'src/backup.conf' and run 'lsblk -o+uuid' to verify"
    exit 1
fi

if [ ! -d "$MOUNTPOINT" ]; then
  echo "!!! ERROR: Mountpoint directory not found at '$MOUNTPOINT'"
  echo "!!! Please check 'src/backup.conf'"
fi
echo "::: Configuration validated successfully"

# Check if sudo available
if [[ $EUID -eq 0 ]];then
    echo "::: You are root."
else
    echo "::: sudo will be used for the setup."
    # Check if it is actually installed
    # If it isn't, exit because the install cannot complete
    if [[ $(dpkg-query -s sudo) ]];then
        export SUDO="sudo"
    else
        echo "!!! ERROR: Root privilages not given"
        echo "!!! Please install sudo or run this as root."
        exit 1
    fi
fi
echo ""

# Setup backup.borg dir
$SUDO mkdir -p $BACKUP_PATH
echo "::: Created backup.borg directory at $BACKUP_PATH"
echo ""

# Make the config file root only
$SUDO chown root:root "$BACKUP_PATH/backup.conf"
$SUDO chmod 600 "$BACKUP_PATH/backup.conf"

# Copy files from src to BACKUP_PATH
$SUDO cp $SCRIPT_PATH/src/* "$BACKUP_PATH/."

# Create autoeject file to unmount after backup
echo ":: Unmount disk after backup? (y/N):"
read -r response
case "$response" in
    [yY]) $SUDO touch "$BACKUP_PATH/autoeject"
        echo "::: Created autoeject file";;
    *) ;;
esac

# Write udev rule
cat <<EOF | $SUDO tee "$BACKUP_PATH/80-backup.rules" > /dev/null
ACTION=="add", SUBSYSTEM=="block", ENV{ID_PART_TABLE_UUID}=="$PTUUID", TAG+="systemd", ENV{SYSTEMD_WANTS}+="automatic-backup.service"
EOF
echo "::: Registered disk $PTUUID to 80-backup.rules"

# Create backup.disks
echo "$UUID" | $SUDO tee "$BACKUP_PATH/backup.disks" > /dev/null
echo "::: Registered partition $UUID to backup.disks"

# Create symlinks
$SUDO ln -s "$BACKUP_PATH/80-backup.rules" /etc/udev/rules.d/80-backup.rules
$SUDO ln -s "$BACKUP_PATH/automatic-backup.service" /etc/systemd/system/automatic-backup.service
$SUDO ln -s "$BACKUP_PATH/automatic-backup.timer" /etc/systemd/system/automatic-backup.timer
echo "::: Created symlinks to $BACKUP_PATH"

# Reload systemd and udev
systemctl daemon-reload
$SUDO udevadm control --reload
echo "::: Reloaded systemd and udev"

# Enable service timer
$SUDO systemctl enable automatic-backup.timer
echo "::: Enabled automated-backup timer"

# Start first backup
$SUDO systemctl start automatic-backup.service
echo "::: Started first backup"
