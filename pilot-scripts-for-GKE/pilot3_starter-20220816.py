#!/usr/bin/env python

"""
This script will be executed at container startup
- It will retrieve the proxy and panda queue from the environment
- It will download the pilot wrapper from github and execute it
- It will upload the pilot logs to panda cache at the end

post-multipart code was taken from: https://github.com/haiwen/webapi-examples/blob/master/python/upload-file.py
"""

try:
    import subprocess32 as subprocess
except Exception:
    import subprocess
import os
import sys
import shutil
import logging
from logging import Logger, INFO
from threading import Thread
import atexit
import signal
import time
import re
try:
    import httplib
    import urlparse
    from urllib2 import urlopen
except ImportError:
    import http.client as httplib
    import urllib.parse as urlparse
    from urllib.request import urlopen
import mimetypes
import ssl
import traceback
import ast
import collections

WORK_DIR = '/scratch'
CONFIG_DIR = '/scratch/jobconfig'
PJD = 'pandaJobData.out'
PFC = 'PoolFileCatalog_H.xml'
CONFIG_FILES = [PJD, PFC]

LogLevelNames = ['CRITICAL', 'DEBUG', 'ERROR', 'FATAL', 'INFO', 'WARN', 'WARNING']

LogName = 'Panda-WorkerLog'
LogFile = '/tmp/wrapper-wid.log'
SleepTime = 10

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s %(message)s', stream=sys.stdout)

# handlers=[logging.FileHandler('/tmp/vm_script.log'), logging.StreamHandler(sys.stdout)])
# filename='/tmp/vm_script.log', filemode='w')


def post_multipart(host, port, selector, files, proxy_cert):
    """
    Post files to an http host as multipart/form-data.
    files is a sequence of (name, filename, value) elements for data to be uploaded as files
    Return the server's response page.
    """
    content_type, body = encode_multipart_formdata(files)

    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain(certfile=proxy_cert, keyfile=proxy_cert)

    h = httplib.HTTPSConnection(host, port, context=context, timeout=180)

    h.putrequest('POST', selector)
    h.putheader('content-type', content_type)
    h.putheader('content-length', str(len(body)))
    h.endheaders()
    h.send(body.encode())
    response = h.getresponse()
    return response.status, response.reason


def encode_multipart_formdata(files):
    """
    files is a sequence of (name, filename, value) elements for data to be uploaded as files
    Return (content_type, body) ready for httplib.HTTP instance
    """
    BOUNDARY = '----------ThIs_Is_tHe_bouNdaRY_$'
    CRLF = '\r\n'
    L = []
    for (key, filename, value) in files:
        L.append('--' + BOUNDARY)
        L.append('Content-Disposition: form-data; name="%s"; filename="%s"' % (key, filename))
        L.append('Content-Type: %s' % get_content_type(filename))
        L.append('')
        L.append(value.decode("utf-8"))
    L.append('--' + BOUNDARY + '--')
    L.append('')
    body = CRLF.join(L)
    content_type = 'multipart/form-data; boundary=%s' % BOUNDARY
    return content_type, body


def get_content_type(filename):
    return mimetypes.guess_type(filename)[0] or 'application/octet-stream'


def upload_logs(url, log_file_name, destination_name, proxy_cert):
    try:
        full_url = url + '/putFile'
        urlparts = urlparse.urlsplit(full_url)

        logging.debug('[upload_logs] start')
        files = [('file', destination_name, open(log_file_name, 'rb').read())]
        status, reason = post_multipart(urlparts.hostname, urlparts.port, urlparts.path, files, proxy_cert)
        logging.debug('[upload_logs] finished with code={0} msg={1}'.format(status, reason))
        if status == 200:
            return True
    except Exception:
        err_type, err_value = sys.exc_info()[:2]
        err_messsage = "failed to put with {0}:{1} ".format(err_type, err_value)
        err_messsage += traceback.format_exc()
        logging.debug('[upload_logs] excepted with:\n {0}'.format(err_messsage))

    return False


def get_url(url, headers=None):
    """
    get content from specified URL
    TODO: error handling
    """
    response = urlopen(wrapper_url, context=ssl._create_unverified_context())
    content = response.read()
    return content


def copy_files_in_dir(src_dir, dst_dir):
    # src_files = os.listdir(src_dir)
    for file_name in CONFIG_FILES:
        full_file_name = os.path.join(src_dir, file_name)
        if os.path.exists(full_file_name):
           shutil.copy(full_file_name, dst_dir)


