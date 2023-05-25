import docker
from config import *
from utility import *
import time
import subprocess
import psutil
from enum import Enum



def execute_parsec_job(job_name,core_family,cpus,threads):
    global running_container_in_cpus_2and3,running_container_in_cpu_1,log_obj

    if(job_name=="radix"):
        image_name='anakli/cca:splash2x_'+job_name
        command=' ./run -a run -S splash2x -p '+job_name
    else:
        image_name='anakli/cca:parsec_'+job_name
        command=' ./run -a run -S parsec -p '+job_name

    command=command + ' -i native -n '+str(threads)
    if(core_family=="large"):

        running_container_in_cpus_2and3=client.containers.run(image_name,command, name=job_name,detach=True, cpuset_cpus=cpus)

        log_obj.job_start(Job(job_name),cpus,threads)

    elif(core_family=="small"):

        running_container_in_cpu_1=client.containers.run(image_name,command, name=job_name,detach=True, cpuset_cpus=cpus)
        log_obj.job_start(Job(job_name),cpus,threads)



def main():
    global client,memcached_state,compute_heavy_job_queue,compute_and_memory_heavy_job_queue,memory_heavy_job_queue,running_container_in_cpus_2and3,running_container_in_cpu_1,log_obj

    #Pin memcached job to cores 0,1
    cmd = 'cat /var/run/memcached/memcached.pid'
    process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
    memcached_pid, err = process.communicate()
    memcached_pid= int(memcached_pid)

    cmd = 'sudo taskset -a -cp 0 '+str(memcached_pid)
    process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
    out, err = process.communicate()

    log_obj=SchedulerLogger()
    p=psutil.Process(memcached_pid)

    while(True):
        time.sleep(sleep_interval)

        #Get CPU utilization
        cpu_utilization=p.cpu_percent()
        print("CPU used =", cpu_utilization, "%")

        if(memcached_state==mc_state.SMALL):
            #If CPU0 utilization is > 40%
            if(cpu_utilization >= SWITCH_CORE_THRESHOLD):
                print("Switch memcached service to 2 cores")

                if(running_container_in_cpu_1!=None):
                    running_container_in_cpu_1.reload()

                    if(running_container_in_cpu_1.attrs['State']['Status']=="running"):
                        print("There are running containers in core 1. Pause them")
                        running_container_in_cpu_1.pause()

                        log_obj.job_pause(Job(running_container_in_cpu_1.name))


                command = 'sudo taskset -a -cp 0,1 '+str(memcached_pid)
                process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
                out, err = process.communicate()
                #print(out)
                log_obj.update_cores(Job("memcached"),"0,1")

                memcached_state=mc_state.LARGE

        else:
            if(cpu_utilization <= SWITCH_CORE_THRESHOLD):
                print("Switch memcached service to 1 core")

                command = 'sudo taskset -a -cp 0 '+str(memcached_pid)
                process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
                out, err = process.communicate()
                #print(out)

                memcached_state=mc_state.SMALL
                log_obj.update_cores(Job("memcached"),"0")

                if(running_container_in_cpu_1!=None):
                    running_container_in_cpu_1.reload()

                    if(running_container_in_cpu_1.attrs['State']['Status']=="paused"):
                        print("There are paused containers in core 1. Unause them")
                        running_container_in_cpu_1.unpause()
                        log_obj.job_unpause(Job(running_container_in_cpu_1.name))


        if(running_container_in_cpus_2and3!=None):
            running_container_in_cpus_2and3.reload()
            if(running_container_in_cpus_2and3.attrs['State']['Status']=="exited"):
                log_obj.job_end(Job(running_container_in_cpus_2and3.name))
                running_container_in_cpus_2and3=None


        if(running_container_in_cpus_2and3==None):

            #Run a new job in cores 2 and 3
            if (len(compute_heavy_job_queue)!=0):
                job_name=compute_heavy_job_queue.pop(0)
                execute_parsec_job(job_name,"large","2,3",2)
                print("Execute job: ",job_name," in cores 2,3")
            elif(len(compute_and_memory_heavy_job_queue)!=0):
                job_name=compute_and_memory_heavy_job_queue.pop(0)
                execute_parsec_job(job_name,"large","2,3",2)
                print("Execute job: ",job_name," in cores 2,3")
            elif(len(memory_heavy_job_queue)!=0):
                job_name=memory_heavy_job_queue.pop(0)
                execute_parsec_job(job_name,"large","2,3",2)
                print("Execute job: ",job_name," in cores 2,3")
            else:
                print("No available jobs to run. Check if there is a paused job")

                if(running_container_in_cpu_1!=None):
                    running_container_in_cpu_1.reload()
                    if(running_container_in_cpu_1.attrs['State']['Status']=="paused"):
                        print("Unpause job and update it to cores 2-3")
                        running_container_in_cpu_1.unpause()
                        log_obj.job_unpause(Job(running_container_in_cpu_1.name))

                        running_container_in_cpu_1.update(cpuset_cpus="2,3")
                        log_obj.update_cores(Job(running_container_in_cpu_1.name),"2,3")

                        running_container_in_cpus_2and3=running_container_in_cpu_1;
                        running_container_in_cpu_1=None


        else:
            print("Another container is running in cpus 2-3")



        if(running_container_in_cpu_1!=None):
            running_container_in_cpu_1.reload()
            if(running_container_in_cpu_1.attrs['State']['Status']=="exited"):
                log_obj.job_end(Job(running_container_in_cpu_1.name))
                running_container_in_cpu_1=None

        if(running_container_in_cpu_1==None):
            #Run a new job in cores 2 and 3
            if(len(memory_heavy_job_queue)!=0):
                job_name=memory_heavy_job_queue.pop(0)
                print("Execute job: ",job_name," in core 1")
                execute_parsec_job(job_name,"small","1",1)
            elif(len(compute_and_memory_heavy_job_queue)!=0):
                job_name=compute_and_memory_heavy_job_queue.pop(0)
                print("Execute job: ",job_name," in core 1")
                execute_parsec_job(job_name,"small","1",1)

            else:
                print("No available jobs to run")

        else:
            print("Another container is running in cpu 1")

        if(running_container_in_cpu_1==None and running_container_in_cpus_2and3==None):
            print("Scheduler finished");

    log_obj.end()

if __name__ == "__main__":
    main()


