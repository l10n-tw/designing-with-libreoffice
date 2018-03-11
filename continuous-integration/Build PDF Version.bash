#!/usr/bin/env bash
#shellcheck disable=SC2034

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

## Runtime Dependencies Checking
declare\
	runtime_dependency_checking_result='still-pass' \
	required_software

for required_command in \
	basename\
	dirname\
	realpath\
	soffice; do
	if ! command -v "${required_command}" &>/dev/null; then
		runtime_dependency_checking_result='fail'

		case "${required_command}" in
			basename\
			|dirname\
			|realpath)
				required_software='GNU Coreutils'
			;;
			soffice)
				required_software='LibreOffice'
			;;
			*)
				required_software="${required_command}"
			;;
		esac

		printf --\
			"Error: This program requires \"%s\" to be installed and it's executables in the executable searching paths.\n"\
			"${required_software}" 1>&2
		unset required_software
	fi
done; unset required_command required_software

if [ "${runtime_dependency_checking_result}" = 'fail' ]; then
	printf --\
		"Error: Runtime dependency checking fail, the progrom cannot continue.\n" 1>&2
	exit 1
fi; unset runtime_dependency_checking_result

## Non-overridable Primitive Variables
## BASHDOC: Shell Variables » Bash Variables
## BASHDOC: Basic Shell Features » Shell Parameters » Special Parameters
if [ -v "BASH_SOURCE[0]" ]; then
	RUNTIME_EXECUTABLE_PATH="$(realpath --strip "${BASH_SOURCE[0]}")"
	RUNTIME_EXECUTABLE_FILENAME="$(basename "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_EXECUTABLE_NAME="${RUNTIME_EXECUTABLE_FILENAME%.*}"
	RUNTIME_EXECUTABLE_DIRECTORY="$(dirname "${RUNTIME_EXECUTABLE_PATH}")"
	RUNTIME_COMMANDLINE_BASECOMMAND="${0}"
	declare -r\
		RUNTIME_EXECUTABLE_FILENAME\
		RUNTIME_EXECUTABLE_DIRECTORY\
		RUNTIME_EXECUTABLE_PATHABSOLUTE\
		RUNTIME_COMMANDLINE_BASECOMMAND
fi
declare -ar RUNTIME_COMMANDLINE_PARAMETERS=("${@}")

## init function: entrypoint of main program
## This function is called near the end of the file,
## with the script's command-line parameters as arguments
init(){
	if ! process_commandline_parameters; then
		printf\
			"Error: %s: Invalid command-line parameters.\n"\
			"${FUNCNAME[0]}"\
			1>&2
		print_help
		exit 1
	fi

	local project_root_dir="$(
		realpath "${RUNTIME_EXECUTABLE_DIRECTORY}/.."
	)"; declare -r project_root_dir

	pushd "${project_root_dir}/target" >/dev/null
	soffice --headless --convert-to pdf *.odt
	popd >/dev/null

	exit 0
}; declare -fr init

check_odt_content_xml(){
	util_check_function_parameters_quantity 1 $#

	local -r odt_file="${1}"; shift

	local check_result='unset'

	printf --\
		"Info: Checking %s...\n"\
		"${odt_file}"

	unzip "${odt_file}" content.xml >/dev/null

	# NOTE: COMPATIBILITY: --stop isn't available in Ubuntu 14.04(Trusty)
	if ! xmlstarlet \
			validate \
			--err \
			content.xml; then
		check_result=failed
	else
		check_result=passed
	fi

	rm content.xml

	if [ "${check_result}" = failed ]; then
		return 1
	else
		return 0
	fi
}; declare -fr check_odt_content_xml

## Traps: Functions that are triggered when certain condition occurred
## Shell Builtin Commands » Bourne Shell Builtins » trap
trap_errexit(){
	printf "An error occurred and the script is prematurely aborted\n" 1>&2
	return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
	return 0
}; declare -fr trap_exit; trap trap_exit EXIT

trap_return(){
	local returning_function="${1}"

	printf "DEBUG: %s: returning from %s\n" "${FUNCNAME[0]}" "${returning_function}" 1>&2
}; declare -fr trap_return

trap_interrupt(){
	printf "\n" # Separate previous output
	printf "Recieved SIGINT, script is interrupted." 1>&2
	return 1
}; declare -fr trap_interrupt; trap trap_interrupt INT

print_help(){
	printf "Currently no help messages are available for this program\n" 1>&2
	return 0
}; declare -fr print_help;

process_commandline_parameters() {
	if [ "${#RUNTIME_COMMANDLINE_PARAMETERS[@]}" -eq 0 ]; then
		return 0
	fi

	# modifyable parameters for parsing by consuming
	local -a parameters=("${RUNTIME_COMMANDLINE_PARAMETERS[@]}")

	# Normally we won't want debug traces to appear during parameter parsing, so we  add this flag and defer it activation till returning(Y: Do debug)
	local enable_debug=N

	while true; do
		if [ "${#parameters[@]}" -eq 0 ]; then
			break
		else
			case "${parameters[0]}" in
				"--help"\
				|"-h")
					print_help;
					exit 0
					;;
				"--debug"\
				|"-d")
					enable_debug="Y"
					;;
				*)
					printf "ERROR: Unknown command-line argument \"%s\"\n" "${parameters[0]}" >&2
					return 1
					;;
			esac
			# shift array by 1 = unset 1st then repack
			unset "parameters[0]"
			if [ "${#parameters[@]}" -ne 0 ]; then
				parameters=("${parameters[@]}")
			fi
		fi
	done

	if [ "${enable_debug}" = "Y" ]; then
		trap 'trap_return "${FUNCNAME[0]}"' RETURN
		set -o xtrace
	fi
	return 0
}; declare -fr process_commandline_parameters;

## Utility function to check if function parameters quantity is legal
## NOTE: non-static function parameter quantity(e.g. either 2 or 3) is not supported
util_check_function_parameters_quantity(){
	if [ "${#}" -ne 2 ]; then
		printf_with_color\
			red\
			'%s: FATAL: Function requires %u parameters, but %u is given\n'\
			"${FUNCNAME[0]}"\
			2\
			"${#}"
		exit 1
	fi

	# The expected given quantity
	local -i expected_parameter_quantity="${1}"; shift
	# The actual given parameter quantity, simply pass "${#}" will do
	local -i given_parameter_quantity="${1}"

	if [ "${given_parameter_quantity}" -ne "${expected_parameter_quantity}" ]; then
		printf_with_color\
			red\
			'%s: FATAL: Function requires %u parameters, but %u is given\n'\
			"${FUNCNAME[1]}"\
			"${expected_parameter_quantity}"\
			"${given_parameter_quantity}"\
			1>&2
		exit 1
	fi
	return 0
}; declare -fr util_check_function_parameters_quantity

init "${@}"

## This script is based on the GNU Bash Shell Script Template project
## https://github.com/Lin-Buo-Ren/GNU-Bash-Shell-Script-Template
## and is based on the following version:
declare -r META_BASED_ON_GNU_BASH_SHELL_SCRIPT_TEMPLATE_VERSION="v2.0.1-2-g877ada8-dirty"
## You may rebase your script to incorporate new features and fixes from the template