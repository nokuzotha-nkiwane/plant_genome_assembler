#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
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
module load app/QUAST/5.3.0

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
REF_GFF3="${REF_DIR}/SL5.0.gff3.gz"
QUAST_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"

#run quast on a single contigs fasta, staged to TEMP_DIR first
#check quality of the ragtag assembly
quast.py "${REF_GENOME}" \
    -o "${RUN_OUT_DIR}" \
    --plots-format pdf \
    -t "${THREADS}" \
    || { echo "QUAST failed for ${REF_GENOME}"; exit 1; }

echo "QUAST for ${REF_GENOME} complete"