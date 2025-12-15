# Talosctl & Omnictl Quick Reference

This guide covers common operations for managing Talos nodes via Omni.

## Prerequisites

```bash
# Install tools
brew install siderolabs/tap/talosctl
brew install siderolabs/tap/omnictl
```

## Authentication

### Get Fresh Talosconfig

```bash
cd ~/git/side/omni

# Download talosconfig for specific cluster
omnictl talosconfig -c erauner-home ./talosconfig.yaml -f

# Download generic talosconfig (works with any machine)
omnictl talosconfig ./talosconfig-generic.yaml -f
```

### Authenticate omnictl

If you see authentication errors, omnictl will open a browser to authenticate:

```bash
# This will trigger auth flow if needed
omnictl cluster status erauner-home
```

## Common Operations

### Check Cluster Status

```bash
# Overall cluster health
omnictl cluster status erauner-home

# Watch status continuously
watch -n5 "omnictl cluster status erauner-home"
```

### Node Operations via talosctl

```bash
# Set talosconfig path
export TALOSCONFIG=./talosconfig.yaml

# List all nodes
kubectl get nodes -o wide

# Reboot a specific node
talosctl -n 10.0.0.33 reboot

# Get node services
talosctl -n 10.0.0.33 services

# View kernel logs
talosctl -n 10.0.0.33 logs -k

# Check installed extensions
talosctl -n 10.0.0.33 get extensions

# Check PCI devices (useful for GPU debugging)
talosctl -n 10.0.0.33 get devices.pci
```

### Template Management

```bash
# Validate template
omnictl cluster template validate -f cluster-template-home.yaml

# Show what would change
omnictl cluster template diff -f cluster-template-home.yaml

# Apply changes (triggers rolling upgrade if needed)
omnictl cluster template sync -f cluster-template-home.yaml

# Export current cluster config to template
omnictl cluster template export -c erauner-home > exported-template.yaml
```

## System Extensions

System extensions add functionality to the immutable Talos OS.

### View Available Extensions

Check [Image Factory](https://factory.talos.dev/) for available extensions.

### Common Extensions

| Extension | Purpose |
|-----------|---------|
| `siderolabs/iscsi-tools` | iSCSI support (Synology CSI) |
| `siderolabs/amdgpu` | AMD GPU driver |
| `siderolabs/amd-ucode` | AMD microcode updates |
| `siderolabs/btrfs` | BTRFS filesystem |
| `siderolabs/util-linux-tools` | Linux utilities |

### Add Extensions

In `cluster-template-home.yaml` under Workers:

```yaml
systemExtensions:
  - siderolabs/iscsi-tools
  - siderolabs/amdgpu
  - siderolabs/amd-ucode
```

Then sync: `omnictl cluster template sync -f cluster-template-home.yaml`

## Troubleshooting

### GPU Not Detected

```bash
# Check extensions are installed
talosctl -n <node-ip> get extensions

# Check PCI devices
talosctl -n <node-ip> get devices.pci

# Check kernel logs for amdgpu
talosctl -n <node-ip> logs -k | grep -i amdgpu

# Check if /dev/dri exists
kubectl exec -n media deploy/media-stack-plex -- ls -la /dev/dri
```

### Node Won't Boot

```bash
# Check machine status in Omni
omnictl cluster status erauner-home

# View boot logs
talosctl -n <node-ip> logs machined
```

### Rolling Upgrade Stuck

```bash
# Check detailed status
omnictl cluster status erauner-home

# Force a machine lock/unlock to retry
omnictl cluster machine lock erauner-home <machine-id>
omnictl cluster machine unlock erauner-home <machine-id>
```

## Upgrading Talos

### Check Available Versions

```bash
# List available Talos versions
omnictl get talosversions

# Check current version
kubectl get nodes -o wide  # OS-IMAGE column shows version
```

### Upgrade Process

1. **Update `cluster-template-home.yaml`**:
   ```yaml
   talos:
     version: v1.11.5  # Change to target version
   ```

2. **Validate and preview**:
   ```bash
   omnictl cluster template validate -f cluster-template-home.yaml
   omnictl cluster template diff -f cluster-template-home.yaml
   ```

3. **Apply the upgrade**:
   ```bash
   omnictl cluster template sync -f cluster-template-home.yaml
   ```

4. **Monitor the rolling upgrade**:
   ```bash
   watch -n5 "omnictl cluster status erauner-home"
   ```

### Upgrade Path

Always upgrade through adjacent minor versions:
- v1.9.x → v1.10.x → v1.11.x (not v1.9.x → v1.11.x directly)

### Supported Kubernetes Versions

Each Talos version supports specific Kubernetes versions. Check compatibility:
- [Talos Support Matrix](https://www.talos.dev/docs/support-matrix/)

## Tool Version Management

### Check Versions

```bash
# Check omnictl version vs backend
omnictl version

# Check talosctl version
talosctl version --client
```

### Update Tools

```bash
# Update omnictl to match backend
brew upgrade siderolabs/tap/omnictl

# Update talosctl
brew upgrade siderolabs/tap/talosctl
```

**Tip**: Keep `omnictl` version close to backend version to avoid compatibility issues.

## Architecture Reference

| Config Layer | Managed By | Examples |
|-------------|-----------|----------|
| Machine/OS | Omni/Talos | kernel modules, extensions, network |
| Cluster Bootstrap | Omni/Talos | CNI, API server, PSS |
| Kubernetes Workloads | Flux/ArgoCD | apps, operators, configs |

**Key insight**: System extensions and kernel modules are OS-level (Omni).
Kubernetes workloads like CoreDNS are GitOps-managed (Flux).

## Links

- [Talos Documentation](https://www.talos.dev/docs/)
- [Omni Documentation](https://omni.siderolabs.io/docs/)
- [AMD GPU Guide](https://docs.siderolabs.com/talos/v1.11/configure-your-talos-cluster/hardware-and-drivers/amd-gpu)
- [Image Factory](https://factory.talos.dev/)
