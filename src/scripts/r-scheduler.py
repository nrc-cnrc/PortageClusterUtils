#!/usr/bin/env python
# @file
# @brief Daemon to monitor run-parallel.sh that maximizes cluster usage.
#
# @author Samuel Larkin
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2013, Sa Majeste la Reine du Chef du Canada /
# Copyright 2013, Her Majesty in Right of Canada


# source: http://pythonhosted.org/APScheduler/

from __future__ import print_function, unicode_literals, division, absolute_import

from apscheduler.scheduler import Scheduler
from apscheduler.events import (EVENT_JOBSTORE_ADDED, EVENT_SCHEDULER_SHUTDOWN)
from apscheduler.triggers.cron import CronTrigger

import os.path
import sys
import time
from datetime import datetime  # now()
import re
from math import ceil
from itertools import izip
from subprocess import call, check_call, check_output, CalledProcessError
from argparse import ArgumentParser, RawDescriptionHelpFormatter, Action

# Activate logging or else this will be UNDEBUGGABLE.
import logging
logging.basicConfig()


debug_flag = False
class DebugAction(Action):
   """argparse action class for turning on verbose output.
   e.g: parser.add_argument("-d", "--debug", action=DebugAction)
   """
   def __init__(self, option_strings, dest, help="print debug output to stderr [False]"):
      super(DebugAction, self).__init__(option_strings, dest, nargs=0,
                                        const=True, default=False,
                                        required=False, help=help)

   def __call__(self, parser, namespace, values, option_string=None):
      setattr(namespace, self.dest, True)
      global debug_flag
      debug_flag = True

def error(*args):
   """Print an error message to stderr."""
   print("{} Error:".format(datetime.now()), *args, file=sys.stderr)
   return

def fatal_error(*args):
   """Print a fatal error message to stderr and exit with code 1."""
   print("{} Fatal error:".format(datetime.now()), *args, file=sys.stderr)
   sys.exit(1)

def warn(*args):
   """Print an warning message to stderr."""
   print("{} Warning:".format(datetime.now()), *args, file=sys.stderr)
   return

def info(*args, **kwargs):
   """Print information output to stderr."""
   print(datetime.now(), *args, file=sys.stderr, **kwargs)

def debug(*args, **kwargs):
   """Print debug output to stderr if debug_flag (-d) is set."""
   if debug_flag:
      print("{} Debug:".format(datetime.now()), *args, file=sys.stderr, **kwargs)

def verbose(*args, **kwargs):
   """Print verbose output to stderr if verbose_flag (-v) or debug_flag (-d) is set."""
   if verbose_flag or debug_flag:
      print(datetime.now(), *args, file=sys.stderr, **kwargs)



def get_args():
   """Command line argument processing."""

   usage = "r-scheduler.py [options] psub_cmd_path"
   help = """
   Monitor a run-parallel.sh job on the cluster to add or quench workers on
   user specified times.
   """
   epilog = """
   Cron like job format:
   %_of_free_resource:second minute hour day month year day_of_week
   examples:
   -a '0.31415:0 */5 * * * * *'  # Add workers to leave 0.31415% of the resources free every 5 minutes
   -q '0.27189:0 0 */4 * * * *'  # Quench workers to leave 0.27189% of the resources free every 4 hours

   where:
   Field        Description
   second       second (0-59)
   minute       minute (0-59)
   hour         hour (0-23)
   day          day of the month (1-31)
   month        month number (1-12)
   year         4-digit year number
   day_of_week  number or name of weekday (0-6 or mon,tue,wed,thu,fri,sat,sun)

   Expression      Field   Description
   *               any     Fire on every value
   */a             any     Fire every a values, starting from the minimum
   a-b             any     Fire on any value within the a-b range (a must be smaller than b)
   a-b/c           any     Fire every c values within the a-b range
   xth y           day     Fire on the x -th occurrence of weekday y within the month
   last x          day     Fire on the last occurrence of weekday x within the month
   last            day     Fire on the last day within the month
   x,y,z           any     Fire on any matching expression; can combine any number of any of the above expressions
   """

   # Use the argparse module, not the deprecated optparse module.
   parser = ArgumentParser(prog='r-scheduler.py', formatter_class=RawDescriptionHelpFormatter, usage=usage, description=help, add_help=True, epilog=epilog)

   parser.add_argument("-a", dest="add", nargs="*", type=str, default=[],
                       help="schedule a cron job to add workers [%(default)s]")
   parser.add_argument("-q", dest="quench", nargs="*", type=str, default=[],
                       help="schedule a cron job to quench workers [%(default)s]")

   parser.add_argument("-b", dest="burst_interval", type=int, default=5,
                       help="monitor cluster resources at interval X in minutes [%(default)s]")

   parser.add_argument("-m", dest="minimumNumberOfWorker", type=int, default=60,
                       help="minimum number of workers [%(default)s]")

   parser.add_argument("-f", dest="freeRessource", type=float, default=0.1,
                       help="amount of resources to leave free [0, 1.0] [%(default)s]")

   parser.add_argument("-d", "--debug", action=DebugAction)

   parser.add_argument("-n", "--not-really", dest="notReally", action='store_true', default=False,
                       help="don't actually change the number of workers in use [%(default)s]")

   parser.add_argument("psub_cmd_or_PBS_JOBID", help="path/run-p.SUFFIX/psub_cmd or PBS_JOBID")

   cmd_args = parser.parse_args()

   # info, verbose, debug all print to stderr.
   for arg in cmd_args.__dict__:
      info("  {0} = {1}".format(arg, getattr(cmd_args, arg)))

   if cmd_args.psub_cmd_or_PBS_JOBID is "":
      fatal_error("No job provided by the user")

   return cmd_args