def get_configuration():
    # get the proxy certificate and save it
    if os.environ.get('proxySecretPath'):
        # os.symlink(os.environ.get('proxySecretPath'), proxy_path)
        proxy_path = os.environ.get('proxySecretPath')
    elif os.environ.get('proxyContent'):
        proxy_path = "/tmp/x509up"
        proxy_string = os.environ.get('proxyContent').replace(",", "\n")
        with open(proxy_path, "wb") as proxy_file:
            proxy_file.write(proxy_string)
        del os.environ['proxyContent']
        os.chmod(proxy_path, 0o600)
    else:
        logging.debug('[main] no proxy specified in env var $proxySecretPath nor $proxyContent')
        raise Exception('Found no voms proxy specified')
    os.environ['X509_USER_PROXY'] = proxy_path
    logging.debug('[main] initialized proxy')

    # get the panda site name
    panda_site = os.environ.get('computingSite')
    logging.debug('[main] got panda site: {0}'.format(panda_site))

    # get the panda queue name
    panda_queue = os.environ.get('pandaQueueName')
    logging.debug('[main] got panda queue: {0}'.format(panda_queue))

    # get the resource type of the worker
    resource_type = os.environ.get('resourceType')
    logging.debug('[main] got resource type: {0}'.format(resource_type))

    prodSourceLabel = os.environ.get('prodSourceLabel')
    logging.debug('[main] got prodSourceLabel: {0}'.format(prodSourceLabel))

    job_type = os.environ.get('jobType')
    logging.debug('[main] got job type: {0}'.format(job_type))

    # get the Harvester ID
    harvester_id = os.environ.get('HARVESTER_ID')
    logging.debug('[main] got Harvester ID: {0}'.format(harvester_id))

    # get the worker id
    worker_id = os.environ.get('workerID')
    logging.debug('[main] got worker ID: {0}'.format(worker_id))

    # get the URL (e.g. panda cache) to upload logs
    logs_frontend_w = os.environ.get('logs_frontend_w')
    logging.debug('[main] got url to upload logs')

    # get the URL (e.g. panda cache) where the logs can be downloaded afterwards
    logs_frontend_r = os.environ.get('logs_frontend_r')
    logging.debug('[main] got url to download logs')

    # get the filename to use for the stdout log
    stdout_name = os.environ.get('stdout_name')
    if not stdout_name:
        stdout_name = '{0}_{1}.out'.format(harvester_id, worker_id)

    logging.debug('[main] got filename for the stdout log')

    # get the submission mode (push/pull) for the pilot
    submit_mode = os.environ.get('submit_mode')
    if not submit_mode:
        submit_mode = 'PULL'

    # get the realtime logging server
    realtime_logging_server = os.environ.get('REALTIME_LOGGING_SERVER')
    logging.debug('[main] got realtime logging server: {0}'.format(realtime_logging_server))

    # get the realtime logging name
    realtime_logname = os.environ.get('REALTIME_LOGNAME')
    logging.debug('[main] got realtime logname: {0}'.format(realtime_logname))

    # get the option where the realtime logging should apply
    use_realtime_logging = os.environ.get('USE_REALTIME_LOGGING')
    if use_realtime_logging is not None:
        use_realtime_logging = use_realtime_logging.lower()
    logging.debug('[main] got realtime logging server: {0}'.format(use_realtime_logging))

    # see if there is a work directory specified
    tmpdir = os.environ.get('TMPDIR')
    if tmpdir:
        global WORK_DIR
        WORK_DIR = tmpdir
        global CONFIG_DIR
        if not os.path.exists(CONFIG_DIR):
           CONFIG_DIR = tmpdir + '/jobconfig'
           if not os.path.exists(CONFIG_DIR):
              os.mkdir(CONFIG_DIR)

    return proxy_path, panda_site, panda_queue, resource_type, prodSourceLabel, job_type, harvester_id, \
           worker_id, logs_frontend_w, logs_frontend_r, stdout_name, submit_mode, realtime_logging_server, realtime_logname, use_realtime_logging


def get_realtime_logger():
    return RealTimeLogger.glogger


def run_realtimeLogger(logFile, logName):
    realtimeLogger = RealTimeLogger(logFile, logName)
    realtimeLogger.send_logFile()


# stop the background task gracefully before exit
def stop_background(realtimeLogger, thread):
    # request the background thread stop
    realtimeLogger.set_jobEnd()

    # wait for the background thread to stop
    thread.join()


# flush the the realtimeLogger in case of kill/interrupt
def flush_logger(signal, frame):
    realtimeLogger = get_realtime_logger()
    if realtimeLogger:
       realtimeLogger.set_jobEnd()
       realtimeLogger.flush()


from google.cloud.logging_v2.handlers.transports import BackgroundThreadTransport
class BkgThreadTransport(BackgroundThreadTransport):

    def __init__(self, client, name):
        super(BkgThreadTransport, self).__init__(client, name, grace_period=30, batch_size=50, max_latency=10)


