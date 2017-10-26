#! /bin/bash

if "true" : '''\'
then

if [ ! -d /cvmfs/cms.cern.ch/crab/CRAB_2_11_1_patch1/python ]; then
    env PATH="${PATH}:${PWD}" $@
elif [ -n "$SRT_LD_LIBRARY_PATH_SCRAMRT" ]; then
    env LD_LIBRARY_PATH=${LD_LIBRARY_PATH%%:}:$SRT_LD_LIBRARY_PATH_SCRAMRT python "$0" "$@"
else
    env python "$0" "$@"
fi
exitcode=$?
exit $exitcode
fi
'''

#! /bin/env python
from datetime import datetime
import os
import subprocess
import sys
import socket
import logging
sys.path.insert(0, '/cvmfs/cms.cern.ch/crab/CRAB_2_11_1_patch1/python/')

# from DashboardAPI import apmonSend, apmonFree
try:
    from DashboardAPI import apmonSend, apmonFree
except:
    u, v, t = sys.exc_info()
    sys.stderr.write('Error: {0}\n'.format(v))
    sys.exit(119)

#import DashboardAPI
#DashboardAPI.apmonLoggingLevel = "DEBUG"

logging.basicConfig(format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.WARNING)

def get_dashboard_parameters(out):
    '''Return a dictionary with all dashboard parameters
    from executable for reporting. Current parameters needed are:
    -CMS_DASHBOARD_N_EVENTS
    -CMS_DASHBOARD_EXE_EXIT_CODE
    -CMS_DASHBOARD_EXE_WC_TIME
    -CMS_DASHBOARD_EXE_CPU_TIME
    -CMS_DASHBOARD_JOB_EXIT_CODE
    -CMS_DASHBOARD_JOB_EXIT_REASON
    -CMS_DASHBOARD_STAGEOUT_SE
    -CMS_DASHBOARD_STAGEOUT_EXIT_CODE
    -CMS_DASHBOARD_STAGEOUT_TIME
    '''

    lines = out.split('\n')
    parameters = {}

    for line in lines:
        line = line.strip()
        if line.startswith('#'):
            continue

        if 'CMS_DASHBOARD_' in line:
            var = line.split('=')
            parameters[var[0].strip()] = var[1].strip()

    return parameters


data = {}
data['time begin'] = int(datetime.now().strftime('%s'))

ce = os.environ.get('GLIDEIN_Gatekeeper', 'unknown')
ce = ce.split()[0]

executable = ""
for args in sys.argv[1:]:
    executable += ' {0}'.format(args)

if not executable:
    executable = "Unknown"

# todo: Handle case when taskid, monitorid, syncid are not present
taskid = os.environ.get('Dashboard_taskid','')
monitorid = os.environ.get('Dashboard_monitorid','')
syncid = os.environ.get('Dashboard_syncid','')
#Replace MetaId by Dashboard_id
_jobid = str(os.environ.get('Dashboard_Id','MetaID'))
monitorid = monitorid.replace('MetaID', _jobid)
syncid = syncid.replace('MetaID', _jobid)

# Start Dashboard Report
hostname = str(socket.gethostname())
parameters = {
            'ExeStart': executable,
            'SyncCE': str(ce),
            'SyncGridJobId': syncid,
            'WNHostName': hostname
            }
apmonSend(taskid, monitorid, parameters)
apmonFree()


###############
# Execute job
###############

#Add PWD to PATH environment
myenv = os.environ
myenv['PATH'] += ':{0}'.format(os.environ.get('PWD'))

print 'current cwd: {0}'.format(os.getcwd())
print 'Directory list'
os.listdir('./')

print 'Environment:'
print myenv

t0 = os.times()
p = subprocess.Popen(executable, stdout = subprocess.PIPE, stderr = subprocess.PIPE, shell=True, env=myenv)
out, err = p.communicate()
t1 = os.times()
if err:
    logging.error("[ERROR] There was an error executing job: {0}".format(err))
    parameters = {
                'taskId': taskid,
                'jobId': monitorid,
                'sid': syncid,
                'StatusValueReason': 'Error: {0}'.format(err),
                'StatusValue': 'Aborted',
                'StatusEnterTime':
                "{0:%F_%T}".format(datetime.utcnow()),
                'StatusDestination': str(ce),
                'RBname': 'condor'
                }
    apmonSend(taskid, monitorid, parameters)
    apmonFree()

print out

# Get environment variables
dash_parameters = get_dashboard_parameters(out)

data['number of events'] = dash_parameters.get('CMS_DASHBOARD_N_EVENTS', '0')
data['exe cpu time'] = dash_parameters.get('CMS_DASHBOARD_EXE_CPU_TIME', str(t1[2] + t1[3] - t0[2] - t0[3]))
data['exe wc time'] = dash_parameters.get('CMS_DASHBOARD_EXE_WC_TIME', str(t1[4] - t0[4]))
data['exe exit code'] = dash_parameters.get('CMS_DASHBOARD_EXE_EXIT_CODE', str(p.returncode))
data['job exit code'] = dash_parameters.get('CMS_DASHBOARD_JOB_EXIT_CODE', str(p.returncode))
data['job exit reason'] = dash_parameters.get('CMS_DASHBOARD_JOB_EXIT_REASON', str(err))
data['stageout se'] = dash_parameters.get('CMS_DASHBOARD_STAGEOUT_SE', 'unknown')
data['stageout exit code'] = dash_parameters.get('CMS_DASHBOARD_STAGEOUT_EXIT_CODE', '0')
data['stageout time'] = dash_parameters.get('CMS_DASHBOARD_STAGEOUT_TIME', '0.0')

# Report end of job execution
apmonSend(taskid, monitorid, {'ExeEnd': executable})

data['time end'] = int(datetime.now().strftime('%s'))

# Finish dashboard report
exe_wc_time = data['exe wc time']
exe_cpu_time = data['exe cpu time']
exe_exit_code = data['exe exit code']
total_time = data['time end'] - data['time begin']
job_exit_code = data['job exit code']
job_exit_reason = data['job exit reason']
stageout_se = data['stageout se']
stageout_time = data['stageout time']
stageout_exit_code = data['stageout exit code']
n_events = data['number of events']

parameters = {
            'ExeTime': str(exe_wc_time),
            'ExeExitCode': str(exe_exit_code),
            'JobExitCode': str(job_exit_code),
            'JobExitReason': str(job_exit_reason),
            'StageOutSE': stageout_se,
            'StageOutExitStatus': str(stageout_exit_code),
            'StageOutExitStatusReason': 'Copy succedeed with srm-lcg utils',
            'CrabUserCpuTime': str(exe_cpu_time),
            'CrabWrapperTime': str(total_time),
            'CrabStageoutTime': str(stageout_time),
            'WCCPU': str(total_time),
            'NEventsProcessed': str(n_events)
            }
try:
    parameters.update({'CrabCpuPercentage': str(float(exe_cpu_time)/float(total_time))})
except:
    pass

apmonSend(taskid, monitorid, parameters)
apmonFree()

# todo: This should be reported at the master
parameters = {
            'taskId': taskid,
            'jobId': monitorid,
            'sid': syncid,
            'StatusValueReason': '',
            'StatusValue': 'Done',
            'StatusEnterTime':
            "{0:%F_%T}".format(datetime.utcnow()),
            'StatusDestination': str(ce),
            'RBname': 'condor'
            }
apmonSend(taskid, monitorid, parameters)
apmonFree()

sys.exit(p.returncode)
