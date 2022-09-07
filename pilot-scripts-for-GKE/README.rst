This directory consists of
  * a pilot starter in python
  * a pilot wrapper in shell
  * the Dockerfile of pilot Docker container
  * a prmon (memory monitor) executable file for X86_64

All the script files and pilot package are stored in the following Google Cloud Storage (GCS) bucket: 

`https://storage.googleapis.com/drp-us-central1-containers/ <https://storage.googleapis.com/drp-us-central1-containers/>`_

The built pilot Docker container is stored in Google Artifact Registry (GAR) under **us-central1-docker.pkg.dev/panda-dev-1a74/pilot/centos**

Files in GCS bucket are cached on GKE nodes, hence it usually takes some time (hours) 
to update if the same filename is used. That is why the pilot starter file is dated,
to make it into effect immediately on GKE nodes.
