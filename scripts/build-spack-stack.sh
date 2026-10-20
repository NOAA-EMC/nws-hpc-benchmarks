#!/bin/bash

ENVNAME="nco-sci-oneapi-2026.0.0-v1"
MACHINE_ID="wcoss3"

case $(hostname -f) in
  gaea7[1-6])          MACHINE_ID=gaea-c7 ;; ### gaea71-76
  gaea7[1-6].ncrc.gov) MACHINE_ID=gaea-c7 ;; ### gaea71-76
  *)                   MACHINE_ID=unknown ;;
esac

git clone --recursive --branch spack-stack-2.1.1 https://github.com/JCSDA/spack-stack.git
mv spack-stack spack-stack-2.1.1
cd spack-stack-2.1.1
git submodule update --init --recursive

cd ../

##Clone here from git@github.com:NOAA-EMC/nws-hpc-benchmarks.git
#git clone --recursive git@github.com:NOAA-EMC/nws-hpc-benchmarks.git
mkdir -p spack-stack-2.1.1/envs


if [ "$MACHINE_ID" == "wcoss3" ]; then
  . /opt/intel/oneapi/compiler/2026.1/env/vars.sh
  cp -r nws-hpc-benchmarks/${MACHINE_ID}/spack-stack/envs/$ENVNAME spack-stack-2.1.1/envs/$ENVNAME
  cp nws-hpc-benchmarks/${MACHINE_ID}/patches/spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/python/package.py spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/python/package.py
  cp nws-hpc-benchmarks/${MACHINE_ID}/patches/spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/cmake/package.py spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/cmake/package.py
elif [ "$MACHINE_ID" == "gaea-c7" ]; then
  module load oneapi/2026.0.0
  module load cray-mpich/9.2.0
  cp -r nws-hpc-benchmarks/${MACHINE_ID}/spack-stack/envs/$ENVNAME spack-stack-2.1.1/envs/$ENVNAME
  cp nws-hpc-benchmarks/${MACHINE_ID}/patches/spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/python/package.py spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/python/package.py
  cp nws-hpc-benchmarks/${MACHINE_ID}/patches/spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/cmake/package.py spack-stack-2.1.1/repos/builtin/repos/spack_repo/builtin/packages/cmake/package.py
fi

#Concretize and install the Spack environment
cd spack-stack-2.1.1
source setup.sh
spack env activate envs/$ENVNAME
spack concretize -f
install_start=$SECONDS
spack install
install_status=$?
install_elapsed=$((SECONDS - install_start))

printf 'spack install took %d minutes and %d seconds\n' \
  "$((install_elapsed / 60))" "$((install_elapsed % 60))"

if [[ $install_status -ne 0 ]]; then
  exit "$install_status"
fi

#Build the modules
spack module lmod refresh --delete-tree -y
#Setup meta modules
spack stack setup-meta-modules


