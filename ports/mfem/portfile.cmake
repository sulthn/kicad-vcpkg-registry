vcpkg_minimum_required(VERSION 2022-10-12) # for ${VERSION}
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mfem/mfem
    REF "v${VERSION}"
    SHA512 819519c061fa96d3cd735090085c86c0d46e6344a69712b9b2af087ea9ce56ab3446fd9b3055f80a5d8b2a61f944497319980fc951a857c7aeef88c62b154b8e
    PATCHES
        additional-metis-libs.patch
        additional-hypre-libs.patch
)

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        mpi     MFEM_USE_MPI
)

set(OPTIONS_DEBUG "")
set(OPTIONS_RELEASE "")

if("mpi" IN_LIST FEATURES)
    list(APPEND OPTIONS_DEBUG "-DMETIS_DIR=${CURRENT_INSTALLED_DIR}/debug/lib")
    list(APPEND OPTIONS_RELEASE "-DMETIS_DIR=${CURRENT_INSTALLED_DIR}/lib")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}    
    OPTIONS_RELEASE
        ${OPTIONS_RELEASE}
    OPTIONS_DEBUG
        ${OPTIONS_DEBUG}
)

vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_cmake_config_fixup(
    CONFIG_PATH lib/cmake/${PORT}
)

# remove the absolute paths in the file, it seems its for loading OCCA kernels at startup
# but we cant support that anyway
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/mfem/config/_config.hpp" "${SOURCE_PATH}" "")
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/mfem/config/_config.hpp" "${CURRENT_PACKAGES_DIR}" "")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")