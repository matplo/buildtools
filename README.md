# buildtools
generic all-in-bash (+basic utils use) scripts to assist building any package (linux/darwin)

# how to use this:

## option 1
 - implement a function build() & execute do_build in a script; you will need a config file... (see below)
 - within build() rely on $BT variables
 - the simplest implementation - a bash script (note: it could have been made shorter...)

```bash
#!/bin/bash
cd $(dirname $BASH_SOURCE)
# cp -v ~/devel/buildtools/bt.sh .
[ ! -f ./bt.sh ] && wget https://raw.github.com/matplo/buildtools/master/bt.sh
[ ! -f ./bt.sh ] && echo "[i] no bt.sh - stop here." && exit 1
BT_config=./tmp.cfg
echo "clean=yes" > $BT_config
echo "cleanup=yes" >> $BT_config
echo "ignore_errors=yes" >> $BT_config
source bt.sh "$@" --build
function build()
{
	separator "cmake/make/other commands here"
	list_options "[i] defined settings:" noundef
}
exec_build_tool
```

## option 2
 - implement a function build() within a script and define some env variables there in
 - then call bt.sh with BT_script=<script.sh>

```bash
$ ./bt.sh BT_script=build_fastjet_script.sh --build --download --module --cleanup
```

- note the --download is needed but the download will `wget` only once unless --force is given or BT_force set
- the build_fastjet_script.sh is below

```bash
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
    if [ -z ${CGALDIR} ]; then
        ./configure --prefix=${BT_install_dir}
    else
            echo "[i] building using cgal at ${CGALDIR}"
        ./configure --prefix=${BT_install_dir} --enable-cgal --with-cgaldir=${CGALDIR} LDFLAGS=-Wl,-rpath,${BOOSTDIR}/lib CXXFLAGS=-I${BOOSTDIR}/include CPPFLAGS=-I${BOOSTDIR}/include
    fi
    [ ${BT_clean} ] && make clean
    make -j $(n_cores)
    make install
}
```
