#!/bin/bash

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

function usage()
{
	echo "[i] usage: $(basename $BASH_SOURCE) --config <config_file>"
}

buildtools_dir=$(thisdir)
echo "[i] build tools in: ${buildtools_dir}"

echo "    sourcing tools: ${buildtools_dir}/tools.sh"
source ${buildtools_dir}/tools.sh
config_file=$(get_opt_with --config)
[ -z ${config_file} ] && echo "[e] no config file..."  && usage && exit 1
echo "    config file ${config_file}"
process_options version clean build module
process_options

echo "[i] version is: ${version}"
echo "[i] module is: ${module}"
echo "[i] test is: ${test}"


