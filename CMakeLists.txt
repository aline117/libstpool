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
  add_compile_definitions($<$<CONFIG:Debug>:_DEBUG,NDEBUG>)
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
    )
    if (APPLE)
      list(APPEND SYMBOLS_TO_CHECK mach_absolute_time)
    endif()
endif()
# Add stdio.h for vasprintf
#set(EVENT_INCLUDES ${EVENT_INCLUDES} stdio.h)
CHECK_SYMBOLS_EXIST("${SYMBOLS_TO_CHECK}" "${EVENT_INCLUDES}" "")
unset(SYMBOLS_TO_CHECK)

# Only `CHECK_TYPE_SIZE()' will use `CMAKE_EXTRA_INCLUDE_FILES'
set(CMAKE_EXTRA_INCLUDE_FILES ${EVENT_INCLUDES})
CHECK_TYPE_SIZE("CLOCK_MONOTONIC"  HAS_CLOCK_MONOTONIC)
CHECK_TYPE_SIZE("pthread_rwlock_t" HAS_PTHREAD_RWLOCK)
CHECK_TYPE_SIZE("sem_timedwait"    HAS_SEM_TIMEDWAIT)
CHECK_TYPE_SIZE("pthread_condattr_setclock" HAS_PTHREAD_CONDATTR_SETCLOCK)

configure_file(
    ${DIR_ROOT}/.help/.ospx_config.h.cmake
    ${DIR_OS}/ospx_config.h
        NEWLINE_STYLE UNIX)

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
  list(APPEND LIB_COM pthread m rt)
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

