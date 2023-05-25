# Cloud-Computing-Architecture, Spring Semester 2023
This repository includes the code, results and reports for Cloud Computing Architecture course project at ETH Zürich.
The objective of the project is to schedule latency-sensitive and batch applications in a cloud cluster. It consists of four parts:

#### Part 1:
>  Run a latency-critical application (memcached) inside a container and measure its performance with the metric of tail latency (e.g., 95th percentile latency) under a desired query rate. Also compare it with different sources of interference.
  
#### Part 2:  
>  Deploy eight different throughput-oriented (“batch”) workloads from the PARSEC (and SPLASH2x) benchmark suite: blackscholes, canneal, dedup, ferret, freqmine,radix and vips. First explore explore each workload’s sensitivity to resource interference using iBench on a small 2 core VM (e2-standard-2) and then investigate how each workload benefits from parallelism by measuring
the performance of each job with 1,2,4,8 threads on a large 8 core VM (e2-standard-8).

#### Part 3:
>  Design and implement a static scheduler of the latency critical memcached application from Part 1 and all batch applications from Part 2. Done in a heterogeneous cluster of VMS with different number of cores. The scheduling policy aims to minimize the time it takes for all the batch workloads to complete while guaranteeing a tail latency (SLO).

#### Part 4:    
>  Design and implement a dynamic scheduler of the PARSEC jobs on a single 4-core server running memcached. Vary the load on the long-running memcached service, such that the number of cores needed by the memcached server to meet the tail latency service level objective (SLO) ranges from 1 to 2 cores.
