#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
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

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
REF_GFF3="${REF_DIR}/SL5.0.gff3.gz"
QUAST_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGATAG_SCAFFOLD_DIR="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output"

TEMP_DIR="${QUAST_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#run quast on a single contigs fasta, staged to TEMP_DIR first
run_quast() {
    local SRC_FASTA="$1"
    local RUN_OUT_DIR="$2"
    mkdir -p "${RUN_OUT_DIR}"

    [[ -s "${SRC_FASTA}" ]] || { echo "Missing fasta: ${SRC_FASTA}"; return 1; }

    cp "${SRC_FASTA}" "${TEMP_DIR}/"
    local SCAFFOLD_IN="${TEMP_DIR}/$(basename "${SRC_FASTA}")"

    #check quality of the ragtag assembly
    quast.py "${SCAFFOLD_IN}" \
        -r "${REF_GENOME}" \
        -g "${REF_GFF3}" \
        -o "${RUN_OUT_DIR}" \
        -e -k --circos --plots-format pdf \
        -t "${THREADS}" \
        || { echo "QUAST failed for ${SCAFFOLD_IN}"; return 1; }

    echo "QUAST for ${SCAFFOLD_IN} complete"

    #free space in TEMP_DIR before the next fasta
    rm -f "${SCAFFOLD_IN}"
}

# run for full output scaffold fasta
run_quast "${RAGATAG_SCAFFOLD_DIR}/ragtag.scaffold.fasta" "${QUAST_DIR}/full"

# run for chromosomes only scaffold fasta
run_quast "${RAGATAG_SCAFFOLD_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" "${QUAST_DIR}/chromosomes"

# run for unplaced chromosomes only scaffold fasta
run_quast "${RAGATAG_SCAFFOLD_DIR}/dSAMPLE_CLI.ragtag.scaffold.unplaced.fasta" "${QUAST_DIR}/unplaced"

