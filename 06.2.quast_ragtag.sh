#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
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
module load app/QUAST/5.3.0

#resource parameters
THREADS=23

#which ragtag stage this run evaluates -- sed-substituted by submit.sh's
#RAGTAG_MODE=correct|scaffold CLI argument (see 06.1.busco_ragtag.sh for the
#same pattern)
RAGTAG_MODE="__RAGTAG_MODE__"

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

#tracks exit status of each fasta for end-of-run summary (scaffold mode only)
declare -A QUAST_STATUS

#run quast on a single contigs fasta, staged to TEMP_DIR first
run_quast() {
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
        || { echo "QUAST failed for ${CONTIGS_IN}"; return 1; }

    echo "QUAST for ${CONTIGS_IN} complete"

    #free space in TEMP_DIR before the next fasta
    rm -f "${CONTIGS_IN}"
}

#parameter sweep values according to 05.2.ragtag_scaffold
F_VALUES=(10000 5000)
D_VALUES=(100000 300000 500000)

if [[ "${RAGTAG_MODE}" == "correct" ]]; then
    run_quast "${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta" "correct"

elif [[ "${RAGTAG_MODE}" == "scaffold" ]]; then
    for F_VAL in "${F_VALUES[@]}"; do
        for D_VAL in "${D_VALUES[@]}"; do
            PREFIX="SAMPLE_CLI.f${F_VAL}_d${D_VAL}"
            COMBO_STEP_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/f${F_VAL}_d${D_VAL}"
            OUT_SUBDIR="f${F_VAL}_d${D_VAL}"

            run_quast "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.fasta" "${OUT_SUBDIR}/full"
            QUAST_STATUS["f${F_VAL}_d${D_VAL}_full"]=$?

            run_quast "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.chromosomes.fasta" "${OUT_SUBDIR}/chromosomes"
            QUAST_STATUS["f${F_VAL}_d${D_VAL}_chromosomes"]=$?

            run_quast "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.unplaced.fasta" "${OUT_SUBDIR}/unplaced"
            QUAST_STATUS["f${F_VAL}_d${D_VAL}_unplaced"]=$?
        done
    done

else
    echo "Error: RAGTAG_MODE must be 'correct' or 'scaffold', got: ${RAGTAG_MODE}"
    exit 1
fi

echo "QUAST (${RAGTAG_MODE}) complete"

#log final exit status of each fasta to the error log (scaffold mode only)
{
    echo "===== QUAST combination exit status summary ====="
    for COMBO in "${!QUAST_STATUS[@]}"; do
        echo "${COMBO}: exit_status=${QUAST_STATUS[${COMBO}]}"
    done
    echo "==================================================="
} >&2