class RealTimeLogger(Logger):

    def __init__(self, logFile, logName):
        super(RealTimeLogger, self).__init__(name="realTimeLogger", level=logging.DEBUG)
        RealTimeLogger.glogger = self

        self.logFile = logFile
        self.jobEnd  = False
        self.pandaID = None
        self.jobName = None
        self.didJobFail = False

        import google.cloud.logging
        from google.cloud.logging_v2.handlers import CloudLoggingHandler
        client = google.cloud.logging.Client()
        h = CloudLoggingHandler(client, name=logName, transport=BkgThreadTransport)
        self.handler = h
        self.addHandler(h)

        self.hostname = os.environ.get('HOSTNAME','')
        self.timestamp = re.compile( '^20\d{2}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3} (.*)' )

    def set_jobEnd(self):
        self.jobEnd  = True

    def hasJobEnded(self):
        return self.jobEnd

    def flush(self):
        h = self.handler
        h.transport.flush()

    def send_with_hostname(self, level, msg):
        log = {"hostname":self.hostname, "message":msg}
        if self.pandaID is not None:
           log["PandaJobID"] = str(self.pandaID)
        if self.jobName is not None:
           log["jobName"] = self.jobName
        self.log(level, log)
    
    def parseLine(self, line):
        objectMatch = self.timestamp.match(line)
        level = INFO
        if objectMatch:
           msg = objectMatch.groups()[0]
           if msg.startswith('| '):
              msg = msg[2:]
              msg_items = msg.split('|')
              # if len(msg_items) > 1 and msg_items[1].strip().startswith('pilot.'):
              if len(msg_items) > 1:
                 item0 = msg_items[0].strip()
                 if item0 in LogLevelNames:
                    level = getattr(logging, item0)
                 else:
                    level = INFO
                 lastItem = msg_items[-1]
                 if msg.find("dump_job_definition") > 0 and lastItem.find("PandaID") > 0:
                    try:
                        dict_lastItem = ast.literal_eval(lastItem.split('=',1)[-1].strip())
                        if "PandaID" in dict_lastItem:
                           self.pandaID = dict_lastItem["PandaID"]
                           self.didJobFail = False
                           if "jobName" in dict_lastItem:
                              self.jobName = dict_lastItem["jobName"]
                    except Exception:
                        pass
                 elif lastItem.find("ready for new job") > 0 and msg.find("pilot.control.job") > 0:
                    self.pandaID = None
                    self.jobName = None
                    self.didJobFail = False

           return msg, level
        else:
           return None, level
        
    def send_logFile(self):
        openfile = None
        while not self.jobEnd:
           if os.path.exists(self.logFile):
              openfile = open(self.logFile)
              break
           else:
              time.sleep(SleepTime)

        last_10_lines = collections.deque([], maxlen=10)
        while openfile is not None:
           lines = openfile.readlines()
           msg_toSave = None
           msgType_toSave = None
           level_toSave = INFO
           for line in lines:
               msg, level = self.parseLine(line)
               if msg is not None:
                  if msg_toSave is not None:
                     if msgType_toSave == "StderrDump":
                        msg_toSave += ':\n'+ ''.join(last_10_lines)
                        last_10_lines.clear()
                     self.send_with_hostname(level_toSave, msg_toSave)
                     msg_toSave = None
                     level_toSave = INFO
                  if level >= logging.ERROR:
                     msg_toSave = msg
                     level_toSave = level
                     msgType_toSave = "ERROR"
                  elif msg.find("pilot.control.payloads.generic") > 0 and len(msg.split('|')[-1].strip()) == 0:
                     msg_toSave = msg
                     level_toSave = level
                     msgType_toSave = "JobStatus"
                  elif msg.find("| payload stderr dump") > 0:
                     msg_toSave = msg
                     msgType_toSave = "StderrDump"
                     last_10_lines.clear()
                     if self.didJobFail:
                        level_toSave = logging.ERROR
                     else:
                        level_toSave = level
                  else:
                     if self.didJobFail:
                        if msg.find("| add_error_codes") > 0 or msg.find("| perform_initial_payload_error_analysis") > 0:
                           level = logging.ERROR
                     self.send_with_hostname(level, msg)
               elif msg_toSave is not None:
                  if msgType_toSave == "StderrDump":
                     if len(line.strip()) > 0:
                        last_10_lines.append(line)
                  else:
                     msg_toSave += line
                     if msgType_toSave == "JobStatus" and line.find('exit_code=') > 0:
                        if line.find('state=failed') > 0:
                           self.didJobFail = True
                           level_toSave = logging.ERROR
           if msg_toSave is not None:
              if msgType_toSave == "StderrDump":
                 msg_toSave += ':\n'+ ''.join(last_10_lines)
                 last_10_lines.clear()
              self.send_with_hostname(level_toSave, msg_toSave)
              msg_toSave = None
              level_toSave = INFO
           if self.jobEnd:
              print("jobEnd has been set, the last line=",line)
              self.flush()
              break
           else:
              time.sleep(SleepTime)

        if openfile:
           openfile.close()


