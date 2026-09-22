#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=96:00:00
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
#need to use a python version later than the 3.6 found on the hpc
module load app/miniconda/mamba
conda activate lifton

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta"
REF_GFF3="${REF_DIR}/SL5.0.gff3"
SCAFFOLD_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
OUTPUT_DIR="__RESULTS_DIR__"
TEMP_DIR="${OUTPUT_DIR}/${PBS_JOBID}_temp"


#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#get basename for output file
BASENAME=$(basename "${SCAFFOLD_FASTA}" .fasta)

#cd into working directory before running (to drop files)
cd "${OUTPUT_DIR}"

#run command
lifton -o "${BASENAME}.lifton.gff3" -mm2_options "-x asm5" \
    -cds \
    -dir "${TEMP_DIR}" \
    -t "${THREADS}" \
    --validate-output \
    -g "${REF_GFF3}" \
    --verbose \
    "${SCAFFOLD_FASTA}" "${REF_GENOME}" 2>&1 | tee -a "${OUTPUT_DIR}/dSAMPLE_CLI_lifton.log"