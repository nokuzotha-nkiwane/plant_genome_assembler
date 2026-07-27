#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail  

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules version 1.4.1
module load app/miniconda/mamba
conda activate merqury

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_GZ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
MERQURY_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"
MERYL_DB="${ALL_RESULTS_DIR}/04.2a.merqury_hifiasm_prep/dSAMPLE_CLI_asm.meryl"
MERQURY_OUT_PREFIX="mq_dSAMPLE_CLI"
HIFIASM_DIR="${ALL_RESULTS_DIR}/03.hifiasm"
P_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_primary.fa"
A_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_alternate.fa"
TEMP_DIR="${HIFIASM_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#check if non-empty files exist
for FILE in "${RAW_READS_GZ}" "${P_CONTIGS_IN}" "${A_CONTIGS_IN}"; do
    if [[ ! -s ${FILE} ]]; then
        echo "ERROR: File empty or missing: ${FILE}"
        exit 1
    fi
done

#copy fastas file to temporary directory
cp "${P_CONTIGS_IN}" "${A_CONTIGS_IN}" "${TEMP_DIR}/"

# Re-assign array to point to temp FASTA copies
CONTIGS_IN=(
    "${TEMP_DIR}/$(basename "${P_CONTIGS_IN}")"
    "${TEMP_DIR}/$(basename "${A_CONTIGS_IN}")"
)

#check if meryl database for reads made
if [[ ! -d "${MERYL_DB}" ]]; then
    echo "ERROR: Meryl database empty or missing: ${MERYL_DB}"
    exit 1
fi

#run merqury to check quality of assembled contigs for each haplotype
echo "Running merqury on assembled contigs "
cd "${MERQURY_DIR}"
$MERQURY/merqury.sh "${MERYL_DB}" "${CONTIGS_IN[0]}" "${CONTIGS_IN[1]}" "${MERQURY_OUT_PREFIX}"
echo "Merqury complete"