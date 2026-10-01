#PBS -l ncpus=26
#PBS -l mem=80GB
#PBS -q bix
#PBS -l walltime=144:00:00
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
conda activate ragtag

#resource parameters
THREADS=26

#read length thresholds: 1000 to 8000 in steps of 1000
MIN_LENGTHS=(1000 2000 3000 4000 5000 6000 7000 8000)

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
RAW_READS_DIR="${WORKDIR}/raw_reads"
FILTERED_READS_DIR="${RAW_READS_DIR}/filtered_reads"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_CORRECT_DIR="__RESULTS_DIR__"
HIFIASM_DIR="${ALL_RESULTS_DIR}/03.hifiasm"
P_CONTIGS_IN="${HIFIASM_DIR}/dSAMPLE_CLI_primary_renamed.fa"
TEMP_DIR="${RAGTAG_CORRECT_DIR}/${PBS_JOBID}_temp"

#filtered read path for a given threshold
filtered_path() {
    echo "${FILTERED_READS_DIR}/dSAMPLE_CLI_filtered_minlen${1}.fastq.gz"
}

#pre-flight: all filtered reads must exist before any 16 h run starts
for MIN_LEN in "${MIN_LENGTHS[@]}"; do
    [[ -s "$(filtered_path "${MIN_LEN}")" ]] \
        || { echo "Missing $(filtered_path "${MIN_LEN}"); run the filtration job first"; exit 1; }
done

#make temp directory so the original files stay accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# copy the shared inputs to TEMP_DIR once
cp "${P_CONTIGS_IN}" "${REF_GENOME}" "${TEMP_DIR}/"
gzip -d "${TEMP_DIR}/$(basename "${REF_GENOME}")"

P_CONTIGS_IN="${TEMP_DIR}/$(basename "${P_CONTIGS_IN}")"
REF_GENOME="${TEMP_DIR}/$(basename "${REF_GENOME}" .gz)"

# RagTag correct for each threshold, each in its own output directory
for MIN_LEN in "${MIN_LENGTHS[@]}"; do
    THRESH_OUT="${RAGTAG_CORRECT_DIR}/minlen_${MIN_LEN}"

    #skip thresholds that already finished
    if [[ -s "${THRESH_OUT}/ragtag.correct.fasta" ]]; then
        echo "RagTag output already present for min length ${MIN_LEN}; skipping"
        continue
    fi

    echo "RagTag correct with reads filtered at min length ${MIN_LEN}"

    ragtag.py correct \
        -R "$(filtered_path "${MIN_LEN}")" \
        -T corr \
        -t "${THREADS}" \
        -o "${THRESH_OUT}" \
        "${REF_GENOME}" "${P_CONTIGS_IN}"wha
done