#!/bin/bash
#PBS -l select=1:ncpus=36:mem=60GB
#PBS -q bix
#PBS -l walltime=12:00:00
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
module load app/parallel/parallel


#resource parameters
THREADS=4
JOBS=8

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME_GZ="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_CORRECT_DIR="${ALL_RESULTS_DIR}/05.1.ragtag_correct"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
TEMP_DIR="${RAGTAG_SCAFFOLD_DIR}/${PBS_JOBID}_temp"

#read length thresholds used for ragtag correct
MIN_LENGTHS=(1000 2000 3000 4000 5000 6000 7000 8000)

#scaffold parameter sweep
F_VALS=(15000)
D_VALS=(500000)

#corrected contigs for a given threshold
corrected_path() {
    echo "${RAGTAG_CORRECT_DIR}/minlen_${1}/ragtag.correct.fasta"
}

#pre-flight: all corrected assemblies must exist
for MIN_LEN in "${MIN_LENGTHS[@]}"; do
    [[ -s "$(corrected_path "${MIN_LEN}")" ]] \
        || { echo "Missing $(corrected_path "${MIN_LEN}"); run ragtag correct first"; exit 1; }
done

mkdir -p "${RAGTAG_SCAFFOLD_DIR}" "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

#worker functions (run once per minlen/f/d combination)
#each worker copies its own contigs and decompresses its own reference, because
#ragtag writes .fai indexes beside its inputs and concurrent workers would race
#on a shared copy
scaffold_one() {
    set -euo pipefail
    local min_len="$1" f_val="$2" d_val="$3"
    local outdir="${RAGTAG_SCAFFOLD_DIR}/minlen_${min_len}/f${f_val}_d${d_val}"
    local prefix="SAMPLE_CLI.minlen${min_len}.f${f_val}_d${d_val}"
    local contigs="${TEMP_DIR}/${prefix}.contigs.fasta"
    local ref="${TEMP_DIR}/${prefix}.ref.fasta"

    cp "$(corrected_path "${min_len}")" "${contigs}"
    zcat "${REF_GENOME_GZ}" > "${ref}"

    #combos are only queued if unfinished, so a leftover outdir is a partial run
    rm -rf "${outdir}"

    ragtag.py scaffold --remove-small -f "${f_val}" -d "${d_val}" -i 0.5 \
        -a 0.5 -s 0.5 --mm2-params '-x asm5' -t "${THREADS}" \
        -o "${outdir}" "${ref}" "${contigs}"

    #prefix all ragtag.py outputs with sample name, threshold and parameters
    for RAGTAG_OUT in "${outdir}"/ragtag.scaffold.*; do
        mv "${RAGTAG_OUT}" "${outdir}/${prefix}.$(basename "${RAGTAG_OUT}")"
    done

    rm -f "${contigs}" "${contigs}.fai" "${ref}" "${ref}.fai"
}

extract_one() {
    set -euo pipefail
    local min_len="$1" f_val="$2" d_val="$3"
    local outdir="${RAGTAG_SCAFFOLD_DIR}/minlen_${min_len}/f${f_val}_d${d_val}"
    local prefix="SAMPLE_CLI.minlen${min_len}.f${f_val}_d${d_val}"
    local scaffold_fasta="${outdir}/${prefix}.ragtag.scaffold.fasta"

    seqkit grep -n -r -p '_RagTag$' "${scaffold_fasta}" > "${outdir}/${prefix}.ragtag.scaffold.chromosomes.fasta"
    seqkit grep -v -n -r -p '_RagTag$' "${scaffold_fasta}" > "${outdir}/${prefix}.ragtag.scaffold.unplaced.fasta"

    for FASTA in "${outdir}"/${prefix}.*.fasta; do
        BASE=$(basename "${FASTA}" .fasta)
        seqkit fx2tab --length --name --header-line "${FASTA}" > "${outdir}/${BASE}.lengths"
    done
}

export -f corrected_path scaffold_one extract_one
export RAGTAG_CORRECT_DIR RAGTAG_SCAFFOLD_DIR REF_GENOME_GZ TEMP_DIR THREADS

#build the list of unfinished combinations (one per line: minlen f d)
COMBOS="${RAGTAG_SCAFFOLD_DIR}/scaffold.combos"
: > "${COMBOS}"
for MIN_LEN in "${MIN_LENGTHS[@]}"; do
    for f_val in "${F_VALS[@]}"; do
        for d_val in "${D_VALS[@]}"; do
            PREFIX="SAMPLE_CLI.minlen${MIN_LEN}.f${f_val}_d${d_val}"
            DONE="${RAGTAG_SCAFFOLD_DIR}/minlen_${MIN_LEN}/f${f_val}_d${d_val}/${PREFIX}.ragtag.scaffold.chromosomes.lengths"
            if [[ -s "${DONE}" ]]; then
                echo "Scaffold output already present for ${PREFIX}; skipping"
                continue
            fi
            printf '%s %s %s\n' "${MIN_LEN}" "${f_val}" "${d_val}" >> "${COMBOS}"
        done
    done
done

###############################################################################
# Stage 1: ragtag scaffold (ragtag env)
###############################################################################
set +u
conda activate ragtag
set -u

parallel -j "${JOBS}" --colsep ' ' \
    --joblog "${RAGTAG_SCAFFOLD_DIR}/stage1.joblog" --halt soon,fail=1 \
    scaffold_one {1} {2} {3} < "${COMBOS}"

###############################################################################
# Stage 2: split into chromosomes/unplaced and index (seqkit env)
###############################################################################
set +u
conda deactivate
conda activate seqkit
set -u

parallel -j "${JOBS}" --colsep ' ' \
    --joblog "${RAGTAG_SCAFFOLD_DIR}/stage2.joblog" --halt soon,fail=1 \
    extract_one {1} {2} {3} < "${COMBOS}"