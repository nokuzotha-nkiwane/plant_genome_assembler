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

SAMPLE="SAMPLE_CLI"

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_DIR="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold"
SUMMARY_DIR="__RESULTS_DIR__"
TSV="${SUMMARY_DIR}/SAMPLE_CLI.ragtag_per_sequence_lengths.tsv"
TMP_DIR="${SUMMARY_DIR}/${PBS_JOBID}_tmp"

[[ -d "${RAGTAG_DIR}" ]] || { echo "Missing RagTag results dir: ${RAGTAG_DIR}"; exit 1; }

mkdir -p "${SUMMARY_DIR}" "${TMP_DIR}"
trap 'rm -rf "${TMP_DIR}"' EXIT

#one file list per section: minlen, -d, -f, column label, path
: > "${TMP_DIR}/full.files"
: > "${TMP_DIR}/chromosomes.files"
: > "${TMP_DIR}/unplaced.files"

N_FILES=0
while IFS= read -r FILE; do
    #name looks like: SAMPLE_CLI.minlen8000.f15000_d500000.ragtag.scaffold[.chromosomes|.unplaced]
    NAME=$(basename "${FILE}" .lengths)

    if [[ ! "${NAME}" =~ ^${SAMPLE}\.minlen([0-9]+)\.f([0-9]+)_d([0-9]+)\.ragtag\.scaffold(\.(chromosomes|unplaced))?$ ]]; then
        echo "WARNING: could not parse name '${NAME}' (${FILE}); skipping" >&2
        continue
    fi
    MINLEN="${BASH_REMATCH[1]}"
    F="${BASH_REMATCH[2]}"
    D="${BASH_REMATCH[3]}"
    TYPE="${BASH_REMATCH[5]:-full}"

    printf '%s\t%s\t%s\tminlen%s_f%s_d%s\t%s\n' \
        "${MINLEN}" "${D}" "${F}" "${MINLEN}" "${F}" "${D}" "${FILE}" >> "${TMP_DIR}/${TYPE}.files"
    N_FILES=$((N_FILES + 1))
done < <(find "${RAGTAG_DIR}" -type f -name "${SAMPLE}.minlen*.ragtag.scaffold*.lengths" | sort)

#build one matrix: rows = sequences, columns = settings (sorted by minlen, -d, -f)
#missing sequences are NA; range_bp = max - min across the settings where the sequence exists
build_matrix() {
    local TYPE="$1"
    local LIST="${TMP_DIR}/${TYPE}.files"

    sort -t$'\t' -k1,1n -k2,2n -k3,3n "${LIST}" | cut -f4,5 | awk -F'\t' -v OFS='\t' \
        -v hdr="${TMP_DIR}/${TYPE}.header" -v body="${TMP_DIR}/${TYPE}.body" '
        {
            ncol++; label[ncol]=$1; path=$2
            while ((getline line < path) > 0) {
                if (line ~ /^#/ || line == "") continue
                n = split(line, f, "\t")
                if (f[n] !~ /^[0-9]+$/) continue
                seen[f[1]] = 1
                val[f[1], ncol] = f[n]
            }
            close(path)
        }
        END {
            h = "sequence"
            for (c=1; c<=ncol; c++) h = h OFS label[c]
            print h OFS "range_bp" OFS "n_present" > hdr
            for (s in seen) {
                row = s; mn = ""; mx = ""; np = 0
                for (c=1; c<=ncol; c++) {
                    if ((s, c) in val) {
                        v = val[s, c] + 0
                        row = row OFS val[s, c]
                        np++
                        if (mn == "" || v < mn) mn = v
                        if (mx == "" || v > mx) mx = v
                    } else row = row OFS "NA"
                }
                print row OFS (np ? mx - mn : "NA") OFS np > body
            }
            close(body)
        }'

    #make sure both files exist even when the section is empty
    [[ -f "${TMP_DIR}/${TYPE}.body" ]]   || : > "${TMP_DIR}/${TYPE}.body"
    [[ -f "${TMP_DIR}/${TYPE}.header" ]] || printf 'sequence\n' > "${TMP_DIR}/${TYPE}.header"
}

write_section() {
    local TITLE="$1" TYPE="$2"
    build_matrix "${TYPE}"
    printf '%s\n' "${TITLE}"
    cat "${TMP_DIR}/${TYPE}.header"
    #natural sort so 1,2,...,10,11,12 instead of 1,10,11,12,2
    sort -t$'\t' -k1,1V "${TMP_DIR}/${TYPE}.body"
    printf '\n'
}

{
    echo "SAMPLE_CLI"
    write_section "Chromosomes only (unplaced removed)"      chromosomes
    write_section "Full scaffolds (including unplaced)"      full
    write_section "Unplaced only"                            unplaced
} > "${TSV}"

echo "Wrote comparison of ${N_FILES} .lengths files to ${TSV}"