FROM debian:bullseye-slim

RUN apt-get update
RUN apt-get install -y build-essential git libsqlite3-dev

# v
WORKDIR /root
RUN git clone https://github.com/vlang/v.git
WORKDIR /root/v
RUN make

# starsd
WORKDIR /root
COPY starsd starsd
WORKDIR /root/starsd
RUN ../v/v install edam.ggetopt
RUN ../v/v .
RUN cp starsd /usr/bin

# cleanup
WORKDIR /root
CMD rm -rf /root/v /root/starsd

# run
EXPOSE 80
WORKDIR /root
ENTRYPOINT /usr/bin/starsd --db=pgsql --host=$DB_HOST --user=$DB_USER --pass=$DB_PASS
