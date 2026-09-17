#!/bin/bash
#PBS -l select=1:ncpus=23:mem=40GB
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
READS="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
FILTERED_READS="${WORKDIR}/raw_reads/dSAMPLE_CLI_filtered.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
READ_SCAFFOLD_ALN_DIR="__RESULTS_DIR__"
RAGTAG_OUTPUT_DIR="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output"
INPUT_FASTA="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
WHOLE_BAM="${READ_SCAFFOLD_ALN_DIR}/dSAMPLE_CLI_whole.bam"

#chromosomes to be corrected
CORRECTION_CHROMOSOMES=()
MIN_MAPQ=30

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
# #use pbmm2
# conda deactivate
# conda activate pbmm2
# pbmm2 align --sort -J "${THREADS}" --bam-index BAI "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" "${FILTERED_READS}" "${WHOLE_BAM}"

#use minimap2
minimap2 -ax map-hifi -t "${THREADS}" --secondary=no -N 1 -p 0.8 --eqx "${INPUT_FASTA}" "${FILTERED_READS}" | \
    samtools view -b -q "${MIN_MAPQ}" -F 2308 -@ "${THREADS}" - | \
    samtools sort -@ "${THREADS}" -o "${WHOLE_BAM}" -

samtools index "${WHOLE_BAM}"

# #deactivate pbmm2 conda environment
# conda deactivate
# conda activate helper-tools

#function to extract regions matching to chromosomes of interest
extract_region(){
    local CHRSM="$1"
    local OUTPUT_DIR="${READ_SCAFFOLD_ALN_DIR}/chromosome_${CHRSM}"
    local OUTPUT_BAM="${OUTPUT_DIR}/dSAMPLE_CLI_chromosome_${CHRSM}.bam"
    local OUTPUT_FASTA="${OUTPUT_DIR}/dSAMPLE_CLI_chromosome_${CHRSM}.fasta"

    mkdir -p "${OUTPUT_DIR}"

    #extract region in bam
    samtools view -b "${WHOLE_BAM}" "${CHRSM}_RagTag" > "${OUTPUT_BAM}"
    samtools index "${OUTPUT_BAM}"

    #extract fasta sequence
    samtools faidx "${INPUT_FASTA}" "${CHRSM}_RagTag" > "${OUTPUT_FASTA}"
}


# run function to correct chromosomes
for CHR in "${CORRECTION_CHROMOSOMES[@]}"; do
    extract_region "${CHR}"
done