if __name__ == "__main__":

    # get all the configuration from environment
    proxy_path, panda_site, panda_queue, resource_type, prodSourceLabel, job_type, harvester_id, worker_id, \
    logs_frontend_w, logs_frontend_r, destination_name, submit_mode, realtime_logging_server, realtime_logname, use_realtime_logging = get_configuration()

    # the pilot should propagate the download link via the pilotId field in the job table
    log_download_url = '{0}/{1}'.format(logs_frontend_r, destination_name)
    os.environ['GTAG'] = log_download_url  # GTAG env variable is read by pilot

    # get the pilot wrapper
    wrapper_path = "/tmp/runpilot3-wrapper.sh"
    # wrapper_url = "http://ai-idds-03.cern.ch/static/images/payload/runpilot3-wrapper.sh"
    wrapper_url = "https://storage.googleapis.com/drp-us-central1-containers/runpilot3-wrapper.sh"
    wrapper_string = get_url(wrapper_url)
    if os.path.exists(wrapper_path):
       os.remove(wrapper_path)
    with open(wrapper_path, "wb") as wrapper_file:
       wrapper_file.write(wrapper_string)
    os.chmod(wrapper_path, 0o544)  # make pilot wrapper executable
    logging.debug('[main] downloaded pilot wrapper')

    # execute the pilot wrapper
    logging.debug('[main] starting pilot wrapper...')
    resource_type_option = ''
    if resource_type:
        resource_type_option = '--resource-type {0}'.format(resource_type)

    if prodSourceLabel:
        psl_option = '-j {0}'.format(prodSourceLabel)
    else:
        psl_option = '-j managed'
    # psl_option = '-j test'

    job_type_option = ''
    if job_type:
        job_type_option = '-i {0}'.format(job_type)

    # wrapper_params = '-a {0} -s {1} -r {2} -q {3} {4} {5} {6}'.format(WORK_DIR, panda_site, panda_queue, panda_queue,
    wrapper_params = '-s {0} -r {1} -q {2} {3} {4} {5}'.format(panda_site, panda_queue, panda_queue,
                                                              resource_type_option, psl_option, job_type_option)

    # parameter/option for realtime logging
    if use_realtime_logging == "yes" or use_realtime_logging == "y":
        wrapper_params += " --use-realtime-logging"
        if realtime_logging_server is not None:
            wrapper_params += " --realtime-logging-server %s" % realtime_logging_server
        if realtime_logname is not None:
            wrapper_params += " --realtime-logname %s" % realtime_logname

    if submit_mode == 'PUSH':
        # job configuration files need to be copied, because k8s configmap mounts as read-only file system
        # and therefore the pilot cannot execute in the same directory
        copy_files_in_dir(CONFIG_DIR, WORK_DIR)
        wrapper_params += " --harvester-datadir %s" % WORK_DIR


    # start a daemon thread to send the log to the Google cloud logging
    thread = Thread(target=run_realtimeLogger, args=(LogFile, LogName,), daemon=True, name="Background")
    thread.start()

    realtimeLogger = get_realtime_logger()

    # register the at exit
    atexit.register(stop_background, realtimeLogger, thread)

    # register the signal of kill/interrupt
    signal.signal(signal.SIGTERM, flush_logger)
    signal.signal(signal.SIGINT, flush_logger)

    pilot_url = "https://storage.googleapis.com/drp-us-central1-containers/pilot3-v3331_5.tgz"
    command = "/tmp/runpilot3-wrapper.sh {0} -i PR --piloturl {1} -w generic --pilot-user rubin --url=https://pandaserver-doma.cern.ch -d --harvester-submit-mode {2} --allow-same-user=False -t | tee {3}". \
        format(wrapper_params, pilot_url, submit_mode, LogFile)
    try:
        subprocess.call(command, shell=True)
    except:
        logging.error(traceback.format_exc())
    logging.debug('[main] pilot wrapper done...')

    # tell the realtime logger that the pilot job has finished.
    logging.debug('[main] Sending jobEnd to the realtimeLogger')
    realtimeLogger.set_jobEnd()
    realtimeLogger.flush()
    time.sleep(SleepTime)

    # upload logs to e.g. panda cache or similar
    upload_logs(logs_frontend_w, LogFile, destination_name, proxy_path)
    logging.debug('[main] FINISHED')
