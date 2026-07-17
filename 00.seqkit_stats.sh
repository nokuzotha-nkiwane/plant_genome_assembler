#!/bin/bash
#PBS -l select=2:ncpus=8:mem=20GB
#PBS -P PROJECT_NAME
#PBS -q serial
#PBS -l walltime=4:00:00
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m abe
#PBS -M PBS_EMAIL

#kill execution at first error
set -euox pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/seqkit/2.7.0 

#files and variables
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/SAMPLE_CLI.fastq"
ALL_RESULTS_DIR="${workdir}/results"
SEQKIT_OUT_DIR="RESULTS_DIR"
OUTPUT_FILE="${SEQKIT_OUT_DIR}/SAMPLE_CLI_seqkit_stats_--all.txt"

#check read stats of samples
seqkit stats --all SAMPLE_CLI > ${OUTPUT_FILE}
