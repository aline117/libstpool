#!/bin/bash

CPATH=$(cd `dirname $0`; pwd)
echo "PATH:$CPATH"

ARCH=$1
B_MD=$2
B_TYPE=$3
DIR_INSTALL=$4
echo "args:'$*'"

echo  --env--OPENSSL_ROOT:${OPENSSL_ROOT_DIR}
echo  --env--ZLIB_ROOT:${ZLIB_ROOT}
echo  --env--ZLIB_STATIC:${ZLIB_USE_STATIC_LIBS}
echo  --env--ZSTD_ROOT:${ZSTD_ROOT}

TOOLS_DIR=../../tools

build_dir=build_arch_${ARCH}
echo "  build dir:'${build_dir}'"

if [ -e "${CPATH}/${build_dir}" ] ; then
  echo "rmdir '${CPATH}/${build_dir}'"
  rmdir "${CPATH}/${build_dir}"
fi
echo "mkdir -p '${CPATH}/${build_dir}'"
mkdir -p "${CPATH}/${build_dir}"

BIN_CMAKE="cmake -S . -B ${build_dir}"
#IF(WIN32)
#  if "${ARCH}" == "32" (
#    BIN_CMAKE=${BIN_CMAKE} -A Win32
#  ) else (
#    BIN_CMAKE=${BIN_CMAKE} -A x64
#  )
#  if "${B_MD}" == "1" (
#    BIN_CMAKE=${BIN_CMAKE} -DBUILD_LIB_MD=ON
#  ) else (
#    BIN_CMAKE=${BIN_CMAKE} -DBUILD_LIB_MD=OFF
#  )
#ENDIF()

BIN_CMAKE="${BIN_CMAKE} -DLIBSTPOOL_DO_INSTALL=ON -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=${B_TYPE} -DCMAKE_INSTALL_PREFIX=${DIR_INSTALL}"
echo ${BIN_CMAKE}
${BIN_CMAKE}
#REM cmake -S . -B "${build_dir}" -DCMAKE_BUILD_TYPE=${B_TYPE} -DCMAKE_INSTALL_PREFIX=${DIR_INSTALL}
cmake --build "${build_dir}" --config ${B_TYPE} --parallel 16
cmake --install "${build_dir}" --config ${B_TYPE}


