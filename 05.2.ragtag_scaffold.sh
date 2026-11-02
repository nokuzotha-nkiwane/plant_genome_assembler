#!/bin/bash
#PBS -l select=1:ncpus=32:mem=120GB
#PBS -q bix
#PBS -l walltime=144:00:00
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
THREADS=2
JOBS=15

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME_GZ="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_CORRECT_DIR="${ALL_RESULTS_DIR}/05.1.ragtag_correct"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
TEMP_DIR="${RAGTAG_SCAFFOLD_DIR}/${PBS_JOBID}_temp"
SHARED_REF="${TEMP_DIR}/reference.fasta"

#single corrected assembly (ragtag correct run with all reads)
CORRECTED_FASTA="${RAGTAG_CORRECT_DIR}/ragtag.correct.fasta"

#scaffold parameter sweep
#  -f min unique alignment length   -d max merge distance
#  -i grouping confidence           -a location confidence
#  -s orientation confidence
F_VALS=(5000 10000 15000 20000)
D_VALS=(100000 300000 500000 700000)
I_VALS=(0.2 0.4 0.6 0.8 1.0)
A_VALS=(0.2 0.4 0.6 0.8 1.0)
S_VALS=(0.2 0.4 0.6 0.8 1.0)

mkdir -p "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

[[ -s "${CORRECTED_FASTA}" ]] || { echo "Missing corrected FASTA: ${CORRECTED_FASTA}" >&2; exit 1; }
zcat "${REF_GENOME_GZ}" > "${SHARED_REF}"
[[ -s "${SHARED_REF}" ]] || { echo "Failed to decompress reference: ${REF_GENOME_GZ}" >&2; exit 1; }

#worker function (runs once per f/d/i/a/s combination)
#each worker copies its own contigs and reference, because ragtag writes .fai
#indexes beside its inputs and concurrent workers would race on shared copies
#
#steps: run ragtag -> measure every sequence in the scaffold fasta -> delete the
#big files (scaffold fasta, alignments) -> keep agp, stats, confidence, lengths
#the .lengths file is written last, so it only exists for a finished combo
scaffold_one() {
    set -euo pipefail
    local f_val="$1" d_val="$2" i_val="$3" a_val="$4" s_val="$5"
    local tag="f${f_val}_d${d_val}_i${i_val}_a${a_val}_s${s_val}"
    local outdir="${RAGTAG_SCAFFOLD_DIR}/f${f_val}_d${d_val}/i${i_val}_a${a_val}_s${s_val}"
    local prefix="SAMPLE_CLI.${tag}"
    local worker_tmp="${TEMP_DIR}/${prefix}"
    local contigs="${worker_tmp}/contigs.fasta"
    local ref="${worker_tmp}/reference.fasta"
    local scaffold_fasta="${outdir}/${prefix}.ragtag.scaffold.fasta"
    local lengths_file="${outdir}/${prefix}.ragtag.scaffold.lengths"

    mkdir -p "${worker_tmp}"
    cp "${CORRECTED_FASTA}" "${contigs}"
    cp "${SHARED_REF}" "${ref}"

    #combos are only queued if unfinished, so a leftover outdir is a partial run
    rm -rf "${outdir}"
    mkdir -p "$(dirname "${outdir}")"

    ragtag.py scaffold --remove-small -f "${f_val}" -d "${d_val}" -i "${i_val}" \
        -a "${a_val}" -s "${s_val}" --mm2-params '-x asm5' -C -t "${THREADS}" \
        -o "${outdir}" "${ref}" "${contigs}"

    #prefix all ragtag.py outputs with sample name and parameters
    for RAGTAG_OUT in "${outdir}"/ragtag.scaffold.*; do
        mv "${RAGTAG_OUT}" "${outdir}/${prefix}.$(basename "${RAGTAG_OUT}")"
    done

    [[ -s "${scaffold_fasta}" ]] || { echo "Missing scaffold FASTA: ${scaffold_fasta}" >&2; exit 1; }

    #length of every sequence in the scaffold fasta: "name <tab> length"
    #(awk, so this does not need the seqkit env)
    awk 'BEGIN { OFS = "\t"; print "name", "length" }
         /^>/ {
             if (seq_name != "") print seq_name, seq_length
             seq_name = substr($1, 2)
             seq_length = 0
             next
         }
         { seq_length += length($0) }
         END { if (seq_name != "") print seq_name, seq_length }' \
        "${scaffold_fasta}" > "${lengths_file}.tmp"

    #delete the big files, keep agp / stats / confidence
    rm -f "${scaffold_fasta}" "${outdir}/${prefix}".ragtag.scaffold.asm.*

    #last step: the lengths file appears only now
    mv "${lengths_file}.tmp" "${lengths_file}"

    rm -rf "${worker_tmp}"
}

export -f scaffold_one
export CORRECTED_FASTA RAGTAG_SCAFFOLD_DIR SHARED_REF TEMP_DIR THREADS

#A non-empty file can still be truncated after an interrupted write. Require
#the expected header and at least one numeric sequence length before resuming.
lengths_complete() {
    local lengths_file="$1"
    [[ -s "${lengths_file}" ]] || return 1

    awk -F '\t' '
        NR == 1 && $1 == "name" && $2 == "length" { header = 1; next }
        NF >= 2 && $1 != "" && $2 ~ /^[0-9]+$/ { row = 1 }
        END { exit !(header && row) }
    ' "${lengths_file}"
}

