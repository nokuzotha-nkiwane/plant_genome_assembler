#!/bin/bash
#PBS -l select=1:ncpus=4:mem=40GB
#PBS -q bix
#PBS -l walltime=8:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate ragtag

#resource allocation
THREADS=2
