FROM debian:testing

ADD rdma-core.tar.gz /
ADD perftest.tar.gz /

RUN apt-get update && \
  apt-get install -f -y build-essential cmake gcc libudev-dev libnl-3-dev \
  libnl-route-3-dev pkg-config cython3 \
  autoconf libtool-bin git pandoc python-docutils gfortran libgfortran5 && \
  useradd -m user && \
  cd /rdma-core && mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr .. && make -j $(nproc) && make install && \
    make -j $(nproc) && make install && \
  cd /perftest && ./autogen.sh && ./configure && make && make install && \
  apt purge -y autoconf libtool-bin git pandoc python-docutils \
    cmake gcc pkg-config && \
  apt autoremove -y && apt-get clean -y && apt-get autoclean -y && \
  rm -rf /perftest /rdma-core && \
  echo 'user:user' | chpasswd

USER user

