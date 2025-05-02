include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(test_templ_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(test_templ_setup_options)
  option(test_templ_ENABLE_HARDENING "Enable hardening" ON)
  option(test_templ_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    test_templ_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    test_templ_ENABLE_HARDENING
    OFF)

  test_templ_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR test_templ_PACKAGING_MAINTAINER_MODE)
    option(test_templ_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(test_templ_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(test_templ_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test_templ_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(test_templ_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_templ_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(test_templ_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_templ_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_templ_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_templ_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(test_templ_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(test_templ_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_templ_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(test_templ_ENABLE_IPO "Enable IPO/LTO" ON)
    option(test_templ_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(test_templ_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(test_templ_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(test_templ_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(test_templ_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(test_templ_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(test_templ_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(test_templ_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(test_templ_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(test_templ_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(test_templ_ENABLE_PCH "Enable precompiled headers" OFF)
    option(test_templ_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      test_templ_ENABLE_IPO
      test_templ_WARNINGS_AS_ERRORS
      test_templ_ENABLE_USER_LINKER
      test_templ_ENABLE_SANITIZER_ADDRESS
      test_templ_ENABLE_SANITIZER_LEAK
      test_templ_ENABLE_SANITIZER_UNDEFINED
      test_templ_ENABLE_SANITIZER_THREAD
      test_templ_ENABLE_SANITIZER_MEMORY
      test_templ_ENABLE_UNITY_BUILD
      test_templ_ENABLE_CLANG_TIDY
      test_templ_ENABLE_CPPCHECK
      test_templ_ENABLE_COVERAGE
      test_templ_ENABLE_PCH
      test_templ_ENABLE_CACHE)
  endif()

  test_templ_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (test_templ_ENABLE_SANITIZER_ADDRESS OR test_templ_ENABLE_SANITIZER_THREAD OR test_templ_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(test_templ_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(test_templ_global_options)
  if(test_templ_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    test_templ_enable_ipo()
  endif()

  test_templ_supports_sanitizers()

  if(test_templ_ENABLE_HARDENING AND test_templ_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test_templ_ENABLE_SANITIZER_UNDEFINED
       OR test_templ_ENABLE_SANITIZER_ADDRESS
       OR test_templ_ENABLE_SANITIZER_THREAD
       OR test_templ_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${test_templ_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${test_templ_ENABLE_SANITIZER_UNDEFINED}")
    test_templ_enable_hardening(test_templ_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(test_templ_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(test_templ_warnings INTERFACE)
  add_library(test_templ_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  test_templ_set_project_warnings(
    test_templ_warnings
    ${test_templ_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(test_templ_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    test_templ_configure_linker(test_templ_options)
  endif()

  include(cmake/Sanitizers.cmake)
  test_templ_enable_sanitizers(
    test_templ_options
    ${test_templ_ENABLE_SANITIZER_ADDRESS}
    ${test_templ_ENABLE_SANITIZER_LEAK}
    ${test_templ_ENABLE_SANITIZER_UNDEFINED}
    ${test_templ_ENABLE_SANITIZER_THREAD}
    ${test_templ_ENABLE_SANITIZER_MEMORY})

  set_target_properties(test_templ_options PROPERTIES UNITY_BUILD ${test_templ_ENABLE_UNITY_BUILD})

  if(test_templ_ENABLE_PCH)
    target_precompile_headers(
      test_templ_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(test_templ_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    test_templ_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(test_templ_ENABLE_CLANG_TIDY)
    test_templ_enable_clang_tidy(test_templ_options ${test_templ_WARNINGS_AS_ERRORS})
  endif()

  if(test_templ_ENABLE_CPPCHECK)
    test_templ_enable_cppcheck(${test_templ_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(test_templ_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    test_templ_enable_coverage(test_templ_options)
  endif()

  if(test_templ_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(test_templ_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(test_templ_ENABLE_HARDENING AND NOT test_templ_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR test_templ_ENABLE_SANITIZER_UNDEFINED
       OR test_templ_ENABLE_SANITIZER_ADDRESS
       OR test_templ_ENABLE_SANITIZER_THREAD
       OR test_templ_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    test_templ_enable_hardening(test_templ_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