class IsDeamonAlive:
   """
   This class will monitor a PBS_JOBID and indicate if it is still present on
   the cluster.
   """
   def __init__(self, jobId):
      """
      Initialize with which PBS_JOBID to track.
      """
      self.KeepRunning = True
      self.jobID = jobId
      info("Monitoring job {}".format(self.jobID))

   def __call__(self):
      """
      Make this class callable in order to make it a thread.
      """
      info("Checking if job {} is still alive!".format(self.jobID))
      cmd  = "qstat | grep " + self.jobID + " &> /dev/null"
      debug(cmd)
      self.KeepRunning = call(cmd, shell=True) is 0


# This class is not used.
class MonitorQueueActivity:
   def __init__(self):
      self.val = 0

   def __call__(self):
      self.val += 1
      info("Monitoring queue's activity ".format(self.val))
      if self.val>2:
         info("Trying to shutdown")
         sched.shutdown(wait=False)


def add_event_listeners(sched):
   """
   Add two event listeners to the scheduler.
   One to display new job added to the scheduler, one to display when the
   scheduler is shutting down.
   """
   def shutdown_event(event):
       """
       Simply advertize that the scheduler is shutting down.
       """
       info("Shutting down {}".format(event))

   def new_job_event(event):
       """
       Simply advertize that the scheduler as a new job.
       """
       info("New job {}".format(event))

   sched.add_listener(shutdown_event, EVENT_SCHEDULER_SHUTDOWN)
   sched.add_listener(new_job_event, EVENT_JOBSTORE_ADDED)


def get_jobID(cmd_args):
   """
   Get the job id from the psub_cmd's directory path or PBS_JOBID provided by
   the user on the command line.
   """
   if os.path.isfile(cmd_args.psub_cmd_or_PBS_JOBID):
      #run-p.1355859.balza.096
      m = re.match(r'.*run-p.(\d+).balza.\d+/psub_cmd', cmd_args.psub_cmd_or_PBS_JOBID)
      if not m:
          fatal_error("Error with regular expression {}".format(cmd_args.psub_cmd_or_PBS_JOBID))

      return m.group(1)
   else:
      m = re.match(r'\d+', cmd_args.psub_cmd_or_PBS_JOBID)
      if not m:
         fatal_error("Unrecognized job id format {}".format(cmd_args.psub_cmd_or_PBS_JOBID))
      return cmd_args.psub_cmd_or_PBS_JOBID


def add_cronjob(sched, cmd_args):
   """
   Add user defined cron jobs.
   (Scheduler, cmd_args)
   """
   def adding(value):
      """
      This function is used to increase the number of workers.
      """
      cmd_args.freeRessource = float(value)
      info("Adding {} workers".format(value))


   def quenching(value):
      """
      This function is used to decrease the number of workers.
      """
      cmd_args.freeRessource = float(value)
      info("Quenching {} workers".format(value))


   def addCron(liste, fonction):
      """
      Create cron jobs for adding and quenching based on specific time of day.
      """
      # source: http://tornadogists.org/1770500/
      _re_split_cron  = re.compile('\s*:\s*')
      _re_split_time  = re.compile("\s+")
      _sched_seq      = ('second', 'minute', 'hour', 'day', 'month', 'year', 'day_of_week')
      try:
         for job in liste:
            w, date  = _re_split_cron.split(job)
            splitted = _re_split_time.split(date)
            if len(splitted) < 7:
               raise TypeError("'schedule' argument pattern mismatch")

            w = float(w)

            schedule = dict(izip(_sched_seq, splitted))
            info(("Adding cron for {} with these parameters: ".format(fonction.__name__), job, w, date, schedule))
            #sched.add_job(trigger=CronTrigger(**schedule), func=(lambda v: sys.stdout.write(v, "\n")), args=[w], kwargs={})
            sched.add_cron_job(func=fonction, name=job, args=[w], kwargs=None, **schedule)
            #sched.add_interval_job('sys:stdout.write', args=['tick\n'], seconds=3)
      except ValueError as err:
        fatal_error("Error expected format for cron job is: %:bla blah bla")

   addCron(cmd_args.add, adding)
   addCron(cmd_args.quench, quenching)


