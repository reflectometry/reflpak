#!/bin/bash

# Author: Frank Szczerba
# stackoverflow.com/questions/59895
# Find the directory containing the script
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
ROOT="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Start octave in the script directory
cd "$ROOT"
echo "server(1515,'129.6.12[123].*')" | octave -q
