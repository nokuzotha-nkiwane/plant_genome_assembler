#!/bin/bash
#PBS -l select=1:ncpus=24:mem=130GB
#PBS -q bix
#PBS -l walltime=04:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

# for evaluating variables in ~/.pbsrc
source ~/.pbsrc

# load modules
module load app/miniconda/mamba
module load app/parallel/parallel
conda activate helper-tools

# resource parameters
THREADS=8
JOBS=3

# directories and files
WORKDIR_03="${TOMATO_PATH}/03"
WORKDIR_05="${TOMATO_PATH}/05"
OUTPUT_DIR="__RESULTS_DIR__"
GZ_DIR="${OUTPUT_DIR}/gz_cache"
mkdir -p "${GZ_DIR}"

# reference genome
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_FULL="${REF_DIR}/SL5.0.fasta"
REF_FULL_GZ="${REF_DIR}/SL5.0.fasta.gz"
REF_CHRSM="${REF_DIR}/SL5.0.unplaced_removed.fasta"
REF_CHRSM_GZ="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"

# d03
D03_FULL_SCFLD="${WORKDIR_03}/results/07.1.agp_correct/ragtag_output/d03.ragtag.scaffold.fasta"
D03_CHRSM_SCFLD="${WORKDIR_03}/results/07.1.agp_correct/ragtag_output/d03.ragtag.scaffold.chromosomes.fasta"
D03_UNPLACED_SCFLD="${WORKDIR_03}/results/07.1.agp_correct/ragtag_output/d03.ragtag.scaffold.unplaced.fasta"
D03_FULL_SCFLD_GZ="${WORKDIR_03}/results/07.1.agp_correct/dgenies_input/d03.ragtag.scaffold.fasta.gz"
D03_CHRSM_SCFLD_GZ="${WORKDIR_03}/results/07.1.agp_correct/dgenies_input/d03.ragtag.scaffold.chromosomes.fasta.gz"

# d05
D05_FULL_SCFLD="${WORKDIR_05}/results/07.1.agp_correct/ragtag_output/d05.ragtag.scaffold.fasta"
D05_CHRSM_SCFLD="${WORKDIR_05}/results/07.1.agp_correct/ragtag_output/d05.ragtag.scaffold.chromosomes.fasta"
D05_UNPLACED_SCFLD="${WORKDIR_05}/results/07.1.agp_correct/ragtag_output/d05.ragtag.scaffold.unplaced.fasta"
D05_FULL_SCFLD_GZ="${WORKDIR_05}/results/07.1.agp_correct/dgenies_input/d05.ragtag.scaffold.fasta.gz"
D05_CHRSM_SCFLD_GZ="${WORKDIR_05}/results/07.1.agp_correct/dgenies_input/d05.ragtag.scaffold.chromosomes.fasta.gz"

# alignment pairs, forward direction only: "ref|ref_gz|query|query_gz"
# reciprocals are generated automatically by swapping ref and query
PAIRS=(
    # sample vs sample
    "${D03_FULL_SCFLD}|${D03_FULL_SCFLD_GZ}|${D05_FULL_SCFLD}|${D05_FULL_SCFLD_GZ}"
    "${D03_CHRSM_SCFLD}|${D03_CHRSM_SCFLD_GZ}|${D05_CHRSM_SCFLD}|${D05_CHRSM_SCFLD_GZ}"
    "${D03_UNPLACED_SCFLD}||${D05_UNPLACED_SCFLD}|"

    # chromosomes vs reference with unplaced removed
    "${REF_CHRSM}|${REF_CHRSM_GZ}|${D03_CHRSM_SCFLD}|${D03_CHRSM_SCFLD_GZ}"
    "${REF_CHRSM}|${REF_CHRSM_GZ}|${D05_CHRSM_SCFLD}|${D05_CHRSM_SCFLD_GZ}"

    # full scaffolds and unplaced scaffolds vs full reference (with unplaced)
    "${REF_FULL}|${REF_FULL_GZ}|${D03_FULL_SCFLD}|${D03_FULL_SCFLD_GZ}"
    "${REF_FULL}|${REF_FULL_GZ}|${D05_FULL_SCFLD}|${D05_FULL_SCFLD_GZ}"
    "${REF_FULL}|${REF_FULL_GZ}|${D03_UNPLACED_SCFLD}|"
    "${REF_FULL}|${REF_FULL_GZ}|${D05_UNPLACED_SCFLD}|"
)

# strip path and .fasta/.fa extension
get_name(){
    local n
    n=$(basename "$1")
    n="${n%.fasta}"
    n="${n%.fa}"
    echo "${n}"
}

# return a gzipped path for a fasta: use the provided one, else gzip once into a shared cache
# called serially before parallel starts, so there are no races on the cache
get_gz(){
    local fasta="$1"
    local gz="$2"
    if [[ -n "${gz}" ]]; then
        echo "${gz}"
        return
    fi
    local out="${GZ_DIR}/$(basename "${fasta}").gz"
    if [[ ! -s "${out}" ]]; then
        gzip -c "${fasta}" > "${out}.tmp"
        mv -f "${out}.tmp" "${out}"
    fi
    echo "${out}"
}

# run one alignment, all four args are always non-empty here
run_alignment(){
    local ref_file="$1"
    local ref_gz="$2"
    local query_file="$3"
    local query_gz="$4"

    local ref_name query_name run_name paf
    ref_name=$(get_name "${ref_file}")
    query_name=$(get_name "${query_file}")
    run_name="${query_name}_vs_${ref_name}"
    paf="${OUTPUT_DIR}/${run_name}/${run_name}.paf"

    mkdir -p "${OUTPUT_DIR}/${run_name}"

    # skip finished alignments so a rerun only does what is missing
    if [[ ! -s "${paf}" ]]; then
        # write to a temp file so a killed job never leaves a partial .paf
        minimap2 -cx asm5 --cs -t "${THREADS}" "${ref_file}" "${query_file}" > "${paf}.tmp"
        mv -f "${paf}.tmp" "${paf}"
    fi

    # symlink gzipped fastas (for dgenies) into this alignment's folder
    ln -sf "${ref_gz}" "${OUTPUT_DIR}/${run_name}/$(basename "${ref_gz}")"
    ln -sf "${query_gz}" "${OUTPUT_DIR}/${run_name}/$(basename "${query_gz}")"
}

# build the job list: resolve gz paths serially, then add forward and reciprocal lines
JOBLIST="${OUTPUT_DIR}/alignment_jobs.tsv"
: > "${JOBLIST}"
for pair in "${PAIRS[@]}"; do
    IFS='|' read -r ref ref_gz query query_gz <<< "${pair}"
    ref_gz=$(get_gz "${ref}" "${ref_gz}")
    query_gz=$(get_gz "${query}" "${query_gz}")
    # forward
    printf '%s\t%s\t%s\t%s\n' "${ref}" "${ref_gz}" "${query}" "${query_gz}" >> "${JOBLIST}"
    # reciprocal
    printf '%s\t%s\t%s\t%s\n' "${query}" "${query_gz}" "${ref}" "${ref_gz}" >> "${JOBLIST}"
done

# make functions and variables visible to the shells parallel spawns
export SHELL
SHELL=$(type -p bash)
export OUTPUT_DIR THREADS
export -f get_name run_alignment

# run all alignments, JOBS at a time, and stop everything if one fails
parallel --jobs "${JOBS}" --colsep '\t' --halt now,fail=1 \
    --joblog "${OUTPUT_DIR}/alignment_parallel.joblog" \
    run_alignment {1} {2} {3} {4} :::: "${JOBLIST}"