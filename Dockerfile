FROM kamailio/kamailio-ci:5.3

COPY conf/kamailio.cfg /etc/kamailio/
COPY certs /etc/kamailio
