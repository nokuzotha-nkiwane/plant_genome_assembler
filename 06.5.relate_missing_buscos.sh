#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=5:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

# kill execution at first error
# set -euxo pipefail 

# for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#load modules
module load app/miniconda/mamba
conda activate seqkit

#resources
THREADS=21

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_GENOME="${TOMATO_PATH}/data/reference_data/SL5.0.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
UNPLACED_SCAFFOLDS_FASTA="${ALL_RESULTS_DIR}/05.2.ragtag_scaffold/f15000_d500000/SAMPLE_CLI.f15000_d500000.ragtag.scaffold.unplaced.fasta"
BUSCO_DIR="${ALL_RESULTS_DIR}/06.1.busco_ragtag/scaffold"
BUSCO_MISSING_CHRSM_SCAFFOLDS="${BUSCO_DIR}/SAMPLE_CLI.f15000_d500000.ragtag.scaffold.chromosomes_busco/run_solanales_odb10/missing_busco_list.tsv"
BUSCO_FULL_UNPLACED_SCAFFOLDS="${BUSCO_DIR}/SAMPLE_CLI.f15000_d500000.ragtag.scaffold.unplaced_busco/run_solanales_odb10/full_table.tsv"
OUTPUT_DIR="__RESULTS_DIR__"
CMPLTE_FROM_UNPLACED_LIST="${OUTPUT_DIR}/complete_from_full_unplaced.list"
CONSOLIDATED_MISSINGS_LIST="${OUTPUT_DIR}/consoldated_missings.contigs.list"
unique_CONSOLIDATED_MISSINGS_LIST="${OUTPUT_DIR}/unique_consoldated_missings.contigs.list"
unique_CONSOLIDATED_MISSINGS_FASTA="${OUTPUT_DIR}/unique_consoldated_missings.fasta"
DGENIES_INPUT="${OUTPUT_DIR}/dgenies_input"
SORTED_BAM="${OUTPUT_DIR}/dSAMPLE_CLI_aln5.sorted.bam"
PAF_OUT="${OUTPUT_DIR}/dSAMPLE_CLI_aln5.paf"
TEMP_DIR="${OUTPUT_DIR}/${PBS_JOBID}_temp"

# local (temp-dir) copies of the input files actually read/aligned against
TEMP_REF_GENOME="${TEMP_DIR}/$(basename "${REF_GENOME}")"
TEMP_UNPLACED_SCAFFOLDS_FASTA="${TEMP_DIR}/$(basename "${UNPLACED_SCAFFOLDS_FASTA}")"
TEMP_BUSCO_MISSING_CHRSM_SCAFFOLDS="${TEMP_DIR}/$(basename "${BUSCO_MISSING_CHRSM_SCAFFOLDS}")"
TEMP_BUSCO_FULL_UNPLACED_SCAFFOLDS="${TEMP_DIR}/$(basename "${BUSCO_FULL_UNPLACED_SCAFFOLDS}")"

# make dgenies input directory
mkdir -p "${DGENIES_INPUT}" "${TEMP_DIR}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# copy the required inputs into TEMP_DIR so downstream steps read local (fast) copies
cp "${REF_GENOME}" "${TEMP_REF_GENOME}"
cp "${UNPLACED_SCAFFOLDS_FASTA}" "${TEMP_UNPLACED_SCAFFOLDS_FASTA}"
cp "${BUSCO_MISSING_CHRSM_SCAFFOLDS}" "${TEMP_BUSCO_MISSING_CHRSM_SCAFFOLDS}"
cp "${BUSCO_FULL_UNPLACED_SCAFFOLDS}" "${TEMP_BUSCO_FULL_UNPLACED_SCAFFOLDS}"
    # || { echo "Failed to stage input files to ${TEMP_DIR}"; exit 1; }

# read full_table.tsv (TEMP_BUSCO_FULL_UNPLACED_SCAFFOLDS) of unplaced scaffolds from line 4
#from col2 grep 'Complete' and print the whole line to CMPLTE_FROM_UNPLACED_LIST
grep -v '^#' "${TEMP_BUSCO_FULL_UNPLACED_SCAFFOLDS}" | awk -F'\t' '$2=="Complete"' > "${CMPLTE_FROM_UNPLACED_LIST}"
    # || { echo "Failed to parse ${TEMP_BUSCO_FULL_UNPLACED_SCAFFOLDS}"; exit 1; }

# read missing_busco_list.tsv (TEMP_BUSCO_MISSING_CHRSM_SCAFFOLDS) of unplaced scaffolds from line 4
grep -v '^#' "${TEMP_BUSCO_MISSING_CHRSM_SCAFFOLDS}" | awk -F'\t' '{print $1}' > "${OUTPUT_DIR}/missing_ids.list"

# read each line of list (single column list) and check if found in CMPLTE_FROM_UNPLACED_LIST
# if found print entire line to CONSOLIDATED_MISSINGS_LIST
awk -F'\t' 'NR==FNR {missing[$1]; next} $1 in missing' "${OUTPUT_DIR}/missing_ids.list" "${CMPLTE_FROM_UNPLACED_LIST}" > "${CONSOLIDATED_MISSINGS_LIST}"
    # || { echo "Failed to cross-reference BUSCO tables"; exit 1; }

# in CONSOLIDATED_MISSINGS_LIST print third column with contig/sequence name to a list (unique_CONSOLIDATED_MISSINGS_LIST)
#sort and deduplicate list
awk -F'\t' '{print $3}' "${CONSOLIDATED_MISSINGS_LIST}" | sort -u > "${unique_CONSOLIDATED_MISSINGS_LIST}"

# #if file empty emit a warning instead of silent failure
# if [[ ! -s "${unique_CONSOLIDATED_MISSINGS_LIST}" ]]; then
#     echo "No BUSCOs missing-in-chromosomes-but-complete-in-unplaced found — nothing to extract."
#     exit 0
# fi

#use the sorted list to extract the sequences from the orignal fasta (TEMP_UNPLACED_SCAFFOLDS_FASTA) and print the matches to a
#new fasta unique_CONSOLIDATED_MISSINGS_FASTA
seqkit grep -f "${unique_CONSOLIDATED_MISSINGS_LIST}" "${TEMP_UNPLACED_SCAFFOLDS_FASTA}" > "${unique_CONSOLIDATED_MISSINGS_FASTA}"
    # || { echo "seqkit grep failed"; exit 1; }

#deactivate seqkit environment and activate minimap2
conda deactivate
conda activate helper-tools

#run minimap2 on the new fasta unique_CONSOLIDATED_MISSINGS_FASTA and the reference TEMP_REF_GENOME to produce sam and paf
minimap2 -cx asm5 --cs -t "${THREADS}" "${TEMP_REF_GENOME}" "${unique_CONSOLIDATED_MISSINGS_FASTA}" > "${PAF_OUT}"
    # || { echo "minimap2 PAF generation failed"; exit 1; }

#make a bam file file (should be sorted) to visualise in IGV after alignment
minimap2 -ax asm5 -t "${THREADS}" "${TEMP_REF_GENOME}" "${unique_CONSOLIDATED_MISSINGS_FASTA}" | samtools sort -@ "${THREADS}" -o "${SORTED_BAM}" -
    # || { echo "minimap2/samtools sort failed"; exit 1; }
samtools index "${SORTED_BAM}"

#copy paf, unique_CONSOLIDATED_MISSINGS_FASTA and TEMP_REF_GENOME to DGENIES_INPUT
cp "${PAF_OUT}" "${unique_CONSOLIDATED_MISSINGS_FASTA}" "${TEMP_REF_GENOME}" "${DGENIES_INPUT}/"