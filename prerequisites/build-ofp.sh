#!/usr/bin/env bash
# BASH3 Boilerplate
#
# build-ofp.sh
#
#  - Build the Open Fortran Parser
#
# Usage: ./build-ofp.sh -i /opt
#
# More info:
#
#  - https://github.com/kvz/bash3boilerplate
#  - http://kvz.io/blog/2013/02/26/introducing-bash3boilerplate/
#
# Version: 2.0.0
#
# Authors:
#
#  - Kevin van Zonneveld (http://kvz.io)
#  - Izaak Beekman (https://izaakbeekman.com/)
#  - Alexander Rathai (Alexander.Rathai@gmail.com)
#  - Dr. Damian Rouson (http://www.sourceryinstitute.org/) (documentation)
#
# Licensed under MIT
# Copyright (c) 2013 Kevin van Zonneveld (http://kvz.io)

# The invocation of bootstrap.sh below performs the following tasks:
# (1) Import several bash3boilerplate helper functions & default settings.
# (2) Set several variables describing the current file and its usage page.
# (3) Parse the usage information (default usage file name: current file's name with -usage appended).
# (4) Parse the command line using the usage information.

### Start of boilerplate -- do not edit this block #######################
export OPENCOARRAYS_SRC_DIR="${OPENCOARRAYS_SRC_DIR:-${PWD%/}}"
if [[ ! -f "${OPENCOARRAYS_SRC_DIR}/src/libcaf.h" ]]; then
  echo "Please run this script inside the top-level OpenCoarrays source directory or "
  echo "set OPENCOARRAYS_SRC_DIR to the OpenCoarrays source directory path."
  exit 1
fi
export B3B_USE_CASE="${B3B_USE_CASE:-${OPENCOARRAYS_SRC_DIR}/prerequisites/use-case}"
if [[ ! -f "${B3B_USE_CASE:-}/bootstrap.sh" ]]; then
  echo "Please set B3B_USE_CASE to the bash3boilerplate use-case directory path."
  exit 2
else
    # shellcheck source=./prerequisites/use-case/bootstrap.sh
    source "${B3B_USE_CASE}/bootstrap.sh" "$@"
fi
### End of boilerplate -- start user edits below #########################

# Set up a function to call when receiving an EXIT signal to do some cleanup. Remove if
# not needed. Other signals can be trapped too, like SIGINT and SIGTERM.
function cleanup_before_exit () {
  info "Cleaning up. Done"
}
# TODO: investigate why this turns off errexit:
#trap cleanup_before_exit EXIT # The signal is specified here. Could be SIGINT, SIGTERM etc.

export __flag_present=1

# Verify requirements

[ -z "${LOG_LEVEL:-}" ] && emergency "Cannot continue without LOG_LEVEL. "

# shellcheck disable=SC2154
if [[ "${__os}" != "OSX" ]]; then
   echo "Source tranlsation via OFP is currently supported only on OS X."
   echo "Please submit an issue at http://github.com/sourceryinstitute/opencoarrays/issues."
   emergency "${PWD}/build-ofp.sh: Aborting."
fi

if [[ $(uname) == "Darwin"  ]]; then
  default_ofp_downloader=curl
  args="-LO"
else
  default_ofp_downloader=wget
  args="--no-check-certificate"
fi

# If -D is passed, print the download programs used for OFP and its prerequisites.
# Then exit with normal status.
# shellcheck  disable=SC2154
if [[ "${arg_D}" == "${__flag_present}" ]]; then
  echo "strategoxt-superbundle downloader: $("${OPENCOARRAYS_SRC_DIR}/prerequisites/install-binary.sh" -D strategoxt-superbundle)"
  echo "ofp-sdf default downloader: ${default_ofp_downloader}"
  exit 0
fi

# If -P is passed, print the default installation paths for OFP and its prerequisites.
# Then exit with normal status.
# shellcheck disable=SC2154
#install_path="${arg_b:-${OPENCOARRAYS_SRC_DIR}/prerequisits}"
strategoxt_superbundle_install_path=$("${OPENCOARRAYS_SRC_DIR}/prerequisites/install-binary.sh" -P strategoxt-superbundle)
# shellcheck disable=SC2154
if [[ "${arg_P}" == "${__flag_present}" ]]; then
  echo "strategoxt-superbundle default installation path: ${strategoxt_superbundle_install_path}"
  echo "ofp default installation path: ${install_path}"
  exit 0
fi

# If -V is passed, print the default versions of OFP and its prerequisites.
# Then exit with normal status.
default_ofp_version=sdf
# shellcheck disable=SC2154
if [[ "${arg_V}" == "${__flag_present}" ]]; then
  echo "strategoxt-superbundle default version: $("${OPENCOARRAYS_SRC_DIR}/prerequisites/install-binary.sh" -V strategoxt-superbundle)"
  echo "ofp default version: ${default_ofp_version}"
  exit 0
