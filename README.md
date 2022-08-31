[Français](LISEZMOI.md)

# Portage Cluster Utilities

This repo contains scripts that are used to facilitate parallelization of jobs
on a cluster or on a multi-core machine. These scripts were originally written
as part of the Portage Statistical Machine Translation, but were extracted here
because they are of more general interest.

## Installation

The simplest installation procedure is to activate PortageClusterUtils in place
from a clone.

```
git clone https://github.com/nrc-cnrc/PortageClusterUtils.git
```

and then add this line to your .profile or .bashrc:

```
source /path/to/PortageClusterUtils/SETUP.bash
```

Alternatively, you can also install it to the destination of your choice like
this:

```
cd bin/
make install INSTALL_DIR=/install/path
```

which will copy all the scripts into `/install/path/bin/`.
By default, the destination in `$HOME/bin`.

## Dependencies

PortageClusterUtilities requires:
 - Perl >= 5.14, as `perl` on your PATH;
 - any version of Python 3, as `python3` on your PATH;

## Usage

### Main Scripts

The main tools provided by this repository are these scripts:

 - parallelize.pl: take any non-parallel pipeline processing tool, say, a
   tokenizer, and parallelize it. E.g.,
      parallelize.pl -n 10 'utokenize.pl < input > output'
   will produce the same results as
      utokenize.pl < input > output
   but it will run it 10-ways parallel, either on 10 cores, or in 10 scheduled
   cluster jobs if you're running on a cluster.

   Run "parallelize.pl -h" for more details.

 - run-parallel.sh: given a list of M bash commands to run, independently from
   one another, launch N worker jobs (scheduled jobs on a cluster or worker
   threads on a multi-core machine) which will run the all the jobs, N-ways
   parallel, until all are done.

   Run "run-parallel.sh -h" for more details.

 - psub: different computing clusters require different syntax to submit jobs.
   Those differences are encapsulated inside psub, so that run-parallel.sh does
   not have to be aware of them.
      psub -mem 24G -cpus 4 some-command -and -its -options
   will run "some-command -and -its -options" in a job with the requested
   resources.

   Currently, psub is highly specicialized the the clusters we use at the NRC.
   To use PortageClusterUtils on your cluster, you must adapt psub to write job
   scripts compatible with your cluster configuration.

   Run "psub -h" for more details.

### Other Scripts

| Script                          | Brief Description                                            |
| ------------------------------- | ------------------------------------------------------------ |
| `analyze-run-parallel-log.pl`   | Summarize started/done/failed jobs in a run-parallel.sh log. |
| `jobsig.pl`                     | Send a signal to a job.                                      |
| `jobtree`                       | Display the jobstat output as a tree of jobs (jobsub).       |
| `on-cluster.sh`                 | Detect if we're running on a cluster.                        |
| `process-memory-usage.pl`       | Tally the memory usage of a process tree.                    |
| `qstatdir`                      | Run qstat, showing where commands were run from (qsub).      |
| `qstatn`                        | Run qstat -n with a more compact output (qsub).              |
| `qstattree`                     | Display the qstat output as a tree of jobs (qsub).           |
| `r-parallel-d.pl`               | Daemon for run-parallel.sh.                                  |
| `r-parallel-worker.pl`          | Worker for run-parallel.sh.                                  |
| `r-scheduler.py`                | Monitor run-parallel.sh and maximize cluster usage (obsolete)|.
| `rp-mon-totals.pl`              | Helper for run-parallel.sh, for tallying run-time stats.     |
| `rsync-with-restart.sh`         | For really unstable connections, rsync with retries until success. Warning: never gives up! |
| `stripe.py`                     | Helper for parallelize.pl.                                   |
| `sum.pl`                        | Sum/avg/max a column or list of numbers.                     |
| `which-test.sh`                 | "which" with reliable exit code, for scripting.              |

Each script accepts the `-h` option to output its full documentation.

Scripts with a cluster/scheduler type in parentheses might only work on such a
cluster.

## Citation

```bib
@misc{Portage_Cluster_Utils,
author = {Joanis, Eric and Stewart, Darlene and Larkin, Samuel and Leger, Serge},
license = {MIT},
title = {{Portage Cluster Utils}},
url = {https://github.com/nrc-cnrc/PortageClusterUtils}
year = {2022},
}
```

## Copyright

Traitement multilingue de textes / Multilingual Text Processing \
Centre de recherche en technologies numériques / Digital Technologies Research Centre \
Conseil national de recherches Canada / National Research Council Canada \
Copyright 2021, Sa Majesté la Reine du Chef du Canada / Her Majesty in Right of Canada \
Published under the MIT License (see [LICENSE](LICENSE))