#build the list of unfinished combinations (one per line: f d i a s)
#a combo is finished when its .lengths file exists
COMBOS="${RAGTAG_SCAFFOLD_DIR}/scaffold.combos"
: > "${COMBOS}"
for f_val in "${F_VALS[@]}"; do
    for d_val in "${D_VALS[@]}"; do
        for i_val in "${I_VALS[@]}"; do
            for a_val in "${A_VALS[@]}"; do
                for s_val in "${S_VALS[@]}"; do
                    PREFIX="SAMPLE_CLI.f${f_val}_d${d_val}_i${i_val}_a${a_val}_s${s_val}"
                    DONE="${RAGTAG_SCAFFOLD_DIR}/f${f_val}_d${d_val}/i${i_val}_a${a_val}_s${s_val}/${PREFIX}.ragtag.scaffold.lengths"
                    if lengths_complete "${DONE}"; then
                        echo "Scaffold output already present for ${PREFIX}; skipping"
                        continue
                    fi
                    printf '%s %s %s %s %s\n' "${f_val}" "${d_val}" "${i_val}" "${a_val}" "${s_val}" >> "${COMBOS}"
                done
            done
        done
    done
done

echo "Combinations queued: $(wc -l < "${COMBOS}")"

###############################################################################
# Stage 1: ragtag scaffold + measure lengths + clean up (ragtag env)
###############################################################################
set +u
conda activate ragtag
set -u

parallel -j "${JOBS}" --colsep ' ' \
    --joblog "${RAGTAG_SCAFFOLD_DIR}/stage1.joblog" --halt soon,fail=1 \
    scaffold_one {1} {2} {3} {4} {5} < "${COMBOS}"

###############################################################################
# Stage 2: one row per parameter combination, columns Chr0..Chr12 + total
###############################################################################
LENGTHS_TSV="${RAGTAG_SCAFFOLD_DIR}/scaffold_lengths.tsv"

#header: sample, params, Chr0..Chr12, total_length
{
    printf 'sample\tf\td\ti\ta\ts'
    for chrom_number in $(seq 0 12); do printf '\tChr%s' "${chrom_number}"; done
    printf '\ttotal_length\n'
} > "${LENGTHS_TSV}.tmp"

for f_val in "${F_VALS[@]}"; do
    for d_val in "${D_VALS[@]}"; do
        for i_val in "${I_VALS[@]}"; do
            for a_val in "${A_VALS[@]}"; do
                for s_val in "${S_VALS[@]}"; do
                    OUTDIR="${RAGTAG_SCAFFOLD_DIR}/f${f_val}_d${d_val}/i${i_val}_a${a_val}_s${s_val}"
                    PREFIX="SAMPLE_CLI.f${f_val}_d${d_val}_i${i_val}_a${a_val}_s${s_val}"
                    LENGTHS_FILE="${OUTDIR}/${PREFIX}.ragtag.scaffold.lengths"

                    lengths_complete "${LENGTHS_FILE}" \
                        || { echo "Invalid or missing ${LENGTHS_FILE}" >&2; exit 1; }

                    awk -F'\t' \
                        -v sample="SAMPLE_CLI" -v f="${f_val}" -v d="${d_val}" \
                        -v i="${i_val}" -v a="${a_val}" -v s="${s_val}" '

                        # skip the header line
                        NR == 1 { next }

                        # every other line is: sequence name <tab> sequence length
                        {
                            seq_name   = $1
                            seq_length = $2

                            total_length += seq_length

                            # "Chr07_RagTag" -> "07"
                            chrom_number = seq_name
                            sub(/^Chr/, "", chrom_number)
                            sub(/_RagTag$/, "", chrom_number)

                            # keep it only if what is left is a number ("07" -> 7)
                            if (chrom_number ~ /^[0-9]+$/) {
                                length_of_chrom[chrom_number + 0] = seq_length
                            }
                        }

                        END {
                            printf "%s\t%s\t%s\t%s\t%s\t%s", sample, f, d, i, a, s

                            for (chrom = 0; chrom <= 12; chrom++) {
                                if (chrom in length_of_chrom) printf "\t%s", length_of_chrom[chrom]
                                else                          printf "\tNA"
                            }

                            printf "\t%s\n", total_length
                        }' "${LENGTHS_FILE}" >> "${LENGTHS_TSV}.tmp"
                done
            done
        done
    done
done

mv "${LENGTHS_TSV}.tmp" "${LENGTHS_TSV}"
echo "Wrote $(( $(wc -l < "${LENGTHS_TSV}") - 1 )) rows to ${LENGTHS_TSV}"

#second table: per parameter combination, two totals
#  chr1_to_12_length = Chr1 + Chr2 + ... + Chr12 combined
#  unplaced_length   = Chr0 (unplaced sequences only)
#columns in scaffold_lengths.tsv: 1-6 = sample f d i a s, 7 = Chr0, 8-19 = Chr1..Chr12
TOTALS_TSV="${RAGTAG_SCAFFOLD_DIR}/scaffold_total_lengths.tsv"
awk -F'\t' -v OFS='\t' '
    NR == 1 {
        print $1, $2, $3, $4, $5, $6, "chr1_to_12_length", "unplaced_length"
        next
    }
    {
        unplaced_length   = $7
        chr1_to_12_length = 0

        for (column = 8; column <= 19; column++) {
            if ($column == "NA") { chr1_to_12_length = "NA"; break }   # a chromosome is missing
            chr1_to_12_length += $column
        }

        print $1, $2, $3, $4, $5, $6, chr1_to_12_length, unplaced_length
    }' "${LENGTHS_TSV}" > "${TOTALS_TSV}.tmp"
mv "${TOTALS_TSV}.tmp" "${TOTALS_TSV}"
echo "Wrote $(( $(wc -l < "${TOTALS_TSV}") - 1 )) rows to ${TOTALS_TSV}"
