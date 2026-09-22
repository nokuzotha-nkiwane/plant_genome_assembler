#!/bin/bash
#PBS -l ncpus=8
#PBS -l mem=16GB
#PBS -q bix
#PBS -l walltime=4:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#exit at errors
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/apptainer/1.2.5

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GFF3="${REF_DIR}/SL5.0.gff3"
ALL_RESULTS_DIR="${WORKDIR}/results"
BRAKER_GFF3_GZ="${ALL_RESULTS_DIR}/10.BRAKER/output/dSAMPLE_CLI/results/braker.gff3.gz"
BRAKER_GFF3="${ALL_RESULTS_DIR}/10.BRAKER/output/dSAMPLE_CLI/results/braker.gff3"
LIFTON_GFF3="${ALL_RESULTS_DIR}/11.lifton/dSAMPLE_CLI.ragtag.scaffold.chromosomes.lifton.gff3"
OUTPUT_DIR="__RESULTS_DIR__"
OVERLAP_OUTPUT="${OUTPUT_DIR}/aegis_overlap"
MERGE_BRAKER_OUTPUT="${OUTPUT_DIR}/aegis_merge/braker"
MERGE_LIFTON_OUTPUT="${OUTPUT_DIR}/aegis_merge/liftoff"
AEGIS_SIF="/new-home/25086138/my_environments/aegis/aegis.sif"

#make output directories
mkdir -p  "${OVERLAP_OUTPUT}" "${MERGE_BRAKER_OUTPUT}" "${MERGE_LIFTON_OUTPUT}"

#unzip braker gff3 file if unzipped version absent
if [[ ! -s "${BRAKER_GFF3}" ]]; then
    gzip -dk "${BRAKER_GFF3_GZ}"
else
    echo "${BRAKER_GFF3} already exists. Running aegis ..."
fi

#check level of overlap first
singularity run "${AEGIS_SIF}" aegis overlap "${BRAKER_GFF3}" "${LIFTON_GFF3}" \
    --original-annotation-files NA,"${REF_GFF3}" \
    --output-dir "${OVERLAP_OUTPUT}"

#merge annotation files
touch "${OUTPUT_DIR}/aegis_overlap/dir_names_according_to_which_gff3_was_first_in_command.note"

#preference given to BRAKER annotation
singularity run "${AEGIS_SIF}" aegis merge "${BRAKER_GFF3}" "${LIFTON_GFF3}" --output-dir "${MERGE_BRAKER_OUTPUT}" --output-file dSAMPLE_CLI_consolidated_BRAKER_first 2>&1 | \
    tee -a "${MERGE_BRAKER_OUTPUT}/dSAMPLE_CLI_aegis_BRAKER_first.log"

#preference given to Lifton annotation
singularity run "${AEGIS_SIF}" aegis merge "${LIFTON_GFF3}" "${BRAKER_GFF3}" --output-dir "${MERGE_LIFTON_OUTPUT}" --output-file dSAMPLE_CLI_consolidated_LIFTON_first 2>&1 | \
    tee -a "${MERGE_LIFTON_OUTPUT}/dSAMPLE_CLI_aegis_LIFTON_first.log"