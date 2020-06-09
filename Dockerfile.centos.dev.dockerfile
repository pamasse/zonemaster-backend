ARG IMAGE_NAME="cenots:latest"
FROM $IMAGE_NAME

ENV DEBIAN_FRONTEND noninteractive

# Install a couple dependencies + extra packages
RUN yum update --fix-missing -y && yum install -y \
    build-essential \
    curl \
    gcc \
    git \
    gpp \
    locales \
    libncurses5-dev \
    libreadline-dev \
    libssl-dev

# Set the locale
RUN echo "fr_FR.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen fr_FR.UTF-8 && \
    dpkg-reconfigure locales && \
    /usr/sbin/update-locale LANG=fr_FR.UTF-8
ENV LC_ALL fr_FR.UTF-8  

# From Zonemaster Engine installation instruction 
RUN yum install -y gettext libgettextpo-dev autoconf automake build-essential cpanminus libclone-perl libfile-sharedir-perl libfile-slurp-perl libidn11-dev libintl-perl libio-socket-inet6-perl libjson-pp-perl liblist-moreutils-perl liblocale-msgfmt-perl libmail-rfc822-address-perl libmodule-find-perl libnet-ip-perl libpod-coverage-perl libreadonly-perl libreadonly-xs-perl libssl-dev libtest-differences-perl libtest-exception-perl libtest-fatal-perl libtest-pod-perl libtext-csv-perl libtool m4

# From Zonemaster Backend installation instruction 
RUN yum install -y libclass-method-modifiers-perl libconfig-inifiles-perl libdbd-sqlite3-perl libdbi-perl libfile-sharedir-perl libfile-slurp-perl libhtml-parser-perl libio-captureoutput-perl libjson-pp-perl libjson-rpc-perl liblog-any-adapter-dispatch-perl liblog-any-perl liblog-dispatch-perl libplack-perl libplack-middleware-debug-perl librole-tiny-perl librouter-simple-perl libstring-shellquote-perl starman

# Zonemaster LDNS needs a newer version of Module::Install
RUN cpan install Module::Install Module::Install::XSUtil && \
    # Zonemaster Backend transitively needs a newer version of Devel::CheckLib
    cpan install Devel::CheckLib && \
    # Moose installed from OS packages depend on a newer version of Devel::OverloadInfo
    cpan install Devel::OverloadInfo Moose && \ 
    # IO::Socket::INET6 can't find Socket6 unless it's installed from CPAN
    cpan install Socket6

    # Install Zonemaster LDNS
    
RUN git clone --depth=1 --branch=develop https://github.com/zonemaster/zonemaster-ldns.git && \
    if [ "$IMAGE_NAME" = "cenots:8" ]; then \
        ( cd zonemaster-ldns && cpanm --verbose --notest . ) 
    else \
        ( cd zonemaster-ldns && cpanm --verbose --notest --configure-args="--no-ed25519" . ) fi; && \
    rm -rf zonemaster-ldns
    
    # Install Zonemaster Engine
RUN git clone --depth=1 --branch=develop https://github.com/zonemaster/zonemaster-engine.git && \
    ( cd zonemaster-engine && cpanm --verbose --notest . ) && rm -rf zonemaster-engine


ARG DB 
ARG ZONEMASTER_BACKEND_CONFIG_FILE

COPY . /app
WORKDIR app

#RUN if [ "$DB" = "postgres" ]; then \
ENV ZONEMASTER_BACKEND_CONFIG_FILE $ZONEMASTER_BACKEND_CONFIG_FILE
RUN yum install -y libpq-dev libdbd-pg-perl postgresql-client postgresql
RUN cpanm DBD::Pg && cpanm --installdeps .
RUN sed -i 's/peer/trust/' /etc/postgresql/*/main/pg_hba.conf && \
    service postgresql start && \
    psql -c "create user travis_zonemaster WITH PASSWORD 'travis_zonemaster';"  -U postgres && \
    psql -c 'create database travis_zonemaster OWNER travis_zonemaster;' -U postgres && \
    perl -I./lib ./script/create_db_postgresql_9.3.pl && \
    sed -i 's/peer/md5/' /etc/postgresql/*/main/pg_hba.conf 