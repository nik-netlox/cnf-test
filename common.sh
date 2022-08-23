#!/bin/bash

if [[ "$1" == "init" ]]; then
  pull_dockers
fi

hexec="sudo ip netns exec "
pid=""

## Given a docker name(arg1), return its pid
get_docker_pid() {
  id=`docker ps -f name=$1| cut  -d " "  -f 1 | grep -iv  "CONTAINER"`
  pid=`docker inspect -f '{{.State.Pid}}' $id`
}

## Pull all necessary dockers for testbed
pull_dockers() {
  ## Host docker
  docker pull ghcr.io/loxilb-io/loxilb:latest
  ## Host docker 
  docker pull eyes852/ubuntu-iperf-test:0.5
}

## arg1 - "loxilb"|"host"
## arg2 - instance-name
spawn_docker_host() {
  pid=""
  if [[ "$1" == "loxilb" ]]; then
    docker run -u root --cap-add SYS_ADMIN   --restart unless-stopped --privileged -dit -v /dev/log:/dev/log --name $2 ghcr.io/loxilb-io/loxilb:latest

  else
    docker run -u root --cap-add SYS_ADMIN -dit --name $2 eyes852/ubuntu-iperf-test:0.5
  fi

  sleep 2
  get_docker_pid $2
  echo $pid
  if [ ! -f "/var/run/netns/$2" -a "$pid" != "" ]; then
    sudo touch /var/run/netns/$2
    echo "sudo mount -o bind /proc/$pid/ns/net /var/run/netns/$2"
    sudo mount -o bind /proc/$pid/ns/net /var/run/netns/$2
  fi

  $hexec $2 ifconfig lo up
  $hexec $2 sysctl net.ipv6.conf.all.disable_ipv6=1
}

## arg1 - hostname 
delete_docker_host() {
  docker stop $1 2>&1 >> /dev/null
  sudo ip netns del $1 2>&1 >> /dev/null
  sudo rm -fr /var/run/$1 2>&1 >> /dev/null
  docker rm $1 2>&1 >> /dev/null
}

## arg1 - hostname1 
## arg2 - hostname2 
connect_docker_hosts() {
  link1=enp$1$2
  link2=enp$2$1
  #echo $link1 $link2
  sudo ip -n $1 link add $link1 type veth peer name $link2 netns $2
  sudo ip -n $1 link set $link1 up
  sudo ip -n $2 link set $link2 up
}

## arg1 - hostname1 
## arg2 - hostname2 
disconnect_docker_hosts() {
  link1=enp$1$2
  link2=enp$2$1
  #echo $link1 $link2
  sudo ip -n $1 link set $link1 down 2>&1 >> /dev/null
  sudo ip -n $2 link set $link2 down 2>&1 >> /dev/null
  sudo ip -n $1 link del $link1 2>&1 >> /dev/null
  sudo ip -n $2 link del $link2 2>&1 >> /dev/null
}

## arg1 - hostname1 
## arg2 - hostname2 
## arg3 - ip_addr
## arg4 - gw
config_docker_host() {
  link1=enp$1$2
  link2=enp$2$1
  echo "$1:$link1->$2:$link2"
  sudo ip -n $1 addr add $3 dev $link1
  if [[ "$4" != "" ]]; then
    sudo ip -n $1 route del default
    sudo ip -n $1 route add default via $4
  fi
}
