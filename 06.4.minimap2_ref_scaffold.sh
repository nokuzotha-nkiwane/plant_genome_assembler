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
THREADS=23


#load modules
module load app/miniconda/mamba
conda activate helper-tools

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME_1="${REF_DIR}/SL5.0.fasta.gz"
REF_GENOME_2="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
READS="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
MIN_MEAN_Q=20
# MIN_LENGTH=3000
MIN_MAPQ=30
FILTERED_READS="${WORKDIR}/raw_reads/filtered_reads/dSAMPLE_CLI_filtered_minlen7000.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
READ_SCAFFOLD_ALN_DIR="__RESULTS_DIR__"
RAGTAG_OUTPUT_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/f15000_d500000"
RAGTAG_PREFIX="SAMPLE_CLI.f15000_d500000"
CHROMOSOMES_FASTA="${RAGTAG_OUTPUT_DIR}/${RAGTAG_PREFIX}.ragtag.scaffold.chromosomes.fasta"
SCAFFOLD_FASTA="${RAGTAG_OUTPUT_DIR}/${RAGTAG_PREFIX}.ragtag.scaffold.fasta"
SCAFFOLD_PAF="${READ_SCAFFOLD_ALN_DIR}/${RAGTAG_PREFIX}.scaffold.paf"
CHROMOSOMES_PAF="${READ_SCAFFOLD_ALN_DIR}/${RAGTAG_PREFIX}.chromosomes.paf"
WHOLE_BAM_SCAFFOLD="${READ_SCAFFOLD_ALN_DIR}/${RAGTAG_PREFIX}_scaffold_whole.bam"
WHOLE_BAM_CHROMOSOMES="${READ_SCAFFOLD_ALN_DIR}/${RAGTAG_PREFIX}_chromosomes_whole.bam"

# #filter reads if needed
# if [[ -s "${FILTERED_READS}" ]]; then
#     echo "Found filtered reads; proceeding to minimap2"
# else
#     echo "Filtering raw reads"
#     filtlong \
#     --min_mean_q "${MIN_MEAN_Q}" \
#     --min_length "${MIN_LENGTH}" \
#     "${READS}" | gzip -k > "${FILTERED_READS}" || { echo "Filtlong failed for ${READS}"; exit 1; }
# fi

#align reads to the whole scaffolded assembly once
# #use pbmm2
# conda deactivate
# conda activate pbmm2
# pbmm2 align --sort -J "${THREADS}" --bam-index BAI "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta" "${FILTERED_READS}" "${WHOLE_BAM}"

#use minimap2
minimap2 -ax map-hifi -t "${THREADS}" --secondary=no -N 1 -p 0.8 --eqx "${SCAFFOLD_FASTA}" "${FILTERED_READS}" | \
    samtools view -b -q "${MIN_MAPQ}" -F 2308 -@ "${THREADS}" - | \
    samtools sort -@ "${THREADS}" -o "${WHOLE_BAM_SCAFFOLD}" -

samtools index "${WHOLE_BAM_SCAFFOLD}"

#use minimap2
minimap2 -ax map-hifi -t "${THREADS}" --secondary=no -N 1 -p 0.8 --eqx "${CHROMOSOMES_FASTA}" "${FILTERED_READS}" | \
    samtools view -b -q "${MIN_MAPQ}" -F 2308 -@ "${THREADS}" - | \
    samtools sort -@ "${THREADS}" -o "${WHOLE_BAM_CHROMOSOMES}" -

samtools index "${WHOLE_BAM_CHROMOSOMES}"

# align scaffold fasta to reference
minimap2 -cx asm5 --cs -t "${THREADS}" "${REF_GENOME_1}" "${SCAFFOLD_FASTA}" > "${SCAFFOLD_PAF}"

# align chromosomes fasta to reference
minimap2 -cx asm5 --cs -t "${THREADS}" "${REF_GENOME_2}" "${CHROMOSOMES_FASTA}" > "${CHROMOSOMES_PAF}"