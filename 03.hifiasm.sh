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

#load modules
module load app/miniconda/mamba
conda activate hifiasm

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
HIFIASM_DIR="__RESULTS_DIR__"
HIFIASM_ASM="${HIFIASM_DIR}/dSAMPLE_CLI.asm"
GFA_P_FILE="${HIFIASM_DIR}/dSAMPLE_CLI.asm.p_ctg.gfa"
GFA_A_FILE="${HIFIASM_DIR}/dSAMPLE_CLI.asm.a_ctg.gfa"
TEMP_DIR="${HIFIASM_DIR}/${PBS_JOBID}_temp"
HIFIASM_P_FASTA="${HIFIASM_DIR}/dSAMPLE_CLI_primary.fa"
HIFIASM_A_FASTA="${HIFIASM_DIR}/dSAMPLE_CLI_alternate.fa"

#make temp directory to copy reads to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"
cp "${RAW_READS_FQ}" "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#hifiasm assembly
echo "Performing contig assembly..."
hifiasm -o "${HIFIASM_ASM}" --primary -t "${THREADS}" -i "${RAW_READS_FQ}" || { echo "Contig assembly failed"; exit 1; }
echo "Contig assembly complete"

#make an arrary of input gfa files and corresponding output fasta files
GFA_FILES=("${GFA_P_FILE}" "${GFA_A_FILE}")
FASTA_FILES=("${HIFIASM_P_FASTA}" "${HIFIASM_A_FASTA}" )

#convert gfa to fasta
echo "Converting GFA files to fasta"
for i in "${!GFA_FILES[@]}"; do
    awk '/^S/{print ">"$2; print $3}' "${GFA_FILES[$i]}" > "${FASTA_FILES[$i]}" \
        || { echo "GFA to FASTA conversion failed for ${GFA_FILES[$i]}"; exit 1; }
done
gzip -k "${FASTA_FILES[@]}"


#delete temp dir
rm -rf "${TEMP_DIR}"