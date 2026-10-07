#!/bin/bash
#PBS -l select=1:ncpus=1:mem=2GB
#PBS -q bix
#PBS -l walltime=0:10:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
MERQURY_RESULTS_DIR="${ALL_RESULTS_DIR}/06.3.merqury_ragtag"
SUMMARY_DIR="__RESULTS_DIR__"
SUMMARY_COPY_DIR="${SUMMARY_DIR}/merqury_stats"
TSV="${SUMMARY_DIR}/SAMPLE_CLI.merqury_minlen_summary.tsv"
ROWS_DIR="${SUMMARY_DIR}/${PBS_JOBID}_rows"

[[ -d "${MERQURY_RESULTS_DIR}" ]] || { echo "Missing merqury results dir: ${MERQURY_RESULTS_DIR}"; exit 1; }

mkdir -p "${SUMMARY_COPY_DIR}" "${ROWS_DIR}"
trap 'rm -rf "${ROWS_DIR}"' EXIT

#one rows file per section; sorted and assembled into the final table at the end
: > "${ROWS_DIR}/full.rows"
: > "${ROWS_DIR}/chromosomes.rows"
: > "${ROWS_DIR}/unplaced.rows"

N_FILES=0
while IFS= read -r QV_FILE; do
    #name looks like: mq_SAMPLE_CLI.minlen8000.f15000_d500000_{full|chromosomes|unplaced}.qv
    #(the strict pattern skips any extra per-assembly qv files merqury might write)
    BASE=$(basename "${QV_FILE}" .qv)
    if [[ ! "${BASE}" =~ ^mq_([^.]+)\.minlen([0-9]+)\.f([0-9]+)_d([0-9]+)_(full|chromosomes|unplaced)$ ]]; then
        echo "WARNING: could not parse name '${BASE}' (${QV_FILE}); skipping" >&2
        continue
    fi
    MINLEN="${BASH_REMATCH[2]}"
    F="${BASH_REMATCH[3]}"
    D="${BASH_REMATCH[4]}"
    TYPE="${BASH_REMATCH[5]}"

    COMP_FILE="${QV_FILE%.qv}.completeness.stats"
    if [[ ! -s "${COMP_FILE}" ]]; then
        echo "WARNING: missing ${COMP_FILE}; skipping" >&2
        continue
    fi

    #keep both raw stats files for this run
    cp -p "${QV_FILE}" "${COMP_FILE}" "${SUMMARY_COPY_DIR}/"

    #qv columns: assembly, k-mers only in assembly, k-mers in assembly, QV, error rate
    QV_VALUES=$(awk -v OFS='\t' 'NR==1 { print $4, $5, $2, $3 }' "${QV_FILE}")
    #completeness.stats columns: assembly, region, k-mers found in assembly, total k-mers in reads, % completeness
    COMP_VALUES=$(awk -v OFS='\t' '$2=="all" { print $5, $3, $4 }' "${COMP_FILE}")

    printf '%s\t%s\t%s\t%s\t%s\n' "${MINLEN}" "${D}" "${F}" "${QV_VALUES}" "${COMP_VALUES}" >> "${ROWS_DIR}/${TYPE}.rows"
    N_FILES=$((N_FILES + 1))
done < <(find "${MERQURY_RESULTS_DIR}" -type f -name "mq_*.qv" | sort)

#assemble the sheet layout: title row, header row, data rows, blank row
HEADER=$'minlen\t-d\t-f\tQV\tError rate\tAssembly-only k-mers\tAssembly k-mers\tCompleteness (%)\tRead k-mers found in assembly\tTotal read k-mers'

write_section() {
    local TITLE="$1" TYPE="$2"
    printf '%s\n' "${TITLE}"
    printf '%s\n' "${HEADER}"
    sort -t$'\t' -k1,1n -k2,2n -k3,3n "${ROWS_DIR}/${TYPE}.rows"
    printf '\n'
}

{
    echo "SAMPLE_CLI"
    write_section "Full scaffolds merqury (including unplaced)" full
    write_section "Scaffolds only (unplaced removed)"          chromosomes
    write_section "Unplaced only"                              unplaced
} > "${TSV}"

echo "Wrote ${N_FILES} rows to ${TSV}"