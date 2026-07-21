#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
#PBS -N STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euox pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#parameters
THREADS=23
MEMORY=60
kmer_size=21

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS="${WORKDIR}/raw_reads/SAMPLE_CLI.fastq"
RAW_READS_GZ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
MERYL_DIR="__RESULTS_DIR__"
MERYL_OUTPUT="${MERYL_DIR}/dSAMPLE_CLI_asm.meryl"

#load modules
module load app/miniconda/mamba
conda activate merqury

mkdir -p ${MERYL_DIR}
# >>> run only on first execution of merqury >>>

#compress raw read files
if [[ -s ${RAW_READS_GZ} ]]; then
    echo "Compressed file already exists. Skipping gzip: ${RAW_READS_GZ}"
elif [[ -s ${RAW_READS} ]]; then
    gzip ${RAW_READS}
else
    echo "ERROR: File empty or missing: ${RAW_READS} and ${RAW_READS_GZ}"
    exit 1
fi

#make reads.meryl database
echo "Performing k-mer count on raw reads for reads.meryl database"
meryl count k=${KMER_SIZE} threads=${THREADS} memory=${MEMORY} ${RAW_READS_GZ} output ${MERYL_OUTPUT} 
echo "Reads database successfully made"

# <<< run only on first execution of merqury <<<
