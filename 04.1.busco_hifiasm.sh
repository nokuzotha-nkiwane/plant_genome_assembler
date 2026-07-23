#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=6:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="${TOMATO_PATH}/data"
BUSCO_OUTPUT_PREFIX="dSAMPLE_CLI_"
CONTIGS_DIR="${ALL_RESULTS_DIR}/03.hifiasm"
CONTIGS_IN="${CONTIGS_DIR}/dSAMPLE_CLI_primary.fa"

#load modules
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"

#check quality of assembled contigs for each haplotype
RUN_BUSCO() {
    local FASTA="${1}"
    busco --in ${FASTA} \
    -m genome \
    --offline \
    -l eudicotyledons_odb12 \
    --download_path ${BUSCO_DB_DIR} \
    -c ${THREADS} \
    -f \
    -o ${BUSCO_OUTPUT_PREFIX} \
    --out_path ${BUSCO_DIR}
}

for FASTA in ${CONTIGS_IN};do
    echo "Running BUSCO for ${FASTA}"
    RUN_BUSCO ${FASTA}
    echo "BUSCO for ${FASTA} complete";
done