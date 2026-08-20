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
conda activate syri

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME_1="${REF_DIR}/SL5.0.fasta.gz"
REF_GENOME_2="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
REF_SCAFFOLD_ALN="${ALL_RESULTS_DIR}/06.4.minimap2_ref_scaffold"
NO_UNPLACED_REF_DIR="${REF_SCAFFOLD_ALN}/no_unplaced_ref"
SCAFFOLD_IN="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/ragtag.scaffold.chromosomes.fasta"
TEMP_DIR="${REF_SCAFFOLD_ALN}/${PBS_JOBID}_temp"

