#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -P PROJECT_NAME
#PBS -q serial
#PBS -l walltime=48:00:00
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
kmer_size=31

#directories and files
workdir="${GRAPEVINE_PATH}/SAMPLE_CLI"
raw_reads="${workdir}/raw_reads/SAMPLE_CLI.fastq"
raw_reads_gz="${workdir}/raw_reads/SAMPLE_CLI.fastq.gz"
merqury_dir="RESULTS_DIR"
meryl_output="${merqury_dir}/SAMPLE_CLI_asm.meryl"

#load modules
module load chpc/BIOMODULES
module load merqury

# >>> run only on first execution of merqury >>>

#compress raw read files
if [[ -s ${raw_reads_gz} ]]; then
    echo "Compressed file already exists. Skipping gzip: ${raw_reads_gz}"
elif [[ -s ${raw_reads} ]]; then
    gzip ${raw_reads}
else
    echo "ERROR: File empty or missing: ${raw_reads} and ${raw_reads_gz}"
    exit 1
fi

#make reads.meryl database
echo "Performing k-mer count on raw reads for reads.meryl database"
meryl count k=${kmer_size} threads=${THREADS} memory=${MEMORY} ${raw_reads_gz} output ${meryl_output} 
echo "Reads database successfully made"

# <<< run only on first execution of merqury <<<
