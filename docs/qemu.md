# Deploying Immich on Flatcar with QEMU

This guide walks you through running the Immich Flatcar App locally using QEMU.

## Prerequisites

- Linux or macOS with KVM support
- `qemu-system-x86_64` installed
- `butane` installed ([installation guide](https://coreos.github.io/butane/getting-started/))
- At least 4GB RAM and 20GB disk space available

## Step 1: Download Flatcar QEMU Image

```bash
# Download the latest stable Flatcar image
wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu.sh
wget https://stable.release.flatcar-linux.net/amd64-usr/current/flatcar_production_qemu_image.img.bz2

# Extract the image
bunzip2 flatcar_production_qemu_image.img.bz2
chmod +x flatcar_production_qemu.sh
```
## Step 2: Generate Ignition Config

```bash
mkdir -p ignition
butane --strict butane/immich.bu > ignition/immich.ign
```

## Step 3: Boot Flatcar with Ignition

The `flatcar_production_qemu.sh` script already creates a netdev with SSH port-forwarding on `2222`.  
**Do not** create another netdev with `id=eth0` or duplicate the `2222` forward — that causes QEMU errors.

```bash
# Forward only the extra port (2283) via a second NIC
./flatcar_production_qemu.sh -i ignition/immich.ign -- -m 4096 \
  -netdev user,id=net0,hostfwd=tcp::2283-:2283 \
  -device virtio-net-pci,netdev=net0
```

> **Note:** Increase `-m 4096` to `-m 8192` if you have enough RAM. Immich ML benefits from more memory.  
> The `hvf` warning (if shown) is harmless — QEMU falls back to KVM automatically.

## Step 4: Access Immich

Wait ~2-3 minutes for all containers to pull and start, then:

```bash
# SSH into the VM (port 2222 is forwarded by the script)
ssh -p 2222 core@localhost

# Check service status
systemctl status immich-server

# Run the health check
/opt/bin/immich-health
```

From the host:

```bash
curl http://localhost:2283/api/server-info/ping
```

Open your browser to `http://localhost:2283` and create your admin account.

## Step 5: Verify Backups

```bash
ssh -p 2222 core@localhost

# Trigger a manual backup
/opt/bin/immich-backup

# List backups
ls -la /var/lib/immich/backups/
```

## Troubleshooting

### Ignition fails with "read-only file system"
You tried to write to `/usr/local/bin/`, `/usr/lib/`, or another immutable path. Move custom scripts to `/opt/bin/` and configs to `/etc/` or `/var/`.

### Ignition fails with "A file exists there already and overwrite is false"
A file in `/etc/` (like `/etc/logrotate.d/immich`) already exists in the base Flatcar image. Add `overwrite: true` to the file entry in your Butane config.

### QEMU error: "Duplicate ID 'eth0' for netdev"
The script already defines `id=eth0`. Use a different ID (e.g., `id=net0`) in your extra `-netdev` argument, or simply don't duplicate the SSH forward.

### QEMU error: "Could not set up host forwarding rule 'tcp::2222-:22'"
Same as above — port `2222` is already forwarded by the script. Only add your extra port (`2283`) to the second NIC.

### Containers won't start
```bash
ssh -p 2222 core@localhost
journalctl -u immich-server -f
docker logs immich-server
```

### Out of disk space
```bash
# Check disk usage
df -h

# Immich stores photos in /var/lib/immich/upload
# The default QEMU disk might be too small. Create a larger overlay:
qemu-img create -f qcow2 -b flatcar_production_qemu_image.img extra-disk.img 50G
```

### SSH connection refused
Wait a bit longer — Flatcar takes ~30-60 seconds to boot and apply Ignition on first boot. The script forwards port `2222`, not `22`.

## Cleanup

```bash
# In QEMU console (Ctrl+A then C), type:
(qemu) quit

# Or from another terminal
killall qemu-system-x86_64
```