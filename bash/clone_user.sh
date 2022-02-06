#!/bin/bash -exu

SRC_USER=$1
DEST_USER=$2

SRC_GROUPS=$(id -Gn ${SRC_USER} | sed "s/ /,/g" | sed -r 's/\<'${SRC_USER}'\>\b,?//g')
SRC_SHELL=$(awk -F : -v name=${SRC_USER} '(name == $1) { print $7 }' /etc/passwd)

sudo useradd --groups ${SRC_GROUPS} --shell ${SRC_SHELL} --create-home ${DEST_USER}
sudo passwd ${DEST_USER}
