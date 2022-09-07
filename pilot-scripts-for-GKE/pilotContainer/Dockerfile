FROM opensciencegrid/osg-wn:3.6-release-el7
LABEL Description="This image is for PanDA pilot jobs with OSG-WN-3.6 package, CERN CA certificates, prmon, Docker, python pkg of GCS, google-cloud-sdk, google-logging, fluent, and logstash"
LABEL maintainer="yesw2000@gmail.com"

# which command is missing in the osg-wn container
RUN yum install -y which

# install GCS and CERN-CA-certs
RUN pip3 install protobuf==3.19.4 && pip3 install google-cloud-storage==2.0.0
RUN yum install -y https://linuxsoft.cern.ch/cern/centos/7/cern/x86_64/Packages/CERN-CA-certs-20200530-1.el7.cern.noarch.rpm

# Install Docker from Docker Inc. repositories.
RUN yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo \
    && yum install -y docker-ce docker-ce-cli containerd.io

# Install the Process MONitor "prmon"
# Reference: https://github.com/HSF/prmon
COPY ./bin/prmon /usr/local/bin/prmon

# Install docker-credential-gcr
RUN curl -fsSL https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.1.0/docker-credential-gcr_linux_amd64-2.1.0.tar.gz \
    | tar xz --to-stdout docker-credential-gcr > /usr/bin/docker-credential-gcr \
    && chmod +x /usr/bin/docker-credential-gcr \
    && /usr/bin/docker-credential-gcr configure-docker --registries=us.gcr.io \
    && /usr/bin/docker-credential-gcr configure-docker --registries=us-central1-docker.pkg.dev

# Install google-cloud-logging and fluent-logger
RUN yum install -y git && pip3 install --upgrade pip \
    && cd /tmp && git clone -b v3.0.0 https://github.com/googleapis/python-logging.git \
    && pip3 install python-logging/ && rm -rf python-logging \
    && pip3 install fluent-logger \
    && pip3 install python-logstash

# Install python stomp and unzip
RUN yum install -y unzip
RUN pip3 install stomp.py

CMD ["/bin/bash"]