#||| 265 jobs pending
#||| 320 CPUs: 16 down or offline, 304 busy, 0 free
jobs_pending_pattern = re.compile(r'\|\|\|( (\d+) jobs pending)?')
free_cpu_pattern = re.compile(r'\|\|\| (\d+) CPUs: .*, (\d+) free')
def cluster_resources():
   """
   () -> (int, int)
   Check general cluster usage.
   return (totalCPUs, freeCPUs)
   """
   contents = check_output("analyze").strip().split('\n')

   m = free_cpu_pattern.search(contents[-1])
   if not m:
       fatal_error("Error with regular expression free cpu re:{} {}".format(free_cpu_pattern, contents[-1]))
   totalCPUs, freeCPUs = m.group(1), m.group(2)

   n = jobs_pending_pattern.search(contents[-2])
   if not n:
       fatal_error("Error with regular expression jobs pending re:{} {}".format(jobs_pending_pattern, contents[-2]))
   pending = 0
   if n.group(2):
      pending = n.group(2)

   return int(totalCPUs), int(freeCPUs) - int(pending)


num_worker_pattern = re.compile(r"w:(\d+) q:(\d+) a:(\d+)$")
def job_resources(jobID):
   """
   (int) -> (int, int, int)

   Queries run-parallel.sh with num_worker to get the following information:
   W: current number of workers
   Q: number of workers been quenched
   A: number of workers been added
   returns (W, Q, A)
   """
   contents = check_output(["run-parallel.sh", "num_worker", str(jobID)]).strip().split('\n')[-1]
   #contents = check_output("qstattree " + str(jobID) + " | \wc -l", shell=True)
   #contents = check_output("qstat | grep " + str(jobID) + " | egrep '[QR] long[ ]*$' | wc -l", shell=True)
   m = num_worker_pattern.match(contents)
   if not m:
       fatal_error("Error with regular expression re:{} {}".format(free_cpu_pattern, contents))

   return int(m.group(1)), int(m.group(2)), int(m.group(3))


def main():
   # Parse command line arguments.
   cmd_args = get_args()


   # Figure out which job to monitor.
   jobID = get_jobID(cmd_args)


   # Create the scheduler
   sched = Scheduler()


   # Add event listeners
   add_event_listeners(sched)


   # Add user defined cron jobs.
   add_cronjob(sched, cmd_args)


   # Add the thread that checks if master is still alive.
   d = IsDeamonAlive(jobID)
   sched.add_interval_job(d, seconds=60)

   # Start the scheduler
   try:
      sched.start()
   except (KeyboardInterrupt, SystemExit):
      pass

   factor_add = 0.25
   factor_quench = 1
   try:
      while d.KeepRunning:
         totalCPUs, freeCPUs = cluster_resources()

         currentNumberOfWorker, workersQuenched, workersAdded = job_resources(jobID)

         info("STATUS: ({W} + {A} - {Q}) / {T} CPUs, {F} free (minimum {R}% free)".format(
                W = currentNumberOfWorker,
                A = workersAdded,
                Q = workersQuenched,
                T = totalCPUs,
                F = freeCPUs,
                R = cmd_args.freeRessource))

         currentlyFreeResource = float(freeCPUs) / float(totalCPUs)
         if currentlyFreeResource > cmd_args.freeRessource:
            x = int(ceil((currentlyFreeResource - cmd_args.freeRessource) * (float(totalCPUs) * factor_add))) - workersAdded
            x = max(0, x)
            if x > 0:
               cmd = "run-parallel.sh add " + str(x) + " " + jobID
               debug(cmd)
               if not cmd_args.notReally:
                  check_call(cmd + " &> /dev/null", shell=True)
                  info("Dynamically adding {w} worker(s) to job {J}".format(w = x, J = jobID))
         else:
            # Make sure there is at least a minimum number of worker running.
            if currentNumberOfWorker > cmd_args.minimumNumberOfWorker:
               x = (cmd_args.freeRessource - currentlyFreeResource) * (float(totalCPUs) * factor_quench) - workersQuenched
               x = max(0, x) # we cannot remove a negative number of workers.
               # Never quench below the minimum number of workers.
               x = int(min(x, currentNumberOfWorker-cmd_args.minimumNumberOfWorker))
               if x > 0:
                  cmd = "run-parallel.sh quench " + str(x) + " " + jobID
                  debug(cmd)
                  if not cmd_args.notReally:
                     check_call(cmd + " &> /dev/null", shell=True)
                     info("Dynamically quenching {w} worker(s) from job {J}".format(w = x, J = jobID))

         time.sleep(60 * cmd_args.burst_interval)
   except CalledProcessError as err:
      warn("Process Error ".format(err.returncode))
      sched.shutdown(wait=False)


if __name__ == '__main__':
   main()
