#!/bin/bash

# A sourced build must not exit or change options in the calling shell.
if [[ $- == *i* && -z "${SLURM_JOB_ID:-}" ]]; then
  set +e
fi
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  if bash "${BASH_SOURCE[0]}" "$@"; then
    return 0
  else
    return $?
  fi
fi

set -e

export PW="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
#
# Build the ufs-weather-model against the libraries already built in the
# spack-stack environment (no simple-ufs build).
#
source "$(dirname -- "${BASH_SOURCE[0]}")/envset.spack.sh"

cd "$PW"
## Extract the source only once; re-extracting clobbers local CMake fixes
## (IntelLLVM.cmake, PIO SHARED). Delete ufs-weather-model to force a fresh untar.
#if [ ! -d ufs-weather-model ]; then
#  tar -xvf UFS.WEATHER.MODEL.tar
#fi
cd ufs-weather-model

# Some source archives omit the CVmix link expected by the MOM6 CMake list.
mom6_dir=MOM6-interface/MOM6
cvmix_dir="$mom6_dir/src/parameterizations/CVmix"
if [[ ! -e "$cvmix_dir" && ! -L "$cvmix_dir" ]]; then
  if [[ ! -f "$mom6_dir/pkg/CVMix-src/src/shared/cvmix_background.F90" ]]; then
    echo "MAKEUFS.spack.sh: missing MOM6/pkg/CVMix-src sources; restore the CVMix submodule or source archive." >&2
    exit 1
  fi
  ln -s ../../pkg/CVMix-src/src/shared "$cvmix_dir"
fi
for cvmix_source in background convection ddiff kinds_and_types kpp math put_get shear tidal utils; do
  if [[ ! -f "$cvmix_dir/cvmix_${cvmix_source}.F90" ]]; then
    echo "MAKEUFS.spack.sh: missing $cvmix_dir/cvmix_${cvmix_source}.F90; check the CVmix link and sources." >&2
    exit 1
  fi
done

mkdir -p exec
rm -rf build
mkdir build
cd build
cmake ..  -DAPP=S2SW -D32BIT=ON \
          -DCCPP_SUITES=FV3_GFS_v17_p8_ugwpv1,FV3_GFS_v17_coupled_p8_ugwpv1,FV3_global_nest_v1 \
          -DPDLIB=ON -DCMAKE_BUILD_TYPE=Release -DMPI=ON
make -j 8 VERBOSE=1
cp ufs_model ../exec/ufs_model.x
cd ..
