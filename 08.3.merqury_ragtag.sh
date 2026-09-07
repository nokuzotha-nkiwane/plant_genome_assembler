#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=72:00:00
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
RAGATAG_SCAFFOLD_DIR="${ALL_RESULTS_DIR}/07.2.ragtag_scaffold_2"

#reuse the read k-mer database built once in 04.2a -- it's a property of the
#raw reads, not of any particular assembly, so no separate ragtag prep step
#is needed
MERYL_DB="${ALL_RESULTS_DIR}/04.2a.merqury_hifiasm_prep/dSAMPLE_CLI_asm.meryl"

TEMP_DIR="${MERQURY_DIR}/${PBS_JOBID}_temp"
mkdir -p "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

#check if meryl database for reads made (shared across all combos, checked once)
if [[ ! -d "${MERYL_DB}" ]]; then
    echo "ERROR: Meryl database empty or missing: ${MERYL_DB}"
    exit 1
fi
if [[ ! -s "${RAW_READS_GZ}" ]]; then
    echo "ERROR: File empty or missing: ${RAW_READS_GZ}"
    exit 1
fi

#run merqury on a single fasta, staged to its own TEMP_DIR subdir, output
#isolated in its own MERQURY_DIR subdir so parallel prefixes never collide
run_merqury() {
    local SRC_FASTA="$1"
    local OUT_SUBDIR="$2"
    local OUT_PREFIX="$3"

    [[ -s "${SRC_FASTA}" ]] || { echo "Missing fasta: ${SRC_FASTA}"; return 1; }

    local RUN_TEMP="${TEMP_DIR}/${OUT_PREFIX}"
    mkdir -p "${RUN_TEMP}"
    cp "${SRC_FASTA}" "${RUN_TEMP}/"
    local SCAFFOLD_IN="${RUN_TEMP}/$(basename "${SRC_FASTA}")"

    local RUN_OUT_DIR="${MERQURY_DIR}/${OUT_SUBDIR}"
    mkdir -p "${RUN_OUT_DIR}"

    #merqury.sh writes output files to cwd using OUT_PREFIX -- subshell keeps
    #the cd scoped to this run only
    (
        cd "${RUN_OUT_DIR}" && \
        ${MERQURY}/merqury.sh "${MERYL_DB}" "${SCAFFOLD_IN}" "${OUT_PREFIX}"
    ) || { echo "Merqury failed for ${SCAFFOLD_IN}"; return 1; }

    echo "Merqury for ${SCAFFOLD_IN} complete"
    rm -f "${SCAFFOLD_IN}"
}

# run for full output scaffold fasta
run_merqury "${RAGATAG_SCAFFOLD_DIR}/ragtag.scaffold.fasta" "full" "mq_full"

# run for chromosomes only scaffold fasta
run_merqury "${RAGATAG_SCAFFOLD_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" "chromosomes" "mq_chromosomes"

# run for unplaced chromosomes only scaffold fasta
run_merqury "${RAGATAG_SCAFFOLD_DIR}/dSAMPLE_CLI.ragtag.scaffold.unplaced.fasta" "unplaced" "mq_unplaced"
