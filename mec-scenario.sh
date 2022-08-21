#!/bin/bash

HADD="sudo ip netns add "
HDEL="sudo ip netns del "
LB1HCMD="sudo ip netns exec loxilb1 "
LB2HCMD="sudo ip netns exec loxilb2 "
HCMD="sudo ip netns exec "
LB1LNCMD="sudo ip -n loxilb1 link "
LB2LNCMD="sudo ip -n loxilb2 link "

docker stop loxilb1
docker stop loxilb2
docker rm loxilb1
docker rm loxilb2
sudo rm -f /var/run/loxilb1
sudo rm -f /var/run/loxilb2

# Clean-up previous testbed if still running
$LB1LNCMD set enp1 down
$LB1LNCMD set enp2 down
$LB1LNCMD set enp12 down
$LB2LNCMD set enp1 down
$LB2LNCMD set enp2 down
$LB2LNCMD set enp3 down
$LB2LNCMD set enp21 down

$HCMD ue1 ip link set eth0 down
$HCMD ue2 ip link set eth0 down
$HCMD l3e1 ip link set eth0 down
$HCMD l3e2 ip link set eth0 down
$HCMD l3e3 ip link set eth0 down

$LB1LNCMD del enp1
$LB1LNCMD del enp2
$LB1LNCMD del enp12
$LB2LNCMD del enp1
$LB2LNCMD del enp2
$LB2LNCMD del enp3
$LB2LNCMD del enp21

$HDEL loxilb1
$HDEL loxilb2
$HDEL ue1
$HDEL ue2
$HDEL l3e1
$HDEL l3e2
$HDEL l3e3
echo "Cleaned previous testbed"

sleep 5
echo "Running loxilb1 instance"
docker run -u root --cap-add SYS_ADMIN   --restart unless-stopped --privileged -dit -v /dev/log:/dev/log --name loxilb1 ghcr.io/loxilb-io/loxilb:latest
echo "Running loxilb2 instance"
docker run -u root --cap-add SYS_ADMIN   --restart unless-stopped --privileged -dit -v /dev/log:/dev/log --name loxilb2 ghcr.io/loxilb-io/loxilb:latest
echo "Pausing for a bit..."

id=`docker ps -f name=loxilb1 | cut  -d " "  -f 1 | grep -iv  "CONTAINER"`
echo $id
pid=`docker inspect -f '{{.State.Pid}}' $id`
if [ ! -f /var/run/netns/loxilb1 ]; then
  sudo touch /var/run/netns/loxilb1
  sudo mount -o bind /proc/$pid/ns/net /var/run/netns/loxilb1
fi

id=`docker ps -f name=loxilb2 | cut  -d " "  -f 1 | grep -iv  "CONTAINER"`
echo $id
pid=`docker inspect -f '{{.State.Pid}}' $id`
if [ ! -f /var/run/netns/loxilb2 ]; then
  sudo touch /var/run/netns/loxilb2
  sudo mount -o bind /proc/$pid/ns/net /var/run/netns/loxilb2
fi

$LB1HCMD sysctl net.ipv6.conf.all.disable_ipv6=1
$LB1HCMD ifconfig lo up

$LB2HCMD sysctl net.ipv6.conf.all.disable_ipv6=1
$LB2HCMD ifconfig lo up

$HADD ue1
$HADD ue2
$HADD l3e1
$HADD l3e2
$HADD l3e3

## Configure interlink between gNB and MEC  
sudo ip -n loxilb1 link add enp12 type veth peer name enp21 netns loxilb2
sudo ip -n loxilb1 link set enp12 mtu 9000 up
$LB1HCMD ip addr add 10.10.10.59/24 dev enp12
sudo ip -n loxilb2 link set enp21 mtu 9000 up
$LB2HCMD ip addr add 10.10.10.56/24 dev enp21

## Configure gNB end-point ue1
sudo ip -n loxilb1 link add enp1 type veth peer name eth0 netns ue1
sudo ip -n loxilb1 link set enp1 mtu 9000 up
sudo ip -n ue1 link set eth0 mtu 7000 up
$LB1HCMD ip addr add 31.31.31.254/24 dev enp1
$HCMD ue1 ifconfig eth0 31.31.31.1/24 up
$HCMD ue1 ip route add default via 31.31.31.254
$HCMD ue1 ip link set lo up

## Configure gNB end-point ue2
sudo ip -n loxilb1 link add enp2 type veth peer name eth0 netns ue2
sudo ip -n loxilb1 link set enp2 mtu 9000 up
sudo ip -n ue2 link set eth0 mtu 7000 up
$LB1HCMD ip addr add 32.32.32.254/24 dev enp2
$HCMD ue2 ifconfig eth0 32.32.32.2/24 up
$HCMD ue2 ip route add default via 32.32.32.254
$HCMD ue2 ip link set lo up

## Configure MEC load-balancer end-point l3e1
sudo ip -n loxilb2 link add enp1 type veth peer name eth0 netns l3e1
sudo ip -n loxilb2 link set enp1 mtu 9000 up
sudo ip -n l3e1 link set eth0 mtu 7000 up
$LB2HCMD ip addr add 25.25.25.254/24 dev enp1
$HCMD l3e1 ifconfig eth0 25.25.25.1/24 up
$HCMD l3e1 ip route add default via 25.25.25.254
$HCMD l3e1 ip link set lo up

## Configure MEC load-balancer end-point l3e2
sudo ip -n loxilb2 link add enp2 type veth peer name eth0 netns l3e2
sudo ip -n loxilb2 link set enp2 mtu 9000 up
sudo ip -n l3e2 link set eth0 mtu 7000 up
$LB2HCMD ip addr add 26.26.26.254/24 dev enp2
$HCMD l3e2 ifconfig eth0 26.26.26.1/24 up
$HCMD l3e2 ip route add default via 26.26.26.254
$HCMD l3e2 ip link set lo up

## Configure MEC load-balancer end-point l3e3
sudo ip -n loxilb2 link add enp3 type veth peer name eth0 netns l3e3
sudo ip -n loxilb2 link set enp3 mtu 9000 up
sudo ip -n l3e3 link set eth0 mtu 7000 up
$LB2HCMD ip addr add 27.27.27.254/24 dev enp3
$HCMD l3e3 ifconfig eth0 27.27.27.1/24 up
$HCMD l3e3 ip route add default via 27.27.27.254
$HCMD l3e3 ip link set lo up

$LB1HCMD ip route add 25.25.25.0/24 via 10.10.10.56 dev enp12
$LB1HCMD ip route add 26.26.26.0/24 via 10.10.10.56 dev enp12
$LB1HCMD ip route add 27.27.27.0/24 via 10.10.10.56 dev enp12
$LB2HCMD ip route add 31.31.31.0/24 via 10.10.10.59 dev enp21
$LB2HCMD ip route add 32.32.32.0/24 via 10.10.10.59 dev enp21
                                                               
