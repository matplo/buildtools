#!/bin/bash

# how to use this:
# implement a function build() & execute do_build
# within build() rely on $BT variables

BT_global_args="$@"
BT_built_in_options=$(cat $BASH_SOURCE | grep -o "BT_.*" | cut -f 1 -d "}" | grep -v "=" | grep -v " " | grep -v "{" | grep -v ")" | sort -d | uniq | cut -f 2- -d "_" | grep -v built_in_options | grep -v get_var_value_return | grep -v global_args)
#BT_built_in_options="build build_type clean cleanup config config_dir debug download dry force help ignore_errors install_dir install_prefix module module_dir module_paths modules name now rebuild remote_file script src_dir verbose version working_dir"
BT_error_code=1

function valid_var_name()
{
	local _trimmed=$(echo -e "${1}" | sed 's|\.|_|g' | sed 's|-|_|g')
	echo ${_trimmed}
}

function no_dots()
{
	local _trimmed=$(echo -e "${1}" | sed 's|\.|_|g')
	echo ${_trimmed}
}

function no_white_space()
{
	local _trimmed="$(echo -e "${1}" | tr -d '[:space:]')"
	echo ${_trimmed}
}

function trim_lead_space()
{
	local _trimmed="$(echo -e "${1}" | sed -e 's/^[[:space:]]*//')"
	echo ${_trimmed}
}

function trim_trail_space()
{
	local _trimmed="$(echo -e "${1}" | sed -e 's/[[:space:]]*$//')"
	echo ${_trimmed}
}

function trim_spaces()
{
	local _trimmed="$(echo -e "${1}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	echo ${_trimmed}
}

function echo_debug()
{
	if [ "x${BT_debug}" != "x" ]; then
		(>&2 echo "[debug] $@")
	fi
}

function echo_trace()
{
	if [ "x${BT_trace}" != "x" ]; then
		(>&2 echo "[trace] $@")
	fi
}

function echo_info()
{
	(>&2 echo "[info] $@")
}

function echo_warning()
{
	(>&2 echo -e "\033[1;93m$@ \033[0m")
}

function echo_error()
{
	(>&2 echo -e "\033[1;31m$@ \033[0m")
}

function echo_note_red()
{
	(>&2 echo -e "\033[1;31m[note] $@ \033[0m")
}


function note_red()
{
	(>&2 echo -e "\033[1;31m[note] $@ \033[0m")
}

function separator()
{
	echo
	echo -e "\033[1;32m$(padding "[ ${1} ]" "-" 25 center) \033[0m"
	## colors at http://misc.flogisoft.com/bash/tip_colors_and_formatting
}

function echo_note()
{
	echo_warning "$(padding "[note] ${@}" "-" 10 left)"
}

function note()
{
	echo_warning "$(padding "[note] ${@}" "-" 10 left)"
}

function warning()
{
	echo_warning "[warning] $(padding "[${@}] " "-" 50 right)"
}

