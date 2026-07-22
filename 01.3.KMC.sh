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

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
KMC_OUT_DIR="__RESULTS_DIR__"
TEMP_DIR="${KMC_OUT_DIR}/${PBS_JOBID}"

#make temp directory to store intermediate files
mkdir -p ${TEMP_DIR}

#kmc kmer analysis
KMERS=(17 21 27 31 37)

for K in "${KMERS[@]}"; do
    # scratch space for this kmer — safe to delete after the run
    SCRATCH_K="${TEMP_DIR}/k${K}_scratch"
    mkdir -p "${SCRATCH_K}"

    # final output location for this kmer — lives directly under KMC_OUT_DIR
    OUT_K="${KMC_OUT_DIR}/k${K}"
    mkdir -p "${OUT_K}"

    kmc -k${K} "${RAW_READS_FQ}" "${OUT_K}/${K}mers" "${SCRATCH_K}"
done

# optional cleanup of scratch once all kmers are done
rm -rf "${TEMP_DIR}"