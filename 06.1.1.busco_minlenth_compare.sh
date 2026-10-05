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

#busco lineage used for the summary filenames
LINEAGE="solanales_odb10"

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
BUSCO_DIR="${ALL_RESULTS_DIR}/06.1.busco_ragtag"
SUMMARY_DIR="__RESULTS_DIR__"
SUMMARY_COPY_DIR="${SUMMARY_DIR}/short_summaries"
TSV="${SUMMARY_DIR}/SAMPLE_CLI.busco_minlen_summary.tsv"
ROWS_DIR="${SUMMARY_DIR}/${PBS_JOBID}_rows"

[[ -d "${BUSCO_DIR}" ]] || { echo "Missing BUSCO results dir: ${BUSCO_DIR}"; exit 1; }

mkdir -p "${SUMMARY_COPY_DIR}" "${ROWS_DIR}"
trap 'rm -rf "${ROWS_DIR}"' EXIT

#one rows file per section; sorted and assembled into the final table at the end
: > "${ROWS_DIR}/full.rows"
: > "${ROWS_DIR}/chromosomes.rows"
: > "${ROWS_DIR}/unplaced.rows"

N_FILES=0
while IFS= read -r FILE; do
    #copy the summary into one folder for this sample
    cp -p "${FILE}" "${SUMMARY_COPY_DIR}/"

    #name looks like: SAMPLE_CLI.minlen8000.f15000_d500000.ragtag.scaffold[.chromosomes|.unplaced]
    BASE=$(basename "${FILE}" .txt)
    NAME=${BASE#short_summary.specific.${LINEAGE}.}
    NAME=${NAME%_busco}

    if [[ ! "${NAME}" =~ ^([^.]+)\.minlen([0-9]+)\.f([0-9]+)_d([0-9]+)\.ragtag\.scaffold(\.(chromosomes|unplaced))?$ ]]; then
        echo "WARNING: could not parse name '${NAME}' (${FILE}); skipping" >&2
        continue
    fi
    MINLEN="${BASH_REMATCH[2]}"
    F="${BASH_REMATCH[3]}"
    D="${BASH_REMATCH[4]}"
    TYPE="${BASH_REMATCH[6]:-full}"

    #Scaffold_N50 (Mbp), Complete, Single, Duplicate, Fragmented, Missing, Error (%),
    #Scaffolds, Contigs, Total length, Percent gaps -- in the column order of the sheet
    VALUES=$(awk -v OFS='\t' '
        /^[[:space:]]*C:[0-9]/ { l=$0; gsub(/[^0-9. ]+/, " ", l); split(l, p, " "); err=p[7] }
        /Complete BUSCOs \(C\)/                 { cc=$1 }
        /Complete and single-copy BUSCOs \(S\)/ { cs=$1 }
        /Complete and duplicated BUSCOs \(D\)/  { cd=$1 }
        /Fragmented BUSCOs \(F\)/               { cf=$1 }
        /Missing BUSCOs \(M\)/                  { cm=$1 }
        /Number of scaffolds/                   { ns=$1 }
        /Number of contigs/                     { nc=$1 }
        /Total length/                          { tl=$1 }
        /Percent gaps/                          { pg=$1; sub(/%/, "", pg) }
        /Scaffold N50/ {
            v=$1; u=$2
            if (u=="Mbp") n50=v
            else if (u=="kbp") n50=v/1000
            else if (u=="Gbp") n50=v*1000
            else if (u=="bp")  n50=v/1000000
            else n50=v
        }
        END { print n50, cc, cs, cd, cf, cm, err, ns, nc, tl, pg }
    ' "${FILE}")

    printf '%s\t%s\t%s\t%s\n' "${MINLEN}" "${D}" "${F}" "${VALUES}" >> "${ROWS_DIR}/${TYPE}.rows"
    N_FILES=$((N_FILES + 1))
done < <(find "${BUSCO_DIR}" -type f -name "short_summary.specific.${LINEAGE}.*_busco.txt" | sort)

#assemble the sheet layout: title row, header row, data rows, blank row
HEADER=$'minlen\t-d\t-f\tScaffold_N50 (Mbp)\tComplete (n)\tSingle (n)\tDuplicate (n)\tFragmented (n)\tMissing (n)\tError (%)\tScaffolds (n)\tContigs (n)\tTotal length\tPercent gaps (%)'

write_section() {
    local TITLE="$1" TYPE="$2"
    printf '%s\n' "${TITLE}"
    printf '%s\n' "${HEADER}"
    sort -t$'\t' -k1,1n -k2,2n -k3,3n "${ROWS_DIR}/${TYPE}.rows"
    printf '\n'
}

{
    echo "SAMPLE_CLI"
    write_section "Full scaffolds buscos (including unplaced)" full
    write_section "Scaffolds only (unplaced removed)"          chromosomes
    write_section "Unplaced only"                              unplaced
} > "${TSV}"

echo "Wrote ${N_FILES} rows to ${TSV}"