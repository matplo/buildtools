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
	[ $(os_darwin) ] && sed -i "" -e ${global_args}
	[ $(os_linux)  ] && sed -i'' -e ${global_args}
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
	local _what="$1"
	local _retval=""
	#"[error]querying-an-unset-config-setting:${_what}"
	local _config=${BT_config}
	if [ ! -f ${_config} ]; then
		echo ${_retval}
	fi
	if [ ! -z ${_what} ]; then
		local _nlines=$(cat ${_config} | wc -l)
		_nlines=$((_nlines+1))
		for ln in $(seq 1 ${_nlines})
		do
			_line=$(head -n ${ln} ${_config} | tail -n 1)
			_pack=$(echo ${_line} | grep ${_what} | cut -f 1 -d "=" | sed 's/^ *//g' | sed 's/ *$//g')
			_val=$(echo ${_line} | grep ${_what} | cut -f 2 -d "=" | sed 's/^ *//g' | sed 's/ *$//g' | tr -d '\n')
			[ "${_pack}" == "${_what}" ] && _retval=${_val}
		done
	fi
	echo ${_retval}
}

function process_options()
{
	local _opts="$@"
	echo "[i] processing options: ${_opts}"
	[ -f .tmp.sh ] && rm -rf .tmp.sh
	touch .tmp.sh
	for opt in ${_opts}
	do
		if [ $(is_opt_set "--${opt}") ];
			then
				echo "export BT_$opt=yes" >> .tmp.sh
			else
				echo "export BT_UNDEFINED_$opt=" >> .tmp.sh
		fi
		if [ ! -z $(get_opt_with --${opt}) ]; then
			echo "export BT_$opt=$(get_opt_with --${opt})" >> .tmp.sh
		fi
	done
	source .tmp.sh
	rm -rf .tmp.sh
}

function reprocess_defined_options()
{
	local _opts="$@"
	echo "[i] re-processing defined options: ${_opts}"
	[ -f .tmp.sh ] && rm -rf .tmp.sh
	touch .tmp.sh
	for opt in ${_opts}
	do
		if [ ! -z $(get_opt_with --${opt}) ]; then
			echo "export BT_$opt=$(get_opt_with --${opt})" >> .tmp.sh
		fi
	done
	source .tmp.sh
	rm -rf .tmp.sh
}

function process_options_config()
{
	local _var="options"
	[ ! -z $1 ] && _var=$1
	local _opts=$(config_value ${_var})
	[ -f .tmp.sh ] && rm -rf .tmp.sh
	touch .tmp.sh
	for opt in ${_opts}
	do
		echo "export BT_$opt=$(get_opt_with --${opt})" >> .tmp.sh
		if [ -z "${BT_config_options}" ]; then
			export BT_config_options="${opt}"
		else
			export BT_config_options="${BT_config_options} ${opt}"
		fi
	done
	source .tmp.sh
	rm -rf .tmp.sh
}

function read_config_options()
{
	for o in ${BT_config_options}
	do
		export BT_${o}="$(config_value $o)"
	done
}

function usage()
{
	#echo "[i] usage: $(basename $BASH_SOURCE) --config <config_file> [--clean] [--version] [--build] [--rebuild] [--module] [--help] [--dry]"
	echo "[i] usage example: --config <config_file> --download --build"
	list_options "[i] set/defined options are:"
	do_exit
}

function check_config_present()
{
	[ -z ${BT_config} ] && echo "[e] no config file specified."  && usage && do_exit
	[ ! -f "${BT_config}" ] && echo "[e] config file ${BT_config} not found."  && usage && do_exit
}

function bool()
{
	[ -z "$1" ] && echo && return
	[ $1 == "yes" ] && echo "true"
	[ $1 == "no" ] && echo ""
}

function is_set()
{
	[ -z "$1" ] && echo "" && return
	[ "$1" == "no" ] && echo "" && return
	[ "$1" == "yes" ] && [ -z "$1" ] && echo "" && return
	echo "$1"
}

function list_options()
{
	local _list=$(env | grep "BT_")
	if [ -z "$1" ]; then
		echo "[i] options:"
	else
		echo $1
	fi
	for l in ${_list}
	do
		param=$(echo $l | grep "BT" | cut -f 1 -d "=")
		[ ! -z "$2" ] && param=$(echo $l | grep "BT" | grep -v UNDEFINED | cut -f 1 -d "=")
		if [ ! -z $param ]; then
			env | grep $param | sed 's|BT_||g' | sed 's|UNDEFINED_||g'
		fi
	done
}

