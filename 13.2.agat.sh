#!/bin/bash
#PBS -l select=1:ncpus=24:mem=40GB
#PBS -q bix
#PBS -l walltime=8:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -uxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource allocation
THREADS=23

#load modules
module load app/agat/1.4.1

# directories and files

WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
ANNOTATION_DIR="__RESULTS_DIR__"
INPUT_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
REF_GFF3="${TOMATO_PATH}/data/reference_data/SL5.0.gff3"
LIFTON_GFF3="${ALL_RESULTS_DIR}/11.lifton/dSAMPLE_CLI.ragtag.scaffold.chromosomes.lifton.gff3"
BRAKER_GFF3="${ALL_RESULTS_DIR}/10.BRAKER/output/dSAMPLE_CLI/results/braker.gff3"
AEGIS_LIFTON_GFF3="${ALL_RESULTS_DIR}/12.aegis_merge/liftoff/dSAMPLE_CLI_consolidated_LIFTON_first.gff3"
AEGIS_BRAKER_GFF3="${ALL_RESULTS_DIR}/12.aegis_merge/braker/dSAMPLE_CLI_consolidated_BRAKER_first.gff3"

#make output directory
mkdir -p "${ANNOTATION_DIR}"
cd "${ANNOTATION_DIR}"

#get basenames of each
LIFTON_BASENAME="dSAMPLE_CLI.lifton"
BRAKER_BASENAME="dSAMPLE_CLI.braker"
REF_BASENAME="SL5.0"
AEGIS_LIFTON_BASENAME="dSAMPLE_CLI.aegis_lifton"
AEGIS_BRAKER_BASENAME="dSAMPLE_CLI.aegis_braker"

#check syntax, duplicate IDs
# agat_convert_sp_gxf2gxf.pl --gff "${REF_GFF3}" --cpu "${THREADS}" -o "${ANNOTATION_DIR}/${REF_BASENAME}.agat.gff3"
# agat_convert_sp_gxf2gxf.pl --gff "${LIFTON_GFF3}" --cpu "${THREADS}" -o "${ANNOTATION_DIR}/${LIFTON_BASENAME}.agat.gff3"
# agat_convert_sp_gxf2gxf.pl --gff "${BRAKER_GFF3}" --cpu "${THREADS}" -o "${ANNOTATION_DIR}/${BRAKER_BASENAME}.agat.gff3"
# agat_convert_sp_gxf2gxf.pl --gff "${AEGIS_LIFTON_GFF3}" --cpu "${THREADS}" -o "${ANNOTATION_DIR}/${AEGIS_LIFTON_BASENAME}.agat.gff3"
# agat_convert_sp_gxf2gxf.pl --gff "${AEGIS_BRAKER_GFF3}" --cpu "${THREADS}" -o "${ANNOTATION_DIR}/${AEGIS_BRAKER_BASENAME}.agat.gff3"

#get genic content statistics (for comparing gene count, mean gene, CDS, exon and intron lengths among other spicy things)
agat_sp_statistics.pl --gff "${REF_GFF3}" -o "${ANNOTATION_DIR}/${REF_BASENAME}.gene_stats.txt"
agat_sp_statistics.pl --gff "${LIFTON_GFF3}" -o "${ANNOTATION_DIR}/${LIFTON_BASENAME}.gene_stats.txt"
agat_sp_statistics.pl --gff "${BRAKER_GFF3}" -o "${ANNOTATION_DIR}/${BRAKER_BASENAME}.gene_stats.txt"
agat_sp_statistics.pl --gff "${AEGIS_LIFTON_GFF3}" -o "${ANNOTATION_DIR}/${AEGIS_LIFTON_BASENAME}.gene_stats.txt"
agat_sp_statistics.pl --gff "${AEGIS_BRAKER_GFF3}" -o "${ANNOTATION_DIR}/${AEGIS_BRAKER_BASENAME}.gene_stats.txt"

#get genic content statistics for agat gff3 (for comparing gene count, mean gene, CDS, exon and intron lengths among other spicy things)
agat_sp_statistics.pl --gff "${REF_GFF3}" -o "${ANNOTATION_DIR}/${REF_BASENAME}.agat.gene_stats.txt"
agat_sp_statistics.pl --gff "${LIFTON_GFF3}" -o "${ANNOTATION_DIR}/${LIFTON_BASENAME}.agat.gene_stats.txt"
agat_sp_statistics.pl --gff "${BRAKER_GFF3}" -o "${ANNOTATION_DIR}/${BRAKER_BASENAME}.agat.gene_stats.txt"
agat_sp_statistics.pl --gff "${AEGIS_LIFTON_GFF3}" -o "${ANNOTATION_DIR}/${AEGIS_LIFTON_BASENAME}.agat.gene_stats.txt"
agat_sp_statistics.pl --gff "${AEGIS_BRAKER_GFF3}" -o "${ANNOTATION_DIR}/${AEGIS_BRAKER_BASENAME}.agat.gene_stats.txt"

#extract cds
agat_sp_extract_sequences.pl --gff "${LIFTON_GFF3}" -f "${INPUT_FASTA}" -t cds -o "${ANNOTATION_DIR}/${LIFTON_BASENAME}.cds.fasta"
agat_sp_extract_sequences.pl --gff "${BRAKER_GFF3}" -f "${INPUT_FASTA}" -t cds -o "${ANNOTATION_DIR}/${BRAKER_BASENAME}.cds.fasta"
agat_sp_extract_sequences.pl --gff "${AEGIS_LIFTON_GFF3}" -f "${INPUT_FASTA}" -t cds -o "${ANNOTATION_DIR}/${AEGIS_LIFTON_BASENAME}.cds.fasta"
agat_sp_extract_sequences.pl --gff "${AEGIS_BRAKER_GFF3}" -f "${INPUT_FASTA}" -t cds -o "${ANNOTATION_DIR}/${AEGIS_BRAKER_BASENAME}.cds.fasta"

#extract protein sequences
agat_sp_extract_sequences.pl --gff "${LIFTON_GFF3}" -f "${INPUT_FASTA}" -t cds -p -o "${ANNOTATION_DIR}/${LIFTON_BASENAME}.proteins.fasta"
agat_sp_extract_sequences.pl --gff "${BRAKER_GFF3}" -f "${INPUT_FASTA}" -t cds -p -o "${ANNOTATION_DIR}/${BRAKER_BASENAME}.proteins.fasta"
agat_sp_extract_sequences.pl --gff "${AEGIS_LIFTON_GFF3}" -f "${INPUT_FASTA}" -t cds -p -o "${ANNOTATION_DIR}/${AEGIS_LIFTON_BASENAME}.proteins.fasta"
agat_sp_extract_sequences.pl --gff "${AEGIS_BRAKER_GFF3}" -f "${INPUT_FASTA}" -t cds -p -o "${ANNOTATION_DIR}/${AEGIS_BRAKER_BASENAME}.proteins.fasta"