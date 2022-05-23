#!/bin/bash -eu

qemu_pass=""
qemu_port=""
qemu_dbg_port=""
qemu_user=""
qemu_workspace=""
qemu_sshpass_timeout_sec="3600" # default 1 hour timeout
qemu_max_connect_attempts="5"   # default 5 connect attempts (15 seconds between each)
qemu_max_start_attempts="5"     # default 5 start/wait attempts
qemu_ssh_command="sshpass -p $qemu_pass ssh -o StrictHostKeyChecking=no $qemu_user -p $qemu_port"
qemu_scp_command="sshpass -p $qemu_pass scp -o StrictHostKeyChecking=no -r -P $qemu_port"
