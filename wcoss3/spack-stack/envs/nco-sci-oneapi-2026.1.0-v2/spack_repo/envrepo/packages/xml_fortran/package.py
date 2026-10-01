# Copyright Spack Project Developers. See COPYRIGHT file for details.
#
# SPDX-License-Identifier: (Apache-2.0 OR MIT)

from spack_repo.builtin.build_systems.makefile import MakefilePackage

from spack.package import *


class XmlFortran(MakefilePackage):
    """Parser for XML files in Fortran"""

    homepage = "https://github.com/paulromano/xml-fortran"
    git = "https://github.com/paulromano/xml-fortran"

    maintainers("AlexanderRichert-NOAA")

    license("BSD-3-Clause", checked_by="AlexanderRichert-NOAA")

    version("master", commit="ffe63a0591e86fc1c17a6cb673b56e633b15f906")

    depends_on("fortran", type="build")

    variant("debug", default=False, description="Enable debugging")

    def build(self, spec, prefix):
        if spec.satisfies("^[virtuals=fortran] intel-oneapi-compilers-classic"): compiler_name = "intel"
        elif spec.satisfies("^[virtuals=fortran] intel-oneapi-compilers"): compiler_name = "intel"
        else: compiler_name = "gfortran"
        debug = ["no", "yes"][spec.satisfies("+debug")]
        with working_dir(join_path(self.stage.source_path, "src")):
            make(f"COMPILER={compiler_name}", f"F90={spack_fc}", f"DEBUG={debug}", "-j1")

    def install(self, spec, prefix):
        with working_dir(join_path(self.stage.source_path, "src")):
            make("install")
            mkdirp(prefix.lib)
            install("libxmlparse.a", prefix.lib)
            mkdirp(prefix.include)
            for modfile in ("read_xml_primitives.mod", "write_xml_primitives.mod", "xmlparse.mod"):
                install(modfile, prefix.include)
