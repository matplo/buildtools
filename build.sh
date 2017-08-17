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
	echo "[i] usage: $(basename $BASH_SOURCE) --config <config_file> [--clean] [--version] [--build] [--rebuild] [--module] [--help] [--dry]"
	list_options "[i] set/defined options are:"
	exit 1
}

function check_config_present()
{
	[ -z ${BT_config} ] && echo "[e] no config file specified."  && usage && exit 1
	[ ! -f "${BT_config}" ] && echo "[e] config file ${BT_config} not found."  && usage && exit 1
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
	# echo $(env | grep "BT_" | sed 's|\n|,|g' | sed 's|BT_||g')
	echo ${_list}
}

function process_modules()
{
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

function download()
{
	if [ $(bool ${BT_download}) ]; then
		savedir=$PWD
		separator
		echo "[i] download..."
		env | grep BT_working_dir
		[ -z "${BT_working_dir}" ] && echo " - [error] working_dir not specified [${BT_working_dir}]" && exit 1
		[ ! -d "${BT_working_dir}" ] && echo " - [error] workingdir not a directory [${BT_working_dir}]" && exit 1
		env | grep BT_local_file
		[ -z "${BT_local_file}" ] && echo " - [error] local_file not specified [${BT_local_file}]" && exit 1
		env | grep BT_remote_file
		[ -z "${BT_remote_file}" ] && echo " - [error] remote file not specified [${BT_remote_file}]" && exit 1
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
		separator
		cd $savedir
	fi
}

this_file_dir=$(thisdir)
this_dir=$(abspath $this_file_dir)
up_dir=$(dirname $this_dir)
buildtools_dir=$(thisdir)

process_options version clean build rebuild module config help dry download working_dir force
[ $(bool ${BT_help}) ] && usage
check_config_present
process_options_config
read_config_options
reprocess_defined_options ${BT_config_options}

list_options

download
process_modules
