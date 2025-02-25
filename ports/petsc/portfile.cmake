# Original petsc port written by Albert Ziegenhagel https://github.com/albertziegenhagel/vcpkg
# Updated to the latest vcpkg and petsc for use in KiCad

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO petsc/petsc
    REF "v${VERSION}"
    SHA512 055b4fbad50415296112ba74d543ef3162fff741212237d11c4320485f9d1a20c83356efe8d54cbd2434cd5df15218572e52589d9a4033275c63fc347e4065dd
)

# Prepare msys
vcpkg_acquire_msys(MSYS_ROOT 
        PACKAGES diffutils make
        DIRECT_PACKAGES
            "https://repo.msys2.org/msys/x86_64/python-3.11.5-1-x86_64.pkg.tar.zst"
            f5a3a5a5b6f5bd5f6b23d6f1ea6cef0cec8b1803c73aedb0c10b4a77a36e759efa388bc37b421bb8b1cd9f1815b3238f35f9598ebf87217d1a34b2c88869b05b
            # needed for python hash functions to work
            "https://repo.msys2.org/msys/x86_64/libopenssl-3.1.2-1-x86_64.pkg.tar.zst"
            0616d825f683dd374299e2e0d824ba04b87e37f2662bb6097e53cd116385bd35811b7d342b94cc49d2fe80c0f068b0ba67d89fbcbf8d137449597c8120d73dde)
vcpkg_add_to_path("${MSYS_ROOT}/usr/bin")
set(BASH ${MSYS_ROOT}/usr/bin/bash.exe)
set(CYGPATH ${MSYS_ROOT}/usr/bin/cygpath.exe)

macro(to_msys_path PATH OUTPUT_VAR)
    execute_process(
        COMMAND ${CYGPATH} "${PATH}"
        OUTPUT_VARIABLE ${OUTPUT_VAR}
        ERROR_VARIABLE ${OUTPUT_VAR}
        RESULT_VARIABLE error_code
    )
    if(error_code)
        message(FATAL_ERROR "cygpath failed: ${${OUTPUT_VAR}}")
    endif()
    string(REGEX REPLACE "\n" "" ${OUTPUT_VAR} "${${OUTPUT_VAR}}")
endmacro()

to_msys_path("${CURRENT_PACKAGES_DIR}"            MSYS_PACKAGES_DIR)
to_msys_path("${SOURCE_PATH}"                     MSYS_SOURCE_PATH)
to_msys_path("${CURRENT_INSTALLED_DIR}"           VCPKG_INSTALL_DIR)
to_msys_path("${CURRENT_INSTALLED_DIR}/include"   VCPKG_INSTALL_INCLUDE_DIR)
to_msys_path("${CURRENT_INSTALLED_DIR}/lib"       VCPKG_INSTALL_RELEASE_LIB_DIR)
to_msys_path("${CURRENT_INSTALLED_DIR}/debug/lib" VCPKG_INSTALL_DEBUG_LIB_DIR)
to_msys_path("${CURRENT_INSTALLED_DIR}/bin"       VCPKG_INSTALL_RELEASE_BIN_DIR)
to_msys_path("${CURRENT_INSTALLED_DIR}/debug/bin" VCPKG_INSTALL_DEBUG_BIN_DIR)

# Select compilers
set(PETSC_C_COMPILER "win32fe cl")
set(PETSC_CXX_COMPILER "win32fe cl")
# Fortran disabled unless we need it later
set(PETSC_FORTRAN_COMPILER "0")

# Generic options
set(OPTIONS
    "${MSYS_SOURCE_PATH}/config/configure.py"
    "--with-cc=${PETSC_C_COMPILER}"
    "--with-cxx=${PETSC_CXX_COMPILER}"
    "--with-fc=${PETSC_FORTRAN_COMPILER}"
    "--with-ar=win32fe lib"
    "--ignore-cygwin-link"
    # "--CC_LINKER_FLAGS=-DEBUG -INCREMENTAL:NO -OPT:REF -OPT:ICF"
    # "--CXX_LINKER_FLAGS=-DEBUG -INCREMENTAL:NO -OPT:REF -OPT:ICF"
)

# Select CRT flag
if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
    set(RUNTIME_FLAG_NAME "MD")
else()
    set(RUNTIME_FLAG_NAME "MT")
endif()

string( APPEND ADDITIONAL_CXX_FLAGS "-D_CRT_SECURE_NO_WARNINGS -Zc:preprocessor" )
string( APPEND ADDITIONAL_C_FLAGS "-D_CRT_SECURE_NO_WARNINGS -Zc:preprocessor" )

