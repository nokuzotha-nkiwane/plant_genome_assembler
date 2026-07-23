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
module load app/miniconda/mamba
conda activate verkko_2.3..2

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
VERKKO_DIR="__RESULTS_DIR__"
TEMP_DIR="${VERKKO_DIR}/${PBS_JOBID}"
VERKKO_DIR_STD="${VERKKO_DIR}/standard"
VERKKO_DIR_NOCORR="${VERKKO_DIR}/no_correction"

#make temp directory to copy reads to so the original ones are accessible to other scripts
mkdir -p ${TEMP_DIR} ${VERKKO_DIR_STD} ${VERKKO_DIR_NOCORR}
cp ${RAW_READS_FQ} "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#perform assembly
verkko -d ${VERKKO_DIR_STD} --hifi ${RAW_READS_FQ}
verkko -d ${VERKKO_DIR_NOCORR} --hifi ${RAW_READS_FQ} --no-correction 

#delete temp dir
rm -rf "${TEMP_DIR}/"