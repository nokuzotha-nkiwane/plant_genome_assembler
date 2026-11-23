#!/bin/bash
#PBS -l select=1:ncpus=64:mem=80GB
#PBS -q bix
#PBS -l walltime=96:00:00
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
module load app/Java/21.0.2
module load app/apptainer/1.2.5
