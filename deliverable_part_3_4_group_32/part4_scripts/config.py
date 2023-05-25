from enum import Enum
import subprocess
import docker

class mc_state(Enum):
    SMALL = 0
    LARGE = 1

client = docker.from_env()


memcached_state=mc_state.LARGE;
SWITCH_CORE_THRESHOLD=40

compute_heavy_job_queue=['freqmine','ferret']
compute_and_memory_heavy_job_queue=['vips','dedup','canneal']
memory_heavy_job_queue=['blackscholes','radix']

running_container_in_cpus_2and3=None
running_container_in_cpu_1=None


sleep_interval=1

