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
HIFIASM_DIR="${ALL_RESULTS_DIR}/03.hifiasm"
P_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_primary.fa"
A_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_alternate.fa"
TEMP_DIR="${HIFIASM_DIR}/${PBS_JOBID}_temp"

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
# check quality of assembled contigs for each haplotype
RUN_BUSCO() {
    local FASTA="${1}"
    
    # Extract base filename without extension to create a unique output folder per run
    local BASE_NAME
    BASE_NAME=$(basename "${FASTA}" .fa)
    
    busco --in "${FASTA}" \
        -m genome \
        --offline \
        -l solanales_odb10 \
        --download_path "${BUSCO_DB_DIR}" \
        -c "${THREADS}" \
        -f \
        -o "${BASE_NAME}_busco" \
        --out_path "${BUSCO_DIR}"
}

for FASTA in "${CONTIGS_IN[@]}"; do
    echo "Running BUSCO for ${FASTA}"
    RUN_BUSCO "${FASTA}" || { echo "BUSCO failed for ${FASTA}"; exit 1; }
    echo "BUSCO for ${FASTA} complete"
done