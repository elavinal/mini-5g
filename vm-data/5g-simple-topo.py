#!/usr/bin/env python3

"""
                >>> Mininet topology <<<

Simple data plane 5G topology running UERANSIM and Free5GC's UPF
(Free5GC is in another VM)

(UERANSIM)                      (UPF)
    h1 ---------- r0 ---------- h2
     |                           |
     +----------- s0 ------------+
              (OVSBridge)
                   |
                 h3 (nat)
                   |
                  ...
                (Free5GC)

- 192.168.1.0/24
    h1-eth0 192.168.1.1/24
    r0-eth0 192.168.1.10/24
- 192.168.2.0/24
    h2-eth0 192.168.2.2/24
    r0-eth1 192.168.2.20/24
- 192.168.3.0/24
    h1-eth1 192.168.3.1/24
    h2-eth1 192.168.3.2/24
    h3-eth0 192.168.3.3/24
"""

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import Node, OVSBridge
from mininet.nodelib import NAT
from mininet.log import setLogLevel, info
from mininet.cli import CLI

SL24 = '/24'

NET1   = '192.168.1.0' + SL24
H1_IP4 = '192.168.1.1'
H1_MAC = '00:00:00:00:01:01'

NET2   = '192.168.2.0' + SL24
H2_IP4 = '192.168.2.2'
H2_MAC = '00:00:00:00:02:02'

R0_N1_IP4 = '192.168.1.254'
R0_N1_MAC = '00:00:00:00:01:a0'
R0_N2_IP4 = '192.168.2.254'
R0_N2_MAC = '00:00:00:00:02:a0'

NET3   = '192.168.3.0' + SL24
H1_N3  = '192.168.3.1'
H2_N3  = '192.168.3.2'
H3_N3  = '192.168.3.3'

class LinuxRouter( Node ):
    """A Node with IP forwarding enabled."""

    def config( self, **params ):
        super( LinuxRouter, self).config( **params )
        # Enable forwarding on the router
        self.cmd( 'sysctl net.ipv4.ip_forward=1' )

    def terminate( self ):
        self.cmd( 'sysctl net.ipv4.ip_forward=0' )
        super( LinuxRouter, self ).terminate()


class NetworkTopo( Topo ):
    """A simple network topo with 3 IP subnets: (h1-r0), (h2-r0) and (h1, h2, h3)."""

    def build( self, **_opts ):
        r0 = self.addNode( 'r0', cls=LinuxRouter, ip=R0_N1_IP4+SL24, mac=R0_N1_MAC )
        h1 = self.addHost( 'h1', ip=H1_IP4+SL24, mac=H1_MAC )
        h2 = self.addHost( 'h2', ip=H2_IP4+SL24, mac=H2_MAC )
        h3 = self.addHost( 'h3', cls=NAT, inNamespace=False, subnet=NET3, localIntf='h3-eth0', ip=H3_N3+SL24 )

        self.addLink( h1, r0, intfName1='h1-eth0', intfName2='r0-eth0' )
        self.addLink( h2, r0, intfName1='h2-eth0', intfName2='r0-eth1' )

        s0 = self.addSwitch('s0')
        self.addLink( h1, s0, intfName1='h1-eth1' )
        self.addLink( h2, s0, intfName1='h2-eth1' )
        self.addLink( h3, s0, intfName1='h3-eth0' )

def config(net):
    # interfaces
    net.get('r0').cmd('ip l set dev r0-eth1 address %s' % R0_N2_MAC)
    net.get('r0').cmd('ip a add %s dev r0-eth1' % (R0_N2_IP4+SL24))
    net.get('h1').cmd('ip a add %s dev h1-eth1' % (H1_N3+SL24))
    net.get('h2').cmd('ip a add %s dev h2-eth1' % (H2_N3+SL24))
    # neighbors (h1 - r0 - h2)
    net.get('h1').cmd('ip nei add %s lladdr %s dev h1-eth0' % (R0_N1_IP4, R0_N1_MAC))
    net.get('r0').cmd('ip nei add %s lladdr %s dev r0-eth0' % (H1_IP4, H1_MAC))
    net.get('h2').cmd('ip nei add %s lladdr %s dev h2-eth0' % (R0_N2_IP4, R0_N2_MAC))
    net.get('r0').cmd('ip nei add %s lladdr %s dev r0-eth1' % (H2_IP4, H2_MAC))
    # routes (h1 <--> h2 and (h1, h2) <--> h3 (nat))
    net.get('h1').cmd('ip r add %s via %s dev h1-eth0' % (NET2, R0_N1_IP4))
    net.get('h2').cmd('ip r add %s via %s dev h2-eth0' % (NET1, R0_N2_IP4))
    net.get('h1').cmd('ip r add default via %s dev h1-eth1' % H3_N3)
    net.get('h2').cmd('ip r add default via %s dev h2-eth1' % H3_N3)

def run():
    topo = NetworkTopo()
    net = Mininet( topo=topo, switch=OVSBridge, controller=None )
    config(net)
    net.start()
    info( '*** Done (network started).\n' )
    CLI( net )
    net.stop()

if __name__ == '__main__':
    setLogLevel( 'info' )
    run()
