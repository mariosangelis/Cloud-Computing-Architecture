#!/bin/bash

# stops processing in case of failure
set -euo pipefail

# prints each line executed
set -x

#to deploy a cluster run the 5 following commands. Part1.yaml contains the configuration for the Virtual machines.

#---------------------------------------------------------------------------------------------------------------------------------------------------------
#Code for part 1a

export KOPS_STATE_STORE=gs://cca-eth-2023-group-032-mangelis/
kops create -f cloud-comp-arch-project/part1.yaml

#Before you deploy the cluster with kops you will need an ssh key to login to your nodes once they
#are created. Execute the following commands to go to your .ssh folder and create a key:
cd ~/.ssh
ssh-keygen -t rsa -b 4096 -f cloud-computing
PROJECT='gcloud config get-value project'
#We will now add the key as a login key for our nodes. Type the following command:
kops create secret --name part1.k8s.local sshpublickey admin -i ~/.ssh/cloud-computing.pub

#We are ready now to deploy the cluster by typing:
kops update cluster --name part1.k8s.local --yes --admin
kops validate cluster --wait 10m
kubectl get pods -o wide

#You can connect to any of the nodes by using your generated ssh key and the node name. For example to connect to the client-agent node, you can type:
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@client-agent-vg5v --zone europe-west3-a

#To launch memcached using Kubernetes, run the following commands
cd cloud-comp-arch-project/

kubectl create -f memcache-t1-cpuset.yaml
kubectl expose pod some-memcached --name some-memcached-11211 --type LoadBalancer --port 11211 --protocol TCP
sleep 60
kubectl get service some-memcached-11211
kubectl get pods -o wide

#To delete the cluster, run the following command
kops delete cluster part1.k8s.local --yes

#---------------------------------------------------------------------------------------------------------------------------------------------------------
#Code for parts 2a and 2b

export KOPS_STATE_STORE=gs://cca-eth-2023-group-032-mangelis/
PROJECT='gcloud config get-value project'
kops create -f part2a.yaml
kops update cluster part2a.k8s.local --yes --admin
kops validate cluster --wait 10m
kubectl get nodes -o wide

kubectl label nodes parsec-server-3nng cca-eth-2023-group-032-mangelis-nodetype=parsec


#Then deploy jobs to the cluster. Kubernetes cluster will run in one of the 2 VMs. The interference job as well as the parsec benchmark job will be scheduled by Kubernetes master to the other VM as 2 containers.

kubectl create -f interference/ibench-cpu.yaml
kubectl create -f parsec-benchmarks/part2b/parsec-dedup.yaml

kubectl get jobs
kubectl logs $(kubectl get pods --selector=job-name=parsec-dedup --output=jsonpath='{.items[*].metadata.name}') > results/dedup_cpu_interference.txt


gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@parsec-server-s28x --zone europe-west3-a


kubectl delete pods --all
kubectl delete jobs --all

kops delete cluster part2a.k8s.local --yes


kops create -f part2b.yaml
kops update cluster part2b.k8s.local --yes --admin
kops validate cluster --wait 10m
kubectl get nodes -o wide


#---------------------------------------------------------------------------------------------------------------------------------------------------------
#Code for part 3

export KOPS_STATE_STORE=gs://cca-eth-2023-group-032-mangelis/
PROJECT='gcloud config get-value project'
kops create -f part3.yaml
kops update cluster part3.k8s.local --yes --admin
kops validate cluster --wait 10m
kubectl get nodes -o wide

#Connect to each of the agents and the measure machines and execute the following:

sudo apt-get update
sudo apt-get install libevent-dev libzmq3-dev git make g++ --yes
sudo cp /etc/apt/sources.list /etc/apt/sources.list~
sudo sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
sudo apt-get update
sudo apt-get build-dep memcached --yes
cd && git clone https://github.com/shaygalon/memcache-perf.git
cd memcache-perf
git checkout 0afbe9b
make

kubectl create -f memcache-t1-cpuset.yaml


gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@<MACHINE_NAME> --zone europe-west3-a


./mcperf -s 100.96.2.2 -a 10.0.16.6 -a 10.0.16.2 --noload -T 6 -C 4 -D 4 -Q 1000 -c 4 -t 10 --scan 30000:30500:5



















