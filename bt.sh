#!/bin/bash

# how to use this:
# implement a function build() & execute do_build
# within build() rely on $BT variables
# the simplest implementation
# #!/bin/bash
# cd $(dirname $BASH_SOURCE)
# # cp -v ~/devel/buildtools/bt.sh .
# [ ! -f ./bt.sh ] && wget https://raw.github.com/matplo/buildtools/master/bt.sh
# [ ! -f ./bt.sh ] && echo "[i] no bt.sh - stop here." && exit 1
# BT_config=./tmp.cfg
# echo "clean=yes" > $BT_config
# echo "cleanup=yes" >> $BT_config
# echo "ignore_errors=yes" >> $BT_config
# source bt.sh "$@" --build
# function build()
# {
# 	separator "cmake/make/other commands here"
# }
# exec_build_tool

BT_global_args="$@"
BT_built_in_options="build build_type clean cleanup config config_dir debug download dry force help ignore_errors install_dir install_prefix module module_dir module_paths modules name now rebuild remote_file script src_dir verbose version working_dir"
BT_error_code=1

function abspath()
{
	case "${1}" in
		[./]*)
		[ ! -d ${1%/*} ] && echo "${1}" && return
		echo "$(cd ${1%/*}; pwd)/${1##*/}"
		;;
		*)
		echo "${PWD}/${1}"
		;;
	esac
}

