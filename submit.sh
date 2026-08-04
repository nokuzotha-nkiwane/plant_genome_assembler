#!/bin/bash
#kill execution at first error
set -euo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#user input of sample and script to run
SCRIPT="${1:?Please enter the command line argument: script_name}"

#cross-sample scripts are named step_name.cross.sh; strip both the .cross
#marker and .sh extension to get the base step name, and use the marker's
#presence to identify cross-sample scripts (e.g. asm-to-asm alignments)
if [[ "${SCRIPT}" == *.cross.sh ]]; then
    IS_CROSS=true
    STEP="${SCRIPT%.cross.sh}"
else
    IS_CROSS=false
    SAMPLE_CLI="${2:?Please enter the command line argument: sample_name}"
    STEP="${SCRIPT%.sh}"
fi
[[ "${IS_CROSS}" == true ]] && SAMPLE_CLI="combined_03_05"

#validate environment (variables set in ~/.pbsrc)
[[ -z "${TOMATO_PATH}" ]] && { echo "Error: TOMATO_PATH not set"; exit 1; }
[[ -z "${PBS_EMAIL}" ]] && { echo "Error: PBS_EMAIL not set"; exit 1; }


#cross-sample scripts (e.g. asm-to-asm alignments) write to TOMATO_PATH/results
#instead of being nested under an individual SAMPLE_CLI's results directory
if [[ "${IS_CROSS}" == true ]]; then
    RESULTS_DIR="${TOMATO_PATH}/combined_03_05/results/${STEP}"
else
    RESULTS_DIR="${TOMATO_PATH}/${SAMPLE_CLI}/results/${STEP}"
fi

#move existing results directory to old_runs; include run metadata in filename for easy tracking
if [ -d ${RESULTS_DIR} ]; then
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OLD_COMMIT=$(grep "commit:" "${RESULTS_DIR}/run_metadata.txt" 2>/dev/null | cut -d ":" -f2 | tr -d " ") || OLD_COMMIT="unknown"
ARCHIVE_NAME="${STEP}_${TIMESTAMP}_${OLD_COMMIT}"

#cross sample analyses
if [[ "${IS_CROSS}" == true ]]; then
    mkdir -p "${TOMATO_PATH}/combined_03_05/old_runs/${STEP}"
    mv ${RESULTS_DIR} "${TOMATO_PATH}/combined_03_05/old_runs/${STEP}/${ARCHIVE_NAME}" || \
    { echo "Error: archive failed. Results may be overwritten"; exit 1; }
else
    mkdir -p "${TOMATO_PATH}/${SAMPLE_CLI}/old_runs/${STEP}"
    mv ${RESULTS_DIR} "${TOMATO_PATH}/${SAMPLE_CLI}/old_runs/${STEP}/${ARCHIVE_NAME}" || \
    { echo "Error: archive failed. Results may be overwritten"; exit 1; }
fi
echo "Archived old results -> old_runs/${ARCHIVE_NAME}"
fi

#make new results directory
mkdir -p ${RESULTS_DIR}

#substitutions for PBS directives in script
JOB_ID=$(sed -e "s/PBS_EMAIL/${PBS_EMAIL}/g" \
    -e "s/STEP_PBS/${STEP}/g" \
    -e "s|OUTPUT_FILE_PBS|${RESULTS_DIR}/${STEP}.out|g" \
    -e "s|ERROR_FILE_PBS|${RESULTS_DIR}/${STEP}.err|g" \
    -e "s|__RESULTS_DIR__|${RESULTS_DIR}|g" \
    -e "s/SAMPLE_CLI/${SAMPLE_CLI}/g" \
    ${SCRIPT} | qsub) || { echo "Error: qsub submission failed"; exit 1; }

#write run metadata for current iteration
echo "sample: ${SAMPLE_CLI}
script: ${SCRIPT}
commit: $(git rev-parse --short HEAD)
date: $(date -u)
pbs_job_id: ${JOB_ID}" > "${RESULTS_DIR}/run_metadata.txt"

#notify that job was successfully submitted
echo "Submitted ${JOB_ID} -> ${RESULTS_DIR}"