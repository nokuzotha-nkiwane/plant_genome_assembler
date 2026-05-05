#!/bin/bash
source ~/.pbsrc

#user input of sample and script to run 
SAMPLE="${1}"
SCRIPT="${2}"
STEP="${2%.pbs}"

#directory to write results out to 
RESULTS_DIR="${GRAPEVINE_PATH}/${SAMPLE}/results/${STEP}"

#move existing results directory to old_runs; include run metadata in filename for easy tracking
if [ -d ${RESULTS_DIR} ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OLD_COMMIT=$(grep "commit:" "${RESULTS_DIR}/run_metadata.txt" 2>/dev/null | cut -d ":" -f2 | tr -d " ")
    ARCHIVE_NAME="${STEP}_${TIMESTAMP}_${OLD_COMMIT}"
    mkdir -p "${GRAPEVINE_PATH}/${SAMPLE}/old_runs/${STEP}"
    mv ${RESULTS_DIR} "${GRAPEVINE_PATH}/${SAMPLE}/old_runs/${STEP}/${ARCHIVE_NAME}"
    echo "Archived old results -> old_runs/${ARCHIVE_NAME}"
fi

#make new results directory
mkdir -p ${RESULTS_DIR}

#substitutions for PBS directives in script
JOB_ID=$(sed -e "s/PBS_EMAIL/${PBS_EMAIL}/g" \
    -e "s/PROJECT_NAME/${PROJECT_NAME}/g" \
    -e "s|GRAPEVINE_PATH_PBS|${GRAPEVINE_PATH}|g" \
    -e "s/SAMPLE_CLI/${SAMPLE}/g" \
    ${SCRIPT} | qsub)

#write run metadata for current iteration
echo "sample: ${SAMPLE}
script: ${2}
commit: $(git rev-parse --short HEAD)
date: $(date -u)
pbs_job_id: ${JOB_ID}" > "${RESULTS_DIR}/run_metadata.txt"

#notify that job was successfully submitted
echo "Submitted ${JOB_ID} -> ${RESULTS_DIR}"