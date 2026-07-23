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

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
WTDBG2_DIR="__RESULTS_DIR__"
TEMP_DIR="${WTDBG2_DIR}/${PBS_JOBID}_temp"
PREFIX="dSAMPLE_CLI"

#make temp directory to copy reads to so the original ones are accessible to other scripts
mkdir -p ${TEMP_DIR}
cp ${RAW_READS_FQ} "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#move to output directory and perform assembly
cd ${WTDBG2_DIR}
wtdbg2 -x ccs -t ${THREADS} -i ${RAW_READS_FQ} -fo ${PREFIX}
wtpoa-cns -t 16 -i ${PREFIX}.ctg.lay.gz -fo ${PREFIX}.ctg.fa

#delete temp dir
rm -rf "${TEMP_DIR}"