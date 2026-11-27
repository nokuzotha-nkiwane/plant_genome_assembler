#!/bin/bash
#PBS -l select=1:ncpus=72:mem=256GB
#PBS -q bix
#PBS -l walltime=96:00:00
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
module load app/Java/21.0.2
module load app/apptainer/1.2.5

#files and directories
WORKDIR="${TOMATO_PATH}"
VARIANTS_OUT_DIR="__RESULTS_DIR__"
CUSTOM_CONFIG="/new-home/25086138/my_environments/pacvar/custom.config"
PARAMS_JSON="/new-home/25086138/my_environments/pacvar/params.json"
REF_FASTA="${WORKDIR}/data/subset_tests/SL5.0_chr2_chr6.fa"
SAMPLE_CSV="${VARIANTS_OUT_DIR}/samplesheet.csv"
SAMPLE_D03_TAG="sample_d03"
SAMPLE_D05_TAG="sample_d05"
BAM_READS_03="${WORKDIR}/data/subset_tests/d03/D260405-03.chr2_chr6.hifi_reads.bam"
PBI_READS_03="${WORKDIR}/data/subset_tests/d03/D260405-03.chr2_chr6.hifi_reads.bam.pbi"
BAM_READS_05="${WORKDIR}/data/subset_tests/d05/D260405-05.chr2_chr6.hifi_reads.bam"
PBI_READS_05="${WORKDIR}/data/subset_tests/d05/D260405-05.chr2_chr6.hifi_reads.bam.pbi"
SAMPLE_D03_ID_MAP="${VARIANTS_OUT_DIR}/d03.id_map.tsv"
SAMPLE_D05_ID_MAP="${VARIANTS_OUT_DIR}/d05.id_map.tsv"
WORKFLOW_TYPE="wgs"
SV_CALLER="sawfish"
SNV_CALLER="deepvariant"
LOGFILE="${VARIANTS_OUT_DIR}/pacvar.log"

#move into output directory
cd "${VARIANTS_OUT_DIR}"

#singularity cache directory
export NXF_SINGULARITY_CACHEDIR="/new-home/25086138/singularity_cache"

#make sample csv
printf 'sample,bam,pbi\n' > "${SAMPLE_CSV}"
printf '%s,%s,%s\n' "${SAMPLE_D03_TAG}" "${BAM_READS_03}" "${PBI_READS_03}" >> "${SAMPLE_CSV}"
printf '%s,%s,%s\n' "${SAMPLE_D05_TAG}" "${BAM_READS_05}" "${PBI_READS_05}" >> "${SAMPLE_CSV}"

#run pacvar
nextflow run nf-core/pacvar \
    -revision 1.1.0 \
    -profile singularity \
    -c "${CUSTOM_CONFIG}" \
    -params-file "${PARAMS_JSON}" \
    --input "${SAMPLE_CSV}" \
    --workflow "${WORKFLOW_TYPE}" \
    --fasta "${REF_FASTA}" \
    --sv_caller "${SV_CALLER}" \
    --snv_caller "${SNV_CALLER}" \
    --outdir "${VARIANTS_OUT_DIR}" \
      2>&1 | tee -a "${LOGFILE}"
