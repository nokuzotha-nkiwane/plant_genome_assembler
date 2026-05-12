#!/bin/bash
#kill execution at first error
set -euo pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#user input of sample and script to run 
SCRIPT="${1:?Please enter the command line argument: script_name}"
SAMPLE="${2:?Please enter the command line argument: sample_name}"
STEP="${SCRIPT%.pbs}"

#validate environment (variables set in ~/.pbsrc)
[[ -z "${GRAPEVINE_PATH}" ]] && { echo "Error: GRAPEVINE_PATH not set"; exit 1; }
[[ -z "${PBS_EMAIL}" ]] && { echo "Error: PBS_EMAIL not set"; exit 1; }
[[ -z "${PROJECT_NAME}" ]] && { echo "Error: PROJECT_NAME not set"; exit 1; }

#directory to write results out to 
RESULTS_DIR="${GRAPEVINE_PATH}/${SAMPLE}/results/${STEP}"

#move existing results directory to old_runs; include run metadata in filename for easy tracking
if [ -d ${RESULTS_DIR} ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OLD_COMMIT=$(grep "commit:" "${RESULTS_DIR}/run_metadata.txt" 2>/dev/null | cut -d ":" -f2 | tr -d " ")
    ARCHIVE_NAME="${STEP}_${TIMESTAMP}_${OLD_COMMIT}"
    mkdir -p "${GRAPEVINE_PATH}/${SAMPLE}/old_runs/${STEP}" 
    mv ${RESULTS_DIR} "${GRAPEVINE_PATH}/${SAMPLE}/old_runs/${STEP}/${ARCHIVE_NAME}" || \
    { echo "Error: archive failed. Results may be overwritten"; exit 1; }
    echo "Archived old results -> old_runs/${ARCHIVE_NAME}"
fi

#make new results directory
mkdir -p ${RESULTS_DIR}

#substitutions for PBS directives in script
JOB_ID=$(sed -e "s/PBS_EMAIL/${PBS_EMAIL}/g" \
    -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
    -e "s|OUTPUT_FILE_PBS|${GRAPEVINE_PATH}/${SAMPLE}/results/${STEP}/${STEP}.out|g" \
    -e "s|ERROR_FILE_PBS|${GRAPEVINE_PATH}/${SAMPLE}/results/${STEP}/${STEP}.err|g" \
    -e "s|RESULTS_DIR|${RESULTS_DIR}|g" \
    -e "s/SAMPLE_CLI/${SAMPLE}/g" \
    ${SCRIPT} | qsub) || { echo "Error: qsub submission failed"; exit 1; }

#write run metadata for current iteration
echo "sample: ${SAMPLE}
script: ${1}
commit: $(git rev-parse --short HEAD)
date: $(date -u)
pbs_job_id: ${JOB_ID}" > "${RESULTS_DIR}/run_metadata.txt"

#notify that job was successfully submitted
echo "Submitted ${JOB_ID} -> ${RESULTS_DIR}"