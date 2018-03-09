FROM debian:stretch

# feel free to change this ;)
LABEL maintainer "Alphayax <alphayax@gmail.com>"

# properly setup debian sources
ENV DEBIAN_FRONTEND noninteractive

# Default configuration
ENV PUBLICHOST localhost
ENV MAX_CLIENTS 50
ENV MAX_CLIENT_PER_IP 50
ENV PASSIVE_PORT_RANGE_START 30000
ENV PASSIVE_PORT_RANGE_END 30009


RUN echo "deb http://http.debian.net/debian stretch main\n\
deb-src http://http.debian.net/debian stretch main\n\
deb http://http.debian.net/debian stretch-updates main\n\
deb-src http://http.debian.net/debian stretch-updates main\n\
deb http://security.debian.org stretch/updates main\n\
deb-src http://security.debian.org stretch/updates main\n\
" > /etc/apt/sources.list

# install package building helpers
# rsyslog for logging (ref https://github.com/stilliard/docker-pure-ftpd/issues/17)
RUN apt-get -y update 							\
 && apt-get -y --force-yes --fix-missing install dpkg-dev debhelper 	\
 && apt-get -y build-dep pure-ftpd 					\
 && apt-get -y install openbsd-inetd rsyslog

# build from source to add --without-capabilities flag
RUN mkdir /tmp/pure-ftpd/ 						\
 && cd /tmp/pure-ftpd/ 							\
 && apt-get source pure-ftpd 						\
 && cd pure-ftpd-* 							\
 && ./configure --with-tls 						\
 && sed -i '/^optflags=/ s/$/ --without-capabilities/g' ./debian/rules 	\
 && dpkg-buildpackage -b -uc

# install the new deb files
RUN dpkg -i /tmp/pure-ftpd/pure-ftpd-common*.deb 			\
 && dpkg -i /tmp/pure-ftpd/pure-ftpd_*.deb

# Prevent pure-ftpd upgrading
RUN apt-mark hold pure-ftpd pure-ftpd-common

# setup ftpgroup and ftpuser
RUN groupadd ftpgroup 							\
 && useradd -g ftpgroup -d /home/ftpusers -s /dev/null ftpuser

# configure rsyslog logging
RUN echo "" 				>> /etc/rsyslog.conf 		\
 && echo "#PureFTP Custom Logging" 	>> /etc/rsyslog.conf 		\
 && echo "ftp.* /dev/stdout" 		>> /etc/rsyslog.conf		\
 && echo "Updated /etc/rsyslog.conf with /dev/stdout"

# setup run/init file
COPY run.sh /run.sh
RUN chmod u+x /run.sh

# couple available volumes you may want to use
VOLUME ["/home/ftpusers", "/etc/pure-ftpd/passwd"]

# startup
CMD /run.sh -l puredb:/etc/pure-ftpd/pureftpd.pdb -E -j -R 

EXPOSE 20 21 30000-30009

