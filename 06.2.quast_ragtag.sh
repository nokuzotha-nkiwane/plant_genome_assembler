#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=8:00:00
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
module load app/QUAST/5.3.0

#resource parameters
THREADS=23

#which ragtag stage this run evaluates -- sed-substituted by submit.sh's
#RAGTAG_MODE=correct|scaffold CLI argument (see 06.1.busco_ragtag.sh for the
#same pattern)
RAGTAG_MODE="__RAGTAG_MODE__"

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
REF_GFF3="${REF_DIR}/SL5.0.gff3.gz"
QUAST_DIR="__RESULTS_DIR__"
ALL_RESULTS_DIR="${WORKDIR}/results"

if [[ "${RAGTAG_MODE}" == "correct" ]]; then
    CONTIGS_IN="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
elif [[ "${RAGTAG_MODE}" == "scaffold" ]]; then
    CONTIGS_IN="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/ragtag.scaffold.chromosomes.fasta"
else
    echo "Error: RAGTAG_MODE must be 'correct' or 'scaffold', got: ${RAGTAG_MODE}"
    exit 1
fi

TEMP_DIR="${QUAST_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#check if non-empty file exists
if [[ ! -s "${CONTIGS_IN}" ]]; then
    echo "ERROR: File empty or missing: ${CONTIGS_IN}"
    exit 1
fi

#copy fasta file to temporary directory
cp "${CONTIGS_IN}" "${TEMP_DIR}/"
CONTIGS_IN="${TEMP_DIR}/$(basename "${CONTIGS_IN}")"

#check quality of the ragtag assembly (single input -- no alternate haplotype
#at this stage, unlike the hifiasm primary+alternate comparison in 04.2)
quast.py "${CONTIGS_IN}" \
    -r "${REF_GENOME}" \
    -g "${REF_GFF3}" \
    -o "${QUAST_DIR}" \
    -e \
    -k \
    --circos \
    --plots-format pdf \
    -t "${THREADS}"

echo "QUAST for ${CONTIGS_IN} (${RAGTAG_MODE}) complete"