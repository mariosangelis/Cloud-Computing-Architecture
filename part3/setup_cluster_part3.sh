#!/bin/bash

# stops processing in case of failure
set -euo pipefail

# prints each line executed
#set -x


export KOPS_STATE_STORE=gs://cca-eth-2023-group-032-mangelis/
PROJECT='gcloud config get-value project'
kops create -f part3.yaml
kops update cluster part3.k8s.local --yes --admin
kops validate cluster --wait 10m
kubectl get nodes -o wide


for i in $(seq 0 6)

do
    wh_base_url="{.items[$i].metadata.name}"
    node_name=$(kubectl get nodes --output=jsonpath=$wh_base_url)

    echo $node_name

    if [[ $node_name == *"client"* ]]; then

        gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$node_name --zone europe-west3-a  <<'EOL'
        sudo apt-get update
        sudo apt-get install libevent-dev libzmq3-dev git make g++ --yes
        sudo cp /etc/apt/sources.list /etc/apt/sources.list~
        sudo sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
        sudo apt-get update
        sudo apt-get build-dep memcached --yes
        cd && git clone https://github.com/eth-easl/memcache-perf-dynamic.git
        cd memcache-perf-dynamic
        make
EOL

    fi

done
