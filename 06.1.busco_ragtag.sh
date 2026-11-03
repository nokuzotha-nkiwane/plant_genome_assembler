#!/bin/bash
#PBS -l ncpus=38
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=12:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -uxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"

#resource parameters
THREADS=12

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="${TOMATO_PATH}/data"
RAGTAG_SCAFFOLD_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold"
RAGTAG_OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/f15000_d500000"
FASTAS_IN=(
    "${RAGTAG_OUTPUT_DIR}/SAMPLE_CLI.f15000_d500000.ragtag.scaffold.fasta"
    "${RAGTAG_OUTPUT_DIR}/SAMPLE_CLI.f15000_d500000.ragtag.scaffold.chromosomes.fasta"
    "${RAGTAG_OUTPUT_DIR}/SAMPLE_CLI.f15000_d500000.ragtag.scaffold.unplaced.fasta"
)

TEMP_DIR="${BUSCO_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#run busco on a single contigs fasta, staged to TEMP_DIR first
run_busco() {
    local SRC_FASTA="$1"

    [[ -s "${SRC_FASTA}" ]] || { echo "Missing fasta: ${SRC_FASTA}"; return 1; }

    cp "${SRC_FASTA}" "${TEMP_DIR}/"
    local CONTIGS_IN="${TEMP_DIR}/$(basename "${SRC_FASTA}")"

    #extract base filename without extension for a unique output folder
    local BASE_NAME
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
        || { echo "BUSCO failed for ${CONTIGS_IN}"; return 1; }

    echo "BUSCO for ${CONTIGS_IN} complete"

    #free space in TEMP_DIR before the next combination
    rm -f "${CONTIGS_IN}"
}

#run BUSCO on the RagTag scaffold FASTAs produced by 05.2.ragtag_scaffold.sh
PIDS=()
FASTA_NAMES=()
for FASTA in "${FASTAS_IN[@]}"; do
    echo "Running BUSCO for ${FASTA}"
    run_busco "${FASTA}" &
    PIDS+=("$!")
    FASTA_NAMES+=("${FASTA}")
done

FAILED=0
for INDEX in "${!PIDS[@]}"; do
    if wait "${PIDS[INDEX]}"; then
        echo "BUSCO for ${FASTA_NAMES[INDEX]} complete"
    else
        echo "BUSCO failed for ${FASTA_NAMES[INDEX]}" >&2
        FAILED=1
    fi
done

exit "${FAILED}"

### why is it in braces?
# without braces the actual outputs go to stout because that is the default stream
# putting >&2 on the last line without using braces will print everything else to
# stout and only the last line to stderr. Hence putting everything in braces allows
# >&2 to apply to all lines and the overall output gets printed to stderr

# NB: Note the syntax requirements: { needs a space after it and }
# needs to be preceded by a ; or newline

### but I have set -x at the top should this not suffice
# set -x prints the trace of each command as it's about to execute
# (the + echo "..." lines) that trace always goes to stderr regardless
# of anything else.
# the actual output of the command (what echo prints) still goes to whatever
# stream it's normally connected to — stdout by default — unless you redirect it yourself.