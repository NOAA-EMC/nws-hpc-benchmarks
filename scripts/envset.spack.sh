# envset.spack - load the installed spack-stack Lmod modules.
# Source this in Bash before running cmake for ufs-weather-model or GSI.
# Lmod must already be initialized. No Spack activation or queries are needed.
# Compiler selection comes from the compiler module; MPI wrappers are on PATH.
#
# Usage: source /path/to/b2026_gb/envset.spack
# Defaults to the adjacent spack-stack-2.1.1 installation and its sole environment.
# Export SPACK_STACK_DIR and/or SPACK_ENV (an environment directory) to override.
# Multiple matching modules/environments are errors, not arbitrary selections.

_envset_spack() {
    local script_dir module_root module_files compiler_module compiler_version mpi_root
    local entry variable package prefix candidate mpi_include mpi_found
    local -a prefixes environments=()

    script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || return 1
    export SPACK_STACK_DIR="${SPACK_STACK_DIR:-${script_dir}/spack-stack-2.1.1}"
    if [[ ! -d "$SPACK_STACK_DIR" ]]; then
        echo "envset.spack: stack directory does not exist: $SPACK_STACK_DIR" >&2
        return 1
    fi
    SPACK_STACK_DIR=$(cd -- "$SPACK_STACK_DIR" && pwd -P) || return 1
    if [[ -z "${SPACK_ENV:-}" ]]; then
        for candidate in "$SPACK_STACK_DIR"/envs/*/spack.yaml; do
            [[ -f "$candidate" ]] && environments+=("${candidate%/spack.yaml}")
        done
        if [[ ${#environments[@]} -ne 1 ]]; then
            echo "envset.spack: set SPACK_ENV to one environment directory under $SPACK_STACK_DIR/envs." >&2
            return 1
        fi
        export SPACK_ENV="${environments[0]}"
    fi
    if [[ ! -f "$SPACK_ENV/spack.yaml" ]]; then
        echo "envset.spack: missing environment configuration: $SPACK_ENV/spack.yaml" >&2
        return 1
    fi
    export SPACK_ENV

    if ! type module >/dev/null 2>&1; then
        echo "envset.spack: initialize Lmod before sourcing this file." >&2
        return 1
    fi

    module_root="${SPACK_STACK_DIR}/spack/share/spack/lmod"
    if [[ ! -d "$module_root/Core" ]]; then
        echo "envset.spack: missing meta-modules; run spack stack setup-meta-modules for this stack." >&2
        return 1
    fi
    module_files=$(find "$module_root" -type f -name '*.lua') || return 1
    _envset_spack_load "$module_root/Core/stack-intel-oneapi-compilers/*.lua" || return 1
    compiler_module=$_envset_spack_module
    compiler_version=${compiler_module##*/}
    _envset_spack_load "$module_root/intel-oneapi-compilers/$compiler_version/stack-*/*.lua" || return 1

    # CMake reads FFLAGS on first configure; CMEPS/CDEPS omit MPI include paths.
    # Use the first root containing mpi.mod. MPI_ROOT/MPICH_DIR come from the spack-stack
    # MPI meta-module (cray-mpich prefix on gaea); for Intel MPI they are the top-level
    # oneAPI prefix without mpi.mod, so fall back to I_MPI_ROOT from Intel's mpi module.
    mpi_found=0
    for mpi_root in "${MPI_ROOT:-}" "${MPICH_DIR:-}" "${I_MPI_ROOT:-}"; do
        [[ -n "$mpi_root" ]] || continue
        for mpi_include in "$mpi_root/include" "$mpi_root/include/mpi"; do
            [[ -f "$mpi_include/mpi.mod" ]] && mpi_found=1
        done
        [[ "$mpi_found" -eq 1 ]] && break
    done
    if [[ "$mpi_found" -ne 1 ]]; then
        echo "envset.spack: the MPI meta-module did not provide a valid Fortran module directory." >&2
        return 1
    fi
    for mpi_include in "$mpi_root/include" "$mpi_root/include/mpi"; do
        [[ -d "$mpi_include" ]] || continue
        case " ${FFLAGS:-} " in
            *" -I${mpi_include} "*) ;;
            *) export FFLAGS="${FFLAGS:+${FFLAGS} }-I${mpi_include}" ;;
        esac
    done

    for package in \
        gmake cmake pkgconf hdf5 netcdf-c netcdf-fortran \
        python python-venv py-pyyaml esmf g2c \
        zlib-ng libpng parallelio jasper scotch \
        bacio crtm g2 g2tmpl gfsio ip nemsio sfcio sigio sp w3nco w3emc
    do
        _envset_spack_load "$module_root/*/$package/*.lua" || return 1
    done
    # The UFS snapshot requires FMS's deprecated I/O APIs.
    _envset_spack_load "$module_root/*/fms/2024.03-*.lua" || return 1

    # These aliases are required by find modules that do not use CMAKE_PREFIX_PATH.
    IFS=: read -r -a prefixes <<< "${CMAKE_PREFIX_PATH:-}"
    for entry in \
        ZLIB_ROOT:zlib-ng PNG_ROOT:libpng \
        NetCDF_C_ROOT:netcdf-c NetCDF_Fortran_ROOT:netcdf-fortran \
        PIO_ROOT:parallelio jasper_ROOT:jasper \
        ESMF_ROOT:esmf esmf_ROOT:esmf FMS_ROOT:fms SCOTCH_PATH:scotch \
        bacio_ROOT:bacio crtm_ROOT:crtm g2_ROOT:g2 g2tmpl_ROOT:g2tmpl \
        gfsio_ROOT:gfsio ip_ROOT:ip nemsio_ROOT:nemsio sfcio_ROOT:sfcio \
        sigio_ROOT:sigio sp_ROOT:sp w3nco_ROOT:w3nco w3emc_ROOT:w3emc
    do
        variable=${entry%%:*}
        package=${entry#*:}
        prefix=
        for candidate in "${prefixes[@]}"; do
            candidate=${candidate%/.}
            candidate=${candidate%/}
            case "$candidate" in
                */${package}-*)
                    prefix=$candidate
                    break
                    ;;
            esac
        done
        if [[ -z "$prefix" || ! -d "$prefix" ]]; then
            echo "envset.spack: no installed module prefix found for $package." >&2
            return 1
        fi
        export "$variable=$prefix"
    done
    export NetCDF_ROOT="${NetCDF_C_ROOT};${NetCDF_Fortran_ROOT}"
    if [[ ! -f "${ESMFMKFILE:-}" ]]; then
        echo "envset.spack: the ESMF module did not provide a valid ESMFMKFILE." >&2
        return 1
    fi
}

_envset_spack_load() {
    local pattern=$1 file module_dir
    local -a matches=()
    while IFS= read -r file; do
        if [[ "$file" == $pattern ]]; then
            matches+=("$file")
        fi
    done <<< "$module_files"
    if [[ ${#matches[@]} -ne 1 ]]; then
        printf 'envset.spack: expected one module matching %s, found %d.\n' \
            "$pattern" "${#matches[@]}" >&2
        return 1
    fi
    file=${matches[0]}
    module_dir=${file%/*}
    _envset_spack_module="${module_dir##*/}/${file##*/}"
    _envset_spack_module=${_envset_spack_module%.lua}
    module use "${module_dir%/*}" || return 1
    module load "$_envset_spack_module" || return 1
}

if _envset_spack; then
    unset -f _envset_spack _envset_spack_load
    unset _envset_spack_module
else
    unset -f _envset_spack _envset_spack_load
    unset _envset_spack_module
    return 1
fi
