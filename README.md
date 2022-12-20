# mini-5g
A virtual environment to experiment a mini 5G network (based on free5GC and UERANSIM)

This environment is composed of two virtual machines:

1. A data plane VM (`vm-data`) that runs a simple [mininet](http://mininet.org/) topology
with a simulated RAN based on [UERANSIM](https://github.com/aligungr/UERANSIM),
a Linux router and a UPF from free5GC.

2. A control plane VM (`vm-ctrl`) that runs [free5GC](https://www.free5gc.org/) v3.2.1,
an open-source 5G core network.

The overall architecture is illustrated bellow.

**TODO**

## Install

The VMs are automatically provisioned with [Vagrant](https://www.vagrantup.com/).
Once you have cloned this repository, installing and configuring the VMs is very easy:

```
cd vm-ctrl
vagrant up
```
and

```
cd vm-data
vagrant up
```

## Run

Data plane

Start mininet

```
$ cd vm-data
$ vagrant ssh
$ cd mini-5g
$ sudo -E ./5g-simple-topo.py
mininet> xterm h1 h1 h2
```

Start UPF in `h2`

```
h2# sysctl -w net.ipv4.ip_forward=1
h2# iptables -I FORWARD 1 -j ACCEPT
h2# iptables -t nat -A POSTROUTING -s 10.60.0.0/16 -o h2-eth1 -j MASQUERADE
h2# cd ~/free5gc
h2# ./run.sh
```

Start control plane in VM free5GC

```
cd vm-ctrl
vagrant ssh
sudo ip route add 192.168.3.0/24 via 192.168.56.20 dev enp0s8
cd free5gc
./run.sh
```

Start gNB in `h1`

```
h1# cd ~/UERANSIM/build
h1# ./nr-gnb -c ../config/free5gc-gnb.yaml
```

Start UE in `h1` (another xterm)

```
h1# cd ~/UERANSIM/build
h1# ./nr-ue -c ../config/free5gc-ue.yaml
```

Test connectivity

```
mininet> h1 ping -I uesimtun0 -c1 9.9.9.9
PING 9.9.9.9 (9.9.9.9) from 10.60.0.1 uesimtun0: 56(84) bytes of data.
64 bytes from 9.9.9.9: icmp_seq=1 ttl=59 time=14.7 ms

--- 9.9.9.9 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 14.650/14.650/14.650/0.000 ms
mininet>
```
