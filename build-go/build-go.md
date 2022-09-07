Go can be found in most distro's package repositories, don't forget to check them.

Follow the below instructions if you need a specific version, as pre-made riscv64 Go binaries aren't officially available.

# Install from source

Instructions adapted from https://go.dev/doc/install/source and from https://github.com/carlosedp/riscv-bringup/blob/master/build-golang.md

The Go toolchain is written in Go : Go is used to build itself. 

### Bootstrap toolchain from binary release

Pre-made binaries can be found here : https://github.com/carlosedp/riscv-bringup/releases/tag/v1.0

Or here : https://github.com/chefmtt/riscv64/releases/tag/v0.1

If your build system uses a MMU in SV57 mode (see [this warning](https://github.com/chefmtt/riscv64#warning-if-you-want-to-use-another-image), you'll need a binary integrating this [commit](https://github.com/golang/go/commit/1e3c19f3fe), such as this one : https://github.com/chefmtt/riscv64/releases/download/v0.1/go1.19beta1-264-g1e3c19f3fe.linux-riscv64.tar.xz

To install binary release :

```bash
wget <link to binary release>
tar vxf <path to binary release> -C /usr/local
# Add the go binary to your PATH
export PATH="/usr/local/go/bin:$PATH"
echo "export PATH=/usr/local/go/bin:$PATH" >> ~/.bashrc
```

### Bootstrap toolchain from cross-compiled source

Alternatively, you can cross-compile a bootstrap toolchain. On a system where Go is installed, follow these steps : 

```bash
git clone https://github.com/golang/go.git
cd go
# If the system you target uses SV57 mode, you have to either apply the patch manually or checkout to a commit where the fix has been integrated (https://github.com/golang/go/commit/1e3c19f3fe)
cd src
GOOS=linux GOARCH=riscv64 ./bootstrap.bash
```

Copy the resulting `go-linux-riscv64-bootstrap.tbz` file to your RISCV-64 system.

### Bootstrap toolchain from C source code

For this, you need go 1.14. However, go 1.14 enabled only [experimental support of the RISCV-64 architecture](https://tip.golang.org/doc/go1.14#riscv). I haven't tested it, but I would be wary  of using this method.

## On your RISCV-64 system

Install git

Install a C compiler (gcc, clang...)

If you decided to use a binary release to bootstrap your build, make sure it is installed.

You can then start building go :

```bash
tar vxf go-linux-riscv64-bootstrap.tbz && export GOROOT_BOOTSTRAP=$HOME/go-linux-riscv64-bootstrap # If you cross-compiled a bootstrap toolchain
git clone https://github.com/golang/go.git goroot
cd goroot
git checkout <commit or desired version tag>

pushd goroot/src
./make.bash
# Test your go build
GO_TEST_TIMEOUT_SCALE=10 ./run.bash
popd
# To package your go build
tar -cvf $(git --git-dir ./go/.git describe --tags).$(uname -s |tr [:upper:] [:lower:])-$(uname -m).tar --exclude=pkg/obj --exclude=.git go
```
