#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -P PROJECT_NAME
#PBS -q serial
#PBS -l walltime=48:00:00
#PBS -N 03.hifiasm
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euox pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
HIFIASM_DIR="RESULTS_DIR"
HIFIASM_ASM="${HIFIASM_DIR}/dSAMPLE_CLI.asm"
GFA_FILES="${HIFIASM_DIR}/dSAMPLE_CLI.asm.bp.hap?.p_ctg.gfa"
CONTIGS_DIR="${ALL_RESULTS_DIR}/contigs"

mkdir -p ${contigs_dir}

#load modules
module load app/miniconda/mamba
conda activate hifiasm

#hifiasm assembly
echo "Performing contig assembly..."
hifiasm -o ${HIFIASM_ASM} -t ${THREADS} ${RAW_READS_FQ} || { echo "Contig assembly failed"; exit 1; }
echo "Contig assembly complete"

#convert gfa to fasta
for gfa in ${GFA_FILES}; do
    echo "Extracting contigs for ${GFA}..."

    #extract basename to name output fasta file
    hap=$(basename ${GFA} | grep -o "hap[0-9]")
    fasta_out="${CONTIGS_DIR}/SAMPLE_CLI_${HAP}.fa"

    #extract sequences from gfa to fasta
    awk '/^S/{print ">"$2; print $3}' "${GFA}" > ${FASTA_OUT} || { echo "Contig extraction failed for ${GFA}"; exit 1; }
    echo "Contig extraction for ${GFA} complete."

    #compress original fasta file
    echo "Compressing fasta file..."
    gzip -k ${FASTA_OUT} || { echo "Fasta compression failed for ${FASTA_OUT}"; exit 1; }
    echo "Fasta and compressed files successfully produced"
done
