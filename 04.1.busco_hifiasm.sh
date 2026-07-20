#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
#PBS -N STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euox pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${workdir}/results"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="/mnt/lustre/users/nnkiwane/masters/databases"
CONTIGS_DIR="${ALL_RESULTS_DIR}/contigs"
CONTIGS_IN="${CONTIGS_DIR}/dSAMPLE_CLI_hap?.fa"

#load modules
module load chpc/BIOMODULES
module load busco/6.0.0

#check quality of assembled contigs for each haplotype
RUN_BUSCO() {
    local fasta="${1}"
    singularity run $SIF busco --in ${FASTA} \
    --metaeuk \
    -m genome \
    --offline \
    -l eudicotyledons_odb12 \
    --download_path ${BUSCO_DB_DIR} \
    -c ${THREADS} \
    --out_path ${BUSCO_DIR}
}

for FASTA in ${CONTIGS_IN};do
    echo "Running BUSCO for ${FASTA}"
    RUN_BUSCO ${fasta}
    echo "BUSCO for ${FASTA} complete";
done