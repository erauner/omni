#!/bin/bash
# Quick cluster status check with useful info

set -e

CLUSTER_NAME="${1:-erauner-home}"

echo "=== Cluster Status ==="
omnictl cluster status "$CLUSTER_NAME" 2>&1 | head -20

echo ""
echo "=== Node Versions ==="
kubectl get nodes -o wide 2>/dev/null | awk '{print $1, $5, $9}' || echo "kubectl not configured"

echo ""
echo "=== Tool Versions ==="
echo -n "omnictl: "
omnictl version 2>&1 | grep -o 'client.*' | head -1 || echo "unknown"
echo -n "talosctl: "
talosctl version --client 2>&1 | grep -o 'Tag:.*' | head -1 || echo "unknown"

echo ""
echo "=== GPU Status (workers) ==="
export TALOSCONFIG="${TALOSCONFIG:-./talosconfig-fresh.yaml}"
for node in $(kubectl get nodes -l 'amd.com/gpu=true' -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); do
    echo "Node $node:"
    talosctl -n "$node" ls /dev/dri 2>&1 | grep -E 'card|render' || echo "  No GPU devices"
done
