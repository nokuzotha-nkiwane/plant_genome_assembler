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
QUAST_RESULTS_DIR="${ALL_RESULTS_DIR}/06.2.quast_ragtag"
SUMMARY_DIR="__RESULTS_DIR__"
SUMMARY_COPY_DIR="${SUMMARY_DIR}/quast_reports"
TSV="${SUMMARY_DIR}/SAMPLE_CLI.quast_minlen_summary.tsv"
ROWS_DIR="${SUMMARY_DIR}/${PBS_JOBID}_rows"

[[ -d "${QUAST_RESULTS_DIR}" ]] || { echo "Missing QUAST results dir: ${QUAST_RESULTS_DIR}"; exit 1; }

mkdir -p "${SUMMARY_COPY_DIR}" "${ROWS_DIR}"
trap 'rm -rf "${ROWS_DIR}"' EXIT

#QUAST metric names exactly as they appear in report.tsv, in output column order
METRICS=(
    "Largest contig"
    "# contigs (>= 0 bp)"
    "Total length (>= 0 bp)"
    "N50"
    "NG50"
    "NGA50"
    "Genome fraction (%)"
    "Duplication ratio"
    "# misassemblies"
    "# local misassemblies"
    "Unaligned length"
    "# N's per 100 kbp"
    "# mismatches per 100 kbp"
    "# indels per 100 kbp"
    "K-mer-based compl. (%)"
    "# k-mer-based misjoins"
)
METRIC_LIST=$(printf '%s|' "${METRICS[@]}"); METRIC_LIST=${METRIC_LIST%|}

#one rows file per section; sorted and assembled into the final table at the end
: > "${ROWS_DIR}/full.rows"
: > "${ROWS_DIR}/chromosomes.rows"
: > "${ROWS_DIR}/unplaced.rows"

N_FILES=0
while IFS= read -r REPORT; do
    #path looks like: .../minlen_8000/f15000_d500000/{full|chromosomes|unplaced}/report.tsv
    if [[ ! "${REPORT}" =~ /minlen_([0-9]+)/f([0-9]+)_d([0-9]+)/(full|chromosomes|unplaced)/report\.tsv$ ]]; then
        echo "WARNING: could not parse path '${REPORT}'; skipping" >&2
        continue
    fi
    MINLEN="${BASH_REMATCH[1]}"
    F="${BASH_REMATCH[2]}"
    D="${BASH_REMATCH[3]}"
    TYPE="${BASH_REMATCH[4]}"

    #keep the raw report for this run under a unique name
    cp -p "${REPORT}" "${SUMMARY_COPY_DIR}/SAMPLE_CLI.minlen${MINLEN}.f${F}_d${D}.${TYPE}.report.tsv"

    #report.tsv is "metric<TAB>value" with a header row; missing metrics become NA
    VALUES=$(awk -F'\t' -v OFS='\t' -v list="${METRIC_LIST}" '
        BEGIN { n = split(list, want, "|") }
        NR > 1 { v[$1] = $2 }
        END {
            for (i = 1; i <= n; i++) printf "%s%s", (i > 1 ? OFS : ""), ((want[i] in v) ? v[want[i]] : "NA")
            printf "\n"
        }
    ' "${REPORT}")

    printf '%s\t%s\t%s\t%s\n' "${MINLEN}" "${D}" "${F}" "${VALUES}" >> "${ROWS_DIR}/${TYPE}.rows"
    N_FILES=$((N_FILES + 1))
done < <(find "${QUAST_RESULTS_DIR}" -type f -name "report.tsv" | sort)

#assemble the sheet layout: title row, header row, data rows, blank row
HEADER=$'minlen\t-d\t-f\tLargest contig\tScaffolds (n)\tTotal length\tN50\tNG50\tNGA50\tGenome fraction (%)\tDuplication ratio\t# misassemblies\t# local misassemblies\tUnaligned length\t# N\x27s per 100 kbp\t# mismatches per 100 kbp\t# indels per 100 kbp\tK-mer completeness (%)\t# k-mer misjoins'

write_section() {
    local TITLE="$1" TYPE="$2"
    printf '%s\n' "${TITLE}"
    printf '%s\n' "${HEADER}"
    sort -t$'\t' -k1,1n -k2,2n -k3,3n "${ROWS_DIR}/${TYPE}.rows"
    printf '\n'
}

{
    echo "SAMPLE_CLI"
    write_section "Full scaffolds QUAST (including unplaced)" full
    write_section "Scaffolds only (unplaced removed)"         chromosomes
    write_section "Unplaced only"                             unplaced
} > "${TSV}"

echo "Wrote ${N_FILES} rows to ${TSV}"