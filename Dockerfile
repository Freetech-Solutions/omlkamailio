FROM omnileads/kamailio:230204.01 as run

COPY source/* /etc/kamailio/
