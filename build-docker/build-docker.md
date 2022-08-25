# Building Docker

This guide is an update of [Carlos de Paula's guide]([riscv-bringup/build-docker-env.md at master · carlosedp/riscv-bringup · GitHub](https://github.com/carlosedp/riscv-bringup/blob/master/build-docker-env.md)).

[This updated guide](https://forum.rvspace.org/t/docker-engine-and-docker-cli-on-riscv64/267[Docker engine and Docker CLI on riscv64 - RISC-V Ecosystem - RVspace Forum](https://forum.rvspace.org/t/docker-engine-and-docker-cli-on-riscv64/267)) was also used.

This guide create a deb package.

## Create a temp folder for building

```bash
mkdir -p $HOME/riscv-docker/debs
cd $HOME/riscv-docker

//TODO GOPATH
```

## Install building dependencies

```bash
sudo apt install -y build-essential cmake pkg-config libseccomp2 libseccomp-dev libdevmapper-dev libbtrfs-dev
```

## runc

```bash
git clone https://github.com/opencontainers/runc
pushd runc
make
DESTDIR=$HOME/riscv-docker/debs make install
popd
```

## containerd

```bash
git clone https://github.com/containerd/containerd
pushd containerd

make BUILDTAGS="no_btrfs"
DESTDIR=$HOME/riscv-docker/debs/usr/local make install
popd
```

## docker-cli

```bash
mkdir -p $GOPATH/src/github.com/docker/
pushd $GOPATH/src/github.com/docker/
git clone https://github.com/docker/cli
pushd cli
DISABLE_WARN_OUTSIDE_CONTAINER=1 GO111MODULE=off make
cp ./build/docker-linux-riscv64 $HOME/riscv-docker/debs/usr/local/bin
ln -sf docker-linux-riscv64 $HOME/riscv-docker/debs/usr/local/bin/docker
popd
popd
```

## docker-init

```bash
git clone https://github.com/krallin/tini
pushd tini
export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"
cmake . && make
cp tini-static $HOME/riscv-docker/debs/usr/local/bin/docker-init
popd
```

## docker-proxy

```bash
mkdir $GOPATH/src/github.com/docker
pushd $GOPATH/src/github.com/docker
git clone https://github.com/docker/libnetwork/
pushd libnetwork
go get github.com/ishidawataru/sctp
GO111MODULE=off go build ./cmd/proxy
cp proxy $HOME/riscv-docker/debs/usr/local/bin/docker-proxy
popd
popd
```

## rootlesskit

```bash
mkdir $GOPATH/src/github.com/rootless-containers/
pushd $GOPATH/src/github.com/rootless-containers/
git clone https://github.com/rootless-containers/rootlesskit.git
pushd rootlesskit
make
DESTDIR=$HOME/riscv-docker/debs/ make install
popd
popd
```

## dockerd

```bash
mkdir -p $GOPATH/src/github.com/docker/
pushd $GOPATH/src/github.com/docker/
git clone https://github.com/moby/moby docker
pushd docker
sudo cp ./contrib/dockerd-rootless.sh $HOME/riscv-docker/debs/usr/local/bin

./hack/make.sh binary
sudo cp bundles/binary-daemon/dockerd-dev $HOME/riscv-docker/debs/usr/local/bin/dockerd
popd
popd
```

## Add systemd services files

```bash

```

## Add DEB files

```bash

```

## Create .deb package

```bash
chmod +x $HOME/riscv-docker/debs/DEBIAN/postinst

cd $HOME/riscv-docker/
dpkg-deb -b debs docker-master-dev_riscv64.deb
```


