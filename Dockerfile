FROM ubuntu

COPY myCA.pem /myCA.pem
COPY insert-ca.sh /usr/sbin/

CMD insert-ca.sh
