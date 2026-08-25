#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=24:00:00
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
conda activate helper-tools

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME_1="${REF_DIR}/SL5.0.fasta.gz"
REF_GENOME_2="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
REF_SCAFFOLD_ALN="__RESULTS_DIR__"
FULL_REF_DIR="${REF_SCAFFOLD_ALN}/full_ref"
NO_UNPLACED_REF_DIR="${REF_SCAFFOLD_ALN}/no_unplaced_ref"
SCAFFOLD_STEP_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold"
TEMP_DIR="${REF_SCAFFOLD_ALN}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}" "${FULL_REF_DIR}" "${NO_UNPLACED_REF_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy input file to temporary directory
cp "${REF_GENOME_1}" \
    "${REF_GENOME_2}" "${TEMP_DIR}/"

#reassign variables to the temp directory versions
REF_GENOME_1="${TEMP_DIR}/$(basename "${REF_GENOME_1}")"
REF_GENOME_2="${TEMP_DIR}/$(basename "${REF_GENOME_2}")"

REF_IN=("${REF_GENOME_1}" "${REF_GENOME_2}")

OUT_FILES=("${FULL_REF_DIR}" "${NO_UNPLACED_REF_DIR}")

#parameter sweep values according to 05.2.ragtag_scaffold
F_VALUES=(15000 20000)
D_VALUES=(100000 300000 500000)

#align one parameter combination's scaffolded chromosomes fasta against one reference
REF_SCAFFOLD_ALIGN() {
    local REFERENCE="$1" OUT_DIR="$2" F_VAL="$3" D_VAL="$4"
    local PREFIX="SAMPLE_CLI.f${F_VAL}_d${D_VAL}"
    local COMBO_STEP_DIR="${SCAFFOLD_STEP_DIR}/f${F_VAL}_d${D_VAL}"
    local SCAFFOLD_SRC="${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.chromosomes.fasta"
    local COMBO_OUT_DIR="${OUT_DIR}/f${F_VAL}_d${D_VAL}"

    [[ -s "${SCAFFOLD_SRC}" ]] || { echo "Missing scaffold fasta: ${SCAFFOLD_SRC}"; exit 1; }
    mkdir -p "${COMBO_OUT_DIR}"

    #copy to temp with unique name (prefix already encodes f/d so no collisions across combos)
    cp "${SCAFFOLD_SRC}" "${TEMP_DIR}/"
    local SCAFFOLD_IN="${TEMP_DIR}/$(basename "${SCAFFOLD_SRC}")"

    minimap2 -ax asm5 -t "${THREADS}" "${REFERENCE}" "${SCAFFOLD_IN}" > "${COMBO_OUT_DIR}/${PREFIX}.aln5.sam" \
        || { echo "minimap2 SAM alignment failed for ${PREFIX} vs $(basename "${REFERENCE}")"; exit 1; }
    minimap2 -cx asm5 --cs -t "${THREADS}" "${REFERENCE}" "${SCAFFOLD_IN}" > "${COMBO_OUT_DIR}/${PREFIX}.aln5.paf" \
        || { echo "minimap2 PAF alignment failed for ${PREFIX} vs $(basename "${REFERENCE}")"; exit 1; }
}

#align every parameter combination's chromosomes fasta against both reference variants
for i in "${!REF_IN[@]}"; do
    for F_VAL in "${F_VALUES[@]}"; do
        for D_VAL in "${D_VALUES[@]}"; do
            REF_SCAFFOLD_ALIGN "${REF_IN[$i]}" "${OUT_FILES[$i]}" "${F_VAL}" "${D_VAL}"
        done
    done
done