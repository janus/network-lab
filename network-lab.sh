#!bash

#Cloned from https://github.com/sudomesh/network-lab
#Example on how to run it , source ./network-lab.sh  example-network.json

if [ -f $1 ]; then
  input=$(<"$1")
else
  stdin=$(cat)
  input=$stdin
fi


# clear namespaces
ip -all netns delete

# add namespaces
echo "adding nodes"
for node in $(jq '.nodes | keys[]' <<< "$input")
do
  # set up alias for later use
  alias "n${node:1:-1}"="ip netns exec netlab-${node:1:-1}"  
  ip netns add "netlab-${node:1:-1}"
done


length=$(jq '.edges | length' <<< "$input")
for ((i=0; i<$length; i++)); do

  # get names of nodes
  A=$(jq '.edges['$i'].nodes[0]' <<< "$input")
  B=$(jq '.edges['$i'].nodes[1]' <<< "$input")
  A=${A:1:-1}
  B=${B:1:-1}

  # create veth to link them
  ip link add "veth-$A-$B" type veth peer name "veth-$B-$A"

  # assign each side of the veth to one of the nodes namespaces
  ip link set "veth-$A-$B" netns "netlab-$A"
  ip link set "veth-$B-$A" netns "netlab-$B"

  # add ip addresses on each side
  ipA=$(jq '.nodes["'$A'"].ip' <<< "$input")
  ipB=$(jq '.nodes["'$B'"].ip' <<< "$input")
 
  # bring the interfaces up
  ip netns exec "netlab-$A" ifconfig "veth-$A-$B"  ${ipA:1:-1}/24 up
  ip netns exec "netlab-$B" ifconfig "veth-$B-$A"  ${ipB:1:-1}/24 up

  echo ${ipA:1:-1}
  echo ${ipB:1:-1}

 

  # add some connection quality issues
  AtoB=$(jq '.edges['$i']["->"]' <<< "$input")
  BtoA=$(jq '.edges['$i']["<-"]' <<< "$input")


  ip netns exec "netlab-$A" tc qdisc add dev "veth-$A-$B" root netem ${AtoB:1:-1}
  ip netns exec "netlab-$B" tc qdisc add dev "veth-$B-$A" root netem ${BtoA:1:-1}
done


