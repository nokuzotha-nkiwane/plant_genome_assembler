#!/bin/bash
#PBS -l ncpus=64
#PBS -l mem=80GB
#PBS -q bix
#PBS -l walltime=24:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#exit at errors
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/miniconda/mamba
conda activate my_python
# cd ~/my_environments
source /new-home/25086138/my_environments/snakemake_env/bin/activate
module load app/apptainer/1.2.5
export _JAVA_OPTIONS="-Xmx8g"

#resource parameters
THREADS=64

#directories and files
OUTPUT_DIR="__RESULTS_DIR__"
SAMPLESHEET="${TOMATO_PATH}/SAMPLE_CLI/results/10a.braker_prep/dSAMPLE_CLI_samplesheet.csv"
CONFIG_INI="${TOMATO_PATH}/SAMPLE_CLI/results/10a.braker_prep/config.ini.dSAMPLE_CLI"

#move to output directory
cd "${OUTPUT_DIR}"
cp "${SAMPLESHEET}" "${OUTPUT_DIR}/"
cp "${CONFIG_INI}" "${OUTPUT_DIR}/config.ini"

#run command 
#sge_logs should be in OUTPUT_DIR
mkdir -p "${OUTPUT_DIR}/sge_logs"

snakemake \
    --default-resources \
    --cores "${THREADS}" \
    --snakefile /new-home/25086138/my_environments/BRAKER4/Snakefile \
    --use-singularity \
    --singularity-prefix "${OUTPUT_DIR}/.singularity_cache" \
    --singularity-args "-B ${TOMATO_PATH}" \
    --latency-wait 120 \
    --restart-times 2 \
    --printshellcmds \
    2>&1 | tee -a "${OUTPUT_DIR}/snakemake_run.log"