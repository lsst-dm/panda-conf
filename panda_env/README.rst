# pilot_env
setup pilot env

Setup pilot env
===============

Run *panda_pilot_install.sh* to setup pilot env. It will::
  * setup pilot env with conda
  * install CA certificates
  * install voms-clients, panda-client, rucio-clients, google-storage packages
  * install pilot codes
  * install pilot wrapper

Here is how to run *panda_pilot_install.sh*::
  $> bash panda_pilot_install.sh  <dest_dir>
For example::
  $> bash panda_pilot_install.sh /cvmfs/sw.lsst.eu/linux-x86_64/panda/


Setup cron jobs
================

A cron job is required to renew the CRL of CA certificates. *panda_pilot_install.sh* will
generate the cron command under *<dest_dir>/tools/fetch-crl.cron*. Please install it too.


How to update
=============
* To add/update pacakges to the pilot env, you can update *pilot_environments.yaml* or *pilot_requirements.txt*.

* To update pilot version, you can update *pilot_version.txt*.

* To update pilot wrapper version, you can update *pilot_wrapper.txt*.
