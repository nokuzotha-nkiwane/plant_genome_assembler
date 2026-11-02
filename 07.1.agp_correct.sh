#!/bin/bash
#PBS -l select=1:ncpus=8:mem=40GB
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
conda activate ragtag

#resource allocation
THREADS=2
JOBS=4

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
TEMP_DIR="${RAGTAG_SCAFFOLD_DIR}/${PBS_JOBID}_temp"
SHARED_REF="${TEMP_DIR}/reference.fasta"
INPUT_FASTA="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
AGP="${ALL_RESULTS_DIR}/06.5.relate_missing_buscos/ragtag.scaffold_corrected.agp"
AGP2FASTA_DIR="${RAGTAG_SCAFFOLD_DIR}/agp2fasta"
OUTPUT_FASTA="${AGP2FASTA_DIR}/corrected.fasta"
OUTPUT_FASTA_RENAMED="${AGP2FASTA_DIR}/dSAMPLE_CLI.renamed_corrected.fasta"
RAGTAG_OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/ragtag_output"
MINIMAP_PAF="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_to_ref_aln5.paf"
MINIMAP_PAF_2="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_w-unplaced_to_ref_aln5.paf"
MINIMAP_PAF_3="${RAGTAG_OUTPUT_DIR}/ref_to_dSAMPLE_CLI_aln5.paf"
DGENIES_INPUT="${RAGTAG_SCAFFOLD_DIR}/dgenies_input"
UNPLACED_LIST="${AGP2FASTA_DIR}/dSAMPLE_CLI_unplaced_ids.txt"

#make dgenies input directory
mkdir -p "${DGENIES_INPUT}" "${AGP2FASTA_DIR}"

#check format of agp
ragtag.py agpcheck "${AGP}" > "${AGP2FASTA_DIR}/agpcheck.txt"

#convert agp to fasta
ragtag.py agp2fa "${AGP}" "${INPUT_FASTA}" > "${OUTPUT_FASTA}"

#replace the ragtag ending with something else so that when scaffolding to make new agp first and 6th column are different
sed 's/_RagTag/_Chromosome/g' "${OUTPUT_FASTA}" > "${OUTPUT_FASTA_RENAMED}"
rm "${OUTPUT_FASTA}"

#make list of unplaced contigs to not be included scaffold fasta
awk '$1 !~ /_RagTag$/ {print $1}' "${AGP}" > "${UNPLACED_LIST}"

F_VALS=(5000 10000 15000 20000)
D_VALS=(100000 300000 500000 700000)
I_VALS=(0.2 0.4 0.6 0.8 1.0)
A_VALS=(0.2 0.4 0.6 0.8 1.0)
S_VALS=(0.2 0.4 0.6 0.8 1.0)

mkdir -p "${TEMP_DIR}"
trap 'rm -rf "${TEMP_DIR}"' EXIT

[[ -s "${OUTPUT_FASTA_RENAMED}" ]] || { echo "Missing complete corrected FASTA: ${OUTPUT_FASTA_RENAMED}" >&2; exit 1; }
zcat "${REF_GENOME}" > "${SHARED_REF}"
[[ -s "${SHARED_REF}" ]] || { echo "Failed to decompress reference: ${REF_GENOME}" >&2; exit 1; }

#Run one complete-FASTA scaffold for each parameter combination.
scaffold_one() {
    set -euo pipefail
    local f_val="$1" d_val="$2" i_val="$3" a_val="$4" s_val="$5"
    local tag="f${f_val}_d${d_val}_i${i_val}_a${a_val}_s${s_val}"
    local outdir="${RAGTAG_OUTPUT_DIR}/f${f_val}_d${d_val}/i${i_val}_a${a_val}_s${i_val}"
    local prefix="dSAMPLE_CLI.${tag}"
    local worker_tmp="${TEMP_DIR}/${prefix}"
    local contigs="${worker_tmp}/contigs.fasta"
    local ref="${worker_tmp}/reference.fasta"
    local scaffold_fasta="${outdir}/${prefix}.ragtag.scaffold.fasta"
    local lengths_file="${outdir}/${prefix}.ragtag.scaffold.lengths"

    mkdir -p "${worker_tmp}"
    cp "${OUTPUT_FASTA_RENAMED}" "${contigs}"
    cp "${SHARED_REF}" "${ref}"
    rm -rf "${outdir}"
    mkdir -p "$(dirname "${outdir}")"

    ragtag.py scaffold --remove-small -f "${f_val}" -d "${d_val}" -i "${i_val}" \
        -a "${a_val}" -s "${s_val}" --mm2-params '-x asm5' -j "${UNPLACED_LIST}" \
        -C -t "${THREADS}" -o "${outdir}" "${ref}" "${contigs}"

    for RAGTAG_OUT in "${outdir}"/ragtag.scaffold.*; do
        mv "${RAGTAG_OUT}" "${outdir}/${prefix}.$(basename "${RAGTAG_OUT}")"
    done

    [[ -s "${scaffold_fasta}" ]] || { echo "Missing complete scaffold FASTA: ${scaffold_fasta}" >&2; exit 1; }

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

    rm -f "${scaffold_fasta}" "${outdir}/${prefix}".ragtag.scaffold.asm.*
    mv "${lengths_file}.tmp" "${lengths_file}"
    rm -rf "${worker_tmp}"
}

