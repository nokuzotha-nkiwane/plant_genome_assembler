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

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
HIFIASM_DIR="__RESULTS_DIR__"
CONTIGS_DIR="${ALL_RESULTS_DIR}/contigs"
TEMP_DIR="${HIFIASM_DIR}/${PBS_JOBID}"
SAMPLE_NAME="SAMPLE_CLI"

#load modules
module load app/miniconda/mamba
conda activate hifiasm

#make temp directory to copy reads to so the original ones are accessible to other scripts
mkdir -p ${CONTIGS_DIR} ${TEMP_DIR}
cp ${RAW_READS_FQ} "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#run label -> flags (parallel arrays, same index = same run)
RUN_LABELS=(
    "i"
    "i_l0"
    "i_s0.1"
    "i_s0.2"
    "i_s0.3"
    "i_s0.4"
    "i_s0.5"
)
RUN_FLAGS=(
    "-i"
    "-i -l0"
    "-i -s0.1"
    "-i -s0.2"
    "-i -s0.3"
    "-i -s0.4"
    "-i -s0.5"
)

for idx in "${!RUN_LABELS[@]}"; do
    LABEL="${RUN_LABELS[$idx]}"
    FLAGS="${RUN_FLAGS[$idx]}"

    RUN_NAME="${SAMPLE_NAME}_${LABEL}"
    OUT_RUN="${HIFIASM_DIR}/${RUN_NAME}"
    mkdir -p "${OUT_RUN}"

    HIFIASM_ASM="${OUT_RUN}/d${RUN_NAME}.asm"
    GFA_FILES="${HIFIASM_ASM}.bp.hap?.p_ctg.gfa"

    CONTIGS_RUN="${CONTIGS_DIR}/${RUN_NAME}"
    mkdir -p "${CONTIGS_RUN}"

    #hifiasm assembly
    echo "Performing contig assembly for ${RUN_NAME} (flags: ${FLAGS})..."
    hifiasm -o ${HIFIASM_ASM} -t ${THREADS} ${FLAGS} ${RAW_READS_FQ} || { echo "Contig assembly failed for ${RUN_NAME}"; exit 1; }
    echo "Contig assembly complete for ${RUN_NAME}"

    #convert gfa to fasta
    for gfa in ${GFA_FILES}; do
        echo "Extracting contigs for ${gfa}..."

        #extract basename to name output fasta file
        hap=$(basename ${gfa} | grep -o "hap[0-9]")
        fasta_out="${CONTIGS_RUN}/d${RUN_NAME}_${hap}.fa"

        #extract sequences from gfa to fasta
        awk '/^S/{print ">"$2; print $3}' "${gfa}" > ${fasta_out} || { echo "Contig extraction failed for ${gfa}"; exit 1; }
        echo "Contig extraction for ${gfa} complete."

        #compress original fasta file
        echo "Compressing fasta file..."
        gzip -k ${fasta_out} || { echo "Fasta compression failed for ${fasta_out}"; exit 1; }
        echo "Fasta and compressed files successfully produced"
    done
done

#delete temp dir
rm -rf "${TEMP_DIR}/"