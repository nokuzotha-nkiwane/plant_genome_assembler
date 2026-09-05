#!/bin/bash
#PBS -l select=1:ncpus=4:mem=40GB
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
module load app/miniconda/mamba
conda activate ragtag

#resource parameters
THREADS=4

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
P_CONTIGS_IN="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
TEMP_DIR="${RAGTAG_SCAFFOLD_DIR}/${PBS_JOBID}_temp"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy fastas file to temporary directory
cp "${P_CONTIGS_IN}" \
    "${REF_GENOME}" "${TEMP_DIR}/"

#unzip reference fasta
gzip -d "${TEMP_DIR}/$(basename "${REF_GENOME}")"

#reassign variables to the temp directory versions
P_CONTIGS_IN="${TEMP_DIR}/$(basename "${P_CONTIGS_IN}")"
REF_GENOME="${TEMP_DIR}/$(basename "${REF_GENOME}" .gz)"

#scaffold assemblies asm5
#run ragtag scaffold for a given (-f, -d) combination, into its own subdirectory
#run ragtag scaffold for a given (-f, -d) combination, into its own subdirectory
run_ragtag_scaffold() {
    local f_val="$1"
    local d_val="$2"
    local outdir="${RAGTAG_SCAFFOLD_DIR}/f${f_val}_d${d_val}"
    local prefix="SAMPLE_CLI.f${f_val}_d${d_val}"

    ragtag.py scaffold --remove-small -f "${f_val}" -d "${d_val}" -i 0.5 \
        -a 0.5 -s 0.5 --mm2-params '-x asm5' -t "${THREADS}" \
        -o "${outdir}" "${REF_GENOME}" "${P_CONTIGS_IN}" \
        || { echo "ragtag scaffold failed for -f ${f_val} -d ${d_val}"; exit 1; }

    #prefix all ragtag.py outputs with sample name and parameter combination
    for RAGTAG_OUT in "${outdir}"/ragtag.scaffold.*; do
        mv "${RAGTAG_OUT}" "${outdir}/${prefix}.$(basename "${RAGTAG_OUT}")"
    done
}

#parameter sweep
for f_val in 15000; do
    for d_val in 500000; do
        run_ragtag_scaffold "${f_val}" "${d_val}"
    done
done



#deactivate ragtag and activate seqkit
conda deactivate
conda activate seqkit

#perform for each output directory (asm5 and asm10)
#split a single parameter combination's scaffold fasta into chromosomes-only and unplaced, then index all three
extract_and_index() {
    local f_val="$1"
    local d_val="$2"
    local outdir="${RAGTAG_SCAFFOLD_DIR}/f${f_val}_d${d_val}"
    local prefix="SAMPLE_CLI.f${f_val}_d${d_val}"
    local scaffold_fasta="${outdir}/${prefix}.ragtag.scaffold.fasta"

    seqkit grep -n -r -p '_RagTag$' "${scaffold_fasta}" > "${outdir}/${prefix}.ragtag.scaffold.chromosomes.fasta"
    seqkit grep -v -n -r -p '_RagTag$' "${scaffold_fasta}" > "${outdir}/${prefix}.ragtag.scaffold.unplaced.fasta"

    for FASTA in "${outdir}"/${prefix}.*.fasta; do
        BASE=$(basename "${FASTA}" .fasta)
        seqkit fx2tab --length --name --header-line "${FASTA}" > "${outdir}/${BASE}.lengths"
    done
}

#run extraction/indexing for every parameter combination directory
for f_val in 15000; do
    for d_val in 500000; do
        extract_and_index "${f_val}" "${d_val}"
    done
done