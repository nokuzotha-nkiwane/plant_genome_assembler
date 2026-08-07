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
conda activate helper-tools

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
REF_SCAFFOLD_ALN="__RESULTS_DIR__"
SCAFFOLD_IN="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
TEMP_DIR="${REF_SCAFFOLD_ALN}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy input file to temporary directory
cp "${REF_GENOME}" \
 "${SCAFFOLD_IN}" "${TEMP_DIR}/"

#reassign variables to the temp directory versions
REF_GENOME="${TEMP_DIR}/$(basename "${REF_GENOME}")"
SCAFFOLD_IN="${TEMP_DIR}/$(basename "${SCAFFOLD_IN}")"

#align assemblies to each other have 03 as reference
minimap2 -ax asm5 -t "${THREADS}" "${REF_GENOME}" "${SCAFFOLD_IN}" > "${REF_SCAFFOLD_ALN}/aln5.sam"
minimap2 -cx asm5 --cs -t "${THREADS}" "${REF_GENOME}" "${SCAFFOLD_IN}" > "${REF_SCAFFOLD_ALN}/aln5.paf"
minimap2 -ax asm10 -t "${THREADS}" "${REF_GENOME}" "${SCAFFOLD_IN}" > "${REF_SCAFFOLD_ALN}/aln10.sam"
minimap2 -cx asm10 --cs -t "${THREADS}" "${REF_GENOME}" "${SCAFFOLD_IN}" > "${REF_SCAFFOLD_ALN}/aln10.paf"
minimap2 -ax asm20 -t "${THREADS}" "${REF_GENOME}" "${SCAFFOLD_IN}" > "${REF_SCAFFOLD_ALN}/aln20.sam"
minimap2 -cx asm20 --cs -t "${THREADS}" "${REF_GENOME}" "${SCAFFOLD_IN}" > "${REF_SCAFFOLD_ALN}/aln20.paf"