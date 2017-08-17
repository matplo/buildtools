#!/bin/bash

global_args="$@"

function abspath()
{
	case "${1}" in
		[./]*)
		echo "$(cd ${1%/*}; pwd)/${1##*/}"
		;;
		*)
		echo "${PWD}/${1}"
		;;
	esac
}

function thisdir()
{
	THISFILE=`abspath $BASH_SOURCE`
	XDIR=`dirname $THISFILE`
	if [ -L ${THISFILE} ];
	then
		target=`readlink $THISFILE`
		XDIR=`dirname $target`
	fi

	THISDIR=$XDIR
	echo $THISDIR
}

function get_opt_with()
{
	local do_echo=
	local retval=
	for g in ${global_args}
	do
		if [ ! -z $do_echo ] ; then
			if [[ ${g:0:1} != "-" ]]; then
				retval=$g
			fi
			do_echo=
		fi
		if [ $g == $1 ]; then
			do_echo="yes"
		fi
	done
	echo $retval
}

function is_opt_set()
{
	local retval=
	for g in ${global_args}
	do
		if [[ ${g:0:1} != "-" ]]; then
			continue
		fi
		if [ $g == $1 ]; then
			retval="yes"
		fi
	done
	echo $retval
}

this_file_dir=$(thisdir)
this_dir=$(abspath $this_file_dir)
up_dir=$(dirname $this_dir)

function os_linux()
{
	_system=$(uname -a | cut -f 1 -d " ")
	if [ $_system == "Linux" ]; then
		echo "yes"
	else
		echo
	fi
}

function os_darwin()
{
	_system=$(uname -a | cut -f 1 -d " ")
	if [ $_system == "Darwin" ]; then
		echo "yes"
	else
		echo
	fi
}

function host_pdsf()
{
	_system=$(uname -n | cut -c 1-4)
	if [ $_system == "pdsf" ]; then
		echo "yes"
	else
		echo
	fi
}

function sedi()
{
	[ $(os_darwin) ] && sed -i "" -e $@
	[ $(os_linux)  ] && sed -i'' -e $@
}

function strip_root_dir()
{
	local _this_dir=$1
	echo $(echo $_this_dir | sed "s|${up_dir}||" | sed "s|/||")
}

function module_name()
{
	local _this_dir=$(abspath $1)
	#echo $(dirname $(echo $_this_dir | sed "s|${up_dir}||" | sed "s|/||" | sed "s|.||"))
	echo $(basename $(dirname $(echo ${_this_dir} | sed "s|${up_dir}||")))
}

function n_cores()
{
	local _ncores="1"
	[ $(os_darwin) ] && local _ncores=$(system_profiler SPHardwareDataType | grep "Number of Cores" | cut -f 2 -d ":" | sed 's| ||')
	[ $(os_linux) ] && local _ncores=$(lscpu | grep "CPU(s):" | head -n 1 | cut -f 2 -d ":" | sed 's| ||g')
	#[ ${_ncores} -gt "1" ] && retval=$(_ncores-1)
	echo ${_ncores}
}

function executable_from_path()
{
	# this thing does NOT like the aliases
	local _exec=$(which $1 | grep -v "alias" | cut -f 2)
	if [ ${_exec} ]; then
		echo ${_exec}
	else
		echo ""
	fi
}

function config_value()
{
	local _what=$1
	local _retval=""
	#"[error]querying-an-unset-config-setting:${_what}"
	local _config=${config_file}
	if [ ! -z ${_what} ]; then
		local _nlines=$(cat ${_config} | wc -l)
		_nlines=$((_nlines+1))
		for ln in $(seq 1 ${_nlines})
		do
			_line=$(head -n ${ln} ${_config} | tail -n 1)
			#_pack=$(echo ${_line} | grep ${_what} | cut -f 1 -d "=" | sed 's| ||g')
			#_val=$(echo ${_line} | grep ${_what} | grep -v ${_what}_deps | cut -f 2 -d "=" | sed 's| ||g')
			_pack=$(echo ${_line} | grep ${_what} | cut -f 1 -d "=" | sed 's/^ *//g' | sed 's/ *$//g')
			_val=$(echo ${_line} | grep ${_what} | grep -v ${_what}_deps | cut -f 2 -d "=" | sed 's/^ *//g' | sed 's/ *$//g' | tr -d '\n')
			[ "${_pack}" == "${_what}" ] && _retval=${_val}
		done
	fi
	echo ${_retval}
}

