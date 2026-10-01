#PBS -l ncpus=26
#PBS -l mem=80GB
#PBS -q bix
#PBS -l walltime=48:00:00
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
module load app/parallel/parallel

#resource parameters
THREADS=26

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
RAW_READS_DIR="${WORKDIR}/raw_reads"
FILTERED_READS_DIR="${RAW_READS_DIR}/filtered_reads"
RAW_READS_GZ="${RAW_READS_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_CORRECT_DIR="__RESULTS_DIR__"
TEMP_DIR="${RAGTAG_CORRECT_DIR}/${PBS_JOBID}_temp"

#read length thresholds: 1000 to 8000 in steps of 1000
MIN_LENGTHS=(1000 2000 3000 4000 5000 6000 7000 8000)
MIN_MEAN_Q=30

#filtered read path for a given threshold
filtered_path() {
    echo "${FILTERED_READS_DIR}/dSAMPLE_CLI_filtered_minlen${1}.fastq.gz"
}

#make temp directory so the original files stay accessible to other scripts
mkdir -p "${TEMP_DIR}" "${FILTERED_READS_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# filter reads at each threshold (skipped if the filtered file already exists)
# build the list of independent commands (one per missing threshold)
CMDS="${FILTERED_READS_DIR}/filter.cmds"
: > "${CMDS}"
for MIN_LEN in "${MIN_LENGTHS[@]}"; do
    OUT="${FILTERED_READS_DIR}/dSAMPLE_CLI_filtered_minlen${MIN_LEN}.fastq.gz"
    if [[ -s "${OUT}" ]]; then
        echo "Found filtered reads for ${MIN_LEN}; skipping"
        continue
    fi
    #write to .partial and rename on success so -s never matches a truncated file
    echo "filtlong --min_mean_q ${MIN_MEAN_Q} --min_length ${MIN_LEN} ${RAW_READS_GZ} | gzip > ${OUT}.partial && mv ${OUT}.partial ${OUT} || { rm -f ${OUT}.partial; exit 1; }" >> "${CMDS}"
done

# run the missing thresholds in parallel
parallel -j "${JOBS}" --joblog "${FILTERED_READS_DIR}/filter.joblog" --halt soon,fail=1 < "${CMDS}"