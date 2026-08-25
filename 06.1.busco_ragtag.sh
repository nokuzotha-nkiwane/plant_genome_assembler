#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=12:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -uxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"

#resource parameters
THREADS=23

#which ragtag stage this run evaluates -- sed-substituted by submit.sh's
#RAGTAG_MODE=correct|scaffold CLI argument. The two modes are independent for now
#(scaffold runs on the raw hifiasm output, not the ragtag-corrected assembly); will
#chain them once the best hifiasm config + correction step is settled
RAGTAG_MODE="__RAGTAG_MODE__"

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="${TOMATO_PATH}/data"

TEMP_DIR="${BUSCO_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#tracks exit status of each combination for end-of-run summary
declare -A COMBO_STATUS

### what does declare mean
# -A flag means "associative array"
# associative array = a variable that maps arbitrary string keys to values (like a dictionary/
# hash map) instead of bash's default indexed arrays which only use integer indices (0,1,2,..)

#run busco on a single contigs fasta, staged to TEMP_DIR first
run_busco() {
    local SRC_FASTA="$1"

    [[ -s "${SRC_FASTA}" ]] || { echo "Missing fasta: ${SRC_FASTA}"; return 1; }

    cp "${SRC_FASTA}" "${TEMP_DIR}/"
    local CONTIGS_IN="${TEMP_DIR}/$(basename "${SRC_FASTA}")"

    #extract base filename without extension for a unique output folder
    local BASE_NAME
    BASE_NAME=$(basename "${CONTIGS_IN}" .fasta)

    #check quality of assembled contigs
    busco --in "${CONTIGS_IN}" \
        -m genome \
        --offline \
        -l solanales_odb10 \
        --download_path "${BUSCO_DB_DIR}" \
        -c "${THREADS}" \
        -f \
        -o "${BASE_NAME}_busco" \
        --out_path "${BUSCO_DIR}" \
        || { echo "BUSCO failed for ${CONTIGS_IN}"; return 1; }

    echo "BUSCO for ${CONTIGS_IN} complete"

    #free space in TEMP_DIR before the next combination
    rm -f "${CONTIGS_IN}"
}

#parameter sweep values according to 05.2.ragtag_scaffold
F_VALUES=(15000 20000)
D_VALUES=(100000 300000 500000)

if [[ "${RAGTAG_MODE}" == "correct" ]]; then
    run_busco "${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"

elif [[ "${RAGTAG_MODE}" == "scaffold" ]]; then
    for F_VAL in "${F_VALUES[@]}"; do
        for D_VAL in "${D_VALUES[@]}"; do
            PREFIX="SAMPLE_CLI.f${F_VAL}_d${D_VAL}"
            COMBO_STEP_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/f${F_VAL}_d${D_VAL}"

            # run for full output scaffold fasta
            run_busco "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.fasta"
            COMBO_STATUS["f${F_VAL}_d${D_VAL}_full"]=$?

            # run for chromosomes only scaffold fasta
            run_busco "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.chromosomes.fasta"
            COMBO_STATUS["f${F_VAL}_d${D_VAL}_chromosomes"]=$?

            # run for unplaced chromosomes only scaffold fasta
            run_busco "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.unplaced.fasta"
            COMBO_STATUS["f${F_VAL}_d${D_VAL}_unplaced"]=$?
        done
    done

else
    echo "Error: RAGTAG_MODE must be 'correct' or 'scaffold', got: ${RAGTAG_MODE}"
    exit 1
fi

echo "BUSCO (${RAGTAG_MODE}) complete"
#log final exit status of each combination to the error log
{
    echo "===== BUSCO combination exit status summary ====="
    for COMBO in "${!COMBO_STATUS[@]}"; do
        echo "${COMBO}: exit_status=${COMBO_STATUS[${COMBO}]}"
    done
    echo "==================================================="
} >&2

### why is it in braces?
# without braces the actual outputs go to stout because that is the default stream
# putting >&2 on the last line without using braces will print everything else to
# stout and only the last line to stderr. Hence putting everything in braces allows
# >&2 to apply to all lines and the overall output gets printed to stderr

# NB: Note the syntax requirements: { needs a space after it and }
# needs to be preceded by a ; or newline

### but I have set -x at the top should this not suffice
# set -x prints the trace of each command as it's about to execute
# (the + echo "..." lines) that trace always goes to stderr regardless
# of anything else.
# the actual output of the command (what echo prints) still goes to whatever
# stream it's normally connected to — stdout by default — unless you redirect it yourself.