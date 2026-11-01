cmake_minimum_required(VERSION 3.20)
project(sds VERSION "${SDS_VERSION}" LANGUAGES C)

include(GNUInstallDirs)
include(CTest)

add_library(sds SHARED sds.c)
set_target_properties(sds PROPERTIES VERSION "${PROJECT_VERSION}" SOVERSION 2)
target_include_directories(sds PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/sds>
)

install(TARGETS sds LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(FILES sds.h sdsalloc.h DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/sds")

file(CONFIGURE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/sds.pc" CONTENT
"prefix=@CMAKE_INSTALL_PREFIX@
libdir=\${prefix}/@CMAKE_INSTALL_LIBDIR@
includedir=\${prefix}/@CMAKE_INSTALL_INCLUDEDIR@

Name: sds
Description: Simple dynamic strings library
Version: @PROJECT_VERSION@
Libs: -L\${libdir} -lsds
Cflags: -I\${includedir}/sds
" @ONLY)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/sds.pc"
	DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")

if(BUILD_TESTING)
	add_executable(sds-test sds.c)
	target_compile_definitions(sds-test PRIVATE SDS_TEST_MAIN)
	add_test(NAME sds COMMAND sds-test)
endif()
