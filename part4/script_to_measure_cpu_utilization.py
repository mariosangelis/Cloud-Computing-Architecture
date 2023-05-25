import psutil
import subprocess

cmd = 'cat /var/run/memcached/memcached.pid'
process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
memcached_pid, err = process.communicate()
memcached_pid= int(memcached_pid)

cmd = 'sudo taskset -a -cp 0,1 '+str(memcached_pid)
process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE)
out, err = process.communicate()

log_obj=SchedulerLogger()
p=psutil.Process(memcached_pid)

while(True):
    time.sleep(sleep_interval)

    cpu_utilization=p.cpu_percent()
    print("CPU used =", cpu_utilization, "%")
    #print("Timestamp = ",time.time()*1000)
