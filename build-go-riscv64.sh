#!/usr/bin/env bash

wget "https://go.dev/dl/go1.19.src.tar.gz"
tar -xf go1.19.src.tar.gz
cd go/src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
cd ../..
mv go go1.19-src
mv go-linux-riscv64-bootstrap go
tar -cJf go1.19.linux-riscv64.tar.xz go/
