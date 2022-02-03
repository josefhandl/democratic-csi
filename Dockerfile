FROM debian:10-slim AS build
#FROM --platform=$BUILDPLATFORM debian:10-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN echo "I am running build on $BUILDPLATFORM, building for $TARGETPLATFORM"

RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
        && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG=en_US.utf8
ENV NODE_VERSION=v12.22.6
#ENV NODE_VERSION=v14.15.1
ENV NODE_ENV=production

# install build deps
RUN apt-get update && apt-get install -y python make cmake gcc g++

# install node
RUN apt-get update && apt-get install -y wget xz-utils
ADD docker/node-installer.sh /usr/local/sbin
RUN chmod +x /usr/local/sbin/node-installer.sh && node-installer.sh
ENV PATH=/usr/local/lib/nodejs/bin:$PATH

# Run as a non-root user
RUN useradd --create-home csi \
        && mkdir /home/csi/app \
        && chown -R csi: /home/csi
WORKDIR /home/csi/app
USER csi

COPY package*.json ./
RUN npm install --grpc_node_binary_host_mirror=https://grpc-uds-binaries.s3-us-west-2.amazonaws.com/debian-buster
COPY --chown=csi:csi . .
RUN rm -rf docker


######################
# actual image
######################
FROM debian:10-slim
#FROM ubuntu:18.04

LABEL org.opencontainers.image.source https://github.com/democratic-csi/democratic-csi

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN echo "I am running on final $BUILDPLATFORM, building for $TARGETPLATFORM"

RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
        && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

ENV LANG=en_US.utf8
ENV NODE_ENV=production

