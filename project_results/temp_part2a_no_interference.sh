#!/bin/bash

# stops processing in case of failure
set -euo pipefail

# prints each line executed
#set -x

#------------------------cpu interference, dedup benchmark---------------------------------
export KOPS_STATE_STORE=gs://cca-eth-2023-group-032-mangelis/

kubectl label nodes parsec-server-rtps cca-eth-2023-group-032-mangelis-nodetype=parsec

echo "Starting benchmarking test for no interference"
kubectl delete pods --all
kubectl delete jobs --all

for job_name in {"parsec-dedup","parsec-blackscholes","parsec-canneal","parsec-ferret","parsec-freqmine","parsec-radix","parsec-vips"}
do
    kubectl delete jobs --all
    kubectl create -f parsec-benchmarks/part2a/$job_name.yaml

    while true
    do
        while IFS=" " read -r NAME COMPLETIONS DURATION AGE;
        do
            #echo $COMPLETIONS;
            if [ "$COMPLETIONS" != "COMPLETIONS" ]; then
                break
            fi
        done < <(kubectl get jobs)

        if [ "$COMPLETIONS" = "1/1" ]; then
            break
        fi
    done

    tmpfile=$(mktemp)
    kubectl logs $(kubectl get pods --selector=job-name=$job_name --output=jsonpath='{.items[*].metadata.name}') > ${tmpfile}
    cat ${tmpfile} >> results/"no-interference"/$job_name.txt
done

