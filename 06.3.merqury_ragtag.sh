#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=14:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules version 1.4.1
module load app/miniconda/mamba
conda activate merqury

#which ragtag stage this run evaluates -- sed-substituted by submit.sh's
#RAGTAG_MODE=correct|scaffold CLI argument (see 06.1.busco_ragtag.sh)
RAGTAG_MODE="__RAGTAG_MODE__"

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_GZ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
MERQURY_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"

#reuse the read k-mer database built once in 04.2a -- it's a property of the
#raw reads, not of any particular assembly, so no separate ragtag prep step
#is needed
MERYL_DB="${ALL_RESULTS_DIR}/04.2a.merqury_hifiasm_prep/dSAMPLE_CLI_asm.meryl"

if [[ "${RAGTAG_MODE}" == "correct" ]]; then
    CONTIGS_IN="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
elif [[ "${RAGTAG_MODE}" == "scaffold" ]]; then
    CONTIGS_IN="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/ragtag.scaffold.fasta"
else
    echo "Error: RAGTAG_MODE must be 'correct' or 'scaffold', got: ${RAGTAG_MODE}"
    exit 1
fi

MERQURY_OUT_PREFIX="mq_dSAMPLE_CLI_${RAGTAG_MODE}"
TEMP_DIR="${MERQURY_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#check if non-empty files exist
for FILE in "${RAW_READS_GZ}" "${CONTIGS_IN}"; do
    if [[ ! -s ${FILE} ]]; then
        echo "ERROR: File empty or missing: ${FILE}"
        exit 1
    fi
done

#check if meryl database for reads made
if [[ ! -d "${MERYL_DB}" ]]; then
    echo "ERROR: Meryl database empty or missing: ${MERYL_DB}"
    exit 1
fi

#copy fasta file to temporary directory
cp "${CONTIGS_IN}" "${TEMP_DIR}/"
CONTIGS_IN="${TEMP_DIR}/$(basename "${CONTIGS_IN}")"

#run merqury to check quality of the ragtag assembly (single input -- no
#alternate haplotype at this stage, unlike 04.3's primary+alternate call)
echo "Running merqury on ragtag ${RAGTAG_MODE} assembly"
cd "${MERQURY_DIR}"
$MERQURY/merqury.sh "${MERYL_DB}" "${CONTIGS_IN}" "${MERQURY_OUT_PREFIX}"
echo "Merqury complete"