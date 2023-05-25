#!/bin/bash

# stops processing in case of failure
set -euo pipefail

# prints each line executed
#set -x

#------------------------cpu interference, dedup benchmark---------------------------------
export KOPS_STATE_STORE=gs://cca-eth-2023-group-032-mangelis/
#kubectl label nodes parsec-server-m9x7 cca-eth-2023-group-032-mangelis-nodetype=parsec

kubectl label nodes parsec-server-h5h2 cca-project-nodetype=parsec


for threads in {"1","2","4","8"}
do
    echo "Starting benchmarking test for" $threads "threads"
    kubectl delete pods --all
    kubectl delete jobs --all

    for job_name in {"parsec-dedup","parsec-blackscholes"}
    do
        cat parsec-benchmarks/part2b/$job_name.yaml | sed -e "s/ -n.*/ -n $threads \"]/"  > temp.yaml
        mv temp.yaml parsec-benchmarks/part2b/$job_name.yaml

        kubectl delete jobs --all
        kubectl create -f parsec-benchmarks/part2b/$job_name.yaml

        while true
        do
            while IFS=" " read -r NAME COMPLETIONS DURATION AGE;
            do
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
        cat ${tmpfile} >> results2b/threads-$threads/$job_name.txt
    done
done