# Release and Debug options.
# Libraries paths have to be passed explicitly because PETSc is always prefixing library names with 'lib' on windows if no absolute path is passed.
set(OPTIONS_RELEASE
    "--with-debugging=0"
    "--prefix=${MSYS_PACKAGES_DIR}"
    "--CFLAGS=-${RUNTIME_FLAG_NAME} -O2 -Oi -Gy -DNDEBUG -Z7 -DWIN32 -D_WINDOWS -W3 -utf-8 -MP ${ADDITIONAL_C_FLAGS}"
    "--CXXFLAGS=-${RUNTIME_FLAG_NAME} -O2 -Oi -Gy -DNDEBUG -Z7 -DWIN32 -D_WINDOWS -W3 -utf-8 -GR -EHsc -MP ${ADDITIONAL_CXX_FLAGS}"
    "--FFLAGS=${FFLAGS_RELEASE}"
    "--CPPFLAGS=-DNDEBUG -DWIN32 -D_WINDOWS ${ADDITIONAL_C_FLAGS}"
    "--CXXCPPFLAGS=-DNDEBUG -DWIN32 -D_WINDOWS ${ADDITIONAL_C_FLAGS}"
    "--with-blas-lib=${VCPKG_INSTALL_RELEASE_LIB_DIR}/openblas.lib"
    "--with-lapack-lib=${VCPKG_INSTALL_RELEASE_LIB_DIR}/lapack.lib"
)

set(OPTIONS_DEBUG
    "--with-debugging=1"
    "--prefix=${MSYS_PACKAGES_DIR}/debug"
    "--CFLAGS=-${RUNTIME_FLAG_NAME}d -D_DEBUG -Z7 -Ob0 -Od -RTC1 ${ADDITIONAL_C_FLAGS}"
    "--CXXFLAGS=-${RUNTIME_FLAG_NAME}d -D_DEBUG -Z7 -Ob0 -Od -RTC1 ${ADDITIONAL_CXX_FLAGS}"
    "--FFLAGS=${FFLAGS_DEBUG}"
    "--CPPFLAGS=-D_DEBUG ${ADDITIONAL_C_FLAGS}"
    "--CXXCPPFLAGS=-D_DEBUG ${ADDITIONAL_C_FLAGS}"
    "--with-blas-lib=${VCPKG_INSTALL_DEBUG_LIB_DIR}/openblas.lib"
    "--with-lapack-lib=${VCPKG_INSTALL_DEBUG_LIB_DIR}/lapack.lib"
)

list(APPEND OPTIONS "--with-mpi-include=${VCPKG_INSTALL_INCLUDE_DIR}")
list(APPEND OPTIONS_RELEASE "--with-mpi-lib=${VCPKG_INSTALL_RELEASE_LIB_DIR}/msmpi.lib")
list(APPEND OPTIONS_DEBUG "--with-mpi-lib=${VCPKG_INSTALL_DEBUG_LIB_DIR}/msmpi.lib")

if("metis" IN_LIST FEATURES)
    list(APPEND OPTIONS "--with-metis-include=${VCPKG_INSTALL_INCLUDE_DIR}")
    list(APPEND OPTIONS_RELEASE "--with-metis-lib=${VCPKG_INSTALL_RELEASE_LIB_DIR}/metis.lib ${VCPKG_INSTALL_RELEASE_LIB_DIR}/gklib.lib")
    list(APPEND OPTIONS_DEBUG "--with-metis-lib=${VCPKG_INSTALL_DEBUG_LIB_DIR}/metis.lib ${VCPKG_INSTALL_DEBUG_LIB_DIR}/gklib.lib")
    list(APPEND EXTRA_LIBS_RELEASE "")
    list(APPEND EXTRA_LIBS_DEBUG "")
endif()

if("hypre" IN_LIST FEATURES)
    list(APPEND OPTIONS "--with-hypre-include=${VCPKG_INSTALL_INCLUDE_DIR}")
    list(APPEND OPTIONS_RELEASE "--with-hypre-lib=${VCPKG_INSTALL_RELEASE_LIB_DIR}/HYPRE.lib")
    list(APPEND OPTIONS_DEBUG "--with-hypre-lib=${VCPKG_INSTALL_DEBUG_LIB_DIR}/HYPRE.lib")
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    list(APPEND OPTIONS "--with-shared-libraries=1")
else()
    list(APPEND OPTIONS "--with-shared-libraries=0")
