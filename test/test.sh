#!/bin/bash

cd $(dirname $BASH_SOURCE)
BT_config=./test.cfg
source ../bt.sh "$@" --download --build --module --cleanup

function build()
{
	cd ${BT_src_dir}
    if [ -z ${cgalDIR} ]; then
        ./configure --prefix=${BT_install_dir}
    else
            echo "[i] building using cgal at ${cgalDIR}"
        ./configure --prefix=${BT_install_dir} --enable-cgal --with-cgaldir=${cgalDIR} LDFLAGS=-Wl,-rpath,${boostDIR}/lib CXXFLAGS=-I${boostDIR}/include CPPFLAGS=-I${boostDIR}/include
    fi
    [ ${BT_clean} ] && make clean
    make -j $(n_cores)
    make install
}
exec_build_tool
