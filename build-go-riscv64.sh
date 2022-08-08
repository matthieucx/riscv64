#!/usr/bin/env bash

wget "https://go.dev/dl/go1.19.src.tar.gz"
tar -xf go1.19.src.tar.gz
cd go/src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
