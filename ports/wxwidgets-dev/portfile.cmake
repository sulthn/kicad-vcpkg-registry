vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO wxWidgets/wxWidgets
    REF 1d0ddc90eced65e98ca9fc5f9e4f4b6b446d54bb
    SHA512 025d21932c850c72da20408c05af60e434a98880a25571924ff02487baa5fff4857dfee66b3ed78527cef4948a9c904b34d440e406c212a178653175c1564f5f 
    HEAD_REF master
    PATCHES
        install-layout.patch
        relocatable-wx-config.patch
        nanosvg-ext-depend.patch
        nanosvg.patch
        fix-libs-export.patch
        fix-pcre2.patch
        gtk3-link-libraries.patch
        secret-ime-fix.patch
)

vcpkg_from_github(
    OUT_SOURCE_PATH SCINTILLA_SOURCE_PATH
    REPO wxwidgets/scintilla
    REF 0b90f31ced23241054e8088abb50babe9a44ae67
    SHA512 db1f3007f4bd8860fad0817b6cf87980a4b713777025128cf5caea8d6d17b6fafe23fd22ff6886d7d5a420f241d85b7502b85d7e52b4ddb0774edc4b0a0203e7
    HEAD_REF wx
)

# Remove exisiting folder in case it was not cleaned
file(REMOVE_RECURSE "${SOURCE_PATH}/src/stc/scintilla")
# Copy the submodules to the right place
file(COPY "${SCINTILLA_SOURCE_PATH}/" DESTINATION "${SOURCE_PATH}/src/stc/scintilla")

vcpkg_from_github(
    OUT_SOURCE_PATH SCINTILLA_SOURCE_PATH
    REPO wxwidgets/lexilla
    REF 545d80ef30742956d96f21ed522c04d0ae524da9
    SHA512 bfd665b591aba36968afafa49752600d2e0c53a53c46915a0b2d5ddd7b2f41c8df26409fa637c0812f9a905636cb4408d7c7a4f3fd3d04319a4d65a8963cf334
    HEAD_REF wx
)

# Remove exisiting folder in case it was not cleaned
file(REMOVE_RECURSE "${SOURCE_PATH}/src/stc/lexilla")
# Copy the submodules to the right place
file(COPY "${SCINTILLA_SOURCE_PATH}/" DESTINATION "${SOURCE_PATH}/src/stc/lexilla")

vcpkg_from_github(
    OUT_SOURCE_PATH NANOSVG_SOURCE_PATH
    REPO memononen/nanosvg
    REF ea6a6aca009422bba0dbad4c80df6e6ba0c82183 # submodule commit as of d80887f3
    SHA512 e34196b93155d761a7060b5cc05da5fed0fad812916a28c923d190b011516bb9227641f0994eb705846fcab1d3d503a827336fa7ad9ac99a972e696d90830d8b
    HEAD_REF master
)

# Remove exisiting folder in case it was not cleaned
file(REMOVE_RECURSE "${SOURCE_PATH}/3rdparty/nanosvg")
# Copy the submodules to the right place
file(COPY "${NANOSVG_SOURCE_PATH}/" DESTINATION "${SOURCE_PATH}/3rdparty/nanosvg")


vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        media   wxUSE_MEDIACTRL
        sound   wxUSE_SOUND
        webview wxUSE_WEBVIEW
        webview wxUSE_WEBVIEW_EDGE
)

set(OPTIONS_RELEASE "")
if(NOT "debug-support" IN_LIST FEATURES)
    list(APPEND OPTIONS_RELEASE "-DwxBUILD_DEBUG_LEVEL=0")
endif()

