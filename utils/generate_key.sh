#!/bin/bash
ssh-keygen -q -t ed25519 -N "" -f ./example.keyfile.pem <<<y >/dev/null
base64 -w 0 ./example.keyfile.pem
