#!/bin/bash
#PBS -l select=2:ncpus=8:mem=20GB
#PBS -P PROJECT_NAME
#PBS -q serial
#PBS -N STEP_PBS
#PBS -l walltime=4:00:00
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m abe
#PBS -M PBS_EMAIL

#kill execution at first error
set -euox pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
JELLYFISH_HISTO="${ALL_RESULTS_DIR}/01.jellyfish/dSAMPLE_CLI.histo"
GENOMESCOPE2_OUT_DIR="RESULTS_DIR"

#load modules
module load app/miniconda/mamba
conda activate genomescope2

#genomescope visualisation
genomescope2 -i ${JELLYFISH_HISTO} -o ${GENOMESCOPE2_OUT_DIR} -k 21