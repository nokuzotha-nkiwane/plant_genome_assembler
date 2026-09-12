#!/bin/bash
#PBS -l ncpus=64
#PBS -l mem=80GB
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
module load app/apptainer/1.2.5

#resource parameters
THREADS=64

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
OUTPUT_DIR="__RESULTS_DIR__"
REF_DIR="${TOMATO_PATH}/data/reference_data"
CDS="${REF_DIR}/SL5.cds.fa.gz"
RAGATAG_SCAFFOLD_FASTA="${ALL_RESULTS_DIR}/SL5.0_analyses_l0/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
EDTA_IMAGE="/new-home/25086138/my_environments/edta/EDTA.sif"
TOOL_ENV="/usr/local/bin/"

# EDTA dependency paths (as seen inside the EDTA.sif container, not the host)
EDTA_DEP_OPTS=(
    --repeatmodeler "${TOOL_ENV}"
    --repeatmasker "${TOOL_ENV}"
    --annosine "${TOOL_ENV}"
    --ltrretriever "${TOOL_ENV}"
    --step all
    --anno 1
    --evaluate 1
    -t "${THREADS}"
)

TEMP_DIR="${OUTPUT_DIR}/${PBS_JOBID}_temp"
GENOME_BASENAME="dSAMPLE_CLI.fasta"
CDS_BASENAME="$(basename "${CDS}")"

trap 'rm -rf "${TEMP_DIR}"' EXIT

mkdir -p "${TEMP_DIR}"
cp "${RAGATAG_SCAFFOLD_FASTA}" "${TEMP_DIR}/${GENOME_BASENAME}" || { echo "genome copy-in failed"; exit 1; }
cp "${CDS}" "${TEMP_DIR}/${CDS_BASENAME}" || { echo "cds copy-in failed"; exit 1; }

export PYTHONNOUSERSITE=1
declare -A run_status

run_edta () {
    local outdir="$1"; shift
    local logfile="${TEMP_DIR}/edta.log"

    mkdir -p "${outdir}"
    cd "${TEMP_DIR}" || return 1

    singularity exec --pid --env RMBLAST_DIR=/usr/local/bin "${EDTA_IMAGE}" EDTA.pl "$@" > >(tee -a "${logfile}") 2>&1 &
    local edta_pid=$!

    while kill -0 "${edta_pid}" 2>/dev/null; do
        if grep -qE "^ERROR|FATAL|die at" "${logfile}"; then
            kill -TERM "${edta_pid}"
            wait "${edta_pid}" 2>/dev/null
            return 1
        fi
        sleep 10
    done

    wait "${edta_pid}"
    local edta_status=$?

    mv "${TEMP_DIR}"/* "${outdir}/"
    sleep 10

    mv "${outdir}/${CDS_BASENAME}" "${outdir}/${GENOME_BASENAME}" "${TEMP_DIR}/"
    sleep 10

    return "${edta_status}"
}

# run_edta "${OUTPUT_DIR}/edta_basic" --genome "${GENOME_BASENAME}" "${EDTA_DEP_OPTS[@]}"
# run_status[basic]=$?
# run_edta "${OUTPUT_DIR}/edta_cds" --genome "${GENOME_BASENAME}" " --cds "${CDS_BASENAME}" "${EDTA_DEP_OPTS[@]}"
# run_status[cds]=$?
run_edta "${OUTPUT_DIR}/edta_sensitive" --genome "${GENOME_BASENAME}" --sensitive 1 "${EDTA_DEP_OPTS[@]}"
run_status[sensitive]=$?
# run_edta "${OUTPUT_DIR}/edta_sensitive_cds" --genome "${GENOME_BASENAME}" --sensitive 1 --cds "${CDS_BASENAME}" "${EDTA_DEP_OPTS[@]}"
# run_status[sensitive_cds]=$?

{ for k in "${!run_status[@]}";do
    echo "${k}: ${run_status[${k}]}"
done;
} >&2