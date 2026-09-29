#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=12:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -uxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"


#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="${TOMATO_PATH}/data"
REF_DIR="${BUSCO_DB_DIR}/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta"
REF_PEPTIDE="${REF_DIR}/SL5.pep.fa"

#get basenmae of fasta
BASE_NAME="SL5.0"
cd "${BUSCO_DIR}"

# check quality of assembled contigs for each haplotype
busco --in "${REF_GENOME}" \
    -m genome \
    --offline \
    -l solanales_odb10 \
    --download_path "${BUSCO_DB_DIR}" \
    -c "${THREADS}" \
    -f \
    -o "${BASE_NAME}_nucleotide_busco" \
    --out_path "${BUSCO_DIR}"

# check quality of assembled contigs for each haplotype
busco --in "${REF_PEPTIDE}" \
    -m protein \
    --offline \
    -l solanales_odb10 \
    --download_path "${BUSCO_DB_DIR}" \
    -c "${THREADS}" \
    -f \
    -o "${BASE_NAME}_protein_busco" \
    --out_path "${BUSCO_DIR}"