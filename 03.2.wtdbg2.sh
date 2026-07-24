#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=48:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail 

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource parameters
THREADS=23

#load modules
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"
module load app/QUAST/5.3.0

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
WTDBG2_DIR="__RESULTS_DIR__"
TEMP_DIR="${WTDBG2_DIR}/${PBS_JOBID}_temp"
BUSCO_DB_DIR="${TOMATO_PATH}/data"
BUSCO_DIR="${WTDBG2_DIR}/busco"

REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.fasta.gz"
REF_GFF3="${REF_DIR}/SL5.0.gff3.gz"
QUAST_DIR="${WTDBG2_DIR}/quast"

OUTPUT_PREFIX="dSAMPLE_CLI_"

#make temp directory to copy reads to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}" "${BUSCO_DIR}" "${QUAST_DIR}"
cp "${RAW_READS_FQ}" "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#move to output directory and perform assembly
cd "${WTDBG2_DIR}"
wtdbg2 -x ccs -t "${THREADS}" -i "${RAW_READS_FQ}" -fo "${OUTPUT_PREFIX}"
wtpoa-cns -t 16 -i "${OUTPUT_PREFIX}".ctg.lay.gz -fo "${OUTPUT_PREFIX}".ctg.fa

#check quality of assembled contigs for each haplotype
#busco
echo "Running BUSCO for ${OUTPUT_PREFIX}.ctg.fa"
busco --in "${OUTPUT_PREFIX}".ctg.fa \
    -m genome \
    --offline \
    -l eudicotyledons_odb12 \
    --download_path "${BUSCO_DB_DIR}" \
    -c "${THREADS}" \
    -f \
    -o "${OUTPUT_PREFIX}" \
    --out_path "${BUSCO_DIR}"

echo "BUSCO for ${OUTPUT_PREFIX}.ctg.fa complete"

#quast
quast.py ${HAP1} \
    -r ${REF_GENOME} \
    -g ${REF_GFF3} \
    -o ${QUAST_DIR} \
    -e \
    -k \
    --circos \
    --plots-format pdf \
    -t ${THREADS}

#delete temp dir
rm -rf "${TEMP_DIR}"
