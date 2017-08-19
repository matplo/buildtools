#!/bin/bash

BT_name=fastjet
BT_version=3.3.0
BT_remote_file=http://fastjet.fr/repo/fastjet-${BT_version}.tar.gz
BT_module_paths=~/devel/hepsoft/modules
BT_modules="cgal cmake"
BT_install_dir=~/software/${BT_name}/${BT_version}
BT_module_dir=~/software/${BT_name}/modules/${BT_name}

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
