#!/bin/bash
set -xeuo pipefail

# To be run by systemd
pkill -9 -f 'kubectl port-forward' || true
kubectl port-forward service/pachd 30650:650 &
pid=$!
echo "Waiting for 15 seconds for port forwarding to start working before proceeding..."
sleep 15
if [ ! -e /proc/$pid/cmdline ]; then
    echo "Port-forward exited, oh no"
    exit 1
fi
source /home/ubuntu/scripts/env.sh
/usr/bin/python3 /home/ubuntu/syncer/sync.py
