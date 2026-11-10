#!/bin/bash
#PBS -l select=1:ncpus=24:mem=60GB
#PBS -q bix
#PBS -l walltime=24:00:00
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
module load app/nextflow/24

#files and directories
WORKDIR="${TOMATO_PATH}"
ANNOT_OUT_DIR="__RESULTS_DIR__"
LIFTOFF_ANNOTATION_CSV="${ANNOT_OUT_DIR}/input_liftoff_annotation.csv"
REF_GFF3="${WORKDIR}/data/reference_data/SL5.0.gff3"
REF_FASTA="${WORKDIR}/data/reference_data/SL5.0.fasta"
SAMPLE_CSV="${ANNOT_OUT_DIR}/sample_assembly_sheet.csv"
SAMPLE_D03_TAG="sample_d03"
SAMPLE_D05_TAG="sample_d05"
SAMPLE_D03_PATH="${WORKDIR}/03/results/09.2.edta_repeat_masking/d03.ragtag.scaffold.chromosomes_soft_masked.fasta"
SAMPLE_D05_PATH="${WORKDIR}/05/results/09.2.edta_repeat_masking/d05.ragtag.scaffold.chromosomes_soft_masked.fasta"
BRAKER_PROTEIN_EVIDENCE="${WORKDIR}/data/orthodb13/Viridiplantae.fa"
EGGNOG_MAPPER="${WORKDIR}/data/databases/eggnog_v7"
EGGNOG_MAPPER_TAX_SCOPE=33090
EMAIL="PBS_EMAIL"
LOGFILE="${ANNOT_OUT_DIR}/genepal.log"

#move into output directory
cd "${ANNOT_OUT_DIR}"

#singularity cache directory
export NXF_SINGULARITY_CACHEDIR="/new-home/25086138/singularity_cache"

#make sample csv
printf 'tag,fasta,is_masked\n' > "${SAMPLE_CSV}"
printf '"%s","%s",yes\n' "${SAMPLE_D03_TAG}" "${SAMPLE_D03_PATH}" >> "${SAMPLE_CSV}"
printf '"%s","%s",yes\n' "${SAMPLE_D05_TAG}" "${SAMPLE_D05_PATH}" >> "${SAMPLE_CSV}"

#make liftoff annotation csv
printf 'fasta,gff3\n' > "${LIFTOFF_ANNOTATION_CSV}"
printf '"%s","%s"' "${REF_FASTA}" "${REF_GFF3}" >> "${LIFTOFF_ANNOTATION_CSV}"

#run genepal
nextflow run plant-food-research-open/genepal \
  -revision 1.0.1 \
  -profile singularity\
  --input "${SAMPLE_CSV}" \
  --email "${EMAIL}" \
  --protein_evidence "${BRAKER_PROTEIN_EVIDENCE}" \
  --eggnogmapper_db_dir "${EGGNOG_MAPPER}" \
  --eggnogmapper_tax_scope "${EGGNOG_MAPPER_TAX_SCOPE}" \
  --liftoff_annotations "${LIFTOFF_ANNOTATION_CSV}" \
  --outdir "${ANNOT_OUT_DIR}" \
  2>&1 | tee -a "${LOGFILE}"