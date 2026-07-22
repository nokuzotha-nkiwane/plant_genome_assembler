#!/bin/bash
#PBS -l select=2:ncpus=8:mem=20GB
#PBS -q bix
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -l walltime=04:00:00
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m abe
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail  

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
JELLYFISH_HISTO="${ALL_RESULTS_DIR}/01.jellyfish/dSAMPLE_CLI.histo"
GENOMESCOPE2_OUT_DIR="__RESULTS_DIR__"

#load modules
module load app/miniconda/mamba
conda activate genomescope2

#genomescope visualisation
KMERS=(17 21 27 31 37)

for K in "${KMERS[@]}"; do
    JELLYFISH_HISTO="${JELLYFISH_OUT_DIR}/k${K}/dSAMPLE_CLI.histo"
    OUT_K="${GENOMESCOPE2_OUT_DIR}/k${K}"
    mkdir -p "${OUT_K}"

    #genomescope visualisation
    genomescope2 -i ${JELLYFISH_HISTO} -o ${OUT_K} -k ${K}
done