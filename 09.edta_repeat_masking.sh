#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
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
module load app/apptainer/1.2.5

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
OUTPUT_DIR="__RESULTS_DIR__"
REF_DIR="${TOMATO_PATH}/data/reference_data"
CDS="${REF_DIR}/SL5.cds.fa.gz"
RAGATAG_SCAFFOLD_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
EDTA_IMAGE="/new-home/25086138/my_environments/edta_2/EDTA.sif"

TEMP_DIR="${OUTPUT_DIR}/${PBS_JOBID}_temp"
GENOME_BASENAME="$(basename "${RAGATAG_SCAFFOLD_FASTA}")"
CDS_BASENAME="$(basename "${CDS}")"

trap 'rm -rf "${TEMP_DIR}"' EXIT

mkdir -p "${TEMP_DIR}"
cp "${RAGATAG_SCAFFOLD_FASTA}" "${TEMP_DIR}/${GENOME_BASENAME}" || { echo "genome copy-in failed"; exit 1; }
cp "${CDS}" "${TEMP_DIR}/${CDS_BASENAME}" || { echo "cds copy-in failed"; exit 1; }

export PYTHONNOUSERSITE=1
declare -A run_status

run_edta () {
    local outdir="$1"; shift
    mkdir -p "${outdir}"

    cd "${TEMP_DIR}" || return 1

    singularity exec "${EDTA_IMAGE}" EDTA.pl "$@"
    local edta_status=$?

    #move everything EDTA produced out, except the two input copies, leaving temp dir clean for the next combo
    find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 \
    ! -name "${GENOME_BASENAME}" \
    ! -name "${CDS_BASENAME}" \
    -exec mv -t "${outdir}/" {} +

    sleep 30

    return "${edta_status}"
}

run_edta "${OUTPUT_DIR}/edta_basic" --genome "${GENOME_BASENAME}" --step all --anno 1 --evaluate 1 -t "${THREADS}"
run_status[basic]=$?
# run_edta "${OUTPUT_DIR}/edta_cds" --genome "${GENOME_BASENAME}" --step all --anno 1 --evaluate 1 -t "${THREADS}" --cds "${CDS_BASENAME}"
# run_status[cds]=$?
# run_edta "${OUTPUT_DIR}/edta_sensitive" --genome "${GENOME_BASENAME}" --step all --sensitive 1 --anno 1 --evaluate 1 -t "${THREADS}"
# run_status[sensitive]=$?
# run_edta "${OUTPUT_DIR}/edta_sensitive_cds" --genome "${GENOME_BASENAME}" --step all --sensitive 1 --anno 1 --evaluate 1 -t "${THREADS}" --cds "${CDS_BASENAME}"
# run_status[sensitive_cds]=$?

{ for k in "${!run_status[@]}";do
    echo "${k}: ${run_status[${k}]}"
done;
} >&2