function error()
{
	echo_error "[error] $(padding "[${@}] " "-" 50 right)"
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

# https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself
function thisdir()
{
	SOURCE="${BASH_SOURCE[0]}"
	while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
	  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
	  SOURCE="$(readlink "$SOURCE")"
	  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
	done
	DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
	echo ${DIR}
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
	local retval="no"
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
	[ $(os_darwin) ] && sed -i "" -e \"$@\"
	[ $(os_linux)  ] && sed -i'' -e \"$@\"
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
	[ -f .tmp.sh ] && rm .tmp.sh
	touch .tmp.sh
	for opt in ${_opts}
	do
		if [ $(is_opt_set "--${opt}") == "yes" ];
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
	rm .tmp.sh
}

function reprocess_defined_options()
{
	local _opts="$@"
	[ $(bool ${BT_debug}) ] && echo "[i] re-processing defined options: ${_opts}"
	[ -f .tmp.sh ] && rm .tmp.sh
	touch .tmp.sh
	for opt in ${_opts}
	do
		if [ ! -z $(get_opt_with --${opt}) ]; then
			echo "export BT_$opt=$(get_opt_with --${opt})" >> .tmp.sh
		fi
	done
	source .tmp.sh
	rm .tmp.sh
}

function process_options_config()
{
	local _var="options"
	[ ! -z $1 ] && _var=$1
	local _opts=$(config_value ${_var})
	[ -f .tmp.sh ] && rm .tmp.sh
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
	rm .tmp.sh
}

function get_var_value()
{
	[ -f .tmp.sh ] && rm .tmp.sh
	touch .tmp.sh
	echo "export BT_get_var_value_return=\$$1" >> .tmp.sh
	source .tmp.sh
	echo $BT_get_var_value_return
	BT_get_var_value_return=""
	#cp .tmp.sh peek.sh
	rm .tmp.sh
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
		echo $(padding "   [${1}] " "-" 25 right)" : "$(get_var_value ${1})
	else
		echo $(padding "   [${1}] " "-" 25 right)" : UNDEFINED"
	fi
}

function echo_padded_BT_var()
{
	local _defined=$(get_var_value BT_${1})
	if [ "${2}" == "all" ]; then
		echo $(padding "   [${1}] " "-" 25 right)" : "${_defined}
	else
		if [ "x${_defined}" != "x" ]; then
			echo $(padding "   [${1}] " "-" 25 right)" : "${_defined}
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
	separator "."
	do_exit 0
}

function check_config_present()
{
	[ -z ${BT_config} ] && error "no config file specified."  && usage && do_exit ${BT_error_code}
	[ ! -f "${BT_config}" ] && error "config file ${BT_config} not found."  && usage && do_exit ${BT_error_code}
}

function bool()
{
	if [ "x${1}" == "x" ]; then
	 	echo "" && return
	else
		if [ "${1}" == "no" ]; then
			echo ""
		else
			echo "yes"
		fi
	fi
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
		echo_note "[i] options:"
	else
		echo_note "$1"
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

function current_loaded_modules()
{
	echo $(module -t list 2>&1 | grep -v ":" | tr '\n' ' ')
}

function add_prereq_modules()
{
	for m in $@
	do
		if [ ! $(is_in_string ${m} ${BT_modules}) == "yes" ]; then
			export BT_modules="${BT_modules} ${m}"
		fi
	done
	echo_note "added module dependencies"
	echo_padded_BT_var modules
}

function add_prereq_module_paths()
{
	for m in $@
	do
		if [ ! $(is_in_string ${m} ${BT_module_paths}) == "yes" ]; then
			export BT_module_paths="${BT_module_paths} ${m}"
		fi
	done
	echo_note "added module paths"
	echo_padded_BT_var module_paths
}

function try_load_module()
{
	local _new_loaded=""
	local _mod=${1}
	local _before=$(current_loaded_modules)
	echo_trace "before: ${_before}"
	local _retval=$(module load ${_mod} 2>&1)
	if [ "x${_retval}" != "x" ]; then
		error "something went wrong when loading module [${_mod}] ${_retval}"
		do_exit $BT_error_code
	else
		module load ${_mod}
	fi
	local _after=$(current_loaded_modules)
	echo_trace "after: ${_after}"
	local _new_loaded=$(echo ${_after}|sed "s|${_before}||g"|tr '\n' ' ')
	echo_trace "remaining: [${_new_loaded}]"
	echo ${_new_loaded}
}

function process_modules()
{
	separator "use/load modules"
	export BT_predefined_module_paths=$(module -t avail 2>&1| grep ":" | tr ':' ' ' | tr '\n' ' ')
	echo_padded_BT_var do_preload_modules
	echo_padded_BT_var predefined_module_paths
	for p in ${BT_module_paths}
	do
		local _path
		eval _path=$p
		if [ -d ${_path} ]; then
			echo_info "adding module path: [${_path}]"
			module use ${_path}
			if [ "x${BT_this_added_module_paths}" == "x" ]; then
				BT_this_added_module_paths=${_path}
			else
				BT_this_added_module_paths="${BT_this_added_module_paths} ${_path}"
			fi
		else
			warning "ignoring module path [${_path}]"
		fi
	done
	if [ ! -z "${BT_modules}" ]; then
		for m in ${BT_modules}
		do
			if [ $(module_exists ${m}) == "yes" ]; then
				echo_info "loading module [${m}]"
				local m_loaded=$(try_load_module ${m})
				if [ "x${BT_this_loaded_modules}" == "x" ]; then
					BT_this_loaded_modules=${m_loaded}
				else
					BT_this_loaded_modules="${BT_this_loaded_modules} ${m_loaded}"
				fi
				echo_debug "loading [${m_loaded}]"
				if [ "x${m_loaded}" != "x" ]; then
					module load ${m_loaded}
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
		separator download
		if [ $(bool ${BT_disable_download}) ]; then
			warning "download disabled within the script"
			return
		fi
		check_download_paths
		savedir=$PWD
		cd ${BT_working_dir}
		echo "[i] download..."
		[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
		[ "x${BT_working_dir}" == "x" ] && error "working_dir not specified [${BT_working_dir}]" && do_exit ${BT_error_code}
		[ ! -d "${BT_working_dir}" ] && error "working_dir not a directory [${BT_working_dir}]" && do_exit ${BT_error_code}
		[ $(bool ${BT_debug}) ] && env | grep BT_local_file
		[ "x${BT_local_file}" == "x" ] && error "local_file not specified [${BT_local_file}]" && do_exit ${BT_error_code}
		[ $(bool ${BT_debug}) ] && env | grep BT_remote_file
		[ "x${BT_remote_file}" == "x" ] && error "remote file not specified [${BT_remote_file}]" && do_exit ${BT_error_code}
		if [ -f "${BT_local_file}" ]; then
			if [ ${BT_force} ]; then
				[ -f "${BT_local_file}" ] && rm -fv ${BT_local_file}
				wget ${BT_remote_file} --no-check-certificate -O ${BT_local_file}
			else
				warning "file ${BT_local_file} exists. no download - use --force to override."
			fi
		else
				wget ${BT_remote_file} --no-check-certificate -O ${BT_local_file}
		fi
		cd $savedir
	setup_src_dir
	fi
}

function resolve_directory_full()
{
	local _dir_to_resolve="${1}"
	if [ -f ${_dir_to_resolve} ]; then
		_dir_to_resolve=$(dirname ${_dir_to_resolve})
	fi
	[ ! -d ${_dir_to_resolve} ] && do_exit ${BT_error_code}
	savedir=$(pwd)
	cd ${_dir_to_resolve} 2>/dev/null
	local _retval="$?"
	if [ "x${_retval}" == "x0" ]; then
		echo $(pwd -P) # output full, link-resolved path - not with -P on PDSF
	else
		cd $savedir
		echo "/dev/null/bad directory unable to resolve" && do_exit ${_retval}
		# return ${_retval}  # cd to desired directory; if fail, quell any error messages but return exit status
	fi
}

function resolve_directory()
{
	local _dir_to_resolve="${1}"
	if [ -f ${_dir_to_resolve} ]; then
		_dir_to_resolve=$(dirname ${_dir_to_resolve})
	fi
	[ ! -d ${_dir_to_resolve} ] && do_exit ${BT_error_code}
	savedir=$(pwd)
	cd ${_dir_to_resolve} 2>/dev/null
	local _retval="$?"
	if [ "x${_retval}" == "x0" ]; then
		#echo $(pwd -P) # output full, link-resolved path - not with -P on PDSF
		echo $(pwd)
	else
		cd $savedir
		echo "/dev/null/bad directory unable to resolve" && do_exit ${_retval}
		# return ${_retval}  # cd to desired directory; if fail, quell any error messages but return exit status
	fi
	cd ${savedir}
}

function resolve_file()
{
	local _dir=$(file_dir ${1})
	_retval="$(resolve_directory ${_dir})/$(basename ${1})"
	echo ${_retval}
}

function setup_src_dir()
{
	if [ "x${BT_src_dir}" == "x" ]; then
		savedir=$PWD
		check_working_paths
		check_sources_paths
		cd ${BT_working_dir}
		separator "setup source"
		[ $(bool ${BT_debug}) ] && env | grep BT_local_file
		if [ -f "${BT_local_file}" ]; then
			local _local_dir=$(tar tf ${BT_local_file} --exclude '*/*' | head -n 1)
			[ "x${_local_dir}" == "x" ] && _local_dir=$(tar tf ${BT_local_file} | head -n 1 | cut -f 1 -d "/")
			[ "x${_local_dir}" == "x." ] && error "bad _local_dir ${_local_dir}. stop." && do_exit ${BT_error_code}
			[ "x${_local_dir}" == "x" ] && error "bad _local_dir EMPTY. stop." && do_exit ${BT_error_code}
			BT_sources_dir=$(resolve_directory ${BT_sources_dir})
			[ "x${BT_sources_dir}" == "x" ] && error "something is off with sources dir [${BT_sources_dir}]" && do_exit ${BT_error_code}
			[ ! -d ${BT_sources_dir} ] && error "something is off with sources dir [${BT_sources_dir}]" && do_exit ${BT_error_code}
			export BT_sources_dir
			export BT_src_dir=${BT_sources_dir}/${_local_dir}
			echo "[i] setup unpack_dir based on local file to ${BT_src_dir}"
		else
			if [ "x${BT_src_dir}" == "x" ]; then
				BT_sources_dir=$(resolve_directory ${BT_sources_dir})
				export BT_sources_dir
				export BT_src_dir=${BT_sources_dir}/${BT_name}/${BT_version}
				echo "[i] setup src_dir to ${BT_src_dir}"
			fi
			[ $(bool ${BT_debug}) ] && env | grep BT_src_dir
		fi
		cd $savedir
	fi
}

function fix_working_paths()
{
	# not pwd -P
	[ "x${BT_working_dir}" == "x" ] && export BT_working_dir=$(pwd)/working_dir
}

function check_working_paths()
{
	fix_working_paths
	[ ! -d "${BT_working_dir}" ] && mkdir -pv $BT_working_dir
	[ ! -d "${BT_working_dir}" ] && error "working_dir not a directory [${BT_working_dir}]" && do_exit ${BT_error_code}
	export BT_working_dir=$(resolve_directory ${BT_working_dir})
	[ $(bool ${BT_debug}) ] && env | grep BT_working_dir
}

function fix_install_paths()
{
	if [ "x${BT_install_dir}" == "x" ]; then
		if [ "x{BT_install_prefix}" == "x" ]; then
			export BT_install_prefix=$PWD
			echo_padded_BT_var install_prefix
		fi
		export BT_install_dir=${BT_install_prefix}/${BT_name}/${BT_version}
		eval BT_install_dir=${BT_install_dir}
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
	[ ! -d "${BT_download_dir}" ] && error "download directory is not a dir ${BT_download_dir}" && do_exit ${BT_error_code}
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
		[ ! -d "${BT_sources_dir}" ] && error "build directory is not a dir ${BT_sources_dir}" && do_exit ${BT_error_code}
	fi
	[ $(bool ${BT_debug}) ] && env | grep BT_src_dir
	[ $(bool ${BT_debug}) ] && env | grep BT_sources_dir
}

function fix_build_paths()
{
	fix_working_paths
	[ "x${BT_build_dir}" == "x" ] && export BT_build_dir=${BT_working_dir}/build/${BT_name}/${BT_version}
	export BT_build_dir=${BT_build_dir}
}

function check_build_paths()
{
	check_working_paths
	fix_build_paths
	[ ! -d ${BT_build_dir} ] && warning "making directory for building ${BT_build_dir}"
	mkdir -pv ${BT_build_dir}
	[ ! -d "${BT_build_dir}" ] && error "build directory is not a dir ${BT_build_dir}" && do_exit ${BT_error_code}
	[ $(bool ${BT_debug}) ] && env | grep BT_build_dir
}

function setup_sources()
{
	fix_sources_paths
	check_sources_paths
	if [ $(bool ${BT_download}) ]; then
		download
	fi
}

function build()
{
	echo "[i] call to specific tool here..."
}

function check_rmdir()
{
	if [ "x${1}" != "x" ]; then
		if [[ -d "${1}" ]]; then
			separator "? remove ?"
			read -p "[?] directory: ${1} [y/N]" _user_input
			if [ "x${_user_input}" == "xy" ]; then
				warning "    -> removing... ${1}"
				rm -rf ${1}
			else
				echo "    -> NOT removing"
			fi
		fi
	fi
}

function do_cleanup()
{
	if [ $(bool ${BT_cleanup}) ]; then
		separator cleanup
		echo_padded_BT_var working_dir
		echo_padded_BT_var install_dir
		echo_padded_BT_var build_dir
		echo_padded_BT_var sources_dir
		echo_padded_BT_var src_dir
		echo_padded_BT_var module_dir

		check_rmdir "${BT_working_dir}"
		# check_rmdir "${BT_install_dir}"
		check_rmdir "${BT_build_dir}"
		if [ "x${BT_local_file}" != "x" ]; then
			if [ -f ${BT_local_file} ]; then
				warning "suggesting to cleanup sources because BT_local_file=${BT_local_file} exists..."
				check_rmdir "${BT_sources_dir}"
				check_rmdir "${BT_src_dir}"
			fi
		fi
		# check_rmdir "${BT_module_dir}"
	fi
}

function is_module_loaded()
{
	local _check=$(module -t list 2>&1 | grep "${BT_name}/${BT_version}")
	if [ "x${_check}" == "x${BT_name}/${BT_version}" ]; then
		echo "yes"
	fi
	echo
}

function init_build_tools()
{
	separator "init"
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
			error "build script [${BT_script} does not exist." && do_exit ${BT_error_code}
		fi
	fi
	[ $(bool ${BT_rebuild}) ] && export BT_clean="yes" && export BT_build="yes"
	[ "x${BT_version}" == "x" ] && warning "unspecified version - setting as now $BT_now" && export BT_version=$BT_now && echo_padded_BT_var version
	[ $(bool ${BT_debug}) ] && env | grep BT_version=
	[ "x${BT_name}" == "x" ] && warning "guessing module name from $PWD" && export BT_name=$(basename $PWD) && 	echo_padded_BT_var name
	[ $(bool ${BT_debug}) ] && env | grep BT_name=

	separator "fix paths"
	if [ "x$(is_module_loaded)" == "xyes" ]; then
		BT_working_dir=$(get_var_value BT_working_dir)
		for _dir in working_dir install_dir build_dir src_dir module_dir
		do
			eval BT_${_dir}=$(get_var_value BT_${_dir}_${BT_name}_$(valid_var_name ${BT_version}))
		done
	else
		fix_download_paths
		fix_working_paths
		fix_install_paths
		fix_build_paths
		fix_module_paths
	fi

	if [ $(bool ${BT_clean}) ]; then
		separator clean
		echo_padded_BT_var working_dir
		echo_padded_BT_var install_dir
		echo_padded_BT_var build_dir
		echo_padded_BT_var sources_dir
		echo_padded_BT_var src_dir
		echo_padded_BT_var module_dir

		fix_working_paths
		fix_install_paths
		fix_build_paths
		check_rmdir ${BT_install_dir}
		check_rmdir ${BT_build_dir}
		check_rmdir ${BT_working_dir}

		separator "fix paths ..."
	fi

	setup_sources
	echo_padded_BT_var working_dir
	echo_padded_BT_var install_dir
	echo_padded_BT_var build_dir
	echo_padded_BT_var sources_dir
	echo_padded_BT_var src_dir
	echo_padded_BT_var module_dir
	if [ "x$(is_module_loaded)" == "xyes" ]; then
		note "module for ${BT_name} version ${BT_version} already loaded... nothing to load here."
	else
		process_modules
	fi
}

function untar_local_file()
{
	tar zxvf ${1} 2>&1 > /dev/null
}

function run_build()
{
	if [ $(bool ${BT_build}) ]; then
		separator "build"
		if [ $(bool ${BT_disable_build}) ]; then
			warning "build disabled within the script $(abspath ${BT_script})"
			return
		fi
		check_sources_paths
		check_install_paths
		check_build_paths
		echo_padded_BT_var src_dir
		echo_padded_BT_var install_dir
		echo_padded_BT_var n_cores
		echo
		echo "[i] building..."
		savedir=$PWD
		cd ${BT_sources_dir}
		if [ "x${BT_src_dir}" == "x" ]; then
			echo "[i] figuring out the src directory"
	    	setup_src_dir
			separator "build"
	    	echo_padded_BT_var src_dir
		fi
		if [ ! -d "${BT_src_dir}" ]; then
			warning "src directory "${BT_src_dir}" does not exist - trying to figure this using local file..."
		    if [ -f "${BT_local_file}" ]; then
		    	setup_src_dir
    			separator "build"
				echo "[i] unpacking... [${BT_local_file}]"
				untar_local_file ${BT_local_file}
			fi
		fi
		[ ! -d "${BT_src_dir}" ] && error "src directory "${BT_src_dir}" does not exist" && do_exit ${BT_error_code}
		cd "${BT_build_dir}"
		# if [ ! $(bool ${BT_rebuild}) ]; then
		# 	[ -e ${BT_install_dir} ] && error "${BT_install_dir} exists. remove it before running --build or use --rebuild or --clean --build. stop." && do_exit ${BT_error_code}
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
	[ ! -d "${BT_module_dir}" ] && error "module directory ${BT_module_dir} does not exist" && do_exit ${BT_error_code}
}

function is_in_string()
{
	local _n=$(no_white_space $(echo "$@" | wc -w))
	echo_trace "n : ${_n} in ${@}"
	[ ${_n} -eq 1 ] && echo "no" && return
	[ ${_n} -eq 0 ] && echo "no" && return
	local _s=$(trim_spaces ${1})
	local _sin=$(echo ${@} | cut -f 2- -d " ")
	local _retval="no"
	echo_trace "search for : ${_s}"
	echo_trace "in a string: ${_sin}"
	for s in ${_sin}
	do
		local _test=$(trim_spaces ${s})
		if [ "x${_test}" == "x${_s}" ]; then
			_retval="yes"
			break
		fi
	done
	echo_trace "result is ${_retval}"
	echo ${_retval}
}

function make_module()
{
	if [ $(bool ${BT_module}) ]; then
		separator "make module"
		if [ "x$(is_module_loaded)" == "xyes" ]; then
			warning "a module ${BT_name}/${BT_version} is already loaded - this does not look good. bailing out."
			warning "... you may want to unload it first & then run: ${BT_run_command} --module"
			return
		fi
		check_module_paths
		[ ! -d ${BT_module_dir} ] && error "module folder does not exist." && do_exit ${BT_error_code}

		export BT_module_file=$(resolve_file ${BT_module_file})
		echo_padded_BT_var module_file
		export BT_install_dir=$(resolve_directory ${BT_install_dir})
		echo_padded_BT_var install_dir

		rm -f ${BT_module_file}
		touch ${BT_module_file}
		[ ! -f ${BT_module_file} ] && error "unable to create module file ${BT_module_file}" && do_exit ${BT_error_code}

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
		echo 'setenv <name_to_upper>SYS <dir>' >> ${BT_module_file}

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

		if [ ! -z ${BT_pythonlib} ]; then
		if [ -d ${BT_install_dir}/lib64 ]; then
cat >>${BT_module_file}<<EOL
prepend-path PYTHONPATH <dir>/lib64/${BT_pythonlib}
EOL
		fi
		if [ -d ${BT_install_dir}/lib ]; then
cat >>${BT_module_file}<<EOL
prepend-path PYTHONPATH <dir>/lib/${BT_pythonlib}
EOL
		fi
		fi

		for _dir in working_dir install_dir build_dir src_dir module_dir
		do
			echo "setenv BT_${_dir}_${BT_name}_$(valid_var_name ${BT_version}) \"$(get_var_value BT_${_dir})\"" >> ${BT_module_file}
		done
		echo "setenv BT_${BT_name}_version ${BT_name}_${BT_version}" >> ${BT_module_file}
		echo "set-alias bt_run_${BT_name}_$(valid_var_name ${BT_version}) \"$(get_var_value BT_run_command)\"" >> ${BT_module_file}
		if [ $(bool ${BT_disable_build}) ]; then
			note "bt_build_${BT_name}_$(valid_var_name ${BT_version}) alias will not be available - build disabled"
			note "bt_rebuild_${BT_name}_$(valid_var_name ${BT_version}) alias will not be available - build disabled"
		else
			echo "set-alias bt_build_${BT_name}_$(valid_var_name ${BT_version}) \"$(get_var_value BT_build_command)\"" >> ${BT_module_file}
			echo "set-alias bt_rebuild_${BT_name}_$(valid_var_name ${BT_version}) \"$(get_var_value BT_rebuild_command)\"" >> ${BT_module_file}
		fi

		[ -d ${BT_install_dir}/bin ] && echo "prepend-path PATH <dir>/bin" >> ${BT_module_file}

		local _this_module="$(basename $(dirname ${BT_module_file}))/${BT_version}"

		sedi "s|<dir>|${BT_install_dir}|g" ${BT_module_file}
		sedi "s|<name_to_upper>|$(echo ${BT_name} | awk '{print toupper($0)}')|g" ${BT_module_file}
		sedi "s|<name>|${BT_name}|g" ${BT_module_file}
		sedi "s|<version>|${BT_version}|g" ${BT_module_file}

		mpaths=`module -t avail 2>&1 | grep : | sed "s|:||g"`
		echo_debug "save module paths: ${BT_predefined_module_paths}"
		echo_debug "this added module paths: ${BT_this_added_module_paths}"
		# do not add the module use statement
		# for mp in ${BT_this_added_module_paths}
		# do
		# 	if [ $(is_in_string ${mp} ${BT_predefined_module_paths}) == "yes" ]; then
		# 		echo_debug "skipping path ${mp}"
		# 	else
		# 		echo_debug "module use ${mp}"
		# 		echo "if [ module-info mode load ] {" >> ${BT_module_file}
		#         echo "module use $mp" >> ${BT_module_file}
		#         echo "}" >> ${BT_module_file}
		#     fi
		# done

		all_loaded=`module -t list 2>&1 | grep -v Current | grep -v ${_this_module} | tr '\n' ' '`
		echo_debug "all loaded modules: ${all_loaded}"
		echo_debug "this loaded modules: ${BT_this_loaded_modules}"
		echo_padded_BT_var do_preload_modules
		echo_padded_BT_var this_loaded_modules
		for m in ${all_loaded}
		do
			if [ "x$(is_in_string ${m} ${BT_this_loaded_modules})" == "xno" ]; then
				if [ "x${BT_do_preload_modules}" != "xyes" ]; then
					echo_note "ignoring -> prereq module [${m}]"
					# echo "prereq $m" >> ${BT_module_file}
				else
					echo_note "-> load ${m}"
					echo "module load $m" >> ${BT_module_file}
				fi
			fi
		done

		for m in ${BT_this_loaded_modules}
		do
			if [ "x${BT_do_preload_modules}" != "x" ]; then
				echo "module load $m" >> ${BT_module_file}
			else
				echo "module load $m" >> ${BT_module_file}
				#echo "prereq $m" >> ${BT_module_file}
			fi
		done

	fi
}

function show_options()
{
	separator "show options"
	local _all_opts=$(printenv | grep BT_ | sed 's|UNDEFINED_||g' | cut -f 1 -d "=" | sort | uniq)
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
	[ ! -z ${BT_debug} ] && separator "debug/list" && list_options "defined settings" noundef
	run_build
	make_module
	do_cleanup
	# show_options all
	separator " . "
	do_exit
}

if [[ ! "X$(basename -- ${0})" == "X$(basename $BASH_SOURCE)" ]]; then
	# "Script is being sourced"
	true
else
	#just to catch these either up front or in builtin scan
	BT_n_cores=$(n_cores)
	export BT_n_cores
	BT_do_preload_modules=""
	export BT_do_preload_modules
	# echo_padded_BT_var built_in_options
	if [ "x${1}" != "x" ]; then
		if [ $(is_opt_set --help) == "yes" ]; then
			usage
		fi
		separator "${BASH_SOURCE}"
		note_red "running with $1"
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
			echo_padded_BT_var script_dir
			export BT_build_command="$(abspath $BASH_SOURCE) BT_script=$(abspath ${BT_script}) --build"
			export BT_rebuild_command="$(abspath $BASH_SOURCE) BT_script=$(abspath ${BT_script}) --rebuild"
			export BT_run_command="$(abspath $BASH_SOURCE) BT_script=$(abspath ${BT_script})"
			echo_debug $(echo_padded_BT_var run_command)
			echo_debug $(echo_padded_BT_var build_command)
			echo_debug $(echo_padded_BT_var rebuild_command)
			source ${BT_script}
			exec_build_tool
		else
			error "build script [${BT_script} does not exist." && do_exit ${BT_error_code}
		fi
	fi
fi
