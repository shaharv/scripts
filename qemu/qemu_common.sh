#!/bin/bash -eu

qemu_pass=""
qemu_port=""
qemu_dbg_port=""
qemu_user=""
qemu_workspace=""
qemu_sshpass_timeout_sec="3600" # default 1 hour timeout
qemu_max_connect_attempts="30"  # default 30 connect attempts
qemu_max_start_attempts="3"     # default 3 start/wait attempts
