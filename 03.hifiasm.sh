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

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
HIFIASM_DIR="__RESULTS_DIR__"
HIFIASM_ASM="${HIFIASM_DIR}/dSAMPLE_CLI.asm"
# GFA_FILES="${HIFIASM_DIR}/dSAMPLE_CLI.asm.bp.hap?.p_ctg.gfa"
CONTIGS_DIR="${ALL_RESULTS_DIR}/contigs"
TEMP_DIR="${HIFIASM_DIR}/${PBS_JOBID}_temp"

#load modules
module load app/miniconda/mamba
conda activate hifiasm

#make temp directory to copy reads to so the original ones are accessible to other scripts
mkdir -p ${CONTIGS_DIR} ${TEMP_DIR}
cp ${RAW_READS_FQ} "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#hifiasm assembly
echo "Performing contig assembly..."
hifiasm -o ${HIFIASM_ASM} --primary -t ${THREADS} -i ${RAW_READS_FQ} || { echo "Contig assembly failed"; exit 1; }
echo "Contig assembly complete"

# #convert gfa to fasta
# for gfa in ${GFA_FILES}; do
#     echo "Extracting contigs for ${gfa}..."

#     #extract basename to name output fasta file
#     hap=$(basename ${gfa} | grep -o "hap[0-9]")
#     fasta_out="${CONTIGS_DIR}/dSAMPLE_CLI_${hap}.fa"

#     #extract sequences from gfa to fasta
#     awk '/^S/{print ">"$2; print $3}' "${gfa}" > ${fasta_out} || { echo "Contig extraction failed for ${gfa}"; exit 1; }
#     echo "Contig extraction for ${gfa} complete."

#     #compress original fasta file
#     echo "Compressing fasta file..."
#     gzip -k ${fasta_out} || { echo "Fasta compression failed for ${fasta_out}"; exit 1; }
#     echo "Fasta and compressed files successfully produced"
# done

#delete temp dir
rm -rf "${TEMP_DIR}"