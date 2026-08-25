#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=96:00:00
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
conda activate helper-tools

#resource parameters
THREADS=23

#directories and files
WORKDIR_03="${TOMATO_PATH}/03"
WORKDIR_05="${TOMATO_PATH}/05"
SCFLDS_ALN="__RESULTS_DIR__"
ALIGN_03_05="${SCFLDS_ALN}/align_03_05"
TEMP_DIR="${SCFLDS_ALN}/${PBS_JOBID}_temp"

#parameter sweep values according to 05.2.ragtag_scaffold
F_VALUES=(15000 20000)
D_VALUES=(100000 300000 500000)

mkdir -p "${TEMP_DIR}" "${ALIGN_03_05}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

declare -A ALIGN_STATUS

#align one category (full/chromosomes/unplaced) of one parameter combination's
#d03 vs d05 scaffold fastas, with d03 as reference (matches asm_asm_aln convention)
align_scaffold_pair() {
    local F_VAL="$1" D_VAL="$2" CATEGORY="$3" SUFFIX="$4"

    local COMBO_DIR="f${F_VAL}_d${D_VAL}"
    local D03_SRC="${WORKDIR_03}/results/05.2.ragtag_scaffold/${COMBO_DIR}/03.f${F_VAL}_d${D_VAL}${SUFFIX}"
    local D05_SRC="${WORKDIR_05}/results/05.2.ragtag_scaffold/${COMBO_DIR}/05.f${F_VAL}_d${D_VAL}${SUFFIX}"

    for FILE in "${D03_SRC}" "${D05_SRC}"; do
        [[ -s "${FILE}" ]] || { echo "Missing or empty fasta: ${FILE}"; return 1; }
    done

    local RUN_TEMP="${TEMP_DIR}/${COMBO_DIR}_${CATEGORY}"
    mkdir -p "${RUN_TEMP}"
    cp "${D03_SRC}" "${D05_SRC}" "${RUN_TEMP}/"
    local D03_IN="${RUN_TEMP}/$(basename "${D03_SRC}")"
    local D05_IN="${RUN_TEMP}/$(basename "${D05_SRC}")"

    local OUT_PREFIX="${ALIGN_03_05}/${COMBO_DIR}.${CATEGORY}.aln5"

    minimap2 -ax asm5 -t "${THREADS}" "${D03_IN}" "${D05_IN}" > "${OUT_PREFIX}.sam" \
        || { echo "SAM alignment failed for ${COMBO_DIR} ${CATEGORY}"; return 1; }
    minimap2 -cx asm5 --cs -t "${THREADS}" "${D03_IN}" "${D05_IN}" > "${OUT_PREFIX}.paf" \
        || { echo "PAF alignment failed for ${COMBO_DIR} ${CATEGORY}"; return 1; }

    rm -f "${D03_IN}" "${D05_IN}"
    echo "Alignment complete for ${COMBO_DIR} ${CATEGORY}"
}

for F_VAL in "${F_VALUES[@]}"; do
    for D_VAL in "${D_VALUES[@]}"; do
        align_scaffold_pair "${F_VAL}" "${D_VAL}" "full" ".ragtag.scaffold.fasta"
        ALIGN_STATUS["f${F_VAL}_d${D_VAL}_full"]=$?

        align_scaffold_pair "${F_VAL}" "${D_VAL}" "chromosomes" ".ragtag.scaffold.chromosomes.fasta"
        ALIGN_STATUS["f${F_VAL}_d${D_VAL}_chromosomes"]=$?

        align_scaffold_pair "${F_VAL}" "${D_VAL}" "unplaced" ".ragtag.scaffold.unplaced.fasta"
        ALIGN_STATUS["f${F_VAL}_d${D_VAL}_unplaced"]=$?
    done
done

echo "Cross-sample scaffold alignment complete"

#log final exit status of each combination/category to the error log
{
    echo "===== Alignment exit status summary ====="
    for COMBO in "${!ALIGN_STATUS[@]}"; do
        echo "${COMBO}: exit_status=${ALIGN_STATUS[${COMBO}]}"
    done
    echo "==========================================="
} >&2