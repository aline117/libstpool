cmake_minimum_required(VERSION 3.15.2)

#list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)
#if (${CMAKE_VERSION} VERSION_LESS "3.17.0")
#  list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake-compat)
#endif()
#project(targets VERSION x.x.x LANGUAGES C)
project(libstpool LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/")

include(CheckTypeSize)
#include(CheckFileOffsetBits)
include(Macros)
include(CheckVariableExists)
include(CheckSymbolExists)
include(CheckStructHasMember)
include(CheckCSourceCompiles)
#include(CheckPrototypeDefinition)
#include(CheckFunctionKeywords)
#include(CheckConstExists)
include(AddCompilerFlags)
#include(VersionViaGit)

SET(DIR_ROOT    "${CMAKE_SOURCE_DIR}")
SET(DIR_CPP     "${DIR_ROOT}/c++")
SET(DIR_FACTORY "${DIR_ROOT}/factory")
SET(DIR_JNI     "${DIR_ROOT}/jni")
SET(DIR_MSGLOG  "${DIR_ROOT}/msglog")
SET(DIR_OS      "${DIR_ROOT}/os")
SET(DIR_POOL    "${DIR_ROOT}/pool")

option(BUILD_SHARED_LIBS "Build shared libraries" OFF)
option(LIBSTPOOL_DO_INSTALL "Install libzip and the related files" OFF)

IF(BUILD_SHARED_LIBS)
  ADD_DEFINITIONS(-D_USRDLL) #
ENDIF()
IF(MSVC)
  OPTION(BUILD_LIB_MD "using LIBCTR /MT /MTd or /MD /MDd for windows" ${BUILD_LIB_MD})
  SET(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>$<$<BOOL:${BUILD_LIB_MD}>:DLL>") #ver:3.15
#Definitions="_WIN64;_DEBUG;_WINDOWS;_USRDLL;_CRT_SECURE_NO_WARNINGS;CONFIG_TASK_ROUTINE_MP;CONFIG_LOG_COLOR_OFF;CONFIG_STATICS_REPORT"
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
  add_compile_definitions(_CRT_NONSTDC_NO_DEPRECATE)
  add_compile_definitions(CONFIG_TASK_ROUTINE_MP)
  add_compile_definitions(CONFIG_LOG_COLOR_OFF)
  add_compile_definitions(CONFIG_STATICS_REPORT)
ELSE()
  add_compile_definitions($<$<CONFIG:Debug>:_DEBUG> $<$<NOT:$<CONFIG:Debug>>:NDEBUG>)
  add_compile_definitions(_GNU_SOURCE)
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    add_compile_definitions(OS_W_64) 
  else()
    add_compile_definitions(OS_W_32) 
  endif()
  #$<IF:$<BOOL:${CMAKE_SIZEOF_VOID_P}>:OS_W_32,OS_W_64>
  #add_compile_definitions($<IF:$<BOOL:${__SIZEOF__}>:OS_W_64 -m64,OS_W_32>) 
  set(CMAKE_POSITION_INDEPENDENT_CODE ON) #-fPIC
ENDIF(MSVC)

if(WIN32)
  if(CMAKE_SYSTEM_NAME MATCHES WindowsPhone OR CMAKE_SYSTEM_NAME MATCHES WindowsStore)
    add_compile_definitions(MS_UWP)
  endif()
endif()

# rpath handling: use rpath in installed binaries
if(NOT CMAKE_SYSTEM_NAME MATCHES Linux)
  set(CMAKE_INSTALL_RPATH ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR})
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
endif()

# for code completion frameworks
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# The probes below link against libpthread (and librt, where clock_gettime()
# and sem_timedwait() still live for glibc < 2.17). Tell the check_* commands
# about it before the first probe, or they report false negatives.
if(NOT WIN32)
  set(CMAKE_REQUIRED_LIBRARIES pthread)
  if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    list(APPEND CMAKE_REQUIRED_LIBRARIES rt)
  endif()
endif()

# Check if header files exist
list(APPEND FILES_TO_CHECK
    stdint.h
    pthread.h
    time.h
    semaphore.h
)
IF (WIN32)
  list(APPEND FILES_TO_CHECK
    winsock2.h
  )
ELSE()
  list(APPEND FILES_TO_CHECK
    semaphore.h
    sys/prctl.h
)
ENDIF()
foreach(FILE ${FILES_TO_CHECK})
    CHECK_INCLUDE_FILE_CONCAT(${FILE} "")
endforeach()
unset(FILES_TO_CHECK)

# Check if functions exist
list(APPEND SYMBOLS_TO_CHECK
  pthread_attr_getinheritsched
  clock_gettime
  )
if (WIN32)
  list(APPEND SYMBOLS_TO_CHECK
    _gmtime64_s
    _gmtime64
    )
else()
  list(APPEND SYMBOLS_TO_CHECK
    prctl
    sem_timedwait
    pthread_condattr_setclock   # HAS_PTHREAD_CONDATTR_SETCLOCK (absent on Darwin)
    )
    if (APPLE)
      list(APPEND SYMBOLS_TO_CHECK mach_absolute_time)
    endif()
endif()
# Add stdio.h for vasprintf
#set(EVENT_INCLUDES ${EVENT_INCLUDES} stdio.h)
CHECK_SYMBOLS_EXIST("${SYMBOLS_TO_CHECK}" "${EVENT_INCLUDES}" "")
unset(SYMBOLS_TO_CHECK)

# Every switch that .help/.ospx_config.h.cmake asks for must be probed here,
# otherwise its #cmakedefine silently ends up "undef" on every platform:
#
#   HAS_STDINT_H                     <- CHECK_INCLUDE_FILE_CONCAT(stdint.h)
#   HAS_PTHREAD_RWLOCK               <- check_c_source_compiles(pthread_rwlock_t)
#   HAS_CLOCK_MONOTONIC              <- check_c_source_compiles(CLOCK_MONOTONIC)
#   HAS_CLOCK_GETTIME                <- CHECK_SYMBOLS_EXIST(clock_gettime)
#   HAS_PTHREAD_CONDATTR_SETCLOCK    <- CHECK_SYMBOLS_EXIST(pthread_condattr_setclock)
#   HAS_PTHREAD_ATTR_GETINHERITSCHED <- CHECK_SYMBOLS_EXIST(pthread_attr_getinheritsched)
#   HAS_SEM_TIMEDWAIT                <- CHECK_SYMBOLS_EXIST(sem_timedwait)
#   HAS_PRCTL                        <- CHECK_SYMBOLS_EXIST(prctl)
#
# NOTE: the four CHECK_TYPE_SIZE() calls that used to live here always failed
# ("Check size of ... - failed", all four variables end up empty, verified with
# cmake 3.27 + gcc):
#   - sem_timedwait / pthread_condattr_setclock are functions, not types;
#   - CLOCK_MONOTONIC / pthread_rwlock_t were probed without any #include
#     (CMAKE_EXTRA_INCLUDE_FILES was empty), so the identifiers were unknown.
# As a result HAS_SEM_TIMEDWAIT, HAS_PTHREAD_CONDATTR_SETCLOCK and
# HAS_PTHREAD_RWLOCK were never defined at all.
#
# HAS_CLOCK_GETTIME / HAS_SEM_TIMEDWAIT / HAS_PTHREAD_CONDATTR_SETCLOCK are
# already resolved by CHECK_SYMBOLS_EXIST() above, so only the two type/constant
# style probes are repeated here -- with the includes the autoconf script uses.
if(NOT WIN32)
  check_c_source_compiles("
#include <pthread.h>
int main(void) { pthread_rwlock_t lock; return (int)sizeof(lock); }
" HAS_PTHREAD_RWLOCK)

  # mirrors `configure`: clock_gettime(CLOCK_MONOTONIC, &ts) must compile+link
  check_c_source_compiles("
#include <time.h>
int main(void) { struct timespec ts; return (int)clock_gettime(CLOCK_MONOTONIC, &ts); }
" HAS_CLOCK_MONOTONIC)
endif()

# ---------------------------------------------------------------------------
# Turn the probe results into compile line switches.
#
# NOTE: we deliberately do NOT generate os/ospx_config.h here. ospx_type.h does
# `#include "ospx_config.h"`, which always resolves to the copy sitting next to
# it, so a generated file in the build tree would never be seen. The copy under
# os/ stays untouched as the fallback of the `./configure` + Makefile build and
# both have to stay in sync (the -D list below is exactly what it #defines).
# ---------------------------------------------------------------------------
if(APPLE)
  # ---- Darwin policy, do not relax ---------------------------------------
  # Darwin does not provide pthread_condattr_setclock(): its cond vars are
  # permanently bound to CLOCK_REALTIME and ospx.c uses the Apple specific
  # pthread_cond_timedwait_relative_np() instead. If either of these were
  # defined the library would not even link on Darwin, and the generic POSIX
  # path would build a CLOCK_MONOTONIC deadline for a CLOCK_REALTIME cond var,
  # so every timed wait would return ETIMEDOUT immediately (the pool then
  # degenerates into a busy polling loop).
  foreach(DARWIN_UNSUPPORTED HAS_PTHREAD_CONDATTR_SETCLOCK HAS_SEM_TIMEDWAIT)
    if(${DARWIN_UNSUPPORTED})
      message(WARNING
        "Darwin does not provide ${DARWIN_UNSUPPORTED}, forcing it off "
        "(a stale CMakeCache.txt from another platform?)")
      unset(${DARWIN_UNSUPPORTED} CACHE)
      set(${DARWIN_UNSUPPORTED} FALSE)
    endif()
  endforeach()
endif()

# Write the probe results into os/ospx_config.h, exactly like ./configure does it
# for the Makefile build: the template only carries the guard and the
# "#cmakedefine" list, the values come from the probes above (the Darwin policy a
# few lines up already forced the two unsupported switches off).
set(STPOOL_FEATURES_ON "")
foreach(FEATURE
    HAS_STDINT_H
    HAS_PTHREAD_RWLOCK
    HAS_CLOCK_GETTIME
    HAS_CLOCK_MONOTONIC
    HAS_PTHREAD_CONDATTR_SETCLOCK
    HAS_PTHREAD_ATTR_GETINHERITSCHED
    HAS_SEM_TIMEDWAIT
    HAS_PRCTL
    )
  if(${FEATURE})
    list(APPEND STPOOL_FEATURES_ON ${FEATURE})
  endif()
endforeach()
message(STATUS "libstpool features: ${STPOOL_FEATURES_ON}")

configure_file(
    ${DIR_ROOT}/.help/.ospx_config.h.cmake
    ${DIR_OS}/ospx_config.h
        NEWLINE_STYLE UNIX)
message(STATUS "libstpool config header: ${DIR_OS}/ospx_config.h")

# ---------------------------------------------------------------------------
# Optional diagnostics, only honoured by debug builds of the pool
# ---------------------------------------------------------------------------
option(LIBSTPOOL_TRACE_THREAD    "Trace the per thread scheduler/GC state (debug builds)" OFF)
option(LIBSTPOOL_ERR_THREAD_SAFE "Protect the OSPX last-error storage with a rwlock"      OFF)

set(STPOOL_CONFIG_DEFS "")
if(LIBSTPOOL_TRACE_THREAD)
  list(APPEND STPOOL_CONFIG_DEFS CONFIG_TRACE_THREAD_STATUS CONFIG_TRACE_THREAD_TIMEO)
endif()
if(LIBSTPOOL_ERR_THREAD_SAFE)
  # NOTE: the sources spell the two switches differently (OPSX/OSPX) and both
  # are needed: one declares the lock member, the other one uses it.
  list(APPEND STPOOL_CONFIG_DEFS CONFIG_OPSX_ERR_THREAD_SAFE CONFIG_OSPX_ERR_THREAD_SAFE)
endif()

# Targets
#include(CheckFunctionExists)
set(CMAKE_C_VISIBILITY_PRESET hidden)

set(CMAKE_INCLUDE_CURRENT_DIR TRUE)

set(msglog_src ${DIR_MSGLOG}/msglog.c )
set(msglog_inc ${DIR_MSGLOG}/msglog.h )
file(GLOB impl_inc_INC impl/include/*.h)

add_library(libmsglog ${msglog_inc} ${msglog_src} )
#add_library(libmsglog::msglog ALIAS libmsglog)
set(stpool_install_inc
  ${DIR_MSGLOG}/msglog.h
  ${DIR_ROOT}/stpool.h
  ${DIR_ROOT}/stpool_caps.h
  ${DIR_ROOT}/stpool_group.h
  )
set(stpool_src
  ${DIR_ROOT}/stpool.c
  ${DIR_ROOT}/stpool_group.c
  ${DIR_POOL}/com/cpool_com_method.c
  ${DIR_POOL}/com/cpool_wait.c
  ${DIR_POOL}/core/cpool_core.c
  ${DIR_POOL}/core/cpool_core_gc.c
  ${DIR_POOL}/gp/cpool_gp_advance_method.c
  ${DIR_POOL}/gp/cpool_gp_core_method.c
  ${DIR_POOL}/gp/cpool_gp_entry.c
  ${DIR_POOL}/gp/cpool_gp_factory.c
  ${DIR_POOL}/gp/cpool_gp_internal.c
  ${DIR_POOL}/gp/cpool_gp_method.c
  ${DIR_POOL}/gp/cpool_gp_wait.c
  ${DIR_POOL}/rt/cpool_rt_core_method.c
  ${DIR_POOL}/rt/cpool_rt_factory.c
  ${DIR_POOL}/rt/cpool_rt_internal.c
  ${DIR_POOL}/rt/cpool_rt_method.c
  ${DIR_POOL}/rt/cpool_rt_scheduler_dump.c
  ${DIR_POOL}/core/objpool.c
  ${DIR_POOL}/core/timer.c
  ${DIR_POOL}/core/sm_cache.c
  ${DIR_FACTORY}/cpool_factory.c
  ${DIR_OS}/ospx.c
  ${DIR_OS}/ospx_error.c
  )
set(stpool_inc
  ${stpool_install_inc}
  #${DIR_ROOT}/stpool.h
  #${DIR_ROOT}/stpool_caps.h
  #${DIR_ROOT}/stpool_group.h
  ${DIR_ROOT}/stpool_internal.h
  ${DIR_POOL}/com/cpool_com_internal.h
  ${DIR_POOL}/com/cpool_com_method.h
  ${DIR_POOL}/com/cpool_com_priq.h
  ${DIR_POOL}/com/cpool_wait.h
  ${DIR_POOL}/core/cache_creater.h
  ${DIR_POOL}/core/cpool_core.h
  ${DIR_POOL}/core/cpool_core_gc.h
  ${DIR_POOL}/core/cpool_core_struct.h
  ${DIR_POOL}/core/cpool_core_thread_status.h
  ${DIR_POOL}/core/list.h
  ${DIR_POOL}/core/objpool.h
  ${DIR_POOL}/core/sm_cache.h
  ${DIR_POOL}/core/timer.h
  ${DIR_FACTORY}/cpool_factory.h
  ${DIR_FACTORY}/cpool_method.h
  ${DIR_OS}/ospx.h
  ${DIR_OS}/ospx_compatible.h
  ${DIR_OS}/ospx_config.h
  ${DIR_OS}/ospx_errno.h
  ${DIR_OS}/ospx_error.h
  ${DIR_OS}/ospx_type.h
  )
add_library(libstpool ${stpool_inc} ${stpool_src} )
# HAS_* come from the generated os/ospx_config.h, only the optional diagnostics
# above are passed on the command line.
if(STPOOL_CONFIG_DEFS)
  target_compile_definitions(libstpool PRIVATE ${STPOOL_CONFIG_DEFS})
endif()
list(APPEND LIB_COM libstpool)
#add_library(libstpool ALIAS stpool)

list(APPEND demo_src mach_absolute_time)
IF(MSVC) #_MAC
  list(APPEND demo_src "${DIR_ROOT}/examples/demo-pri.c")
  add_executable(demo_win_c ${stpool_install_inc} "${DIR_ROOT}/examples/demo-pri.c" )
  target_link_libraries(demo_win_c PRIVATE libstpool)
ELSE()
  include_directories(${DIR_MSGLOG})
  list(APPEND demo_src "${DIR_ROOT}/examples/demo.c")
  list(APPEND demo_src "${DIR_ROOT}/examples/demo-pri.c")
  list(APPEND demo_src "${DIR_ROOT}/examples/demo-sche.c")
  list(APPEND demo_src "${DIR_ROOT}/examples/demo-group.c")
  list(APPEND demo_src "${DIR_ROOT}/examples/demo-overload.c")
  list(APPEND LIB_COM pthread m)
  if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    # clock_gettime()/sem_timedwait() live in librt before glibc 2.17
    list(APPEND LIB_COM rt)
  endif()
  add_executable(demo ${stpool_install_inc} "${DIR_ROOT}/examples/demo.c" )
  target_link_libraries(demo PRIVATE ${LIB_COM} )
  add_executable(demo-pri ${stpool_install_inc} "${DIR_ROOT}/examples/demo-pri.c" )
  target_link_libraries(demo-pri PRIVATE ${LIB_COM})
  add_executable(demo-sche ${stpool_install_inc} "${DIR_ROOT}/examples/demo-sche.c" )
  target_link_libraries(demo-sche PRIVATE ${LIB_COM})
  add_executable(demo-group ${stpool_install_inc} "${DIR_ROOT}/examples/demo-group.c" )
  target_link_libraries(demo-group PRIVATE ${LIB_COM})
  add_executable(demo-overload ${stpool_install_inc} "${DIR_ROOT}/examples/demo-overload.c" )
  target_link_libraries(demo-overload PRIVATE ${LIB_COM})
ENDIF()

###source group###
IF(MSVC) #_MAC
 source_group("include"                   FILES ${stpool_install_inc})
 source_group("src"                       FILES ${msglog_src}        )
 source_group("inc"                       FILES ${stpool_inc}        )
 source_group("src"                       FILES ${stpool_src}        )
 source_group("c++"                       FILES ${DIR_CPP}           )
 source_group("factory"                   FILES ${DIR_FACTORY}       )
 source_group("jni"                       FILES ${DIR_JNI}           )
 source_group("msglog"                    FILES ${DIR_MSGLOG}        )
 source_group("os"                        FILES ${DIR_OS}            )
 source_group("pool"                      FILES ${DIR_POOL}          )
 source_group("pool\\com"                 FILES ${DIR_POOL}/com      )
 source_group("pool\\core"                FILES ${DIR_POOL}/core     )
 source_group("pool\\gp"                  FILES ${DIR_POOL}/gp       )
 source_group("pool\\rt"                  FILES ${DIR_POOL}/rt       )
 source_group("src"                       FILES ${demo_src}          )
ENDIF()

target_link_libraries(libstpool PRIVATE libmsglog)
target_include_directories(libstpool  PRIVATE ${DIR_FACTORY} )
target_include_directories(libstpool  PRIVATE ${DIR_MSGLOG} )
target_include_directories(libstpool  PRIVATE ${DIR_OS} )
target_include_directories(libstpool  PRIVATE ${DIR_POOL})
target_include_directories(libstpool  PRIVATE ${DIR_POOL}/com)
target_include_directories(libstpool  PRIVATE ${DIR_POOL}/core)
target_include_directories(libstpool  PRIVATE ${DIR_POOL}/gp)
target_include_directories(libstpool  PRIVATE ${DIR_POOL}/rt)
#target_include_directories(libstpool  PRIVATE ${DIR_TRD}/lib/windows/${CMAKE_VS_PLATFORM_NAME}/st_$<IF:$<BOOL:${USE_LIB_MD}>,md,mt>/include)
IF(MSVC) #_MAC
  target_compile_options(libstpool PRIVATE $<$<CONFIG:Release>:/Zi>)
  set(SET_EH "/EHsc")
  set(COM_COMP_FLAGS "${SET_EH}")
  set(COM_COMP_FLAGS "${COM_COMP_FLAGS} /Oi /FC /Ot /W3 /Gy")
  set_property(TARGET libstpool libmsglog PROPERTY  MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>$<$<BOOL:${USE_LIB_MD}>:DLL>")
  #set_target_properties(libstpool PROPERTIES COMPILE_FLAGS      "${COM_COMP_FLAGS}" )

  #set_property(TARGET libmsglog PROPERTY  MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>$<$<BOOL:${USE_LIB_MD}>:DLL>")
  #set_target_properties(libmsglog PROPERTIES COMPILE_FLAGS      "${COM_COMP_FLAGS}" )
ELSE()
  set(COM_COMP_FLAGS "${COM_COMP_FLAGS} -Wall")
  if(CMAKE_SIZEOF_VOID_P EQUAL 8 AND NOT CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
    set(COM_COMP_FLAGS "${COM_COMP_FLAGS} -m64")
  endif()
ENDIF()
set_target_properties(libstpool libmsglog PROPERTIES COMPILE_FLAGS      "${COM_COMP_FLAGS}" )
#set_target_properties(libmsglog PROPERTIES COMPILE_FLAGS      "${COM_COMP_FLAGS}" )
set_target_properties(libstpool libmsglog PROPERTIES PREFIX "" )
#set_target_properties(${work} PROPERTIES
  #LINK_FLAGS "/DEBUG"            # DEBUG & RELEASE
  #LINK_FLAGS_DEBUG   "/DEBUG"    # olny DEBUG
  #LINK_FLAGS_RELEASE "/DEBUG"    # olny RELEASE
  #OUTPUT_NAME "demo${__SIZEOF__}"
  #OUTPUT_NAME "${workV1}"
  #VERSION 1.0.12
  #SOVERSION 0
  #)
#target_include_directories(zip
#  PUBLIC
#  $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/lib>
#  $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}>
#  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
#  )

if(LIBSTPOOL_DO_INSTALL)
  install(TARGETS libstpool libmsglog
    EXPORT ${PROJECT_NAME}-targets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
  install(FILES ${stpool_install_inc}
   DESTINATION include/stpool)
endif()