function process_options()
{
	echo "    this is process_options"
	local _opts="$@"
	if [[ $# -eq 0 ]]; then
		_opts=$(config_value options)
	fi
	rm -rf .tmp.sh
	for opt in ${_opts}
	do
		echo "$opt=$(get_opt_with --${opt})" >> .tmp.sh
	done
	source .tmp.sh
	rm -rf .tmp.sh
}

function process_variables()
{
	[ -z $1 ] && "[e] process_variables called w/o argument - should be: BASH_SOURCE"
	wdir=${hepsoft_dir}
	echo "[i] processing variables... working with $1"
	module_name=$(module_name $1)
	pdsf_modules=$(config_value ${module_name}_pdsf_modules)
	module_deps=$(config_value ${module_name}_deps)
	module_dir=${hepsoft_dir}/${module_name}
	has_pythonlib=$(config_value ${module_name}_pythonlib)
	do_clean=$(is_opt_set --clean)
	do_rebuild=$(is_opt_set --rebuild)
	do_build=$(is_opt_set --build)
	[ $do_rebuild ] && do_build=$do_rebuild
	do_make_module=$(is_opt_set --module)
	do_download=$(is_opt_set --download)
	version=$(get_opt_with --version)
	[ -z $version ] && version=$(config_value ${module_name})
	unpack_dir=${module_dir}/${module_name}-${version}
	build_dir=${module_dir}/build_${version}
	install_dir=${module_dir}/${version}
	local_file=${module_dir}/${module_name}-${version}.tar.gz
	#remote_file=$(config_value ${module_name}_http_dir)/${local_file}
	remote_dir=$(config_value ${module_name}_remote_dir)
	remote_file=$(config_value ${module_name}_remote_file)
	[ $(is_opt_set --all) ] && do_clean="yes" && do_build="yes" && do_make_module="yes" && do_download="yes"
	system_64_bit=$(uname -m | cut -f 2 -d "_" | grep 64)
}

function process_modules()
{
	module use ${hepsoft_dir}/modules
	if [ $(host_pdsf) ]; then
		if [ ! -z "${pdsf_modules}" ]; then
			echo "[i] pdsf_modules   : " $pdsf_modules
			module load ${pdsf_modules}
			(($?!=0)) && exit 1
		fi
	else
		if [ ! -z "${module_deps}" ]; then
			module load ${module_deps}
			(($?!=0)) && exit 1
		else
			echo "[i] no extra modules loaded"
		fi
	fi
	module list
}

function prep_build()
{
	if [ $do_download ]; then
		cd ${module_dir}
		rm ${local_file}
		wget ${remote_file} --no-check-certificate -O ${local_file}
		cd $wdir
	fi

	if [ -e ${local_file} ]; then
		local _local_dir=$(tar tfz ${local_file} --exclude '*/*' | head -n 1)
		[ -z ${_local_dir} ] && _local_dir=$(tar tfz ${local_file} | head -n 1 | cut -f 1 -d "/")
		[ ${_local_dir} == "." ] && echo "[e] bad _local_dir ${_local_dir}. stop." && exit 1
		[ -z ${_local_dir} ] && echo "[e] bad _local_dir EMPTY. stop." && exit 1
		unpack_dir=${module_dir}/${_local_dir}
		echo "[i] changed unpack_dir to ${unpack_dir}"
	else
		echo "[w] local file does not exist? ${local_file}"
	fi

	if [ $do_clean ]; then
		cd ${module_dir}
		if [ -d ${unpack_dir} ]; then
			echo "[i] cleaning ${unpack_dir}..."
			rm -rf ${unpack_dir}
		fi
		if [ -d ${build_dir} ]; then
			echo "[i] cleaning ${build_dir}..."
			rm -rf ${build_dir}
		fi
		echo "[i] done cleaning."
		cd $wdir
	fi

	if [ $do_build ]; then
		cd ${module_dir}
		mkdir -pv ${build_dir}
		cd $wdir
	fi
}

function exec_build()
{
	if [ $do_build ]; then
		echo "[i] building..."
		cd ${module_dir}
		[ ! -e ${local_file} ] && echo "[e] file ${local_file} does not exist" && exit 1
		if [ ! -d ${unpack_dir} ]; then
			echo "[i] unpacking..."
			tar zxvf $local_file 2>&1 > /dev/null
		fi
		[ ! -d ${unpack_dir} ] && echo "[e] dir ${unpack_dir} does not exist" && exit 1
		cd ${unpack_dir}
		if [ $do_clean ]; then
			rm -rf ${install_dir}
		else
			if [ ! $do_rebuild ]; then
				[ -e ${install_dir} ] && echo "[e] ${install_dir} exists. remove it before running --build or use --rebuild or --clean. stop." && exit 1
			fi
		fi
		build
		cd $wdir
	fi
}

function make_module()
{
	if [ $do_make_module ]; then
		echo "[i] preparing a module file for ${module_name}/${version} ..."
		if [ ! -z ${has_pythonlib} ]; then
			${hepsoft_dir}/bin/make_module_from_current.sh -p ${has_pythonlib} -d ${install_dir} -n ${module_name} -v ${version} -o ${hepsoft_dir}/modules ${module_has_pythonlib}
		else
			${hepsoft_dir}/bin/make_module_from_current.sh -d ${install_dir} -n ${module_name} -v ${version} -o ${hepsoft_dir}/modules ${module_has_pythonlib}
		fi
	fi
}

function echo_common_settings()
{
	echo "[i] module_name    : " $module_name
	echo "[i] version        : " $version
	echo "[i] module_dir     : " $module_dir
	echo "[i] module_deps    : " $module_deps
	echo "[i] pdsf_modules   : " $pdsf_modules
	echo "[i] remote_file    : " $remote_file
	echo "[i] local_file     : " $local_file
	echo "[i] unpack_dir     : " $unpack_dir
	echo "[i] build_dir      : " $build_dir
	echo "[i] install_dir    : " $install_dir
	echo "[i] has_pythonlib  : " $has_pythonlib
	echo "[i] do_download    : " $do_download
	echo "[i] do_clean       : " $do_clean
	echo "[i] do_rebuild     : " $do_rebuild
	echo "[i] do_build       : " $do_build
	echo "[i] do_make_module : " $do_make_module
	echo "[i] module deps    : " $module_deps
	echo "[i] w/ make use -j : " $(n_cores)
}
