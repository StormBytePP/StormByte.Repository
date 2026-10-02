if(NOT COMMAND buildmaster_component)
	add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/modules"
		"${CMAKE_CURRENT_BINARY_DIR}/stormbyte-buildmaster")
endif()