set(OPTIONS "")
if(VCPKG_TARGET_IS_WINDOWS AND (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm"))
    list(APPEND OPTIONS
        -DwxUSE_STACKWALKER=OFF
    )
endif()

if(VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_OSX)
    list(APPEND OPTIONS -DwxUSE_WEBREQUEST_CURL=OFF)
else()
    list(APPEND OPTIONS -DwxUSE_WEBREQUEST_CURL=ON)
endif()

vcpkg_find_acquire_program(PKGCONFIG)

# This may be set to OFF by users in a custom triplet.
if(NOT DEFINED WXWIDGETS_USE_STD_CONTAINERS)
    set(WXWIDGETS_USE_STD_CONTAINERS ON)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DwxUSE_REGEX=sys
        -DwxUSE_ZLIB=sys
        -DwxUSE_EXPAT=sys
        -DwxUSE_LIBJPEG=sys
        -DwxUSE_LIBPNG=sys
        -DwxUSE_LIBTIFF=sys
        -DwxUSE_NANOSVG=sys
        -DwxUSE_GLCANVAS=ON
        -DwxUSE_LIBGNOMEVFS=OFF
        -DwxUSE_LIBNOTIFY=OFF
        -DwxUSE_SECRETSTORE=FALSE
        -DwxUSE_STD_CONTAINERS=${WXWIDGETS_USE_STD_CONTAINERS}
        ${OPTIONS}
        "-DPKG_CONFIG_EXECUTABLE=${PKGCONFIG}"
        # The minimum cmake version requirement for Cotire is 2.8.12.
        # however, we need to declare that the minimum cmake version requirement is at least 3.1 to use CMAKE_PREFIX_PATH as the path to find .pc.
        -DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=ON
    OPTIONS_RELEASE
        ${OPTIONS_RELEASE}
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/wxWidgets)

# The CMake export is not ready for use: It lacks a config file.
file(REMOVE_RECURSE
    ${CURRENT_PACKAGES_DIR}/lib/cmake
    ${CURRENT_PACKAGES_DIR}/debug/lib/cmake
)

set(tools wxrc)
if(NOT VCPKG_TARGET_IS_WINDOWS OR NOT VCPKG_HOST_IS_WINDOWS)
    list(APPEND tools wxrc-3.2)
    file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/tools/${PORT}")
    file(RENAME "${CURRENT_PACKAGES_DIR}/bin/wx-config" "${CURRENT_PACKAGES_DIR}/tools/${PORT}/wx-config")
    if(NOT VCPKG_BUILD_TYPE)
        file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug")
        file(RENAME "${CURRENT_PACKAGES_DIR}/debug/bin/wx-config" "${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug/wx-config")
    endif()
endif()
vcpkg_copy_tools(TOOL_NAMES ${tools} AUTO_CLEAN)

# do the copy pdbs now after the dlls got moved to the expected /bin folder above
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/msvc")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(GLOB_RECURSE INCLUDES "${CURRENT_PACKAGES_DIR}/include/*.h")
if(EXISTS "${CURRENT_PACKAGES_DIR}/lib/mswu/wx/setup.h")
    list(APPEND INCLUDES "${CURRENT_PACKAGES_DIR}/lib/mswu/wx/setup.h")
endif()
if(EXISTS "${CURRENT_PACKAGES_DIR}/debug/lib/mswud/wx/setup.h")
    list(APPEND INCLUDES "${CURRENT_PACKAGES_DIR}/debug/lib/mswud/wx/setup.h")
endif()
foreach(INC IN LISTS INCLUDES)
    file(READ "${INC}" _contents)
    if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
        string(REPLACE "defined(WXUSINGDLL)" "0" _contents "${_contents}")
    else()
        string(REPLACE "defined(WXUSINGDLL)" "1" _contents "${_contents}")
    endif()
    # Remove install prefix from setup.h to ensure package is relocatable
    string(REGEX REPLACE "\n#define wxINSTALL_PREFIX [^\n]*" "\n#define wxINSTALL_PREFIX \"\"" _contents "${_contents}")
    file(WRITE "${INC}" "${_contents}")
endforeach()

if(NOT EXISTS "${CURRENT_PACKAGES_DIR}/include/wx/setup.h")
    file(GLOB_RECURSE WX_SETUP_H_FILES_DBG "${CURRENT_PACKAGES_DIR}/debug/lib/*.h")
    file(GLOB_RECURSE WX_SETUP_H_FILES_REL "${CURRENT_PACKAGES_DIR}/lib/*.h")

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        vcpkg_replace_string("${WX_SETUP_H_FILES_REL}" "${CURRENT_PACKAGES_DIR}" "")

        string(REPLACE "${CURRENT_PACKAGES_DIR}/lib/" "" WX_SETUP_H_FILES_REL "${WX_SETUP_H_FILES_REL}")
        string(REPLACE "/setup.h" "" WX_SETUP_H_REL_RELATIVE "${WX_SETUP_H_FILES_REL}")
    endif()
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        vcpkg_replace_string("${WX_SETUP_H_FILES_DBG}" "${CURRENT_PACKAGES_DIR}" "")

        string(REPLACE "${CURRENT_PACKAGES_DIR}/debug/lib/" "" WX_SETUP_H_FILES_DBG "${WX_SETUP_H_FILES_DBG}")
        string(REPLACE "/setup.h" "" WX_SETUP_H_DBG_RELATIVE "${WX_SETUP_H_FILES_DBG}")
    endif()

    configure_file("${CMAKE_CURRENT_LIST_DIR}/setup.h.in" "${CURRENT_PACKAGES_DIR}/include/wx/setup.h" @ONLY)
endif()

file(GLOB configs LIST_DIRECTORIES false "${CURRENT_PACKAGES_DIR}/lib/wx/config/*" "${CURRENT_PACKAGES_DIR}/tools/${PORT}/wx-config")
foreach(config IN LISTS configs)
    vcpkg_replace_string("${config}" "${CURRENT_INSTALLED_DIR}" [[${prefix}]])
endforeach()
file(GLOB configs LIST_DIRECTORIES false "${CURRENT_PACKAGES_DIR}/debug/lib/wx/config/*" "${CURRENT_PACKAGES_DIR}/tools/${PORT}/debug/wx-config")
foreach(config IN LISTS configs)
    vcpkg_replace_string("${config}" "${CURRENT_INSTALLED_DIR}/debug" [[${prefix}]])
endforeach()

# For CMake multi-config in connection with wrapper
if(EXISTS "${CURRENT_PACKAGES_DIR}/debug/lib/mswud/wx/setup.h")
    file(INSTALL "${CURRENT_PACKAGES_DIR}/debug/lib/mswud/wx/setup.h"
        DESTINATION "${CURRENT_PACKAGES_DIR}/lib/mswud/wx"
    )
endif()

if(NOT "debug-support" IN_LIST FEATURES)
    if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_HOST_IS_WINDOWS)
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/wx/debug.h" "#define wxDEBUG_LEVEL 1" "#define wxDEBUG_LEVEL 0")
    else()
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/wx-3.2/wx/debug.h" "#define wxDEBUG_LEVEL 1" "#define wxDEBUG_LEVEL 0")
    endif()
endif()

if("example" IN_LIST FEATURES)
    file(INSTALL
        "${CMAKE_CURRENT_LIST_DIR}/example/CMakeLists.txt"
        "${SOURCE_PATH}/samples/popup/popup.cpp"
        "${SOURCE_PATH}/samples/sample.xpm"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/example"
    )
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/${PORT}/example/popup.cpp" "../sample.xpm" "sample.xpm")
endif()

configure_file("${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" "${CURRENT_PACKAGES_DIR}/share/wxwidgets/vcpkg-cmake-wrapper.cmake" @ONLY)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(INSTALL "${SOURCE_PATH}/docs/licence.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
