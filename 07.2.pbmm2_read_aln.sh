#!/bin/bash
#PBS -l select=1:ncpus=36:mem=40GB
#PBS -q bix
#PBS -l walltime=8:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource allocation
THREADS=36


#load modules
module load app/miniconda/mamba
conda activate helper-tools

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
READS="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
FILTERED_READS="${WORKDIR}/raw_reads/dSAMPLE_CLI_filtered.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
PBMM2_SCAFFOLD_DIR="__RESULTS_DIR__"
RAGTAG_OUTPUT_DIR="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output"
WHOLE_BAM="${PBMM2_SCAFFOLD_DIR}/correction_checks/dSAMPLE_CLI_whole.bam"

#chromosomes to be corrected
CORRECTION_CHROMOSOMES=()

#make dgenies input directory
mkdir -p "${RAGTAG_SCAFFOLD_DIR}/correction_checks"

#filter reads if needed
if [[ -s "${FILTERED_READS}" ]]; then
    echo "Found filtered reads; proceeding to minimap2"
else
    echo "Filtering raw reads"
    filtlong \
    --min_mean_q 20 \
    --min_length 8000 \
    "${READS}" | gzip -k > "${FILTERED_READS}" || { echo "Filtlong failed for ${READS}"; exit 1; }
fi

#align reads to the whole scaffolded assembly once
conda deactivate
conda activate pbmm2

pbmm2 align --sort -J "${THREADS}" --bam-index BAI "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" "${FILTERED_READS}" "${WHOLE_BAM}"

#deactivate pbmm2 conda environment
conda deactivate
conda activate helper-tools

#function to extract regions matching to chromosomes of interest
extract_region(){
    local CHRSM="$1"
    local OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/correction_checks/chromosome_${CHRSM}"
    local OUTPUT_BAM="${OUTPUT_DIR}/dSAMPLE_CLI_chromosome_${CHRSM}.bam"

    mkdir -p "${OUTPUT_DIR}"

    samtools view -b "${WHOLE_BAM}" "${CHRSM}_RagTag" > "${OUTPUT_BAM}"
    samtools index "${OUTPUT_BAM}"
}


# run function to correct chromosomes
for CHR in "${CORRECTION_CHROMOSOMES[@]}"; do
    extract_region "${CHR}"
done