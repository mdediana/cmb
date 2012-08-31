#!/bin/bash

export TMP_DIR=$HOME/tmp
export RES_DIR=$HOME/res
export RIAK_HOME=/opt/riak/rel/riak
export RIAK_BIN_DIR=$RIAK_HOME/bin
export RIAK_DATA_DIR=/tmp/data	# /tmp is mounted on sda5, bigger than sda3
export RIAK_LOG_DIR=$RIAK_HOME/log
export BENCH_HOME=/opt/basho_bench
export ENV_FILE=$IMG_HOME/squeeze-x64-riak.env
export SITE=rennes
#export SITE=sophia
#export CLUSTER=paradent
#export CLUSTER=parapluie
export CLUSTER=parapide
#export CLUSTER=suno # has sas disks, use 1 cli for every 2 srvs
#export CLUSTER=sol
export ETH=eth0
#export NODE_RAM=32 # paradent
#export NODE_RAM=4 # sol
export LOG_LEVEL=error
#export LOG_LEVEL=info

[[ $CLUSTER == parapluie ]] && ETH=eth1

# return all running jobids (there should be only one)
jobid() {
  echo $(oarstat -u | awk 'NR > 2 {print $1, $5}' | grep R | cut -d' ' -f1)
}

subnets() {
  [[ -z $(jobid) ]] && echo "No running job" && return 1
  g5k-subnets -j $(jobid) -a | sed -n "$1p" | cut -f$2
}

other_dc() {
  [[ $1 -eq 1 ]] && echo 2 || echo 1
}

to_ip() {
  echo $(nslookup $1 | sed -n 's/Address: \(.*\)/\1/p')
}

ip_in_subnet() {
  local first_octets=$(echo $1 | cut -d. -f1-3)
  local last_octet=$(echo $2 | cut -d. -f4)
  echo $first_octets.$last_octet
}

run_basho_bench() {
  local cli=$1; local config=$2
  ssh root@$cli "ulimit -n 16384
cd $BENCH_HOME
rm -fr tests/*
./basho_bench $config"
}

create_all_nodes() {
  [[ -z $(jobid) ]] && echo "No running job" && return 1
  oarstat -u -f -j $(jobid) | sed -n 's/ *assigned_hostnames = \(.*\)/\1/p' | tr '+' '\n' > $TMP_DIR/all_nodes
  for n in $(cat $CMB_HOME/blacklist.conf); do
    sed -i "/$n/ d" $TMP_DIR/all_nodes
  done
  [[ -s $TMP_DIR/all_nodes ]] && return 0 || echo "No available nodes" && return 1 
}

update_conf_info() {
  local k=$1; local v=$2
  local f=$TMP_DIR/conf_info
  if [[ ! -e $f ]] || [[ -z $(grep $k $f) ]]; then
    echo "$k=$v" >> $f
  else 
    sed -i "s/$k=.*/$k=$v/" $f
  fi
}

get_prop() {
  local f=$1; local k=$2
  sed -n "s/$k=\(.*\)/\1/p" $f 
}

# g5k hw: https://www.grid5000.fr/mediawiki/index.php/Sophia:Hardware
# sas x sata: http://blog.lewan.com/2009/09/14/sas-vs-sata-differences-technology-and-cost/
# suno: sas (8 srvs / 4 clis ok)
# parapluie: sata (8 srvs / 4 clis has worst perf than 2 clis)
