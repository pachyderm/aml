#!/bin/bash
set -xeuo pipefail

# To be run by systemd
pkill -9 -f 'kubectl port-forward' || true
kubectl port-forward service/pachd 30650:30650 &
pid=$!
echo "Waiting for 10s for port forwarding to start working before proceeding..."
sleep 10
if [ ! -e /proc/$pid/cmdline ]; then
    echo "Port-forward exited, oh no"
    exit 1
fi
source /home/pachyderm/env.sh
python3 /home/pachyderm/syncer/sync.py
