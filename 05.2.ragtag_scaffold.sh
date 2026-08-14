#!/bin/bash
#PBS -l select=1:ncpus=4:mem=40GB
#PBS -q bix
#PBS -l walltime=1:00:00
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
module load app/miniconda/mamba
conda activate ragtag

#resource parameters
THREADS=4

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
P_CONTIGS_IN="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
TEMP_DIR="${RAGTAG_SCAFFOLD_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy fastas file to temporary directory
cp "${P_CONTIGS_IN}" \
    "${REF_GENOME}" "${TEMP_DIR}/"

#unzip reference fasta
gzip -d "${TEMP_DIR}/$(basename "${REF_GENOME}")"

#reassign variables to the temp directory versions
P_CONTIGS_IN="${TEMP_DIR}/$(basename "${P_CONTIGS_IN}")"
REF_GENOME="${TEMP_DIR}/$(basename "${REF_GENOME}" .gz)"

#scaffold assemblies
ragtag.py scaffold --remove-small -f 10000 -d 500000 -i 0.5 \
    -a 0.5 -s 0.5 --mm2-params '-x asm10' -C -t "${THREADS}" \
    -o  "${RAGTAG_SCAFFOLD_DIR}" "${REF_GENOME}" "${P_CONTIGS_IN}"