#!/bin/bash
#PBS -l ncpus=64
#PBS -l mem=80GB
#PBS -q bix
#PBS -l walltime=96:00:00
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/EDTA2/2.2.2

#resource parameters
THREADS=64

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
OUTPUT_DIR="__RESULTS_DIR__"
REF_DIR="${TOMATO_PATH}/data/reference_data"
CDS="${REF_DIR}/SL5.cds.fa.gz"
logfile="${OUTPUT_DIR}/edta.log"
RAGATAG_SCAFFOLD_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
# EDTA_IMAGE="/new-home/25086138/my_environments/edta/EDTA.sif"
# TOOL_ENV="/usr/local/bin/"

cd "${OUTPUT_DIR}"
EDTA.pl --genome "${RAGATAG_SCAFFOLD_FASTA}" --sensitive 1 --anno 1 -t "${THREADS}" > >(tee -a "${logfile}") 2>&1 &
edta_pid=$!

while kill -0 "${edta_pid}" 2>/dev/null; do
    if grep -qE "^ERROR|FATAL|die at" "${logfile}"; then
        kill -TERM "${edta_pid}"
        wait "${edta_pid}" 2>/dev/null
        return 1
    fi
    sleep 10
done