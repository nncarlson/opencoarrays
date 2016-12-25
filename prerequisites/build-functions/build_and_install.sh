# Make the build directory, configure, and build
# shellcheck disable=SC2154

edit_GCC_download_prereqs_file_if_necessary()
{
  # Only modify download_prerequisites if wget is unavailable
  if type wget &> /dev/null; then
    info "wget available. Invoking unmodified GCC script contrib/download_prerequisites."
  else 
    info "wget unavailable. Editing GCC contrib/download_prerequisites to replace it with ${gcc_prereqs_fetch}"

    download_prereqs_file="${PWD}/contrib/download_prerequisites"
  
    # Define a file extension for the download_prerequisites backup
    backup_extension=".original"
    backup_file="${download_prereqs_file}${backup_extension}"
    if [[ "$(uname)" != "Linux" ]]; then
      # Adjust for POSIX OS (e.g., OSX/macOS):
      backup_extension=" ${backup_extension}"
    fi
    if [[ -f ${backup_file}  ]]; then
      # Prevent overwriting an existing backup:
      backup_extension=""
    fi
  
    # Grab the line with the first occurence of 'wget'
    wget_line=`grep wget "${download_prereqs_file}" | head -1` || true
    if [[ ! -z "${wget_line:-}"  ]]; then
      # Download_prerequisites contains wget so we haven't modified it
      already_modified_downloader="false"
    else 
      # Check whether a backup file already exists
      if [[ ! -f "${backup_file}" ]]; then
        emergency ": gcc contrib/download_prerequisites does not use wget"
      else
        already_modified_downloader="true"
      fi
    fi
  
    # Only modify download_prerequisites once
    if [[ ${already_modified_downloader} != "true"  ]]; then

      # Check for wget format used before GCC 7
      if [[ "${wget_line}" == *"ftp"* ]]; then
        gcc7_format="false"
        wget_command="${wget_line%%ftp*}" # grab everything before "ftp"

      # Check for wget format adopted in GCC 7
      elif [[  "${wget_line}" == *"base_url"* ]]; then 
        gcc7_format="true"
        if [[ "${gcc_prereqs_fetch}" == "ftp_url" ]]; then
          # Insert a new line after line 2 to include ftp_url.sh as a download option
          sed -i${backup_extension} -e '2 a\'$'\n'". ${OPENCOARRAYS_SRC_DIR}/prerequisites/build-functions/ftp_url.sh"$'\n' "${download_prereqs_file}"
          wget_command='wget --no-verbose -O "${directory}\/${ar}"'
        else
          wget_command="${wget_line%%\"\$\{base_url\}*}" # grab everything before "${base_url}
          wget_command="wget${wget_command#*wget}" # keep everything from wget forward
        fi

      else
        emergency "gcc contrib/download_prerequisites does not use a known URL format"
      fi
      info "GCC contrib/download_prerequisites wget command is ${wget_command}"

      arg_string="${gcc_prereqs_fetch_args[@]:-} "

      if [[ ${gcc7_format} == "true" ]]; then
        case "${gcc_prereqs_fetch}" in
          "curl")
            arg_string="${arg_string} -o "
          ;;
          *)
            debug "if problem downloading, ensure that the gcc download_prerequisites edits are compatible with ${gcc_prereqs_fetch}"  
          ;;
        esac
        # Protect against missing sha512sum command adopted in GCC 7 (not available by on a default on all Linux platforms)
        if ! type sha512sum &> /dev/null; then
          info "sha512sum unavailable. Turning off file integrity verification in GCC contrib/download_prerequisites."
          sed -i${backup_extension} s/"verify=1"/"verify=0"/ "${download_prereqs_file}"
        fi
      fi

      info "Using the following command to replacing wget in the GCC download_prerequisites file:"
      info "sed -i${backup_extension} s/\"${wget_command}\"/\"${gcc_prereqs_fetch} ${arg_string} \"/ \"${download_prereqs_file}\""
      sed -i${backup_extension} s/"${wget_command}"/"${gcc_prereqs_fetch} ${arg_string} "/ "${download_prereqs_file}"

    fi # end if [[ ${already_modified_downloader:-} != "true"  ]];
  fi # end if ! type wget &> /dev/null; 
}

build_and_install()
{
  num_threads=${arg_j}
  build_path="${OPENCOARRAYS_SRC_DIR}/prerequisites/builds/${package_to_build}-${version_to_build}"

  info "Building ${package_to_build} ${version_to_build}"
  info "Build path: ${build_path}"
  info "Installation path: ${install_path}"

  set_SUDO_if_needed_to_write_to_directory "${build_path}"
  set_SUDO_if_needed_to_write_to_directory "${install_path}"
  mkdir -p "${build_path}"
  info "pushd ${build_path}"
  pushd "${build_path}"

  if [[ "${package_to_build}" != "gcc" ]]; then

    info "Configuring ${package_to_build} ${version_to_build} with the following command:"
    info "FC=\"${FC:-'gfortran'}\" CC=\"${CC:-'gcc'}\" CXX=\"${CXX:-'g++'}\" \"${download_path}/${package_source_directory}\"/configure --prefix=\"${install_path}\""
    FC="${FC:-'gfortran'}" CC="${CC:-'gcc'}" CXX="${CXX:-'g++'}" "${download_path}/${package_source_directory}"/configure --prefix="${install_path}"
    info "Building with the following command:"
    info "FC=\"${FC:-'gfortran'}\" CC=\"${CC:-'gcc'}\" CXX=\"${CXX:-'g++'}\" make -j\"${num_threads}\""
    FC="${FC:-'gfortran'}" CC="${CC:-'gcc'}" CXX="${CXX:-'g++'}" make "-j${num_threads}"
    info "Installing ${package_to_build} in ${install_path}"
    if [[ ! -z "${SUDO:-}" ]]; then
      info "You do not have write permissions to the installation path ${install_path}"
      info "If you have administrative privileges, enter your password to install ${package_to_build}"
    fi
    info "Installing with the following command: ${SUDO:-} make install"
    ${SUDO:-} make install

  else # ${package_to_build} == "gcc"

    # Use GCC's contrib/download_prerequisites script after modifying it, if necessary, to use the
    # the preferred download mechanism set in prerequisites/build-functions/set_or_print_downloader.sh

    info "pushd ${download_path}/${package_source_directory} "
    pushd "${download_path}/${package_source_directory}"

    # Switch download mechanism, if wget is not available
    edit_GCC_download_prereqs_file_if_necessary
   
    # Download GCC prerequisities
    "${PWD}"/contrib/download_prerequisites

    info "popd"
    popd
    info "Configuring gcc/g++/gfortran builds with the following command:"
    info "${download_path}/${package_source_directory}/configure --prefix=${install_path} --enable-languages=c,c++,fortran,lto --disable-multilib --disable-werror"
    "${download_path}/${package_source_directory}/configure" --prefix="${install_path}" --enable-languages=c,c++,fortran,lto --disable-multilib --disable-werror
    info "Building with the following command: 'make -j${num_threads} bootstrap'"
    make "-j${num_threads}" bootstrap
    if [[ ! -z "${SUDO:-}" ]]; then
      info "You do not have write permissions to the installation path ${install_path}"
      info "If you have administrative privileges, enter your password to install ${package_to_build}"
    fi
    info "Installing with the following command: ${SUDO:-} make install"
    ${SUDO:-} make install

  fi # end if [[ "${package_to_build}" != "gcc" ]]; then
  
  info "popd"
  popd
}