function process_modules()
{
	separator
	for p in ${BT_module_paths}
	do
		local _path
		eval _path=$p
		echo "[i] adding module path: ${_path}"
		module use ${_path}
	done
	if [ ! -z "${BT_modules}" ]; then
		module load ${BT_modules}
	else
		echo "[i] no extra modules loaded"
	fi
	module list
}

function separator()
{
	echo
	echo "---------------"
	echo
}

function do_exit()
{
	cd $BT_save_dir
	exit 1
}

function download()
{
	if [ $(bool ${BT_download}) ]; then
		fix_download_paths
		savedir=$PWD
		cd ${BT_working_dir}
		separator
		echo "[i] download..."
		[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
		[ -z "${BT_working_dir}" ] && echo " - [error] working_dir not specified [${BT_working_dir}]" && do_exit
		[ ! -d "${BT_working_dir}" ] && echo " - [error] working_dir not a directory [${BT_working_dir}]" && do_exit
		[ $(bool ${BT_debug}) ] && env | grep BT_local_file
		[ -z "${BT_local_file}" ] && echo " - [error] local_file not specified [${BT_local_file}]" && do_exit
		[ $(bool ${BT_debug}) ] && env | grep BT_remote_file
		[ -z "${BT_remote_file}" ] && echo " - [error] remote file not specified [${BT_remote_file}]" && do_exit
		if [ -f "${BT_local_file}" ]; then
			if [ ${BT_force} ]; then
				[ -f "${BT_local_file}" ] && rm -fv ${BT_local_file}
				wget ${BT_remote_file} --no-check-certificate -O ${BT_local_file}
			else
				echo "[w] file ${BT_local_file} exists. no download - use --force to override."
			fi
		else
				wget ${BT_remote_file} --no-check-certificate -O ${BT_local_file}
		fi
		cd $savedir
	fi
	setup_src_dir
}

function setup_src_dir()
{
	if [ $(bool ${BT_download}) ]; then
		savedir=$PWD
		cd ${BT_working_dir}
		separator
		echo "[i] setup unpack_dir..."
		[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
		[ $(bool ${BT_debug}) ] && env | grep BT_local_file
		if [ -f "${BT_local_file}" ]; then
			local _local_dir=$(tar tfz ${BT_local_file} --exclude '*/*' | head -n 1)
			[ -z ${_local_dir} ] && _local_dir=$(tar tfz ${BT_local_file} | head -n 1 | cut -f 1 -d "/")
			[ ${_local_dir} == "." ] && echo "[e] bad _local_dir ${_local_dir}. stop." && do_exit
			[ -z ${_local_dir} ] && echo "[e] bad _local_dir EMPTY. stop." && do_exit
			export BT_src_dir=${BT_sources_dir}/${_local_dir}
			echo "[i] setup unpack_dir to ${BT_src_dir}"
		else
			if [ -z "${BT_src_dir}" ]; then
				echo "[w] local file does not exist? ${local_file}"
				export BT_src_dir=${BT_working_dir}/${BT_module}_${BT_version}
			fi
			[ $(bool ${BT_debug}) ] && env | grep BT_src_dir
		fi
		cd $savedir
	fi
}

function fix_working_paths()
{
	[ -z "${BT_working_dir}" ] && export BT_working_dir=$PWD/working_dir
	export BT_working_dir=$(abspath $BT_working_dir)
	[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
	[ ! -d "${BT_working_dir}" ] && mkdir -pv $BT_working_dir
	[ ! -d "${BT_working_dir}" ] && echo " - [error] working_dir not a directory [${BT_working_dir}]" && do_exit
}

function fix_install_paths()
{
	[ -z "$BT_install_dir" ] && export BT_install_dir=$PWD/${BT_module}/${BT_version}
	eval BT_install_dir=$BT_install_dir/${BT_module}/${BT_version}
	export BT_install_dir
	[ $(bool ${BT_debug}) ] && env | grep BT_install_dir
}

function fix_download_paths()
{
	fix_working_paths
	[ -z "${BT_local_file}" ] && export BT_local_file="$BT_working_dir/downloads/$BT_module.download"
	BT_download_dir=$(dirname $BT_local_file)
	[ ! -d ${BT_download_dir} ] && echo "[warning] making directory for download file ${BT_download_dir}"
	mkdir -pv ${BT_download_dir}
	export BT_download_dir=$BT_download_dir
	[ ! -d "${BT_download_dir}" ] && echo "[error] download directory is not a dir ${BT_download_dir}" && do_exit
	[ ! -z "${BT_local_file}" ] && export BT_local_file=$(abspath $BT_local_file)
	export BT_download_dir=$(abspath $BT_download_dir)
	[ $(bool ${BT_debug}) ] && env | grep BT_download_dir
}

function fix_sources_paths()
{
	if [ ! -z "${BT_src_dir}" ]; then
		eval BT_src_dir=$BT_src_dir
		export BT_src_dir
		[ $(bool ${BT_debug}) ] && env | grep BT_src_dir
	else
		fix_working_paths
		[ -z "${BT_sources_dir}" ] && export BT_sources_dir=${BT_working_dir}/src
		[ ! -d ${BT_sources_dir} ] && echo "[warning] making directory for sources ${BT_sources_dir}"
		mkdir -pv ${BT_sources_dir}
		[ ! -d "${BT_sources_dir}" ] && echo "[error] build directory is not a dir ${BT_sources_dir}" && do_exit
		[ $(bool ${BT_debug}) ] && env | grep BT_sources_dir
	fi
}

function fix_build_paths()
{
	fix_working_paths
	[ -z "${BT_build_dir}" ] && export BT_build_dir=$BT_working_dir/build/$BT_version
	[ ! -d ${BT_build_dir} ] && echo "[warning] making directory for building ${BT_build_dir}"
	mkdir -pv ${BT_build_dir}
	export BT_build_dir=$BT_build_dir
	[ ! -d "${BT_build_dir}" ] && echo "[error] build directory is not a dir ${BT_build_dir}" && do_exit
	[ $(bool ${BT_debug}) ] && env | grep BT_build_dir
}

function setup_sources()
{
	fix_sources_paths
	download
}

function build()
{
	echo "[i] call to specific tool here..."
}

function init_build_tools()
{
	export BT_save_dir=$PWD
	export BT_config_dir=$(dirname $(abspath ${BT_config}))
	export BT_now=$(date +%Y-%m-%d_%H_%M_%S)

	# this_file_dir=$(thisdir)
	# this_dir=$(abspath $this_file_dir)
	# up_dir=$(dirname $this_dir)
	# buildtools_dir=$(thisdir)

	process_options version clean build rebuild module config help dry download working_dir force debug verbose
	[ $(bool ${BT_help}) ] && usage
	check_config_present
	process_options_config
	read_config_options
	reprocess_defined_options ${BT_config_options}
	[ ! -z ${BT_rebuild} ] && export BT_clear=yes && export BT_rebuild=yes

	[ -z "${BT_version}" ] && echo "[w] unspecified version - setting as now $BT_now" && export BT_version=$BT_now
	[ $(bool ${BT_debug}) ] && env | grep BT_version=
	[ -z "${BT_module}" ] && echo "[w] guessing module name from $PWD" && export BT_module=$(basename $PWD)
	[ $(bool ${BT_debug}) ] && env | grep BT_module=

	fix_paths
	if [ $(bool ${BT_clean}) ]; then
		separator
		fix_install_paths
		fix_build_paths
		echo "[i] removing ${BT_install_dir}"
		rm -rf ${BT_install_dir}
		echo "[i] removing ${BT_build_dir}"
		rm -rf ${BT_build_dir}
		echo "[i] removing ${BT_working_dir}"
		rm -rf ${BT_working_dir}
	fi
	setup_sources
	process_modules
	separator
	list_options "[i] defined settings:" noundef
}

function run_build()
{
	init_build_tools

	if [ $(bool ${BT_build}) ]; then
		separator
		fix_install_paths
		fix_build_paths
		echo "[i] building..."
		savedir=$PWD
		cd ${BT_sources_dir}
		if [ ! -d "${BT_src_dir}" ]; then
			echo "[i] unpacking..."
			[ ! -e ${BT_local_file} ] && echo "[e] file ${BT_local_file} does not exist" && do_exit
			tar zxvf ${BT_local_file} 2>&1 > /dev/null
		fi
		[ ! -d "${BT_src_dir}" ] && echo "[e] dir "${BT_src_dir}" does not exist" && do_exit
		cd "${BT_build_dir}"
		# if [ ! $(bool ${BT_rebuild}) ]; then
		# 	[ -e ${BT_install_dir} ] && echo "[e] ${BT_install_dir} exists. remove it before running --build or use --rebuild or --clean --build. stop." && do_exit
		# fi
		build
		cd $savedir
	fi
}

# implement function build & execute run_build
# run_build
