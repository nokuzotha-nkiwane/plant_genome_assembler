#!/bin/bash
#PBS -l select=1:ncpus=23:mem=40GB
#PBS -q bix
#PBS -l walltime=15:00:00
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
conda activate helper-tools

#resource parameters
THREADS=23

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
RAW_READS_GZ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
FILTERED_READS="${WORKDIR}/raw_reads/dSAMPLE_CLI_filtered.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_CORRECT_DIR="__RESULTS_DIR__"
HIFIASM_DIR="${ALL_RESULTS_DIR}/03.hifiasm"
P_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_primary_renamed.fa"
TEMP_DIR="${RAGTAG_CORRECT_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#filter raw reads
if [[ -s "${FILTERED_READS}" ]]; then
    echo "Found filtered reads; proceeding to minimap2"
else
    echo "Filtering raw reads"
    #Filter on Q20 quality and minimum read length of 1000
    filtlong \
    --min_mean_q 20 \
    --min_length 1000 \
    "${RAW_READS_GZ}" | gzip > "${FILTERED_READS}" || { echo "Filtlong failed for ${RAW_READS_GZ}"; exit 1; }
fi

#deactivate conda env
conda deactivate
conda activate ragtag

#copy fastas file to temporary directory
cp "${P_CONTIGS_IN}" \
    "${REF_GENOME}" \
    "${FILTERED_READS}" "${TEMP_DIR}/"

#unzip reference fasta
gzip -d "${TEMP_DIR}/$(basename "${REF_GENOME}")"

#reassign variables to the temp directory versions
P_CONTIGS_IN="${TEMP_DIR}/$(basename "${P_CONTIGS_IN}")"
REF_GENOME="${TEMP_DIR}/$(basename "${REF_GENOME}" .gz)"
FILTERED_READS="${TEMP_DIR}/$(basename "${FILTERED_READS}")"

#correct assemblies assemblies
ragtag.py correct -R "${FILTERED_READS}" -T corr -t "${THREADS}" -o "${RAGTAG_CORRECT_DIR}" "${REF_GENOME}" "${P_CONTIGS_IN}"