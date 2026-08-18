#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=15:00:00
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
conda activate mummer

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME_1="${REF_DIR}/SL5.0.fasta.gz"
REF_GENOME_2="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
REF_SCAFFOLD_ALN="__RESULTS_DIR__"
FULL_REF_DIR="${REF_SCAFFOLD_ALN}/full_ref"
NO_UNPLACED_REF_DIR="${REF_SCAFFOLD_ALN}/no_unplaced_ref"
SCAFFOLD_IN="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/ragtag.scaffold.chromosomes.fasta"
TEMP_DIR="${REF_SCAFFOLD_ALN}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}" "${FULL_REF_DIR}" "${NO_UNPLACED_REF_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy input file to temporary directory
cp "${REF_GENOME_1}" \
    "${REF_GENOME_2}" \
    "${SCAFFOLD_IN}" "${TEMP_DIR}/"

#reassign variables to the temp directory versions
REF_GENOME_1="${TEMP_DIR}/$(basename "${REF_GENOME_1}")"
REF_GENOME_2="${TEMP_DIR}/$(basename "${REF_GENOME_2}")"
SCAFFOLD_IN="${TEMP_DIR}/$(basename "${SCAFFOLD_IN}")"

REF_IN=("${REF_GENOME_1}"
    "${REF_GENOME_2}")

OUT_FILES=("${FULL_REF_DIR}"
    "${NO_UNPLACED_REF_DIR}")

#align scaffolded assembly reference
REF_SCAFFOLD_ALIGN() {
    local REFERENCE="$1" OUT_DIR="$2"

    #perform alignment visualisation
    cd "${OUT_DIR}"
    nucmer "${REFERENCE}" "${SCAFFOLD_IN}" -p dSAMPLE_CLI
}

#align the variable reference sequences to the scaffold
for i in "${!REF_IN[@]}";do
    REF_SCAFFOLD_ALIGN "${REF_IN[$i]}" "${OUT_FILES[$i]}"
done