endif()

if( EXTRA_LIBS_RELEASE )
    list(APPEND OPTIONS_RELEASE "--LIBS='${EXTRA_LIBS_RELEASE}'")
endif()

if( EXTRA_LIBS_DEBUG )
    list(APPEND OPTIONS_DEBUG "--LIBS='${EXTRA_LIBS_DEBUG}'")
endif()

message(STATUS "Building petsc for Release")
file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel)
vcpkg_execute_required_process(
    COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}\\build.sh"
        "${SOURCE_PATH}" # BUILD DIR : In source build
        "${VCPKG_INSTALL_RELEASE_BIN_DIR}"
        "${TARGET_TRIPLET}-rel"
        ${OPTIONS} ${OPTIONS_RELEASE}
    WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel
    LOGNAME build-${TARGET_TRIPLET}-rel
)

message(STATUS "Building petsc for Debug")
file(MAKE_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg)
vcpkg_execute_required_process(
    COMMAND ${BASH} --noprofile --norc "${CMAKE_CURRENT_LIST_DIR}\\build.sh"
        "${SOURCE_PATH}" # BUILD DIR : In source build
        "${VCPKG_INSTALL_DEBUG_BIN_DIR}"
        "${TARGET_TRIPLET}-dbg"
        ${OPTIONS} ${OPTIONS_DEBUG}
    WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg
    LOGNAME build-${TARGET_TRIPLET}-dbg
)

# Remove examples
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/share/petsc/examples)

# Remove the generated executables
file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools)
file(RENAME ${CURRENT_PACKAGES_DIR}/lib/petsc/bin ${CURRENT_PACKAGES_DIR}/tools/petsc)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/tools/petsc/__pycache__") # Cruft that might get copied
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/bin)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/lib/petsc/bin)

# Move the dlls to the bin folder
file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/bin)
file(MAKE_DIRECTORY ${CURRENT_PACKAGES_DIR}/debug/bin)
file(RENAME ${CURRENT_PACKAGES_DIR}/lib/libpetsc.dll ${CURRENT_PACKAGES_DIR}/bin/libpetsc.dll)
file(RENAME ${CURRENT_PACKAGES_DIR}/lib/libpetsc.pdb ${CURRENT_PACKAGES_DIR}/bin/libpetsc.pdb)
file(RENAME ${CURRENT_PACKAGES_DIR}/debug/lib/libpetsc.dll ${CURRENT_PACKAGES_DIR}/debug/bin/libpetsc.dll)
file(RENAME ${CURRENT_PACKAGES_DIR}/debug/lib/libpetsc.pdb ${CURRENT_PACKAGES_DIR}/debug/bin/libpetsc.pdb)

# Patch config files
function(fix_petsc_config_file FILEPATH)
    file(READ "${FILEPATH}" FILE_CONTENT)
    string(REPLACE "${MSYS_PACKAGES_DIR}/debug/lib/petsc/bin" "${VCPKG_INSTALL_DIR}/tools" FILE_CONTENT "${FILE_CONTENT}")
    string(REPLACE "${MSYS_PACKAGES_DIR}/debug/include" "${VCPKG_INSTALL_DIR}/include" FILE_CONTENT "${FILE_CONTENT}")
    string(REPLACE "${MSYS_PACKAGES_DIR}/lib/petsc/bin" "${VCPKG_INSTALL_DIR}/tools" FILE_CONTENT "${FILE_CONTENT}")
    string(REPLACE "${MSYS_PACKAGES_DIR}" "${VCPKG_INSTALL_DIR}" FILE_CONTENT "${FILE_CONTENT}")
    file(WRITE "${FILEPATH}" "${FILE_CONTENT}")
endfunction()

fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/lib/petsc/conf/variables")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/lib/petsc/conf/rules")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/lib/petsc/conf/petscvariables")

fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/debug/lib/petsc/conf/variables")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/debug/lib/petsc/conf/rules")
fix_petsc_config_file("${CURRENT_PACKAGES_DIR}/debug/lib/petsc/conf/petscvariables")

# Remove other debug folders
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/share)

# Handle copyright
file(COPY ${SOURCE_PATH}/LICENSE DESTINATION ${CURRENT_PACKAGES_DIR}/share/petsc)
file(RENAME ${CURRENT_PACKAGES_DIR}/share/petsc/LICENSE ${CURRENT_PACKAGES_DIR}/share/petsc/copyright)