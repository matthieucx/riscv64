# Build a k3s release for the RISCV 64 architecture

k3s is a Kubernetes release maintained by Rancher. As k8s, it packages a lot of different software, and each one need to be built for the RISCV-64 architecture before being used by the k3s binary or bundled into it.

### Choose the k3s release you want to build

In this guide, I targeted release `v1.21.11+k3s`.

## Build k3s-root

k3s downloads a k3s-root release during the build process.

You can find the k3s-root version here : https://github.com/k3s-io/k3s/blob/v1.21.11%2Bk3s1/scripts/version.sh#L47

The `riscv64config` file has been built using these 3 ressources :

> https://github.com/k3s-io/k3s-root/tree/master/buildroot
>
> https://github.com/buildroot/buildroot/blob/master/configs/qemu_riscv64_virt_defconfig
>
> https://github.com/buildroot/buildroot/blob/master/arch/Config.in.riscv

```bash
export ROOT-VERSION=v0.9.1
git clone https://github.com/k3s-io/k3s-root.git
cd k3s-root
git checkout tags/$ROOT-VERSION
# Download a buildroot riscv64config file 
wget https://github.com/chefmtt/riscv64/releases/download/v0.1/riscv64config -P ./buildroot
# Target riscv64 arch by default
sed -i "s/ARCH ?= amd64/ARCH ?= riscv64/" Makefile

sudo make
```

You will be prompted with a few configuration options.

I built k3s to use it with a QEMU VM, I went with :

```
Target Architecture
> 22. RISCV (BR2_riscv)

Target Binary Format
> 1. ELF (BR2_BINFMT_ELF)

Target Architecture Variant
> 1. General purpose (G) (BR2_riscv_g)

Target Architecture Size
> 2. 64-bit (BR2_RISCV_64)

Target ABI
> 1. lp64 (BR2_RISCV_ABI_LP64)

*
* Bootloaders
*
Barebox (BR2_TARGET_BAREBOX) [N/y/?] n
opensbi (BR2_TARGET_OPENSBI) [N/y/?] (NEW) y      
  OpenSBI Platform (BR2_TARGET_OPENSBI_PLAT) [] (NEW) generic    
U-Boot (BR2_TARGET_UBOOT) [N/y/?] n
```

k3s uses the `dist/k3s-root-riscv64.tar` archive.

## Build images

You can find the different versions of the services used by k3s for a given version here : https://github.com/k3s-io/k3s/blob/v1.21.11%2Bk3s1/scripts/airgap/image-list.txt
Change the tag according to your target release.

Make sure to have docker installed. Then, set up buildx.

