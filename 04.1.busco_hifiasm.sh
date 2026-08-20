#!/bin/bash
#PBS -l ncpus=4
#PBS -l mem=8GB
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
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"

#resource parameters
THREADS=4

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="${TOMATO_PATH}/data"
REF_DIR="${BUSCO_DB_DIR}/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta"
HIFIASM_DIR="${ALL_RESULTS_DIR}/03.hifiasm"
P_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_primary_renamed.fa"
A_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_alternate.fa"
TEMP_DIR="${BUSCO_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy fasta files to temporary directory
cp "${P_CONTIGS_IN}" "${A_CONTIGS_IN}" "${REF_GENOME}" "${TEMP_DIR}/"

# Re-assign array to point to temp FASTA copies
FASTAS_IN=(
    "${TEMP_DIR}/$(basename "${P_CONTIGS_IN}")"
    "${TEMP_DIR}/$(basename "${A_CONTIGS_IN}")"
    "${TEMP_DIR}/$(basename "${REF_GENOME}")"
)
# check quality of assembled contigs for each haplotype
RUN_BUSCO() {
    local FASTA="${1}"
    
    busco --in "${FASTA}" \
        -m genome \
        --offline \
        -l solanales_odb10 \
        --download_path "${BUSCO_DB_DIR}" \
        -c "${THREADS}" \
        -f \
        -o "${FASTA}_busco" \
        --out_path "${BUSCO_DIR}"
}

for FASTA in "${FASTAS_IN[@]}"; do
    echo "Running BUSCO for ${FASTA}"
    RUN_BUSCO "${FASTA}" || { echo "BUSCO failed for ${FASTA}"; exit 1; }
    echo "BUSCO for ${FASTA} complete"
done