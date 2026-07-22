#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=124GB
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

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
YAK_OUT_DIR="__RESULTS_DIR__"
READS_HASH="${YAK_OUT_DIR}/reads.yak"
READS_OUT_FILE="${YAK_OUT_DIR}/dSAMPLE_CLI_ccs-sr.kqv.txt"
READS_HIST="${YAK_OUT_DIR}/dSAMPLE_CLI_sr.hist"

#resource parameters
THREADS=32

#yak kmer analysis
yak count -b37 -t${THREADS} -o ${READS_HASH} ${RAW_READS_FQ}
yak inspect ${READS_HASH} sr.yak > ${READS_OUT_FILE}
yak inspect sr.yak > ${READS_HIST}