**WARNING :** If you plan on supporting a system where SV57 is enabled, remember to use a compatible go version, as explained [here](https://github.com/chefmtt/riscv64#warning-if-you-want-to-use-another-image)

```bash
wget https://github.com/docker/buildx/releases/download/v0.9.1/buildx-v0.9.1.linux-amd64
sudo cp buildx-v0.9.1.linux-amd64 /usr/local/lib/docker/cli-plugins/buildx

sudo apt install -y qemu-user-static binfmt-support
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

docker buildx create --name k3s-riscv64 # name as you like
docker buildx use k3s-riscv64
# Verify that building for linux/riscv64 architecture is possible
docker buildx inspect --bootstrap
```

### klipper-helm

Helm v2 requires go < 1.17 to build. Meaning, if you were to use a helm v2 chart on a RISCV64 system using MMU in SV57 mode, it would fail. Maybe it could be built with a higher version of go, or simply do not use helm v2 charts on such a system.
If you want the image to work on a system system using MMU in SV57 mode, you have to build the rest with a compatible version of go.

```bash
git clone https://github.com/rancher/klipper-helm
pushd klipper-helm
KLIPPERVERSION=v0.6.6-build20211022
git checkout $KLIPPERVERSION

mkdir helm
git clone https://github.com/helm/helm
cd helm
git checkout v3.6.3
GIT_COMMIT=$(git rev-parse "HEAD^{commit}" 2>/dev/null)
make build-cross
go get -u github.com/prometheus/procfs@v0.7.3
go mod tidy && go mod vendor
GOFLAGS="-trimpath" GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOARCH=riscv64 go build -ldflags '-w -s -X helm.sh/helm/v3/internal/version.metadata=unreleased -X helm.sh/helm/v3/internal/version.gitCommit=${GIT_COMMIT} -X helm.sh/helm/v3/internal/version.gitTreeState=dirty -X helm.sh/helm/v3/pkg/lint/rules.k8sVersionMajor=1 -X helm.sh/helm/v3/pkg/lint/rules.k8sVersionMinor=21 -X helm.sh/helm/v3/pkg/chartutil.k8sVersionMajor=1 -X helm.sh/helm/v3/pkg/chartutil.k8sVersionMinor=21 -extldflags "-static"' -o _dist/linux-riscv64/helm ./cmd/helm
mv _dist _distv3
git reset --hard
mkdir -p $GOPATH/src/k8s.io/ # https://v2.helm.sh/docs/developers/
cd ..
mv helm $GOPATH/src/k8s.io/
cd $GOPATH/src/k8s.io/helm
git checkout v2.17.0
GIT_COMMIT=$(git rev-parse "HEAD^{commit}" 2>/dev/null)

mkdir -p $GOPATH/bin
export GOBIN=$GOPATH/bin
export PATH="$GOBIN:$PATH"
curl https://raw.githubusercontent.com/chenxin0723/glide.sh/master/get | sh

# Replace sys mod to updated one in glide files.(47abb6519492c2e7f35c3a9f4d655f2bd32607cc) https://github.com/golang/go/issues/51513

sed -i "s/b90733256f2e882e81d52f9126de08df5615afd9/47abb6519492c2e7f35c3a9f4d655f2bd32607cc/" glide.yaml
sed -i "s/b90733256f2e882e81d52f9126de08df5615afd9/47abb6519492c2e7f35c3a9f4d655f2bd32607cc/" glide.lock

make bootstrap

for ARCH in riscv64; do
    GO111MODULE=off GOOS=linux GOARCH=${ARCH} go build -tags '' -ldflags '-w -s -X k8s.io/helm/pkg/version.Version=v2.17.0 -X k8s.io/helm/pkg/version.BuildMetadata= -X k8s.io/helm/pkg/version.GitCommit=${GIT_COMMIT} -X k8s.io/helm/pkg/version.GitTreeState=dirty' -o _dist/linux-${ARCH}/helm ./cmd/helm
    GO111MODULE=off GOOS=linux GOARCH=${ARCH} go build -tags '' -ldflags '-w -s -X k8s.io/helm/pkg/version.Version=v2.17.0 -X k8s.io/helm/pkg/version.BuildMetadata= -X k8s.io/helm/pkg/version.GitCommit=${GIT_COMMIT} -X k8s.io/helm/pkg/version.GitTreeState=dirty' -o _dist/linux-${ARCH}/rudder ./cmd/rudder
    GO111MODULE=off GOOS=linux GOARCH=${ARCH} go build -tags '' -ldflags '-w -s -X k8s.io/helm/pkg/version.Version=v2.17.0 -X k8s.io/helm/pkg/version.BuildMetadata= -X k8s.io/helm/pkg/version.GitCommit=${GIT_COMMIT} -X k8s.io/helm/pkg/version.GitTreeState=dirty' -o _dist/linux-${ARCH}/tiller ./cmd/tiller
done

cd ..

cp /root/k3s-images/klipper-helm/entry ./entry

cat > Dockerfile.custom << 'EOF'
FROM debian:sid

ARG TARGETARCH
ENV arch=$TARGETARCH

RUN apt-get update && apt-get install -y \
	ca-certificates \
	jq \
	bash \
	git

COPY helm/_distv3/linux-$arch/helm /usr/bin/helm_v3
COPY helm/_dist/linux-$arch/helm /usr/bin/helm_v2
COPY helm/_dist/linux-$arch/tiller /usr/bin/tiller
COPY entry /usr/bin/
ENV STABLE_REPO_URL=https://charts.helm.sh/stable/
ENTRYPOINT ["entry"]
EOF
# https://stackoverflow.com/questions/65365797/docker-buildx-exec-user-process-caused-exec-format-error
docker buildx build --platform linux/riscv64 -t $REPO/klipper-helm:$KLIPPERVERSION --push -f Dockerfile.custom .
popd
```

### klipper-lb

```bash
git clone https://github.com/rancher/klipper-lb
pushd klipper-lb
KLIPPERLBVERSION=v0.3.4
git checkout ${KLIPPERLBVERSION}

cat > Dockerfile.custom <<EOF
FROM carlosedp/debian-iptables:sid-slim
COPY entry /usr/bin/
CMD ["entry"]
EOF

docker buildx build --platform linux/riscv64 -t $REPO/klipper-lb:$KLIPPERLBVERSION --push -f Dockerfile.custom .

popd
```

### local-path-provisionner

```bash
git clone https://github.com/rancher/local-path-provisioner
pushd local-path-provisioner
LPPVERSION=v0.0.21
git checkout $LPPVERSION
LPPVERSION=v0.0.21
for ARCH in riscv64;
do
    echo "Building local-path-provisioner version $LPPVERSION for $ARCH"
    CGO_ENABLED=0 GOOS=linux GOARCH=$ARCH go build -ldflags "-X main.VERSION=$LPPVERSION -extldflags -static -s -w" -o bin/local-path-provisioner-$ARCH;
done

cat > Dockerfile.simple <<EOF
FROM scratch
ARG TARGETARCH
COPY bin/local-path-provisioner-\$TARGETARCH /usr/bin/local-path-provisioner
CMD ["local-path-provisioner"]
EOF

docker buildx build --platform linux/riscv64 -t $REPO/local-path-provisioner:$LPPVERSION --push -f Dockerfile.simple .
popd
```

### CoreDNS

v1.9.1 requires Go >= 1.17 to build

```bash
git clone https://github.com/coredns/coredns
cd coredns
VER=v1.9.1
git checkout ${VER}
GITCOMMIT=`git describe --dirty --always`
for arch in riscv64; do CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -v -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=${GITCOMMIT}" -o coredns-$arch .; done

docker run -it --rm -v $(pwd):/src -w /src carlosedp/crossbuild-riscv64 bash -c "cp -R /etc/ssl/certs . && cp -R /usr/share/ca-certificates/mozilla/ ./mozilla"
cat > Dockerfile.custom << 'EOF'
FROM scratch
ARG TARGETARCH
ENV arch=$TARGETARCH
ADD certs /etc/ssl/certs
ADD mozilla /usr/share/ca-certificates/mozilla
ADD coredns-$arch /coredns

EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
EOF
mv .dockerignore dockerignore-dis
docker buildx build -t ${REPO}/coredns:${VER} --platform linux/riscv64 --push -f Dockerfile.custom .
mv dockerignore-dis .dockerignore
```

### Busybox

You can find docker images for RISCV-64 on dockerhub here : https://hub.docker.com/r/riscv64/busybox/tags

For the 1.21.11 release, the required version is "1.34.1".

### Traefik

```bash
git clone https://github.com/containous/traefik.git
pushd traefik
TRAEFIKVERSION=v2.6.1
git checkout ${TRAEFIKVERSION}

cat >> ./script/crossbinary-default << 'EOF'
OS_PLATFORM_ARG=(linux)
OS_ARCH_ARG=(riscv64)
for OS in "${OS_PLATFORM_ARG[@]}"; do
  for ARCH in "${OS_ARCH_ARG[@]}"; do
    echo "Building binary for ${OS}/${ARCH}..."
    GOARCH=${ARCH} GOOS=${OS} CGO_ENABLED=0 ${GO_BUILD_CMD} "${GO_BUILD_OPT}" -o "dist/traefik_${OS}-${ARCH}" ./cmd/traefik/
  done
done
EOF

make crossbinary-default

cat > Dockerfile.custom << 'EOF'
FROM scratch
ARG TARGETARCH
ENV arch=$TARGETARCH

COPY script/ca-certificates.crt /etc/ssl/certs/
COPY dist/traefik_linux-$arch /traefik

EXPOSE 80
ENTRYPOINT ["/traefik"]
EOF

mv .dockerignore dockerignore-dis
docker buildx build -t ${REPO}/traefik:${TRAEFIKVERSION} --platform linux/riscv64 --push -f Dockerfile.custom .
mv dockerignore-dis .dockerignore

popd
```

### metrics-server

The original metrics-server image is based on a distroless image. I did not found any for the riscv64 platform and I don't know how to use Bazel. I simply took an already built image, copied my binary and made it the entrypoint. It's not pretty, but it works I guess.

```bash
git clone https://github.com/kubernetes-sigs/metrics-server
pushd metrics-server
#MSVERSION=`git tag | tail -1` # build last tagged version
MSVERSION=v0.5.2

GIT_COMMIT=$(git rev-parse "HEAD^{commit}" 2>/dev/null)
GIT_VERSION_RAW=$(git describe --tags --abbrev=14 "$GIT_COMMIT^{commit}" 2>/dev/null)
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
for ARCH in riscv64; do
    GOARCH=$ARCH GOOS=linux go build -ldflags '-w -X sigs.k8s.io/metrics-server/pkg/version.gitVersion=$GIT_VERSION_RAW -X sigs.k8s.io/metrics-server/pkg/version.gitCommit=$GIT_COMMIT -X sigs.k8s.io/metrics-server/pkg/version.buildDate=$BUILD_DATE' -o _output/$ARCH/metrics-server ./cmd/metrics-server;
doneriscv64-goland.md

cat > Dockerfile.simple <<EOF
FROM carlosedp/metrics-server:v0.3.6
ARG ARCH
COPY $ARCH/metrics-server /metrics-server-0.5.2
ENTRYPOINT ["/metrics-server-0.5.2"]
EOF

docker buildx build --no-cache --progress=plain --platform linux/riscv64 -t $REPO/metrics-server:$MSVERSION --push -f Dockerfile.simple ./_output
popd
```

### pause

```bash
git clone https://github.com/kubernetes/kubernetes
cd kubernetes
VER=3.5
git checkout tags/v1.21.11 # the desired k8s versions, whih uses pause {VER}
# Apply below changes to build/pause/Makefile to build for riscv64
```

```diff
diff --git a/build/pause/Makefile b/build/pause/Makefile
index 43f49e9d868..716d789f54a 100644
--- a/build/pause/Makefile
+++ b/build/pause/Makefile
@@ -20,7 +20,7 @@ IMAGE = $(REGISTRY)/pause
 TAG = 3.5
 REV = $(shell git describe --contains --always --match='v*')
 
-# Architectures supported: amd64, arm, arm64, ppc64le and s390x
+# Architectures supported: amd64, arm, arm64, ppc64le riscv64 and s390x
 ARCH ?= amd64
 # Operating systems supported: linux, windows
 OS ?= linux
@@ -32,7 +32,7 @@ OSVERSION ?= 1809 1903 1909 2004 20H2
 OUTPUT_TYPE ?= docker
 
 ALL_OS = linux windows
-ALL_ARCH.linux = amd64 arm arm64 ppc64le s390x
+ALL_ARCH.linux = amd64 arm arm64 ppc64le s390x riscv64
 ALL_OS_ARCH.linux = $(foreach arch, ${ALL_ARCH.linux}, linux-$(arch))
 ALL_ARCH.windows = amd64
 ALL_OSVERSIONS.windows := 1809 1903 1909 2004 20H2
@@ -70,6 +70,8 @@ TRIPLE.linux-arm := arm-linux-gnueabihf
 TRIPLE.linux-arm64 := aarch64-linux-gnu
 TRIPLE.linux-ppc64le := powerpc64le-linux-gnu
 TRIPLE.linux-s390x := s390x-linux-gnu
+TRIPLE.linux-riscv64 := riscv64-buildroot-gnu-linux
 TRIPLE := ${TRIPLE.${OS}-${ARCH}}
 BASE.linux := scratch
 BASE.windows := mcr.microsoft.com/windows/nanoserver
```

```bash
pushd build/pause
docker buildx build --platform linux/riscv64 --build-arg=BASE=scratch --build-arg=ARCH=riscv64 -t ${REPO}/pause:${VER} --push -f Dockerfile .
popd
```

## Helm-controller

K3s includes a [Helm Controller](https://github.com/rancher/helm-controller/) that manages Helm charts using a HelmChart Custom Resource Definition (CRD). This helm-controller uses rancher own klipper-helm image by default, which is not compatible with the riscv64 architecture.

There are 3 solutions :

1.  Use the spec.jobImage field of the Helm CRD, for example : `jobImage : "matthieucx/klipper-helm:v0.6.6-build20211022"`. [See an example of using the CRD](https://rancher.com/docs/k3s/latest/en/helm/#using-the-helm-crd).

2. Deploy a custom helm-controller, using a custom built image [as mentionned on the official github page](https://github.com/k3s-io/helm-controller#dockerk8s). For this, you need to change the `DefaultJobImage` [here](https://github.com/k3s-io/helm-controller/blob/v0.10.8/pkg/helm/controller.go#L33) to use your own klipper-home image before building the helm-controller image.

3. Find the required version [here](https://github.com/k3s-io/k3s/blob/v1.21.11%2Bk3s1/go.mod#L91). Fork the repository, checkout to the required version, make the aforementioned change and reference your repo instead of rancher's one in the code. Then, when cloning the k3s repo, reference your helm-controller repository instead of rancher's one in the go.mod file. Don't forget to run `go mod tidy` to have a valid go.sum file. [Example](https://github.com/chefmtt/helm-controller-riscv64/commits/release-0.10.8) with the 3 last commits. Basically :

   ```bash
   # Fork and clone repository locally
   cd helm-controller-fork
   git checkout tags/v0.10.8
   go run pkg/codegen/cleanup/main.go
   /bin/rm -rf pkg/generated
   wget https://github.com/chefmtt/riscv64/releases/download/v0.1/helm-controller-0.10.8.patch # Patch for v0.10.8, can easily be adapted to another version
   patch -p1 < helm-controller-0.10.8.patch
   go run pkg/codegen/main.go
   # Commit changes
   ```

   Once the changes are commited, make a new release.

# On your RISCV-64 system

## Trivy

> Scanner for vulnerabilities in container images, file systems, and Git  repositories, as well as for configuration issues and hard-coded secrets    

Trivy can be installed from source as follows :

```bash
cd ~
mkdir go_trivy
export GOPATH=~/go_trivy
mkdir -p $GOPATH/src/github.com/aquasecurity
cd $GOPATH/src/github.com/aquasecurity
git clone --depth 1 --branch v0.16.0 https://github.com/aquasecurity/trivy
cd trivy/cmd/trivy/
export GO111MODULE=on
go install
```

The dapper binary will be located in `~go_trivy/bin/`

## Dapper

Dapper is a docker wrapper maintained by rancher, who develops k3s. Dapper can be installed from source using go.

```bash
go install github.com/rancher/dapper@v0.6.0
```

The dapper binary will be located in `./go/bin/`

## yq

yq is a portable command-line YAML, JSON, XML, CSV and properties processor. The `-e` option appeared in `v4` and became the default option in `v4.18.1` and does not need to be specified in versions since.

Check for wether your target release uses `yq -e` or simply `yq`, [here](https://github.com/k3s-io/k3s/blob/v1.21.11%2Bk3s1/scripts/download) for example.

```bash
# yq -e
go install github.com/mikefarah/yq/v4@v4.17.2
# yq
go install github.com/mikefarah/yq/v4@latest
```

The yq binary will be located in `./go/bin/`

## Installing dependencies

```bash
sudo apt install -y ztsd gawk
# Install your yq binary (the binary must be in your current working directory)
sudo cp yq /usr/local/bin/yq
```

You must have go and docker installed on your system.  
[Follow these instructions to do so](https://github.com/chefmtt/riscv64/blob/main/install/deploy-k3s-from-zero.md#installing-go)  
If  your system uses SV57 mode (see [this warning](https://github.com/chefmtt/riscv64#warning-if-you-want-to-use-another-image)), your glibc version is likely 2.33 or above. If so, you can simply install the appropriate Docker binary (built with a go version supporting SV57, such as [this one](https://github.com/chefmtt/riscv64/releases/download/v0.1/docker-20.10.17_riscv64.deb)) and skip installing glibc and PatchELF.

## Building K3s

The patch mentionned below can be adapted to suit your targeted release and fetch the images and binaries you built.

```bash
git clone https://github.com/k3s-io/k3s.git
cd k3s
git checkout tags/v1.21.11+k3s1
wget https://github.com/chefmtt/riscv64/releases/download/v0.1/k3s-1.21.11.patch
patch -p1 < k3s-1.21.11.patch
```

The k3s binary is located in `dist/artifacts`.
To install k3s using your custom binary :

```bash
# The install script is found at the root of the k3s repo
cd path/to/k3s/repo
# Make sure the binary is executable
sudo cp dist/artifacts/k3s-riscv64 /usr/local/bin
sudo INSTALL_K3S_SKIP_DOWNLOAD=true ./install.sh
# Verify installation
sudo kubectl get nodes
```

