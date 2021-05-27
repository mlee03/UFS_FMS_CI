#!/bin/bash
set -eux

topdir=/lustre/f2/scratch/Mikyung.Lee/UFSFMS2021.02

source $topdir/NEMS/src/conf/module-setup.sh.inc
export PATH=/lustre/f2/pdata/esrl/gsd/contrib/miniconda3/4.8.3/envs/ufs-weather-model/bin:/lustre/f2/pdata/esrl/gsd/contrib/miniconda3/4.8.3/bin:$PATH

source /lustre/f2/pdata/esrl/gsd/contrib/lua-5.1.4.9/init/init_lmod.sh
module use -a $topdir/modulefiles
module load ufs_gaea.intel
module unload fms/2020.04.03

mkdir -p build
cd build

installdir=$topdir/FMS/FMS2021.02

cmake -DGFS_PHYS=ON -D64BIT=ON -DOPENMP=ON -DCMAKE_INSTALL_PREFIX=$installdir ..
make