fi

# If -U is passed, print the URLs for OFP and its prerequisites.
# Then exit with normal status.
ofp_url_head="https://github.com/sourceryinstitute/opencoarrays/files/305727/"
ofp_url_tail="ofp-sdf.tar.gz"
# shellcheck disable=SC2154
if [[ "${arg_U}" == "${__flag_present}" ]]; then
  echo "strategoxt-superbundle URL: $("${OPENCOARRAYS_SRC_DIR}/prerequisites/install-binary.sh" -U strategoxt-superbundle)"
  echo "ofp URL: ${ofp_url_head}${ofp_url_tail}"
  exit 0
fi

### Print bootstrapped magic variables to STDERR when LOG_LEVEL
### is at the default value (6) or above.
#####################################################################
# shellcheck disable=SC2154
{
info "__file: ${__file}"
info "__dir: ${__dir}"
info "__base: ${__base}"
info "__os: ${__os}"
info "__usage: ${__usage}"
info "LOG_LEVEL: ${LOG_LEVEL}"

info "-b (--build-dir):        ${arg_b}"
info "-d (--debug):            ${arg_d}"
info "-D (--print-downloader): ${arg_D}"
info "-e (--verbose):          ${arg_e}"
info "-h (--help):             ${arg_h}"
info "-I (--install-version):  ${arg_I}"
info "-j (--num-threads):      ${arg_j}"
info "-n (--no-color):         ${arg_n}"
info "-P (--print-path):       ${arg_P}"
info "-U (--print-url):        ${arg_U}"
info "-V (--print-version):    ${arg_V}"
}
# Set OFP build path to the value of the -b or --build-dir argument if present.
# Otherwise, build OFP in the OpenCoarrays prerequisites/builds directory.
opencoarrays_prerequisites_dir="${OPENCOARRAYS_SRC_DIR}"/prerequisites/
build_path="${arg_b:-${opencoarrays_prerequisites_dir}/builds}"

# Change present working directory to installation directory
if [[ ! -d "${build_path}" ]]; then
  # shellcheck source=./build-functions/set_SUDO_if_needed_to_write_to_directory.sh
  source "${opencoarrays_prerequisites_dir}/build-functions/set_SUDO_if_needed_to_write_to_directory.sh"
  set_SUDO_if_needed_to_write_to_directory "${build_path}"
  ${SUDO:-} mkdir -p "${build_path}"
fi

export arg_y=${arg_y:-}
# Install OFP prerequisites to /opt (currently the only option)
"${opencoarrays_prerequisites_dir}"/install-binary.sh -p strategoxt-superbundle

# Downlaod OFP
pushd "${build_path}"
#info "OFP Download command: ${default_ofp_downloader} ${args:-} \"${ofp_url_head}${ofp_url_tail}\""
#${default_ofp_downloader} ${args:-} "${ofp_url_head}${ofp_url_tail}" 

# shellcheck source=./build-functions/download_if_necessary.sh
source "${OPENCOARRAYS_SRC_DIR:-}/prerequisites/build-functions/download_if_necessary.sh"
url_tail="${ofp_url_tail}" \
fetch="${default_ofp_downloader}" \
package_url="${ofp_url_head}${ofp_url_tail}" \
package_name="ofp" \
version_to_build="sdf" \
download_if_necessary

# shellcheck source=./build-functions/unpack_if_necessary.sh
source "${OPENCOARRAYS_SRC_DIR:-}/prerequisites/build-functions/unpack_if_necessary.sh"
url_tail="${ofp_url_tail}" \
fetch="${default_ofp_downloader}" \
package_name="ofp" \
version_to_build="sdf" \
unpack_if_necessary
mv -f ${OPENCOARRAYS_SRC_DIR}/prerequisites/downloads/ofp-sdf ${OPENCOARRAYS_SRC_DIR}/prerequisites/builds

popd

ofp_prereqs_install_dir="/opt"
export SDF2_PATH="${ofp_prereqs_install_dir}"/sdf2-bundle/v2.4/bin
export ST_PATH="${ofp_prereqs_install_dir}"/strategoxt/v0.17/bin
export DYLD_LIBRARY_PATH="${ofp_prereqs_install_dir}"/strategoxt/v0.17/lib:/opt/aterm/v2.5/lib

export OFP_HOME="${build_path}"/ofp-sdf
# shellcheck source=./install-binary-functions/build_parse_table.sh
source "${opencoarrays_prerequisites_dir}"/install-binary-functions/build_parse_table.sh
build_parse_table

# shellcheck source=./install-binary-functions/build_parse_table.sh
source "${opencoarrays_prerequisites_dir}"/install-binary-functions/build_source_transformation_rules.sh
build_source_transformation_rules