# Workaround for https://github.com/nodejs/node/issues/37219
RUN test $(uname -m) != armv7l || ( \
                apt-get update \
                && apt-get install -y libatomic1 \
                && rm -rf /var/lib/apt/lists/* \
        )

# install node
#ENV PATH=/usr/local/lib/nodejs/bin:$PATH
#COPY --from=build /usr/local/lib/nodejs /usr/local/lib/nodejs
COPY --from=build /usr/local/lib/nodejs/bin/node /usr/local/bin/node

# node service requirements
# netbase is required by rpcbind/rpcinfo to work properly
# /etc/{services,rpc} are required
RUN apt-get update && \
        apt-get install -y netbase socat e2fsprogs xfsprogs fatresize dosfstools nfs-common cifs-utils sudo curl gcc
#        apt-get install -y netbase socat e2fsprogs xfsprogs fatresize dosfstools nfs-common cifs-utils sudo make git cmake ninja-build build-essential libfuse-dev software-properties-common
#RUN add-apt-repository -y ppa:onedata/build-deps-2002
#RUN apt-get install -y  autoconf bash-completion bc build-essential ccache cmake curl debhelper devscripts doxygen erlang fuse g++ gdb git glusterfs-common golang-go iputils-ping jekyll lcov libacl1 libacl1-dev libboost-all-dev  libcurl4 libcurl4-openssl-dev libdouble-conversion1 libfmt-dev libfuse-dev libgflags-dev libgflags2.2 libgoogle-glog-dev libgoogle-glog0v5 libgoogle-perftools-dev libgoogle-perftools4 libiberty-dev libjemalloc-dev libltdl-dev libnspr4 libnspr4-dev libnss3 libnss3-dev  libprotobuf-dev librados-dev librados2 libradosstriper-dev libradosstriper1 libsodium-dev libsodium23 libspdlog-dev libstdc++-7-dev libtbb-dev libtbb2 libunwind-dev libunwind8 locales nano nfs-common ninja-build nodejs openssl pkg-config protobuf-compiler  python python-dev python-pip python-protobuf python-rados python-sphinx python-xattr python2.7-dev python3 python3-dev unzip uuid uuid-dev
#RUN apt-get install -y  autoconf aws-c-common aws-c-event-stream aws-checksums aws-sdk-cpp-s3 bash-completion bc build-essential ccache cmake curl debhelper devscripts doxygen erlang folly folly-dev fuse g++ gdb git glusterfs-common glusterfs-dbg golang-go iputils-ping jekyll lcov libacl1 libacl1-dev libboost-all-dev libboost-context1.65.1 libboost-filesystem1.65.1 libboost-iostreams1.65.1 libboost-log1.65.1 libboost-program-options1.65.1 libboost-python1.65.1 libboost-random1.65.1 libboost-system1.65.1 libboost-thread1.65.1 libbotan1.10 libbotan1.10-dev libcurl4 libcurl4-openssl-dev libdouble-conversion1 libfmt-dev libfuse-dev libgflags-dev libgflags2.2 libgoogle-glog-dev libgoogle-glog0v5 libgoogle-perftools-dev libgoogle-perftools4 libiberty-dev libjemalloc-dev libjemalloc1 libltdl-dev libnspr4 libnspr4-dev libnss3 libnss3-dev libpoco-dev libpocofoundation50 libpoconetssl50 libpocoutil50 libpocoxml50 libprotobuf-dev libprotobuf10 librados-dev librados2 libradosstriper-dev libradosstriper1 libsodium-dev libsodium23 libspdlog-dev libstdc++-7-dev libtbb-dev libtbb2 libunwind-dev libunwind8 locales nano nfs-common ninja-build nodejs openssl pkg-config protobuf-compiler proxygen-dev python python-dev python-pip python-protobuf python-rados python-sphinx python-xattr python2.7-dev python3 python3-dev swift-sdk-cpp unzip uuid uuid-dev wangle-dev
#RUN apt install -y glusterfs-common folly libxrootd-client-dev xrootd-plugins xrootd-client-plugins fuse3 libunwind8
RUN rm -rf /var/lib/apt/lists/*
# TODO make dat pryc

# controller requirements
#RUN apt-get update && \
#        apt-get install -y ansible && \
#        rm -rf /var/lib/apt/lists/*

# install wrappers
ADD docker/iscsiadm /usr/local/sbin
RUN chmod +x /usr/local/sbin/iscsiadm

ADD docker/multipath /usr/local/sbin
RUN chmod +x /usr/local/sbin/multipath


#ENV ONEDATA_GIT_URL=https://github.com/onedata REBAR_PROFILE="bamboo"
#RUN git clone https://github.com/onedata/oneclient.git && cd oneclient && git checkout release/20.02.15 && git pull
#RUN gem install coveralls-lcov
#RUN pip install six==1.12.0 dnspython Flask Flask-SQLAlchemy pytest==2.9.1 pytest-bdd==2.18.0 requests==2.5.1 boto boto3 rpyc==4.0.2 PyYAML xattr
#RUN curl -L https://github.com/erlang/rebar3/releases/download/3.11.1/rebar3 -o /usr/local/bin/rebar3 && chmod +x /usr/local/bin/rebar3
#RUN git config --global url."https://github.com/onedata".insteadOf "ssh://git@git.onedata.org:7999/vfs"
#WORKDIR /oneclient
#RUN make submodules
#RUN cmake --configure -GNinja -DCMAKE_BUILD_TYPE=Release -DCODE_COVERAGE=ON -DWITH_CEPH=ON -DWITH_SWIFT=ON -DWITH_S3=ON -DWITH_GLUSTERFS=ON -DWITH_WEBDAV=ON -DWITH_XROOTD=OFF -DWITH_ONEDATAFS=ON ..
#RUN ls -la /oneclient/
#RUN mkdir /oneclient/release
#RUN cd oneclient && \
#    cmake --build release



#RUN cd oneclient && mkdir -p debug && \
#    export PKG_REVISION=$(git describe --tags --always --abbrev=7) && \
#    export PKG_COMMIT=$(git rev-parse --verify HEAD) && \
#    export HELPERS_COMMIT=$(git -C helpers rev-parse --verify HEAD) && \
#    cd debug && \
#    cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DGIT_VERSION="$PKG_REVISION" -DGIT_COMMIT="$PKG_COMMIT" -DGIT_HELPERS_COMMIT="$HELPERS_COMMIT" -DCODE_COVERAGE=ON -DWITH_CEPH=ON -DWITH_SWIFT=ON -DWITH_S3=ON -DWITH_GLUSTERFS=ON -DWITH_WEBDAV=ON -DWITH_XROOTD=OFF -DWITH_ONEDATAFS=ON .. && \
#    cd .. && \
#    cmake --build debug && \
#    cmake --build debug --target test && \
#    py.test --verbose debug/test/integration/events_test && \
#    make coverage/events_test && \
#    py.test --verbose debug/test/integration/fslogic_test && \
#    make coverage/fslogic_test && \
#    make coverage_integration && \
#    coveralls-lcov ./oneclient_integration_combined.info


# Install oneclient (OneData client)
#RUN curl -sS  http://get.onedata.org/oneclient.sh | bash

ADD onedata/oneclient.sh /tmp/ 
ADD onedata/onedata.gpg.key /tmp/
RUN bash /tmp/oneclient.sh
ADD onedata/mount.onedata /sbin/mount.onedata
RUN chmod +x /sbin/mount.onedata

ADD oneclient-wrapper.c /
RUN gcc /oneclient-wrapper.c -o /oneclient-wrapper

## USE_HOST_MOUNT_TOOLS=1
ADD docker/umount /usr/local/bin/umount
RUN chmod +x /usr/local/bin/umount

# Run as a non-root user
RUN useradd --create-home csi \
        && chown -R csi: /home/csi

COPY --from=build --chown=csi:csi /home/csi/app /home/csi/app

WORKDIR /home/csi/app

RUN mkdir /mnt/onedata
#RUN chown csi:csi /mnt/onedata
#USER csi

EXPOSE 50051
#ENTRYPOINT ["sleep", "9999"]
ENTRYPOINT [ "bin/democratic-csi" ]
