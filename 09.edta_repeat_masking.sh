#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=120GB
#PBS -q bix
#PBS -l walltime=192:00:00
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
conda activate edta

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
OUTPUT_DIR="__RESULTS_DIR__"
REF_DIR="${TOMATO_PATH}/data/reference_data"
CDS="${REF_DIR}/SL5.cds.fa.gz"
RAGATAG_SCAFFOLD_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"

#run command
declare -A run_status

run_edta () {
    local outdir="$1"; shift
    mkdir -p "${outdir}"
    ( cd "${outdir}" && EDTA.pl "$@" )
}

run_edta "${OUTPUT_DIR}/edta_basic" --genome "${RAGATAG_SCAFFOLD_FASTA}" --step all --anno 1 --evaluate 1 -t "${THREADS}"
run_status[basic]=$?
run_edta "${OUTPUT_DIR}/edta_cds" --genome "${RAGATAG_SCAFFOLD_FASTA}" --step all --anno 1 --evaluate 1 -t "${THREADS}" --cds "${CDS}"
run_status[cds]=$?
run_edta "${OUTPUT_DIR}/edta_sensitive" --genome "${RAGATAG_SCAFFOLD_FASTA}" --step all --sensitive 1 --anno 1 --evaluate 1 -t "${THREADS}"
run_status[sensitive]=$?
run_edta "${OUTPUT_DIR}/edta_sensitive_cds" --genome "${RAGATAG_SCAFFOLD_FASTA}" --step all --sensitive 1 --anno 1 --evaluate 1 -t "${THREADS}" --cds "${CDS}"
run_status[sensitive_cds]=$?

{ for k in "${!run_status[@]}"; do echo "${k}: ${run_status[${k}]}"; done; } >&2