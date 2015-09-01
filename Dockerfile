

FROM phusion/baseimage

RUN apt-get update && apt-get install -y python

RUN rm -f /etc/service/sshd/down
RUN mkdir -p /root/.ssh

ADD key.pub /root/.ssh/authorized_keys
RUN chmod 0600 /root/.ssh/authorized_keys
