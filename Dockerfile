FROM centos:6 AS base
LABEL maintainer="dennis.brendel@sharpreflections.com"

ARG gmp=gmp-4.3.2
ARG mpfr=mpfr-2.4.2
ARG mpc=mpc-1.0.1
ARG isl=isl-0.14.1
ARG cloog=cloog-0.18.4
ARG gcc=gcc-4.8.5

ARG prefix=/opt

WORKDIR /build/


FROM base AS build-base
RUN yum -y upgrade && \
    yum -y install @development && \
    yum clean all


FROM build-base as build-binutils
RUN yum -y install bc bison cvs dejagnu expect flex gettext glibc-static libgomp m4 sharutils tcl texinfo zlib-devel zlib-static && \
    curl --remote-name https://kojipkgs.fedoraproject.org//packages/binutils/2.25.1/9.fc24/src/binutils-2.25.1-9.fc24.src.rpm && \
    rpm -i binutils-2.25.1-9.fc24.src.rpm && \
    rm -f binutils-2.25.1-9.fc24.src.rpm &&  \
    cd /root/rpmbuild/ && \
    sed -i 's/libstdc++-static/libstdc++/' SPECS/binutils.spec && \
    rpmbuild -bb SPECS/binutils.spec && \
    rm -rf SPECS SOURCES BUILD BUILDROOT


FROM build-base as build
COPY --from=build-binutils /root/rpmbuild/RPMS/x86_64/binutils-2.25.1-9.el6.x86_64.rpm /tmp/
RUN yum -y install /tmp/binutils-2.25.1-9.el6.x86_64.rpm && \
    yum clean all && \
    rm /tmp/binutils-2.25.1-9.el6.x86_64.rpm


FROM build AS build-gcc
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
    ../$gcc/configure --prefix=$prefix/$gcc \
                      --disable-multilib \
                      --enable-languages=c,c++,fortran && \
    make --quiet --jobs=$(nproc --all) && \
    make install && \
    rm -rf /build/*


FROM base AS build-cmake
RUN echo "Downloading cmake 3.1.3: " && curl --remote-name --progress-bar https://cmake.org/files/v3.1/cmake-3.1.3-Linux-x86_64.tar.gz && \
    echo "Downloading cmake 3.5.2: " && curl --remote-name --progress-bar https://cmake.org/files/v3.5/cmake-3.5.2-Linux-x86_64.tar.gz && \
    echo "Downloading cmake 3.6.3: " && curl --remote-name --progress-bar https://cmake.org/files/v3.6/cmake-3.6.3-Linux-x86_64.tar.gz && \
    echo "Downloading cmake 3.10.3:" && curl --remote-name --progress-bar https://cmake.org/files/v3.10/cmake-3.10.3-Linux-x86_64.tar.gz && \
    echo "Downloading cmake 3.14.7:" && curl --remote-name --progress-bar https://cmake.org/files/v3.14/cmake-3.14.7-Linux-x86_64.tar.gz && \
    for file in *; do echo -n "Extracting $file: " && tar --directory=$prefix/ -xf $file && echo "done"; done && \
    # strip the dir name suffix '-Linux-x86_64' from each cmake installation
    for dir in $prefix/*; do mv $dir ${dir%-Linux-x86_64}; done && \
    rm -rf /build/*


FROM base AS build-qt5-gcc
COPY --from=build-gcc   $prefix $prefix
COPY --from=build-cmake $prefix $prefix

ENV PATH=$prefix/$gcc/bin:$PATH
ENV LD_LIBRARY_PATH=$prefix/$gcc/lib64:$LD_LIBRARY_PATH
ENV CC=gcc
ENV CXX=g++

RUN yum -y install xz glibc-headers glibc-devel && yum clean all && \
    echo "Downlooading qt5: " && \
    curl --remote-name --location --progress-bar http://download.qt.io/official_releases/qt/5.9/5.9.8/single/qt-everywhere-opensource-src-5.9.8.tar.xz && \
    curl --remote-name --location --silent http://download.qt.io/official_releases/qt/5.9/5.9.8/single/md5sums.txt && \
    sed --in-place '/.*\.zip/d' md5sums.txt && \
    echo -n "Verifying file.." && md5sum --quiet --check md5sums.txt && echo " done" && \
    echo "Extracting qt5.. " && tar xf qt-everywhere-opensource-src-5.9.8.tar.xz && echo " done" && \
    cd qt-everywhere-opensource-src-5.9.8 && \
    sed --in-place "s:\(QMAKE_LFLAGS.*-m64\).*:\1 -Wl,-rpath,\\\'\\\\$\$ORIGIN\\\',--disable-new-dtags:" qtbase/mkspecs/linux-g++-64/qmake.conf && \
    sed --in-place 's/\(QMAKE_LFLAGS .*=\)/\1 -static-intel -Wl,--disable-new-dtags/' qtbase/mkspecs/linux-icc/qmake.conf && \
    sed --in-place "s/\(QMAKE_LFLAGS_SHLIB .*= -shared\).*/\1 -Wl,-rpath,\\\'\\\\$\$ORIGIN\\\'/" qtbase/mkspecs/linux-icc/qmake.conf && \
    ./configure --prefix=/opt/qt-5.9.8-gcc   \
                -opensource -confirm-license \
                -shared                      \
                -platform linux-gcc-64       \
                -qt-zlib                     \
                -qt-libjpeg                  \
                -qt-libpng                   \
                -nomake examples             \
                -no-rpath                    \
                -no-cups                     \
                -no-iconv                    \
                -no-dbus                     \
                -no-gtk                      \
                -no-glib                     \
                -no-opengl                && \
    [ -f "qtbase/src/corelib/QtCore.version" ] && rm qtbase/src/corelib/QtCore.version && \
    gmake -j $(nprocs) && gmake install


FROM build AS production
COPY --from=build-gcc   $prefix $prefix
COPY --from=build-cmake $prefix $prefix
# it's empty by default
ENV LD_LIBRARY_PATH=$prefix/$gcc/bin:
# PSPro build dependencies                                                                                             
RUN yum -y install xorg-x11-server-utils libX11-devel libSM-devel libxml2-devel libGL-devel \
                   libGLU-devel libibverbs-devel freetype-devel && \
    # we need some basic fonts and manpath for the mklvars.sh script
    yum -y install urw-fonts man && \
    # Requirements for using software collections and epel
    yum -y install yum-utils centos-release-scl.noarch epel-release.noarch && \
    # install the software collections
    yum -y install git19 sclo-git25 rh-git29 sclo-git212 sclo-subversion19 devtoolset-8 && \
    # Misc developer tools
    yum -y install strace valgrind bc joe vim nano mc && \
    yum clean all

