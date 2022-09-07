This directory consists of
  * a pilot starter in python
  * a pilot wrapper in shell
  * the Dockerfile of pilot Docker container
  * a prmon (memory monitor) executable file for X86_64

All the script files as well pilot package, and the built pilot Docker container, 
are stored in the following Google Cloud Storage (GCS) bucket: 

`https://storage.googleapis.com/drp-us-central1-containers/ <https://storage.googleapis.com/drp-us-central1-containers/>`_

Files in GCS bucket are cached on GKE nodes, hence it usually takes some time (hours) 
to update if the same filename is used. That is why the pilot starter file is dated,
to make it into effect immediately on GKE nodes.
