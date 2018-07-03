#!/bin/bash

set -exuo pipefail

javap -p -l -v -s -c $1
