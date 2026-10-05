#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#no -e: a failed fasta shouldn't abort the remaining ones, and each status is
#recorded in QUAST_STATUS for the end-of-run summary
set -uxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/QUAST/5.3.0

#resource parameters
THREADS=23

#read length thresholds used for ragtag correct
MIN_LENGTHS=(1000 2000 3000 4000 5000 6000 7000 8000)

#parameter sweep values according to 05.2.ragtag_scaffold
F_VALUES=(15000)
D_VALUES=(500000)

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
REF_GFF3="${REF_DIR}/SL5.0.gff3.gz"
QUAST_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"

TEMP_DIR="${QUAST_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#tracks exit status of each fasta for end-of-run summary
declare -A QUAST_STATUS

#run quast on a single contigs fasta, staged to TEMP_DIR first
run_quast() {
    set -euo pipefail
    local SRC_FASTA="$1"
    local OUT_SUBDIR="$2"

    [[ -s "${SRC_FASTA}" ]] || { echo "Missing fasta: ${SRC_FASTA}"; return 1; }

    cp "${SRC_FASTA}" "${TEMP_DIR}/"
    local CONTIGS_IN="${TEMP_DIR}/$(basename "${SRC_FASTA}")"

    local RUN_OUT_DIR="${QUAST_DIR}/${OUT_SUBDIR}"

    #check quality of the ragtag assembly
    quast.py "${CONTIGS_IN}" \
        -r "${REF_GENOME}" \
        -g "${REF_GFF3}" \
        -o "${RUN_OUT_DIR}" \
        -e -k --circos --plots-format pdf \
        -t "${THREADS}" \
        || { echo "QUAST failed for ${CONTIGS_IN}"; rm -f "${CONTIGS_IN}"; return 1; }

    echo "QUAST for ${CONTIGS_IN} complete"

    #free space in TEMP_DIR
    rm -f "${CONTIGS_IN}"
}

#parallel runs each command through $SHELL, which must be bash for exported functions
export SHELL="$(type -p bash)"
export -f run_quast
export QUAST_DIR REF_GENOME REF_GFF3 TEMP_DIR THREADS

#build the list of independent commands (one per line: fasta  output_subdir)
TASKS="${QUAST_DIR}/quast.tasks"
: > "${TASKS}"
for MIN_LEN in "${MIN_LENGTHS[@]}"; do
    for F_VAL in "${F_VALUES[@]}"; do
        for D_VAL in "${D_VALUES[@]}"; do
            PREFIX="SAMPLE_CLI.minlen${MIN_LEN}.f${F_VAL}_d${D_VAL}"
            COMBO_STEP_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/minlen_${MIN_LEN}/f${F_VAL}_d${D_VAL}"
            OUT_SUBDIR="minlen_${MIN_LEN}/f${F_VAL}_d${D_VAL}"

            printf '%s %s\n' "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.fasta"             "${OUT_SUBDIR}/full"        >> "${TASKS}"
            printf '%s %s\n' "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.chromosomes.fasta" "${OUT_SUBDIR}/chromosomes" >> "${TASKS}"
            printf '%s %s\n' "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.unplaced.fasta"    "${OUT_SUBDIR}/unplaced"    >> "${TASKS}"
        done
    done
done

#--halt never: one failed fasta must not stop the others
JOBLOG="${QUAST_DIR}/quast.joblog"
rm -f "${JOBLOG}"
parallel -j "${JOBS}" --colsep ' ' --joblog "${JOBLOG}" --halt never \
    run_quast {1} {2} < "${TASKS}"
PARALLEL_RC=$?

echo "QUAST complete"

#log final exit status of each fasta to the error log
{
    echo "===== QUAST exit status summary ====="
    awk -F'\t' 'NR>1 {print $9": exit_status="$7}' "${JOBLOG}"
    echo "====================================="
} >&2

exit "${PARALLEL_RC}"