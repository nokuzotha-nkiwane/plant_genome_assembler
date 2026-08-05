#!/bin/bash
#PBS -l ncpus=24
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=6:00:00
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
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"

#resource parameters
THREADS=23

#which ragtag stage this run evaluates -- sed-substituted by submit.sh's
#RAGTAG_MODE=correct|scaffold CLI argument. The two modes are independent for now
#(scaffold runs on the raw hifiasm output, not the ragtag-corrected assembly); will
#chain them once the best hifiasm config + correction step is settled
RAGTAG_MODE="__RAGTAG_MODE__"

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="${TOMATO_PATH}/data"

if [[ "${RAGTAG_MODE}" == "correct" ]];then
        CONTIGS_IN="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
elif [[ "${RAGTAG_MODE}" == "scaffold" ]];then
        CONTIGS_IN="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/ragtag.scaffold.fasta"
else
    echo "Error: RAGTAG_MODE must be 'correct' or 'scaffold', got: ${RAGTAG_MODE}"
    exit 1
fi

TEMP_DIR="${BUSCO_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy fasta to temporary directory
cp "${CONTIGS_IN}" "${TEMP_DIR}/"
CONTIGS_IN="${TEMP_DIR}/$(basename "${CONTIGS_IN}")"

#extract base filename without extension for a unique output folder
BASE_NAME=$(basename "${CONTIGS_IN}" .fasta)

#check quality of assembled contigs
busco --in "${CONTIGS_IN}" \
    -m genome \
    --offline \
    -l solanales_odb10 \
    --download_path "${BUSCO_DB_DIR}" \
    -c "${THREADS}" \
    -f \
    -o "${BASE_NAME}_busco" \
    --out_path "${BUSCO_DIR}" \
    || { echo "BUSCO failed for ${CONTIGS_IN}"; exit 1; }

echo "BUSCO for ${CONTIGS_IN} (${RAGTAG_MODE}) complete"