function thisdir()
{
	echo $BASH_SOURCE
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

function file_dir()
{
	THISFILE=`abspath $1`
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
	for g in ${BT_global_args}
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
	for g in ${BT_global_args}
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
	local _what="$1"
	local _retval=""
	#"[error]querying-an-unset-config-setting:${_what}"
	local _config=${BT_config}
	if [ -z ${BT_config} ]; then
		echo ${_retval}
		return
	fi
	if [ ! -f ${_config} ]; then
		echo ${_retval}
		return
	fi
	if [ ! -z ${_what} ]; then
		local _nlines=$(cat ${_config} | wc -l)
		_nlines=$((_nlines+1))
		for ln in $(seq 1 ${_nlines})
		do
			_line=$(head -n ${ln} ${_config} | tail -n 1)
			if [ ! -z "$(echo ${_line} | grep ${_what})" ]; then
				_pack=$(echo ${_line} | grep ${_what} | cut -f 1 -d "=" | sed 's/^ *//g' | sed 's/ *$//g')
				_val=$(echo ${_line} | grep ${_what} | cut -f 2 -d "=" | sed 's/^ *//g' | sed 's/ *$//g' | tr -d '\n')
				[ "${_pack}" == "${_what}" ] && _retval=${_val}
			fi
		done
	fi
	echo ${_retval}
}

function process_options()
{
	local _opts="$@"
	[ $(bool ${BT_debug}) ] && echo "[i] processing options: ${_opts}"
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
	[ $(bool ${BT_debug}) ] && echo "[i] re-processing defined options: ${_opts}"
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

function get_var_value()
{
	[ -f .tmp.sh ] && rm -rf .tmp.sh
	touch .tmp.sh
	echo "export BT_get_var_value_return=\$$1" >> .tmp.sh
	source .tmp.sh
	echo $BT_get_var_value_return
	BT_get_var_value_return=""
	#cp .tmp.sh peek.sh
	rm -rf .tmp.sh
}

function is_BT_set()
{
	local _var="$1"
	[ ${_var:0:3} != "BT_" ] && _var="BT_${1}"
	if [ -z ${_var+x} ]; then
		echo "${_var} is unset"
	else
		# echo "${_var} is set to ${_tmp}"
		echo "val="$(get_var_value ${_var})
	fi
}

function echo_padded_var()
{
	if [ "x{1}" != "x" ]; then
		echo $(padding "   [${1}] " "-" 20 right)" : "$(get_var_value ${1})
	else
		echo $(padding "   [${1}] " "-" 20 right)" : UNDEFINED"
	fi
}

function echo_padded_BT_var()
{
	local _defined=$(get_var_value BT_${1})
	if [ "${2}" == "all" ]; then
		echo $(padding "   [${1}] " "-" 20 right)" : "${_defined}
	else
		if [ "x${_defined}" != "x" ]; then
			echo $(padding "   [${1}] " "-" 20 right)" : "${_defined}
		fi
	fi
}

function read_config_options()
{
	local o=""
	for o in ${BT_config_options} ${BT_built_in_options}
	do
		local _defined=$(get_var_value BT_${o})
		# echo "[i] checking [${o}] defined ${_defined}"
		if [ -z ${_defined} ]; then
			export BT_${o}="$(config_value $o)"
			_defined=$(get_var_value BT_${o})
			if [ ! -z ${_defined} ]; then
				echo $(padding "   [${o}] " "-" 15 right)" : "${_defined}
			fi
		else
			echo $(padding "   [${o}] " "-" 15 right)" : "${_defined}
		fi
	done
}

function tokenize_string()
{
	local _delim=${2}
	local _s=${1}
	local _tlen=${#_delim}
	local _len=${#_s}
	local _n=0
	local _sublen=0
	local _marks=
	local _nmarks=0
	local _ret_array_name="_tokenize_string_array"
	[ ! -z ${3} ] && _ret_array_name=${3}
	local _escape_space=","
	[ ! -z ${4} ] && _escape_space=${4}
	for _pos in $(seq 0 ${_len})
	do
		local _c=${_s:${_pos}:${_tlen}}
		if [ "${_c}" == "${_delim}" ]; then
			_nmarks=$((_nmarks+1))
			_last_pos=${_pos}
			if [ -z "${_marks}" ]; then
				_marks="${_pos}"
			else
				_marks="${_marks} ${_pos}"
			fi
		fi
	done
	if [ ! -z "${_marks}" ]; then
		_nmarks=$((_nmarks+1))
		_marks="${_marks} ${_pos}"
	fi

	local _retval="local ${_ret_array_name}=("
	for n in $(seq 1 $((_nmarks+1)))
	do
		local _p0=$(echo ${_marks} | cut -f ${n} -d " ")
		local _p1=$(echo ${_marks} | cut -f $((n+1)) -d " ")
		[ -z "${_p1}" ] && break
		#echo '"${_s:${_p0}:$((_p1-_p0))}${_separator}"'
		if [ $n != "1" ]; then
			_retval="${_retval} "
		fi
		local _val=${_s:${_p0}:$((_p1-_p0))}
		_val=$(echo ${_val} | sed 's| |${_escape_space}|g')
		_retval="${_retval} '${_val}'"
	done
	_retval="${_retval})"
	echo ${_retval}
}

function get_last()
{
	for l in ${1}; do true; done;
	echo $l
}

function count_in_string()
{
	local _var=${1}
	local _needle=$(get_last "$@")
	echo ${_needle}
	[ -z ${_var} ] && echo -1 && return
	[ -z ${_needle} ] && echo -1 && return
	local _number_of_occurrences=$(echo ${_var} | grep -o ${_needle}| wc -l)
	echo "    counted ${_needle} ${_number_of_occurrences}"
}

function process_user_short_options()
{
	local _arr_name="_arr"
	local _escape_space=","
	_cstring=$(tokenize_string "${BT_global_args}" "--" ${_arr_name} ${_escape_space})
	eval ${_cstring}
	for o in ${_arr[@]}
	do
		if [ ${o:0:2} == "--" ]; then
			local _val=$(echo ${o} | cut -f 2 -d "=")
			[ "${#_val}" == "1" ] && [ ${_val} == "${o}" ] && _val=""
			local _name=$(echo ${o} | cut -f 1 -d "=")
			local _len="${#_name}"
			_name=${_name:2:${_len}}
			eval BT_${_name}=\"$(echo ${_val} | sed 's|${_escape_space}| |g')\"
			export BT_${_name}
		fi
	done
}

function usage()
{
	#echo "[i] usage: $(basename $BASH_SOURCE) --config <config_file> [--clean] [--version] [--build] [--rebuild] [--module] [--help] [--dry]"
	echo "[i] usage example: --config <config_file> --download --build"
	echo "    see more at: https://github.com/matplo/buildtools"
	process_user_short_options
	process_options "${BT_built_in_options}"
	export BT_help="yes"
	show_options all
	separator " . "
	do_exit 0
}

function check_config_present()
{
	[ -z ${BT_config} ] && echo "[error] no config file specified."  && usage && do_exit ${BT_error_code}
	[ ! -f "${BT_config}" ] && echo "[error] config file ${BT_config} not found."  && usage && do_exit ${BT_error_code}
}

function bool()
{
	[ -z "$1" ] && echo && return
	[ $1 == "yes" ] && echo "true"
	[ $1 == "no" ] && echo ""
}

function is_set()
{
	[ -z ${1+x} ] && echo "" && return
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

function module_exists()
{
	local _retval=$(module -t avail ${1} 2>&1)
	if [ "x${_retval}" == "x" ]; then 
		echo "no"
	else
		echo "yes"
	fi
}

function process_modules()
{
	separator "use/load modules"
	for p in ${BT_module_paths}
	do
		local _path
		eval _path=$p
		if [ -d ${_path} ]; then
			echo "[i] adding module path: [${_path}]"
			module use ${_path}
		else
			warning "ignoring module path [${_path}]"
		fi
	done
	if [ ! -z "${BT_modules}" ]; then
		for m in ${BT_modules}
		do
			if [ $(module_exists ${m}) == "yes" ]; then
				echo "[i] loading module [${m}]"
				local _retval=$(module load ${m} 2>&1)
				if [ "x${_retval}" != "x" ]; then
					warning "something went wrong when loading module [${m}]"
				else
					module load ${m}
				fi
			else
				warning "module not found [${m}]"
			fi
		done
	else
		echo "[i] no extra modules loaded"
	fi
	module list
}

function separator()
{
	echo
	echo $(padding "   [${1}] " "-" 40 center)
	echo
}

function warning()
{
	echo
	echo "[warning] $(padding "[${@}] " "?" 50 left)"
	echo
}

function padding ()
{
	CONTENT="${1}";
	PADDING="${2}";
	LENGTH="${3}";
	TRG_EDGE="${4}";
	case "${TRG_EDGE}" in
		left) echo ${CONTENT} | sed -e :a -e 's/^.\{1,'${LENGTH}'\}$/&\'${PADDING}'/;ta'; ;;
		right) echo ${CONTENT} | sed -e :a -e 's/^.\{1,'${LENGTH}'\}$/\'${PADDING}'&/;ta'; ;;
		center) echo ${CONTENT} | sed -e :a -e 's/^.\{1,'${LENGTH}'\}$/'${PADDING}'&'${PADDING}'/;ta'
	esac
	return ${RET__DONE};
}

function do_exit()
{
	if [ -z $1 ]; then
		cd $BT_save_dir
		exit 0
	else
		if [ $(bool ${BT_ignore_errors}) ]; then
			warning "error ignored - continuing..."
		else
			cd $BT_save_dir
			exit $1
		fi
	fi
}

function download()
{
	if [ $(bool ${BT_download}) ]; then
		check_download_paths
		savedir=$PWD
		cd ${BT_working_dir}
		separator download
		echo "[i] download..."
		[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
		[ -z "${BT_working_dir}" ] && echo "[error] working_dir not specified [${BT_working_dir}]" && do_exit ${BT_error_code}
		[ ! -d "${BT_working_dir}" ] && echo "[error] working_dir not a directory [${BT_working_dir}]" && do_exit ${BT_error_code}
		[ $(bool ${BT_debug}) ] && env | grep BT_local_file
		[ -z "${BT_local_file}" ] && echo "[error] local_file not specified [${BT_local_file}]" && do_exit ${BT_error_code}
		[ $(bool ${BT_debug}) ] && env | grep BT_remote_file
		[ -z "${BT_remote_file}" ] && echo "[error] remote file not specified [${BT_remote_file}]" && do_exit ${BT_error_code}
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
		separator "setup source"
		echo "[i] setup unpack_dir..."
		[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
		[ $(bool ${BT_debug}) ] && env | grep BT_local_file
		if [ -f "${BT_local_file}" ]; then
			local _local_dir=$(tar tfz ${BT_local_file} --exclude '*/*' | head -n 1)
			[ -z ${_local_dir} ] && _local_dir=$(tar tfz ${BT_local_file} | head -n 1 | cut -f 1 -d "/")
			[ ${_local_dir} == "." ] && echo "[error] bad _local_dir ${_local_dir}. stop." && do_exit ${BT_error_code}
			[ -z ${_local_dir} ] && echo "[error] bad _local_dir EMPTY. stop." && do_exit ${BT_error_code}
			export BT_src_dir=${BT_sources_dir}/${_local_dir}
			echo "[i] setup unpack_dir to ${BT_src_dir}"
		else
			if [ -z "${BT_src_dir}" ]; then
				echo "[w] local file does not exist? ${local_file}"
				export BT_src_dir=${BT_working_dir}/${BT_name}_${BT_version}
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
}

function check_working_paths()
{
	fix_working_paths
	[ ! -d "${BT_working_dir}" ] && mkdir -pv $BT_working_dir
	[ ! -d "${BT_working_dir}" ] && echo "[error] working_dir not a directory [${BT_working_dir}]" && do_exit ${BT_error_code}
	[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
}

function fix_install_paths()
{
	if [ -z "${BT_install_dir}" ]; then
		if [ -z "{BT_install_prefix}" ]; then
			export BT_install_prefix=$PWD
			echo_padded_BT_var install_prefix
		fi
		export BT_install_dir=${BT_install_prefix}/${BT_name}/${BT_version}
		export BT_install_dir
	fi
	#/${BT_name}/${BT_version}
	eval BT_install_dir=${BT_install_dir}
}

function check_install_paths()
{
	fix_install_paths
	[ $(bool ${BT_debug}) ] && env | grep BT_install_dir
}

function fix_download_paths()
{
	fix_working_paths
	# [ -z "${BT_local_file}" ] && export BT_local_file="${BT_working_dir}/downloads/${BT_name}_${BT_version}.download"
	[ -z "${BT_local_file}" ] && export BT_local_file="${BT_working_dir}/downloads/${BT_name}.download"
	BT_download_dir=$(dirname $BT_local_file)
	export BT_download_dir=$BT_download_dir
	export BT_download_dir=$(abspath $BT_download_dir)
	[ ! -z "${BT_local_file}" ] && export BT_local_file=$(abspath $BT_local_file)
}

function check_download_paths()
{
	check_working_paths
	fix_download_paths
	[ ! -d ${BT_download_dir} ] && warning "making directory for download file ${BT_download_dir}"
	mkdir -pv ${BT_download_dir}
	[ ! -d "${BT_download_dir}" ] && echo "[error] download directory is not a dir ${BT_download_dir}" && do_exit ${BT_error_code}
	[ $(bool ${BT_debug}) ] && env | grep BT_download_dir
}

function fix_sources_paths()
{
	if [ ! -z "${BT_src_dir}" ]; then
		eval BT_src_dir=$BT_src_dir
		export BT_src_dir
	else
		fix_working_paths
		[ -z "${BT_sources_dir}" ] && export BT_sources_dir=${BT_working_dir}/src
	fi
}

function check_sources_paths()
{
	fix_sources_paths
	if [ -z "${BT_src_dir}" ]; then
		check_working_paths
		[ ! -d ${BT_sources_dir} ] && warning "making directory for sources ${BT_sources_dir}"
		mkdir -pv ${BT_sources_dir}
		[ ! -d "${BT_sources_dir}" ] && echo "[error] build directory is not a dir ${BT_sources_dir}" && do_exit ${BT_error_code}
	fi
	[ $(bool ${BT_debug}) ] && env | grep BT_src_dir
	[ $(bool ${BT_debug}) ] && env | grep BT_sources_dir
}

function fix_build_paths()
{
	fix_working_paths
	[ -z "${BT_build_dir}" ] && export BT_build_dir=${BT_working_dir}/build/${BT_version}
	export BT_build_dir=$BT_build_dir
}

function check_build_paths()
{
	check_working_paths
	fix_build_paths
	[ ! -d ${BT_build_dir} ] && warning "making directory for building ${BT_build_dir}"
	mkdir -pv ${BT_build_dir}
	[ ! -d "${BT_build_dir}" ] && echo "[error] build directory is not a dir ${BT_build_dir}" && do_exit ${BT_error_code}
	[ $(bool ${BT_debug}) ] && env | grep BT_build_dir
}

function setup_sources()
{
	fix_sources_paths
	check_sources_paths
	download
}

function build()
{
	echo "[i] call to specific tool here..."
}

function do_cleanup()
{
	if [ $(bool ${BT_cleanup}) ]; then
		separator cleanup
		fix_build_paths
		[ -d ${BT_build_dir} ] && echo "[i] removing ${BT_build_dir}" && rm -rf ${BT_build_dir}
		[ -d ${BT_working_dir} ] && echo "[i] removing ${BT_working_dir}" && rm -rf ${BT_working_dir}
	fi
}

function init_build_tools()
{
	separator " init "
	export BT_save_dir=$PWD
	export BT_config_dir=$(dirname $(abspath ${BT_config}))
	export BT_now=$(date +%Y-%m-%d_%H_%M_%S)

	# this_file_dir=$(thisdir)
	# this_dir=$(abspath $this_file_dir)
	# up_dir=$(dirname $this_dir)
	# buildtools_dir=$(thisdir)

	process_user_short_options
	[ $(bool ${BT_help}) ] && usage
	if [ -z ${BT_script} ]; then
		process_options ${BT_built_in_options}
		check_config_present
		process_options_config
		read_config_options
		reprocess_defined_options ${BT_config_options} ${BT_built_in_options}
		process_user_short_options
	else
		if [ -f ${BT_script} ]; then
			process_options ${BT_built_in_options}
			source ${BT_script}
			process_options ${BT_built_in_options}
			reprocess_defined_options ${BT_config_options} ${BT_built_in_options}
			process_user_short_options
		else
			echo "[error] build script [${BT_script} does not exist." && do_exit ${BT_error_code}
		fi
	fi
	[ $(bool ${BT_rebuild}) ] && export BT_clean="yes" && export BT_build="yes"

	[ -z "${BT_version}" ] && echo "[w] unspecified version - setting as now $BT_now" && export BT_version=$BT_now && echo_padded_BT_var version

	[ $(bool ${BT_debug}) ] && env | grep BT_version=
	[ -z "${BT_name}" ] && echo "[w] guessing module name from $PWD" && export BT_name=$(basename $PWD) && 	echo_padded_BT_var name
	[ $(bool ${BT_debug}) ] && env | grep BT_name=

	if [ $(bool ${BT_clean}) ]; then
		separator clean
		fix_install_paths
		fix_build_paths
		echo "[i] removing ${BT_install_dir}"
		rm -rf ${BT_install_dir}
		echo "[i] removing ${BT_build_dir}"
		rm -rf ${BT_build_dir}
		echo "[i] removing ${BT_working_dir}"
		rm -rf ${BT_working_dir}
	fi
	fix_download_paths
	fix_working_paths
	fix_install_paths
	fix_build_paths
	fix_module_paths
	setup_sources
	process_modules
}

function run_build()
{
	if [ $(bool ${BT_build}) ]; then
		separator "build"
		check_sources_paths
		check_install_paths
		check_build_paths
		echo "[i] src dir: ${BT_src_dir}"
		echo "[i] install dir: ${BT_install_dir}"
		echo "[i] building..."
		savedir=$PWD
		cd ${BT_sources_dir}
		if [ ! -d "${BT_src_dir}" ]; then
			if [ -f "${BT_local_file}" ]; then
				echo "[i] unpacking... [${BT_local_file}]"
				tar zxvf ${BT_local_file} 2>&1 > /dev/null
			else
				echo "[error] local file [${BT_local_file}] does not exist" && do_exit ${BT_error_code}
			fi
		fi
		[ ! -d "${BT_src_dir}" ] && echo "[error] src directory "${BT_src_dir}" does not exist" && do_exit ${BT_error_code}
		cd "${BT_build_dir}"
		# if [ ! $(bool ${BT_rebuild}) ]; then
		# 	[ -e ${BT_install_dir} ] && echo "[error] ${BT_install_dir} exists. remove it before running --build or use --rebuild or --clean --build. stop." && do_exit ${BT_error_code}
		# fi
		build
		cd $savedir
	fi
}

function fix_module_paths()
{
	fix_install_paths
	[ -z ${BT_module_dir} ] && export BT_module_dir=${BT_install_dir}/modules/${BT_name}
	eval BT_module_dir=${BT_module_dir}
	export BT_module_file=${BT_module_dir}/${BT_version}
	[ $(bool ${BT_debug}) ] && env | grep BT_module_file
}

function check_module_paths()
{
	check_install_paths
	fix_module_paths
	mkdir -pv ${BT_module_dir}
	[ ! -d "${BT_module_dir}" ] && echo "[error] module directory ${BT_module_dir} does not exist" && do_exit ${BT_error_code}
}

function make_module()
{
	if [ $(bool ${BT_module}) ]; then
		separator "make module"
		check_module_paths
		[ ! -d ${BT_module_dir} ] && echo "[error] module folder does not exist." && do_exit ${BT_error_code}

		echo "[i] modfile: "${BT_module_file}
		rm -rf ${BT_module_file}
		touch ${BT_module_file}

cat>>${BT_module_file}<<EOL
#%Module
proc ModulesHelp { } {
    global version
    puts stderr "   Setup <name> <version>"
}

set     version <version>
setenv  <name>DIR <dir>
set-alias <name>_cd "cd <dir>"
EOL

		echo 'setenv <name_to_upper>_ROOT <dir>' >> ${BT_module_file}
		echo 'setenv <name_to_upper>_DIR <dir>' >> ${BT_module_file}
		echo 'setenv <name_to_upper>DIR <dir>' >> ${BT_module_file}

		if [ -d ${BT_install_dir}/lib ]; then
cat >>${BT_module_file}<<EOL
prepend-path LD_LIBRARY_PATH <dir>/lib
prepend-path DYLD_LIBRARY_PATH <dir>/lib
EOL
		fi

		if [ -d ${BT_install_dir}/lib64 ]; then
cat >>${BT_module_file}<<EOL
prepend-path LD_LIBRARY_PATH <dir>/lib64
prepend-path DYLD_LIBRARY_PATH <dir>/lib64
EOL
		fi

		if [ ! -z ${has_pythonlib} ]; then
		if [ -d ${BT_install_dir}/lib64 ]; then
cat >>${BT_module_file}<<EOL
prepend-path PYTHONPATH <dir>/lib64/${has_pythonlib}
EOL
		fi
		if [ -d ${BT_install_dir}/lib ]; then
cat >>${BT_module_file}<<EOL
prepend-path PYTHONPATH <dir>/lib/${has_pythonlib}
EOL
		fi
		fi

		[ -d ${BT_install_dir}/bin ] && echo "prepend-path PATH <dir>/bin" >> ${BT_module_file}

		sedi "s|<dir>|${BT_install_dir}|g" ${BT_module_file}
		sedi "s|<name_to_upper>|$(echo ${BT_name} | awk '{print toupper($0)}')|g" ${BT_module_file}
		sedi "s|<name>|${BT_name}|g" ${BT_module_file}
		sedi "s|<version>|${BT_version}|g" ${BT_module_file}

		echo "if { [ module-info mode load ] } {" >> ${BT_module_file}
		mpaths=`module -t avail 2>&1 | grep : | sed "s|:||g"`
		for mp in $mpaths
		do
		        echo "module use $mp" >> ${BT_module_file}
		done

		#loaded=`module -t list 2>&1 | grep -v Current | grep -v ${BT_module_file} | grep -v use.own`
		loaded=`module -t list 2>&1 | grep -v Current | grep -v ${BT_module_file}`
		for m in $loaded
		do
		        #echo "prereq $m" >> ${BT_module_file}
		        echo "module load $m" >> ${BT_module_file}
		done
		echo "}" >> ${BT_module_file}

	fi
}

function show_options()
{
	separator "show options"
	local _all_opts=$(env | grep BT_ | sed 's|UNDEFINED_||g' | cut -f 1 -d "=" | sort | uniq)
	#echo ${_all_opts}
	#for o in ${BT_built_in_options}
	for o in ${_all_opts}
	do
		echo_padded_BT_var ${o:3:${#o}} ${1}
	done
}

function exec_build_tool()
{
	init_build_tools
	[ ! -z ${BT_debug} ] && separator " debug/list " && list_options "[i] defined settings:" noundef
	run_build
	make_module
	do_cleanup
	show_options
	separator " . "
	do_exit
}

if [[ ! "X$(basename -- ${0})" == "X$(basename $BASH_SOURCE)" ]]; then
	# "Script is being sourced"
	true
else
	if [ ! -z $1 ]; then
		if [ "$1" == "--help" ]; then
			usage
		fi
		separator "running with $1"
		if [ ${1:0:2} == "BT" ]; then
			eval $1
		fi
	else
		usage
	fi

	if [ -z ${BT_script} ]; then
		separator "config mode"
	else
		separator "script mode"
		if [ -f ${BT_script} ]; then
			export BT_script_dir=$(dirname $(abspath ${BT_script}))
			source ${BT_script}
			exec_build_tool
		else
			echo "[error] build script [${BT_script} does not exist." && do_exit ${BT_error_code}
		fi
	fi
fi
