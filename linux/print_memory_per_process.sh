#!/bin/bash -ex

# Print the highest RAM consuming processes.
# Source: https://www.golinuxcloud.com/check-memory-usage-per-process-linux

ps -eo user,pid,ppid,cmd,pmem,rss --no-headers --sort=-rss | \
    awk '{if ($2 ~ /^[0-9]+$/ && $6/1024 >= 1) {printf "PID: %s, PPID: %s, Memory Consumed (RSS): %.2f MB, Command: ", $2, $3, $6/1024; for (i=4; i<NF; i++) printf "%s ", $i; printf "\n"}}'
