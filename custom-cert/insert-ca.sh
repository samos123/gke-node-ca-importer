#!/bin/bash

cp /myCA.pem /mnt/etc/ssl/certs

nsenter --target 1 --mount update-ca-certificates

nsenter --target 1 --mount bash -c "systemctl is-active --quiet docker && echo 'Restarting docker' && systemctl restart docker"
nsenter --target 1 --mount bash -c "systemctl is-active --quiet containerd && echo 'Restarting containerd' && systemctl restart containerd"

# NOTE: After the CRI restarts subsequent logs may not be visible, however the subsequent commands should
# still have run. You can verify with something like:
# touch /mnt/etc/completed.txt
echo "complete"

