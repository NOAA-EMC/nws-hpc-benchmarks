# EMC Repository Template

Getting all the right files in the right place can be a pain. 
This is a simple template repository that you can use to ensure you have all the right files present in your repo.

## Files you need

These should be at the top level of your repository:

* `README.md` - The `README.md` file should have a short section at the bottom
  called "DISCLAIMER", with a really brief statement saying that code is provided on an "as is" basis, and the user assumes responsibility for its use.
* `LICENSE` - The text of the `CC0` license.
* `DISCLAIMER` - Disclaimer 
   
## License

This project is part of NOAA-EMC Ecosystem. 

See LICENSE and DISCLAIMER for details.

## Building UFS with an installed Spack stack

Keep `nws-hpc-benchmarks`, `spack-stack-2.1.1`, and `ufs-weather-model`
in the same parent directory. With Lmod initialized, run from that directory:

```bash
source nws-hpc-benchmarks/scripts/envset.spack.sh
bash nws-hpc-benchmarks/scripts/MAKEUFS.spack.sh
```

The environment loader defaults to the sibling stack and its sole environment.
Export `SPACK_STACK_DIR` and/or `SPACK_ENV` (an environment directory) to override.
It loads generated, hash-suffixed Intel compiler/MPI modules directly when present;
site-provided toolchains use the stack meta-modules instead. Module selection must
be unambiguous.

Run the build scripts with Bash. Sourcing either build script is also supported:
it runs the build in a child Bash process so `exit`, directory changes, and shell
options stay isolated. Build errors stop the child and return a nonzero status.
The Spack build now stops on setup errors as well as installation errors.

When sourced in an interactive shell outside Slurm (`SLURM_JOB_ID` is unset or
empty), all three scripts disable `errexit` (`set +e`) in the caller. This also
clears `set -e` left by an earlier sourced build, preventing an error return from
closing the session. Noninteractive and Slurm shells keep their existing
`errexit` behavior; batch failures still return nonzero.

The UFS build recreates the model's `build` directory. Its environment is loaded
automatically inside the child; source the environment loader separately when
the environment is also needed in the current shell. Sourcing the Spack build
likewise does not activate Spack in the calling shell.
