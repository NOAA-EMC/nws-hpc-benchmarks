#!/bin/bash

MACHINE_ID="wcoss3"

case $(hostname -f) in
  gaea7[1-6])          MACHINE_ID=gaea-c7 ;; ### gaea71-76
  gaea7[1-6].ncrc.gov) MACHINE_ID=gaea-c7 ;; ### gaea71-76
  wcoss3*)             MACHINE_ID=wcoss3 ;; ### wcoss3 login nodes
  *)                   MACHINE_ID=unknown ;;
esac

#Choose the environment from nws-hpc-benchmarks/${MACHINE_ID}/spack-stack/envs
ENVS_DIR="nws-hpc-benchmarks/${MACHINE_ID}/spack-stack/envs"
if [[ ! -d "$ENVS_DIR" ]]; then
  echo "Environment directory not found: $ENVS_DIR (MACHINE_ID=$MACHINE_ID)" >&2
  exit 1
fi
envs=()
for dir in "$ENVS_DIR"/*/; do
  [[ -f "${dir}spack.yaml" ]] && envs+=("$(basename "$dir")")
done
if [[ ${#envs[@]} -eq 0 ]]; then
  echo "No environments (with spack.yaml) found in $ENVS_DIR" >&2
  exit 1
fi
echo "Available spack-stack environments for $MACHINE_ID:"
for i in "${!envs[@]}"; do
  printf '  %d) %s\n' "$((i + 1))" "${envs[i]}"
done
while true; do
  read -r -p "Select environment [1-${#envs[@]}]: " choice || exit 1
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#envs[@]} )); then
    ENVNAME="${envs[choice - 1]}"
    break
  fi
  echo "Invalid choice: '$choice'" >&2
done
echo "Using environment: $ENVNAME"

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


