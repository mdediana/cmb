#!/bin/bash

export TMP_DIR=$HOME/tmp
export RES_DIR=$HOME/res
export RIAK_HOME=/opt/riak/rel/riak
export RIAK_BIN_DIR=$RIAK_HOME/bin
export RIAK_DATA_DIR=/tmp/data	# /tmp is mounted on sda5, bigger than sda3
export RIAK_LOG_DIR=$RIAK_HOME/log
export BENCH_HOME=/opt/basho_bench
export ENV_FILE=$IMG_HOME/squeeze-x64-riak.env
export BLACKLIST=$CMB_HOME/blacklist.conf
export RIAKS=8
export BENCHS=2
export TESTS=1
export LOG_LEVEL=error
#export LOG_LEVEL=info
#export TOTAL_KEYS=2000000
export TOTAL_KEYS=200000
export MIG_THOLD=3
export WARMUP_STEPS=$((MIG_THOLD+2))
export TEST_DURATION=3

# return all running jobids (there should be only one)
jobid() {
  echo $(oarstat -u | awk 'NR > 2 {print $1, $5}' | grep R | cut -d' ' -f1)
}

subnets() {
  local line=$1; local cols=$2
  [[ -z $(jobid) ]] && echo "No running job" && return 1
  g5k-subnets -j $(jobid) -a | sed -n "${line}p" | cut -f$cols
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

iface() {
  local cluster=$(head -1 all_nodes | cut -d- -f1)
  [[ $cluster != parapluie ]] && echo eth0 || echo eth1
}

run_basho_bench() {
  local cli=$1; local config=$2
  ssh root@$cli "ulimit -n 16384
cd $BENCH_HOME
rm -fr tests/*
./basho_bench $config"
}

riak_stats() {
  local stat=$1
  agg $TMP_DIR/srv_nodes "$RIAK_BIN_DIR/riak-admin status | grep $stat | cut -d: -f2"
}

create_all_nodes() {
  [[ -z $(jobid) ]] && echo "No running job" && return 1
  oarstat -u -f -j $(jobid) | sed -n 's/ *assigned_hostnames = \(.*\)/\1/p' | tr '+' '\n' > $TMP_DIR/all_nodes
  [[ -e $BLACKLIST ]] && for n in $(cat $BLACKLIST); do
    sed -i "/$n/ d" $TMP_DIR/all_nodes
  done
  [[ -z $(cat $TMP_DIR/all_nodes) ]] && echo "No available nodes" && return 1
  return 0
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

for_all() {
  local node_file=$1; local cmd=$2
  for n in $(cat $node_file); do eval $cmd; done
}
for_all_p() {
  local node_file=$1; local cmd=$2
  for n in $(cat $node_file); do 
    eval $cmd &
  done; wait
}

ssh_all() {
  local node_file=$1; local cmd=$2
  for n in $(cat $node_file); do ssh root@$n "$cmd"; done
}

ssh_all_p() {
  local node_file=$1; local cmd=$2
  for n in $(cat $node_file); do
    ssh root@$n "$cmd" &
  done; wait
}

agg() {
  local node_file=$1; local cmd=$2
  local total=0
  local vs=($(ssh_all_p $node_file "$cmd"))
  for v in "${vs[@]}"; do ((total+=v)) || true; done
  echo $total
}
