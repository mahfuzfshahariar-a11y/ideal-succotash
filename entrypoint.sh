#!/bin/bash
set -e

echo "Starting OpenSSH server on port 22..."
exec /usr/sbin/sshd -D
