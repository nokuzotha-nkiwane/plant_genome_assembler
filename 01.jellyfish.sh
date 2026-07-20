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

#resource parameters
THREADS=8

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${workdir}/results"
JELLYFISH_OUT_DIR="__RESULTS_DIR__"
JELLYFISH_JF="${JELLYFISH_OUT_DIR}/dSAMPLE_CLI.jf"
JELLYFISH_HISTO="${JELLYFISH_OUT_DIR}/dSAMPLE_CLI.histo"

#load modules
module load app/jellyfish/2.3.1 

#jellyfish kmer analysis
jellyfish count -m 21 -s 100M -t ${THREADS} -C -o ${JELLYFISH_JF} <(zcat ${RAW_READS_FQ})

#jellyfish histogram construction
jellyfish histo -t ${THREADS} ${JELLYFISH_JF} > ${JELLYFISH_HISTO}
