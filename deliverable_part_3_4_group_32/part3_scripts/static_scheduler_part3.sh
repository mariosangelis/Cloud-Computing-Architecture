#!/bin/bash

# stops processing in case of failure
set -euo pipefail

# prints each line executed
#set -x


kubectl delete jobs --all
kubectl delete pods --all

#Create memcached service
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-a-2core\"" memcache-t1-cpuset.yaml
kubectl create -f memcache-t1-cpuset.yaml


while true
do
    while IFS=" " read -r NAME READY STATUS RESTARTS AGE;
    do
        if [ "$STATUS" != "STATUS" ]; then
            break
        fi
    done < <(kubectl get pods)

    if [ "$STATUS" = "Running" ]; then
        break
    fi
done

while IFS=" " read -r NAME READY STATUS RESTARTS AGE IP NODE NOMINATED_NODE READINESS_GATES;
do
    if [[ $NAME == "some-memcached" ]]; then
        MEMCACHED_IP=$IP
        break
    fi
done < <(kubectl get pods -o wide)

echo "MEMCACHED_IP=" $MEMCACHED_IP


while IFS=" " read -r NAME STATUS ROLES AGE VERSION  INTERNAL_IP EXTERNAL_IP OS_IMAGE  KERNEL_VERSION CONTAINER_RUNTIME;
do
    if [[ $NAME == *"client-agent-a"* ]]; then
        INTERNAL_AGENT_A_IP=$INTERNAL_IP
        EXTERNAL_AGENT_A_IP=$EXTERNAL_IP
    elif [[ $NAME == *"client-agent-b"* ]]; then
        INTERNAL_AGENT_B_IP=$INTERNAL_IP
        EXTERNAL_AGENT_B_IP=$EXTERNAL_IP
    elif [[ $NAME == *"client-measure"* ]]; then
        MEASURE_NAME=$NAME
        EXTERNAL_MEASURE_IP=$EXTERNAL_IP
    fi
done < <(kubectl get nodes -o wide)

echo "INTERNAL_AGENT_A_IP=" $INTERNAL_AGENT_A_IP
echo "INTERNAL_AGENT_B_IP=" $INTERNAL_AGENT_B_IP
echo "EXTERNAL_AGENT_A_IP=" $EXTERNAL_AGENT_A_IP
echo "EXTERNAL_AGENT_B_IP=" $EXTERNAL_AGENT_B_IP
echo "EXTERNAL_MEASURE_IP=" $EXTERNAL_MEASURE_IP

echo "Execute iperf commands inside agent nodes"
ssh ubuntu@$EXTERNAL_AGENT_A_IP -f "cd memcache-perf-dynamic; ./mcperf -T 2 -A; bg; exit" > agent_a.txt
ssh ubuntu@$EXTERNAL_AGENT_B_IP -f "cd memcache-perf-dynamic; ./mcperf -T 4 -A; bg; exit" > agent_b.txt

#Start producing traffic
echo "Start producing traffic"
ssh ubuntu@$EXTERNAL_MEASURE_IP -f "
        export MEMCACHED_IP=$MEMCACHED_IP;
        export INTERNAL_AGENT_A_IP=$INTERNAL_AGENT_A_IP;
        export INTERNAL_AGENT_B_IP=$INTERNAL_AGENT_B_IP;
        echo $MEMCACHED_IP;
        cd memcache-perf-dynamic;
        ./mcperf -s $MEMCACHED_IP --loadonly;
        ./mcperf -s $MEMCACHED_IP -a $INTERNAL_AGENT_A_IP -a $INTERNAL_AGENT_B_IP --noload -T 6 -C 4 -D 4 -Q 1000 -c 4 -t 10 --scan 30000:30500:5; bg; exit " > results.txt



echo "Start parsec freqmine job"
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-b-4core\""  parsec-benchmarks/part3/parsec-freqmine.yaml
kubectl create -f parsec-benchmarks/part3/parsec-freqmine.yaml

echo "Start parsec ferret job"
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-c-8core\""  parsec-benchmarks/part3/parsec-ferret.yaml
kubectl create -f parsec-benchmarks/part3/parsec-ferret.yaml

echo "Start parsec canneal job"
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-c-8core\""  parsec-benchmarks/part3/parsec-canneal.yaml
kubectl create -f parsec-benchmarks/part3/parsec-canneal.yaml

echo "Start parsec blackscholes job"
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-b-4core\""  parsec-benchmarks/part3/parsec-blackscholes.yaml
kubectl create -f parsec-benchmarks/part3/parsec-blackscholes.yaml

echo "Start parsec vips job"
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-c-8core\""  parsec-benchmarks/part3/parsec-vips.yaml
kubectl create -f parsec-benchmarks/part3/parsec-vips.yaml

echo "Start parsec dedup job"
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-c-8core\""  parsec-benchmarks/part3/parsec-dedup.yaml
kubectl create -f parsec-benchmarks/part3/parsec-dedup.yaml

echo "Start parsec radix job"
sed -i "/cca-project-nodetype:/c\         cca-project-nodetype: \"node-a-2core\""  parsec-benchmarks/part3/parsec-radix.yaml
kubectl create -f parsec-benchmarks/part3/parsec-radix.yaml



EXIT_FLAG="1"

while true
do
    while IFS=" " read -r NAME COMPLETIONS DURATION AGE;
        do
            if [ "$COMPLETIONS" != "COMPLETIONS" ] && [ "$COMPLETIONS" = "0/1" ]; then
                EXIT_FLAG="0";
                break
            fi
        done < <(kubectl get jobs)


        if [ "$EXIT_FLAG" = "1" ]; then
            break
        fi
        EXIT_FLAG="1"
done

echo "All jobs finished"
ssh ubuntu@$EXTERNAL_MEASURE_IP -f "killall mcperf; bg; exit"
ssh ubuntu@$EXTERNAL_AGENT_A_IP -f "killall mcperf; bg; exit"
ssh ubuntu@$EXTERNAL_AGENT_B_IP -f "killall mcperf; bg; exit"

kubectl get pods -o json > results.json
python3 get_time.py results.json

kubectl delete jobs --all
kubectl delete pods --all

