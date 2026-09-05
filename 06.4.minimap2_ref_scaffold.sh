#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=72:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#allow sweep to continue past individual failures (no -e); trace + unset-var protection retained
set -uxo pipefail

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

#make temp directory for fastas so the original ones are accessible to other scripts
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

#parameter sweep values according to 05.2.ragtag_scaffold (matches extract_and_index)
F_VALUES=(15000)
D_VALUES=(500000)

#track per-combo exit status so failures don't abort the rest of the sweep
declare -A ALN_STATUS

#align one parameter combination's fasta (scaffold/chromosomes/unplaced) against one reference,
#write sam+paf, then stage paf + gzipped query fasta into dgenies_input for that reference
run_alignment_and_dgenies_stage() {
    local REFERENCE="$1" OUT_DIR="$2" F_VAL="$3" D_VAL="$4" FASTA_SRC="$5"
    local COMBO_STEP_DIR="${SCAFFOLD_STEP_DIR}/f${F_VAL}_d${D_VAL}"
    local COMBO_OUT_DIR="${OUT_DIR}/f${F_VAL}_d${D_VAL}"
    local DGENIES_INPUT_DIR="${OUT_DIR}/dgenies_input"
    local PREFIX
    PREFIX="$(basename "${FASTA_SRC}" .fasta)"
    local STATUS_KEY="$(basename "${OUT_DIR}")_f${F_VAL}_d${D_VAL}_${PREFIX}"

    if [[ ! -s "${FASTA_SRC}" ]]; then
        echo "WARNING: missing or empty fasta, skipping: ${FASTA_SRC}"
        ALN_STATUS["${STATUS_KEY}"]="skipped_missing_input"
        return 0
    fi

    mkdir -p "${COMBO_OUT_DIR}"

    #copy to temp with unique name (prefix already encodes f/d/fasta-type so no collisions across combos)
    cp "${FASTA_SRC}" "${TEMP_DIR}/"
    local FASTA_IN="${TEMP_DIR}/$(basename "${FASTA_SRC}")"

    minimap2 -ax asm5 -t "${THREADS}" "${REFERENCE}" "${FASTA_IN}" > "${COMBO_OUT_DIR}/${PREFIX}.aln5.sam"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: minimap2 SAM alignment failed for ${PREFIX} vs $(basename "${REFERENCE}")"
        ALN_STATUS["${STATUS_KEY}"]="failed_sam"
        return 0
    fi

    minimap2 -cx asm5 --cs -t "${THREADS}" "${REFERENCE}" "${FASTA_IN}" > "${COMBO_OUT_DIR}/${PREFIX}.aln5.paf"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: minimap2 PAF alignment failed for ${PREFIX} vs $(basename "${REFERENCE}")"
        ALN_STATUS["${STATUS_KEY}"]="failed_paf"
        return 0
    fi

    #stage paf for dgenies
    cp "${COMBO_OUT_DIR}/${PREFIX}.aln5.paf" "${DGENIES_INPUT_DIR}/"

    #gzip -k the query fasta used for this alignment and move the .gz into dgenies_input
    gzip -k "${FASTA_IN}"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: gzip failed for ${FASTA_IN}"
        ALN_STATUS["${STATUS_KEY}"]="failed_gzip"
        return 0
    fi
    mv "${FASTA_IN}.gz" "${DGENIES_INPUT_DIR}/"

    ALN_STATUS["${STATUS_KEY}"]="ok"
}

#stage the gzipped reference once for a given reference variant's output dir
stage_reference_for_dgenies() {
    local REFERENCE="$1" OUT_DIR="$2"
    local DGENIES_INPUT_DIR="${OUT_DIR}/dgenies_input"

    if [[ "${REFERENCE}" == *.gz ]]; then
        cp "${REFERENCE}" "${DGENIES_INPUT_DIR}/"
    else
        gzip -k -c "${REFERENCE}" > "${DGENIES_INPUT_DIR}/$(basename "${REFERENCE}").gz"
    fi
}

#align every parameter combination's full-scaffold, chromosomes, and unplaced fastas against each reference variant
for i in "${!REF_IN[@]}"; do
    REFERENCE="${REF_IN[$i]}"
    OUT_DIR="${OUT_FILES[$i]}"
    DGENIES_INPUT_DIR="${OUT_DIR}/dgenies_input"

    #make dgenies_input dir and stage reference once, before the combo sweep
    mkdir -p "${DGENIES_INPUT_DIR}"
    stage_reference_for_dgenies "${REFERENCE}" "${OUT_DIR}"

    for F_VAL in "${F_VALUES[@]}"; do
        for D_VAL in "${D_VALUES[@]}"; do
            COMBO_STEP_DIR="${SCAFFOLD_STEP_DIR}/f${F_VAL}_d${D_VAL}"
            PREFIX="SAMPLE_CLI.f${F_VAL}_d${D_VAL}"

            FASTAS=(
                "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.fasta"
                "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.chromosomes.fasta"
                "${COMBO_STEP_DIR}/${PREFIX}.ragtag.scaffold.unplaced.fasta"
            )

            for FASTA_SRC in "${FASTAS[@]}"; do
                run_alignment_and_dgenies_stage "${REFERENCE}" "${OUT_DIR}" "${F_VAL}" "${D_VAL}" "${FASTA_SRC}"
            done
        done
    done
done

#print summary of failures/skips at the end so a scrollback grep isn't required
echo "=== Alignment sweep summary ==="
for KEY in "${!ALN_STATUS[@]}"; do
    if [[ "${ALN_STATUS[${KEY}]}" != "ok" ]]; then
        echo "${KEY}: ${ALN_STATUS[${KEY}]}"
    fi
done