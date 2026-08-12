#!/bin/bash
#PBS -l ncpus=8
#PBS -l mem=40GB
#PBS -q bix
#PBS -l walltime=3:00:00
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
module load app/QUAST/5.3.0

#resource parameters
THREADS=8

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
REF_GFF3="${REF_DIR}/SL5.0.gff3.gz"
QUAST_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"
HIFIASM_DIR="${ALL_RESULTS_DIR}/03.hifiasm"
P_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_primary_renamed.fa"
A_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_alternate.fa"
TEMP_DIR="${QUAST_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy fastas file to temporary directory
cp "${P_CONTIGS_IN}" "${A_CONTIGS_IN}" "${TEMP_DIR}/"

# Re-assign array to point to temp FASTA copies
CONTIGS_IN=(
    "${TEMP_DIR}/$(basename "${P_CONTIGS_IN}")"
    "${TEMP_DIR}/$(basename "${A_CONTIGS_IN}")"
)

#check quality of assembled contigs for primary assembly

quast.py "${CONTIGS_IN[0]}" \
    "${CONTIGS_IN[1]}" \
    -r "${REF_GENOME}" \
    -g "${REF_GFF3}" \
    -o "${QUAST_DIR}" \
    -e \
    -k \
    --circos \
    --plots-format pdf \
    -t "${THREADS}"

