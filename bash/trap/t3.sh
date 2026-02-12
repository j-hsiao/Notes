#!/bin/bash

echo "inside before ${1} ${BASH_SOURCE[0]}"
trap -p ERR RETURN

"${1}"

echo "inside after ${1} ${BASH_SOURCE[0]}"
