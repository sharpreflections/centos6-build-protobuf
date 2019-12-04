FROM centos:6 AS base
LABEL maintainer="dennis.brendel@sharpreflections.com"

RUN yum -y upgrade && \
    yum -y install @development && \
    yum clean all


ARG gmp=gmp-4.3.2
ARG mpfr=mpfr-2.4.2
ARG mpc=mpc-1.0.1
ARG isl=isl-0.14.1
ARG cloog=cloog-0.18.4
ARG gcc=gcc-4.8.5

ARG install_dir=/opt

WORKDIR /build/

FROM base AS build-gcc
# This is very slow, but should work always
#RUN svn co svn://gcc.gnu.org/svn/gcc/tags/gcc_4_8_5_release gcc && \
RUN echo "Downloading $gcc:   " && curl --remote-name --progress-bar https://ftp.gnu.org/gnu/gcc/$gcc/$gcc.tar.bz2 && \
    echo "Downloading $gmp:   " && curl --remote-name --progress-bar https://ftp.gnu.org/gnu/gmp/$gmp.tar.bz2      && \
    echo "Downloading $mpfr:  " && curl --remote-name --progress-bar https://ftp.gnu.org/gnu/mpfr/$mpfr.tar.xz     && \
    echo "Downloading $mpc:   " && curl --remote-name --progress-bar https://ftp.gnu.org/gnu/mpc/$mpc.tar.gz       && \
    echo "Downloading $isl:   " && curl --remote-name --progress-bar http://isl.gforge.inria.fr/$isl.tar.xz        && \
    # see https://repo.or.cz/w/cloog.git
    echo "Downloading $cloog: " && curl --remote-name --progress-bar http://www.bastoul.net/cloog/pages/download/$cloog.tar.gz && \
    echo -n "Extracting $gcc..   " && tar xf $gcc.tar.bz2  && echo " done" && \
    echo -n "Extracting $gmp..   " && tar xf $gmp.tar.bz2  && mv $gmp   $gcc/gmp   && echo " done" && \
    echo -n "Extracting $mpfr..  " && tar xf $mpfr.tar.xz  && mv $mpfr  $gcc/mpfr  && echo " done" && \
    echo -n "Extracting $mpc..   " && tar xf $mpc.tar.gz   && mv $mpc   $gcc/mpc   && echo " done" && \
    echo -n "Extracting $isl..   " && tar xf $isl.tar.xz   && mv $isl   $gcc/isl   && echo " done" && \
    echo -n "Extracting $cloog.. " && tar xf $cloog.tar.gz && mv $cloog $gcc/cloog && echo " done" && \
    mkdir build && cd build && \
    ../$gcc/configure --prefix=$install_dir/$gcc \
                      --disable-multilib \
                      --enable-languages=c,c++,fortran && \
    make -j $(( $(nproc --all) / 2 )) && \
    make install && \
    rm -rf /build/*

FROM base AS production
COPY --from=build-gcc $install_dir $install_dir
# it's empty by default
ENV LD_LIBRARY_PATH=$install_dir/$gcc/bin:
# PSPro build dependencies                                                                                             
RUN yum -y install libX11-devel libSM-devel libxml2-devel libGL-devel libGLU-devel libibverbs-devel && \
    # Requirements for using software collections
    yum -y install yum-utils centos-release-scl.noarch && \
    # install the software collections
    yum -y install git19 sclo-git25 rh-git29 sclo-git212 sclo-subversion19 && \
    # Misc developer tools
    yum -y install curl strace valgrind subversion bc && \
    yum clean all
