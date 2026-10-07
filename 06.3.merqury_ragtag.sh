#!/bin/bash
#PBS -l select=1:ncpus=24:mem=40GB
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
module load app/miniconda/mamba
module load app/parallel/parallel
conda activate merqury

THREADS=4
JOBS=6

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_GZ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
MERQURY_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"

#read length thresholds used for ragtag correct
MIN_LENGTHS=(1000 2000 3000 4000 5000 6000 7000 8000)

#parameter sweep values according to 05.2.ragtag_scaffold
F_VALUES=(15000)
D_VALUES=(500000)

#reuse the read k-mer database built once in 04.2a -- it's a property of the
#raw reads, not of any particular assembly, so no separate ragtag prep step
#is needed
MERYL_DB="${ALL_RESULTS_DIR}/04.2a.merqury_hifiasm_prep/dSAMPLE_CLI_asm.meryl"

TEMP_DIR="${MERQURY_DIR}/${PBS_JOBID}_temp"
mkdir -p "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

#check if meryl database for reads made (shared across all runs, checked once)
if [[ ! -d "${MERYL_DB}" ]]; then
    echo "ERROR: Meryl database empty or missing: ${MERYL_DB}"
    exit 1
fi
if [[ ! -s "${RAW_READS_GZ}" ]]; then
    echo "ERROR: File empty or missing: ${RAW_READS_GZ}"
    exit 1
fi

#run merqury on a single fasta, staged to its own TEMP_DIR subdir, output
#isolated in its own MERQURY_DIR subdir so concurrent runs never collide
run_merqury() {
    set -euo pipefail
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
    ) || { echo "Merqury failed for ${CONTIGS_IN}"; rm -rf "${RUN_TEMP}"; return 1; }

    echo "Merqury for ${CONTIGS_IN} complete"
    rm -rf "${RUN_TEMP}"
}

#parallel runs each command through $SHELL, which must be bash for exported functions
export SHELL="$(type -p bash)"
export -f run_merqury
export MERQURY MERQURY_DIR MERYL_DB TEMP_DIR

#build the list of independent commands (one per line: fasta  output_subdir  prefix)
TASKS="${MERQURY_DIR}/merqury.tasks"
: > "${TASKS}"
for MIN_LEN in "${MIN_LENGTHS[@]}"; do
    for F_VAL in "${F_VALUES[@]}"; do
        for D_VAL in "${D_VALUES[@]}"; do
            PREFIX="SAMPLE_CLI.minlen${MIN_LEN}.f${F_VAL}_d${D_VAL}"
            COMBO_STEP_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/minlen_${MIN_LEN}/f${F_VAL}_d${D_VAL}"
            OUT_SUBDIR="minlen_${MIN_LEN}/f${F_VAL}_d${D_VAL}"

            printf '%s %s %s\n' "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.fasta"             "${OUT_SUBDIR}/full"        "mq_${PREFIX}_full"        >> "${TASKS}"
            printf '%s %s %s\n' "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.chromosomes.fasta" "${OUT_SUBDIR}/chromosomes" "mq_${PREFIX}_chromosomes" >> "${TASKS}"
            printf '%s %s %s\n' "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.unplaced.fasta"    "${OUT_SUBDIR}/unplaced"    "mq_${PREFIX}_unplaced"    >> "${TASKS}"
        done
    done
done

#--halt never: one failed fasta must not stop the others
JOBLOG="${MERQURY_DIR}/merqury.joblog"
rm -f "${JOBLOG}"
parallel -j "${JOBS}" --colsep ' ' --joblog "${JOBLOG}" --halt never \
    run_merqury {1} {2} {3} < "${TASKS}"
PARALLEL_RC=$?

echo "Merqury complete"

#log final exit status of each fasta to the error log
{
    echo "===== Merqury exit status summary ====="
    awk -F'\t' 'NR>1 {print $9": exit_status="$7}' "${JOBLOG}"
    echo "======================================="
} >&2

exit "${PARALLEL_RC}"