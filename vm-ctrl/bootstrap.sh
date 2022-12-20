#!/usr/bin/env bash

# Print commands (-x) and exit on errors (-e)
set -xe

echo "Provisioning 5G control plane VM..."

sudo apt-get update -q

# ----- Installing usefull tools -----
echo "Installing some tools..."
sudo apt-get install -q -y \
  gcc g++ make cmake autoconf \
  git \
  vim \
  curl wget \
  iproute2 \
  net-tools \
  tcpdump \
  iperf

# ----- Go -----
cd ~
wget https://dl.google.com/go/go1.17.linux-amd64.tar.gz
sudo tar -C /usr/local -zxf go1.17.linux-amd64.tar.gz
mkdir -p ~/go/{bin,pkg,src}
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin:$GOROOT/bin' >> ~/.bashrc
echo 'export GO111MODULE=auto' >> ~/.bashrc
source ~/.bashrc
# doing export manually (source ~/.bashrc doesn't seem to work with Vagrant provisioning...)
export GOPATH=$HOME/go
export GOROOT=/usr/local/go
export PATH=$PATH:$GOPATH/bin:$GOROOT/bin
export GO111MODULE=auto
# clean up
rm go1.17.linux-amd64.tar.gz

# ---- Control-plane Supporting Packages -----
echo "Installing control-plane packages..."
sudo apt -y install mongodb wget git
sudo systemctl start mongodb

# ----- User-plane Supporting Packages -----
# NOTE. These packages shouldn't be necessary in this VM?
# echo "Installing user-plane packages..."
# sudo apt -y install git gcc g++ cmake autoconf libtool pkg-config libmnl-dev libyaml-dev

# ----- Install Control Plane Elements -----
cd ~
git clone --recursive -b v3.2.1 -j `nproc` https://github.com/free5gc/free5gc.git
cd free5gc
make amf ausf nrf nssf pcf smf udm udr n3iwf
# Apply patch to run without UPF
patch run.sh ~/tmp/run_without_upf.patch

# Update free5GC config files (AMF and SMF)
# (files have already been provisioned in $HOME/tmp by Vagrant)
cp ~/tmp/amfcfg.yaml ~/free5gc/config/
cp ~/tmp/smfcfg.yaml ~/free5gc/config/

# ---- Install CLI to populate free5GC DB -----
cd ~
git clone https://github.com/shynuu/free5gc-populate.git
cd free5gc-populate
go build
./free5gc-populate --config config.yaml 

echo "**** DONE PROVISIONING VM ****"
