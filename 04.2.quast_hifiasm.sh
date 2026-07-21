#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
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
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/T2T_ref.zip"
REF_GFF3="${REF_DIR}/PN40024_5.1_on_T2T_ref_with_names.zip"
#feature_files="${ref_dir}/5.1_on_T2T_all_variants.zip"
QUAST_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"
CONTIGS_DIR="${ALL_RESULTS_DIR}/contigs"
HAP1="${CONTIGS_DIR}/dSAMPLE_CLI_hap1.fa.gz"
HAP2="${CONTIGS_DIR}/dSAMPLE_CLI_hap2.fa.gz"

#load modules
module load app/QUAST/5.3.0

#check quality of assembled contigs for each haplotype

python /apps/chpc/bio/quast/5.2.0/quast.py ${HAP1} \
    ${HAP2} \
    -r ${REF_GENOME} \
    -g ${REF_GFF3} \
    -o ${QUAST_DIR} \
    -e \
    -k \
    --circos \
    --plots-format pdf \
    -t ${THREADS}
    # --features ${feature_files} \
