#!/bin/bash
#PBS -l select=1:ncpus=32:mem=60GB
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
conda activate hifiasm

#resource parameters -- hifiasm runs are now sequential, so each gets all cores
THREADS=30

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
RAW_READS_FQ="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
HIFIASM_DIR="__RESULTS_DIR__"
HIFIASM_DIR_l0="${HIFIASM_DIR}/l0"
HIFIASM_DIR_primary="${HIFIASM_DIR}/primary"
HIFIASM_ASM_l0="${HIFIASM_DIR_l0}/dSAMPLE_CLI.asm"
HIFIASM_ASM_primary="${HIFIASM_DIR_primary}/dSAMPLE_CLI.asm"
TEMP_DIR="${HIFIASM_DIR}/${PBS_JOBID}_temp"

#make subdirectories for each mode + temp dir for the shared read copy
mkdir -p "${HIFIASM_DIR_l0}" "${HIFIASM_DIR_primary}" "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy reads to temp dir once
cp "${RAW_READS_FQ}" "${TEMP_DIR}/"
RAW_READS_FQ="${TEMP_DIR}/D260405-SAMPLE_CLI_HiFi.fastq.gz"

#run one hifiasm assembly; called twice sequentially below, once per mode
RUN_HIFIASM() {
    local MODE="$1" OUT_PREFIX="$2"
    shift 2
    echo "Starting hifiasm (${MODE})..."
    hifiasm -o "${OUT_PREFIX}" -t "${THREADS}" -i "${RAW_READS_FQ}" "$@" \
        || { echo "hifiasm (${MODE}) failed"; exit 1; }
    echo "hifiasm (${MODE}) complete"
}

#run both configurations one after another -- each uses the full core count
RUN_HIFIASM "l0" "${HIFIASM_ASM_l0}" -l0
RUN_HIFIASM "primary" "${HIFIASM_ASM_primary}" --primary

#make arrays of input gfa files and corresponding output fasta files across both modes
GFA_FILES=(
    "${HIFIASM_ASM_l0}.bp.p_ctg.gfa"
    "${HIFIASM_ASM_l0}.bp.a_ctg.gfa"
    "${HIFIASM_ASM_primary}.p_ctg.gfa"
    "${HIFIASM_ASM_primary}.a_ctg.gfa"
)
FASTA_FILES=(
    "${HIFIASM_DIR_l0}/dSAMPLE_CLI_primary.fa"
    "${HIFIASM_DIR_l0}/dSAMPLE_CLI_alternate.fa"
    "${HIFIASM_DIR_primary}/dSAMPLE_CLI_primary.fa"
    "${HIFIASM_DIR_primary}/dSAMPLE_CLI_alternate.fa"
)

#convert gfa to fasta, then rename contigs -- run all four (convert+rename) in parallel
#now that hifiasm is done and cores are free
CONVERT_AND_RENAME() {
    local gfa="$1" fasta="$2"
    awk '/^S/{print ">"$2; print $3}' "${gfa}" > "${fasta}" \
        || { echo "GFA to FASTA conversion failed for ${gfa}"; return 1; }

    echo "Renaming contigs for ${fasta}..."
    local fasta_renamed="${fasta%.fa}_renamed.fa"
    sed -E 's/^>(.*)/>dSAMPLE_CLI_\1/' "${fasta}" > "${fasta_renamed}" \
        || { echo "Failed to rename contigs for ${fasta}"; return 1; }
}

echo "Converting GFA files to fasta and renaming contigs (in parallel)"
PIDS=()
for i in "${!GFA_FILES[@]}"; do
    CONVERT_AND_RENAME "${GFA_FILES[$i]}" "${FASTA_FILES[$i]}" &
    PIDS+=("$!")
done

FAIL=0
for PID in "${PIDS[@]}"; do
    wait "${PID}" || FAIL=1
done
[[ "${FAIL}" -eq 1 ]] && { echo "One or more GFA to FASTA conversions/renamings failed"; exit 1; }

#build list of renamed fasta files for gzip
RENAMED_FASTA_FILES=()
for f in "${FASTA_FILES[@]}"; do
    RENAMED_FASTA_FILES+=("${f%.fa}_renamed.fa")
done

gzip -k "${FASTA_FILES[@]}" "${RENAMED_FASTA_FILES[@]}"