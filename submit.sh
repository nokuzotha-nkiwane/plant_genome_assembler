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
    #for cross-sample scripts the optional ragtag-mode arg is $2 (no SAMPLE_CLI arg)
    EXTRA_ARG="${2:-}"
else
    IS_CROSS=false
    SAMPLE_CLI="${2:?Please enter the command line argument: sample_name}"
    STEP="${SCRIPT%.sh}"
    #optional 3rd arg: value for __RAGTAG_MODE__, either "correct" or "scaffold".
    #Only meaningful for scripts that contain that placeholder (currently
    #06.1.busco_ragtag.sh); nests results/old_runs by value so runs don't collide
    EXTRA_ARG="${3:-}"
fi

[[ "${IS_CROSS}" == true ]] && SAMPLE_CLI="combined_03_05"

#validate environment (variables set in ~/.pbsrc)
[[ -z "${TOMATO_PATH}" ]] && { echo "Error: TOMATO_PATH not set"; exit 1; }
[[ -z "${PBS_EMAIL}" ]] && { echo "Error: PBS_EMAIL not set"; exit 1; }

#archive/results dir name gets the ragtag mode appended, when given, so e.g.
#06.1.busco_ragtag_correct and 06.1.busco_ragtag_scaffold are distinguishable
ARCHIVE_STEP="${STEP}"
[[ -n "${EXTRA_ARG}" ]] && ARCHIVE_STEP="${STEP}_${EXTRA_ARG}"

#cross-sample scripts (e.g. asm-to-asm alignments) write to TOMATO_PATH/results
#instead of being nested under an individual SAMPLE_CLI's results directory
if [[ "${IS_CROSS}" == true ]]; then
    BASE_RESULTS_DIR="${TOMATO_PATH}/combined_03_05/results/${STEP}"
else
    BASE_RESULTS_DIR="${TOMATO_PATH}/${SAMPLE_CLI}/results/${STEP}"
fi

#nest under the ragtag-mode value when one was supplied, so "correct" and
#"scaffold" runs of the same script land in separate subfolders instead of
#overwriting/archiving each other
if [[ -n "${EXTRA_ARG}" ]]; then
    RESULTS_DIR="${BASE_RESULTS_DIR}/${EXTRA_ARG}"
else
    RESULTS_DIR="${BASE_RESULTS_DIR}"
fi

#move existing results directory to old_runs; include run metadata in filename for easy tracking
if [ -d ${RESULTS_DIR} ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OLD_COMMIT=$(grep "commit:" "${RESULTS_DIR}/run_metadata.txt" 2>/dev/null | cut -d ":" -f2 | tr -d " ") || OLD_COMMIT="unknown"
    ARCHIVE_NAME="${ARCHIVE_STEP}_${TIMESTAMP}_${OLD_COMMIT}"

    #cross sample analyses
    if [[ "${IS_CROSS}" == true ]]; then
        mkdir -p "${TOMATO_PATH}/combined_03_05/old_runs/${ARCHIVE_STEP}"
        mv ${RESULTS_DIR} "${TOMATO_PATH}/combined_03_05/old_runs/${ARCHIVE_STEP}/${ARCHIVE_NAME}" || \
            { echo "Error: archive failed. Results may be overwritten"; exit 1; }
    else
        mkdir -p "${TOMATO_PATH}/${SAMPLE_CLI}/old_runs/${ARCHIVE_STEP}"
        mv ${RESULTS_DIR} "${TOMATO_PATH}/${SAMPLE_CLI}/old_runs/${ARCHIVE_STEP}/${ARCHIVE_NAME}" || \
            { echo "Error: archive failed. Results may be overwritten"; exit 1; }
    fi

    echo "Archived old results -> old_runs/${ARCHIVE_NAME}"
fi

#make new results directory
mkdir -p ${RESULTS_DIR}

#substitutions for PBS directives in script. ARCHIVE_STEP (not STEP) drives the job
#name / .out / .err filenames so ragtag-mode variants are distinguishable in qstat
#and in the results dir listing
SED_ARGS=(
    -e "s/PBS_EMAIL/${PBS_EMAIL}/g"
    -e "s/STEP_PBS/${ARCHIVE_STEP}/g"
    -e "s|OUTPUT_FILE_PBS|${RESULTS_DIR}/${ARCHIVE_STEP}.out|g"
    -e "s|ERROR_FILE_PBS|${RESULTS_DIR}/${ARCHIVE_STEP}.err|g"
    -e "s|__RESULTS_DIR__|${RESULTS_DIR}|g"
    -e "s/SAMPLE_CLI/${SAMPLE_CLI}/g"
)
#substitute __RAGTAG_MODE__ only when a value was actually supplied
[[ -n "${EXTRA_ARG}" ]] && SED_ARGS+=(-e "s/__RAGTAG_MODE__/${EXTRA_ARG}/g")

JOB_ID=$(sed "${SED_ARGS[@]}" ${SCRIPT} | qsub) || { echo "Error: qsub submission failed"; exit 1; }

#write run metadata for current iteration
echo "sample: ${SAMPLE_CLI}
script: ${SCRIPT}
ragtag_mode: ${EXTRA_ARG:-none}
commit: $(git rev-parse --short HEAD)
date: $(date -u)
pbs_job_id: ${JOB_ID}" > "${RESULTS_DIR}/run_metadata.txt"

#notify that job was successfully submitted
echo "Submitted ${JOB_ID} -> ${RESULTS_DIR}"