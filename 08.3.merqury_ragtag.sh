#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=14:00:00
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

#which ragtag stage this run evaluates -- sed-substituted by submit.sh's
#RAGTAG_MODE=correct|scaffold CLI argument (see 06.1.busco_ragtag.sh)
RAGTAG_MODE="__RAGTAG_MODE__"

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_GZ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
MERQURY_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_CORRECT_DIR="${ALL_RESULTS_DIR}/07.1.ragtag_correct"
RAGATAG_SCAFFOLD_DIR="${ALL_RESULTS_DIR}/07.2.ragtag_scaffold"

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

declare -A MERQURY_STATUS

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
    local CONTIGS_IN="${RUN_TEMP}/$(basename "${SRC_FASTA}")"

    local RUN_OUT_DIR="${MERQURY_DIR}/${OUT_SUBDIR}"
    mkdir -p "${RUN_OUT_DIR}"

    #merqury.sh writes output files to cwd using OUT_PREFIX -- subshell keeps
    #the cd scoped to this run only
    (
        cd "${RUN_OUT_DIR}" && \
        ${MERQURY}/merqury.sh "${MERYL_DB}" "${CONTIGS_IN}" "${OUT_PREFIX}"
    ) || { echo "Merqury failed for ${CONTIGS_IN}"; return 1; }

    echo "Merqury for ${CONTIGS_IN} complete"
    rm -f "${CONTIGS_IN}"
}

#### what does the "subshell keeps the cd scoped to this run only" mean?
# with 18 sequential runs just using cd outside a subshell would have the remainder
# of the script working in the directory cd into first and merqury would drop everything
# in there
# the subsehell makes the workdir that script works from the same only that subshell
# breaks away. once its done the script returns to the initial workdir to subshell into
# the next appropriate one again

if [[ "${RAGTAG_MODE}" == "correct" ]]; then
    CONTIGS_IN="${RAGTAG_CORRECT_DIR}/ragtag.correct.fasta"
    run_merqury "${CONTIGS_IN}" "correct" "mq_dSAMPLE_CLI_correct"

elif [[ "${RAGTAG_MODE}" == "scaffold" ]]; then
    F_VALUES=(5000 10000 15000 20000)
    D_VALUES=(100000 300000 500000)

    for F_VAL in "${F_VALUES[@]}"; do
        for D_VAL in "${D_VALUES[@]}"; do
            PREFIX="SAMPLE_CLI.f${F_VAL}_d${D_VAL}"
            COMBO_STEP_DIR="${RAGATAG_SCAFFOLD_DIR}/f${F_VAL}_d${D_VAL}"
            OUT_SUBDIR="f${F_VAL}_d${D_VAL}"

            run_merqury "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.fasta" "${OUT_SUBDIR}" "mq_${PREFIX}_full"
            MERQURY_STATUS["f${F_VAL}_d${D_VAL}_full"]=$?

            run_merqury "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.chromosomes.fasta" "${OUT_SUBDIR}" "mq_${PREFIX}_chromosomes"
            MERQURY_STATUS["f${F_VAL}_d${D_VAL}_chromosomes"]=$?

            run_merqury "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.unplaced.fasta" "${OUT_SUBDIR}" "mq_${PREFIX}_unplaced"
            MERQURY_STATUS["f${F_VAL}_d${D_VAL}_unplaced"]=$?
        done
    done

else
    echo "Error: RAGTAG_MODE must be 'correct' or 'scaffold', got: ${RAGTAG_MODE}"
    exit 1
fi

echo "Merqury (${RAGTAG_MODE}) complete"

#log final exit status of each fasta to the error log (scaffold mode only)
{
    echo "===== Merqury combination exit status summary ====="
    for COMBO in "${!MERQURY_STATUS[@]}"; do
        echo "${COMBO}: exit_status=${MERQURY_STATUS[${COMBO}]}"
    done
    echo "======================================================"
} >&2