export -f scaffold_one
export OUTPUT_FASTA_RENAMED RAGTAG_OUTPUT_DIR SHARED_REF TEMP_DIR UNPLACED_LIST THREADS

lengths_complete() {
    local lengths_file="$1"
    [[ -s "${lengths_file}" ]] || return 1
    awk -F '\t' '
        NR == 1 && $1 == "name" && $2 == "length" { header = 1; next }
        NF >= 2 && $1 != "" && $2 ~ /^[0-9]+$/ { row = 1 }
        END { exit !(header && row) }
    ' "${lengths_file}"
}

COMBOS="${RAGTAG_OUTPUT_DIR}/scaffold.combos"
: > "${COMBOS}"
for f_val in "${F_VALS[@]}"; do
    for d_val in "${D_VALS[@]}"; do
        for i_val in "${I_VALS[@]}"; do
            for a_val in "${A_VALS[@]}"; do
                for s_val in "${S_VALS[@]}"; do
                    PREFIX="dSAMPLE_CLI.f${f_val}_d${d_val}_i${i_val}_a${a_val}_s${s_val}"
                    DONE="${RAGTAG_OUTPUT_DIR}/f${f_val}_d${d_val}/i${i_val}_a${a_val}_s${i_val}/${PREFIX}.ragtag.scaffold.lengths"
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
parallel -j "${JOBS}" --colsep ' ' --joblog "${RAGTAG_OUTPUT_DIR}/stage1.joblog" \
    --halt soon,fail=1 scaffold_one {1} {2} {3} {4} {5} < "${COMBOS}"

LENGTHS_TSV="${RAGTAG_OUTPUT_DIR}/scaffold_lengths.tsv"
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
                    OUTDIR="${RAGTAG_OUTPUT_DIR}/f${f_val}_d${d_val}/i${i_val}_a${a_val}_s${i_val}"
                    PREFIX="dSAMPLE_CLI.f${f_val}_d${d_val}_i${i_val}_a${a_val}_s${s_val}"
                    LENGTHS_FILE="${OUTDIR}/${PREFIX}.ragtag.scaffold.lengths"
                    lengths_complete "${LENGTHS_FILE}" || { echo "Invalid or missing ${LENGTHS_FILE}" >&2; exit 1; }
                    awk -F '\t' -v sample="dSAMPLE_CLI" -v f="${f_val}" -v d="${d_val}" \
                        -v i="${i_val}" -v a="${a_val}" -v s="${s_val}" '
                        NR == 1 { next }
                        {
                            total_length += $2
                            chrom_number = $1
                            sub(/^Chr/, "", chrom_number)
                            sub(/_RagTag$/, "", chrom_number)
                            if (chrom_number ~ /^[0-9]+$/) length_of_chrom[chrom_number + 0] = $2
                        }
                        END {
                            printf "%s\t%s\t%s\t%s\t%s\t%s", sample, f, d, i, a, s
                            for (chrom = 0; chrom <= 12; chrom++) {
                                if (chrom in length_of_chrom) printf "\t%s", length_of_chrom[chrom]
                                else printf "\tNA"
                            }
                            printf "\t%s\n", total_length
                        }' "${LENGTHS_FILE}" >> "${LENGTHS_TSV}.tmp"
                done
            done
        done
    done
done
mv "${LENGTHS_TSV}.tmp" "${LENGTHS_TSV}"

TOTALS_TSV="${RAGTAG_OUTPUT_DIR}/scaffold_total_lengths.tsv"
awk -F '\t' -v OFS='\t' '
    NR == 1 { print $1, $2, $3, $4, $5, $6, "chr1_to_12_length", "unplaced_length"; next }
    {
        unplaced_length = $7
        chr1_to_12_length = 0
        for (column = 8; column <= 19; column++) {
            if ($column == "NA") { chr1_to_12_length = "NA"; break }
            chr1_to_12_length += $column
        }
        print $1, $2, $3, $4, $5, $6, chr1_to_12_length, unplaced_length
    }' "${LENGTHS_TSV}" > "${TOTALS_TSV}.tmp"
mv "${TOTALS_TSV}.tmp" "${TOTALS_TSV}"