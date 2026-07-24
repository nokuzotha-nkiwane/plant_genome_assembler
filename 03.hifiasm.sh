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
HIFIASM_DIR="__RESULTS_DIR__"
HIFIASM_ASM="${HIFIASM_DIR}/dSAMPLE_CLI.asm"
GFA_FILE="${HIFIASM_DIR}/dSAMPLE_CLI.asm.p_ctg.gfa"
TEMP_DIR="${HIFIASM_DIR}/${PBS_JOBID}_temp"
HIFIASM_OUT_FASTA="${HIFIASM_DIR}/dSAMPLE_CLI_primary.fa"
BUSCO_DB_DIR="${TOMATO_PATH}/data"
BUSCO_DIR="${HIFIASM_DIR}/busco"
OUTPUT_PREFIX="dSAMPLE_CLI_"

#load modules
module load app/miniconda/mamba
conda activate hifiasm

#make temp directory to copy reads to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}" "${BUSCO_DIR}"
cp "${RAW_READS_FQ}" "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#hifiasm assembly
echo "Performing contig assembly..."
hifiasm -o "${HIFIASM_ASM}" --primary -t "${THREADS}" -i "${RAW_READS_FQ}" || { echo "Contig assembly failed"; exit 1; }
echo "Contig assembly complete"

#convert gfa to fasta
awk '/^S/{print ">"$2; print $3}' "${GFA_FILE}" > "${HIFIASM_OUT_FASTA}"
gzip -k "${HIFIASM_OUT_FASTA}"

#deactivate conda environment
conda deactivate

#activate busco environment
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"

#busco
echo "Running BUSCO for $( basename "${HIFIASM_OUT_FASTA}" )"
busco --in "${HIFIASM_OUT_FASTA}" \
    -m genome \
    --offline \
    -l eudicotyledons_odb12 \
    --download_path "${BUSCO_DB_DIR}" \
    -c "${THREADS}" \
    -f \
    -o "${OUTPUT_PREFIX}" \
    --out_path "${BUSCO_DIR}"

echo "BUSCO for $( basename "${HIFIASM_OUT_FASTA}" )"

#delete temp dir
rm -rf "${TEMP_DIR}"