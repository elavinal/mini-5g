#!/usr/bin/env bash

# Print commands (-x) and exit on errors (-e)
set -xe

echo "Provisioning 5G data plane VM..."

sudo apt-get update -q

# ----- Dependencies and other usefull tools -----
echo "Installing dependencies"
sudo apt-get install -q -y --no-install-recommends --fix-missing\
  gcc g++ \
  make \
  git \
  python3 python3-pip \
  vim \
  curl \
  wget \
  libsctp-dev lksctp-tools \
  iproute2 \
  net-tools \
  tcpdump \
  iperf \
  xterm

sudo snap install cmake --classic

#----- Mininet -----
echo "Installing Mininet"
git clone https://github.com/mininet/mininet.git
cd mininet
# Install Mininet itself (-n), the OpenFlow reference controller (-f),
# and Open vSwitch (-v)
PYTHON=python3
sudo util/install.sh -fnv

# ----- UERANSIM -----
echo "Installing UERANSIM"
cd ~
git clone https://github.com/aligungr/UERANSIM
cd UERANSIM
make

# Update UERANSIM config files
# (files have already been provisioned in $HOME/tmp by Vagrant)
cp ~/tmp/free5gc-gnb.yaml ~/UERANSIM/config/
cp ~/tmp/free5gc-ue.yaml ~/UERANSIM/config/

# ----- Free5GC UPF -----

# ----- Go -----
cd ~
wget https://dl.google.com/go/go1.14.4.linux-amd64.tar.gz
sudo tar -C /usr/local -zxvf go1.14.4.linux-amd64.tar.gz
mkdir -p ~/go/{bin,pkg,src}
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export GOROOT=/usr/local/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin:$GOROOT/bin' >> ~/.bashrc
echo 'export GO111MODULE=auto' >> ~/.bashrc
source ~/.bashrc
# doing export manually (source ~/.bashrc doesn't seem to work with Vagrant...)
export GOPATH=$HOME/go
export GOROOT=/usr/local/go
export PATH=$PATH:$GOPATH/bin:$GOROOT/bin
export GO111MODULE=auto
# clean up
rm go1.14.4.linux-amd64.tar.gz

# ----- User-plane Supporting Packages -----
sudo apt-get install -q -y \
  git gcc g++ cmake autoconf libtool pkg-config libmnl-dev libyaml-dev
go get -u github.com/sirupsen/logrus

# ----- Install Free5GC's UPF -----
cd ~
git clone --recursive -b v3.1.0 -j `nproc` https://github.com/free5gc/free5gc.git
cd free5gc
make upf
# Apply patch to run only UPF
patch run.sh ~/tmp/run_only_upf.patch
# Update UPF's config (N3 and N4 addresses to run in mininet)
cp ~/tmp/upfcfg.yaml ~/free5gc/config/

# ----- Install 5G GTP-U kernel module -----
sudo apt install linux-headers-$(uname -r)
cd ~
git clone -b v0.5.3 https://github.com/free5gc/gtp5g.git
cd gtp5g
make
sudo make install

echo "**** DONE PROVISIONING VM ****"

sudo reboot
