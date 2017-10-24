#!/bin/bash

cat ./bt.sh | grep -o "BT_.*" | cut -f 1 -d "}" | grep -v "=" | grep -v " " | grep -v "{" | grep -v ")" | sort -d | uniq