project(InputTests)
cmake_minimum_required(VERSION 3.3)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(InputTests 
  inclusion.c index-action.c init-ast.c is-from-main-file.c locations.c reparse.c unsaved-file.c
  inclusion-header.h
)

target_include_directories(InputTests
PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}
PRIVATE
)

# target_compile_features(InputTests
# PUBLIC
# PRIVATE
# )
# target_link_libraries(InputTests
# PUBLIC
# PRIVATE
# )