# Install

If you want to launch a RISC-V systen through QEMU, see [the first two parts of the from zero guide](https://github.com/chefmtt/riscv64/blob/main/install/deploy-k3s-from-zero.md#preparing-the-host-os-and-installing-qemu). 

## Install Go

Read the [warning](https://github.com/chefmtt/riscv64#warning) and decides on which Go version you want.

Go 1.16.7 : https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/go1.16.7.linux-riscv64.tar.gz
Go 1.17 : https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/go1.17.linux-riscv64.tar.gz
Go 1.19 with SV57 mode support :

On your riscv64 machine :

```bash
# Install wget if needed
sudo apt install -y wget
# Download and unpack release
wget <GO-RELEASE-LINK>
sudo tar vxf <DO-RELEASE>.tar.gz-C /usr/local
# Add the go binary to your PATH
export PATH="/usr/local/go/bin:$PATH"
echo "export PATH=/usr/local/go/bin:$PATH" >> ~/.bashrc
```

## Install Docker

Read the [warning](https://github.com/chefmtt/riscv64#warning) and choose the appropriate Docker version.

Docker 20.20.2-dev : https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/docker-v20.10.2-dev_riscv64.deb
Docker <version number> built using Go 1.19 with SV57 mode support

On your riscv64 machine :

```bash
# Install wget if needed
sudo apt install -y wget
# Download and unpack release
wget <DOCKER-PACKAGE-LINK>
sudo apt install ./<DOCKER-PACKAGE>
# Reboot to start the docker systemd service
# Verify your installation
sudo docker run hello-world
```
By default, you need to run docker as sudo. to add permissions to another user :
```bash
sudo usermod -aG docker <USER>
```

## Install K3s