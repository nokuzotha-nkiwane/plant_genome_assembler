#!/bin/bash
#PBS -l select=1:ncpus=20:mem=60GB
#PBS -q bix
#PBS -l walltime=24:00:00
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
THREADS=20

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
READS="${WORKDIR}/raw_reads/D260405-SAMPLE_CLI_HiFi.fastq.gz"
FILTERED_READS="${WORKDIR}/raw_reads/dSAMPLE_CLI_filtered.fastq.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
INPUT_FASTA="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
AGP="${ALL_RESULTS_DIR}/06.5.relate_missing_buscos/ragtag.scaffold_corrected.agp"
AGP2FASTA_DIR="${RAGTAG_SCAFFOLD_DIR}/agp2fasta"
OUTPUT_FASTA="${AGP2FASTA_DIR}/corrected.fasta"
OUTPUT_FASTA_RENAMED="${AGP2FASTA_DIR}/dSAMPLE_CLI.renamed_corrected.fasta"
RAGTAG_OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/ragtag_output"
WHOLE_BAM="${RAGTAG_SCAFFOLD_DIR}/correction_checks/dSAMPLE_CLI_whole.bam"
MINIMAP_PAF="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_to_ref_aln5.paf"
DGENIES_INPUT="${RAGTAG_SCAFFOLD_DIR}/dgenies_input"

#chromosomes to be corrected
CORRECTION_CHROMOSOMES=()

#make dgenies input directory
mkdir -p "${DGENIES_INPUT}" "${AGP2FASTA_DIR}" "${RAGTAG_SCAFFOLD_DIR}/correction_checks"

#check format of agp
ragtag.py agpcheck "${AGP}" > "${AGP2FASTA_DIR}/agpcheck.txt"

#convert agp to fasta
ragtag.py agp2fa "${AGP}" "${INPUT_FASTA}" > "${OUTPUT_FASTA}"

#replace the ragtag ending with something else so that when scaffolding to make new agp first and 6th column are different
sed 's/_RagTag/_Chromosome/g' "${OUTPUT_FASTA}" > "${OUTPUT_FASTA_RENAMED}"
rm "${OUTPUT_FASTA}"

#run ragtag scaffold for new fasta
ragtag.py scaffold --remove-small -f 15000 -d 500000 -i 0.5 -a 0.5 -s 0.5 --mm2-params '-x asm5' -t "${THREADS}" \
    -o "${RAGTAG_OUTPUT_DIR}" "${REF_GENOME}" "${OUTPUT_FASTA_RENAMED}" || { echo "ragtag scaffold failed for sample dSAMPLE_CLI"; exit 1; }

#deactivate env and activate minimap 2
conda deactivate
conda activate seqkit

seqkit grep -n -r -p '_RagTag$' "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.fasta" > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
seqkit grep -v -n -r -p '_RagTag$' "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.fasta" > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.unplaced.fasta"

seqkit fx2tab --length --name --header-line "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" \
    > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.lengths"

#deactivate env and activate minimap 2
conda deactivate
conda activate helper-tools

#run minimap2 alignment
minimap2 -cx asm5 -t "${THREADS}" --eqx "${REF_GENOME}" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" > "${MINIMAP_PAF}"

#gzip the output fasta
gzip -k "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"

#move outputs to dgenies folder
mv "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta.gz" "${MINIMAP_PAF}" "${DGENIES_INPUT}/"
ln -s "${REF_GENOME}" "${DGENIES_INPUT}/"

#filter reads if needed
if [[ -s "${FILTERED_READS}" ]]; then
    echo "Found filtered reads; proceeding to minimap2"
else
    echo "Filtering raw reads"
    filtlong \
    --min_mean_q 20 \
    --min_length 8000 \
    "${READS}" | gzip -k > "${FILTERED_READS}" || { echo "Filtlong failed for ${READS}"; exit 1; }
fi

#align reads to the whole scaffolded assembly once
conda deactivate
conda activate pbmm2


mkdir -p "$(dirname "${WHOLE_BAM}")"

pbmm2 align --sort -J "${THREADS}" --bam-index BAI "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" "${FILTERED_READS}" "${WHOLE_BAM}"

extract_region(){
    local CHRSM="$1"
    local OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/correction_checks/chromosome_${CHRSM}"
    local OUTPUT_BAM="${OUTPUT_DIR}/dSAMPLE_CLI_chromosome_${CHRSM}.bam"

    mkdir -p "${OUTPUT_DIR}"

    conda deactivate
    conda activate helper-tools

    samtools view -b "${WHOLE_BAM}" "${CHRSM}_RagTag" > "${OUTPUT_BAM}"
    samtools index "${OUTPUT_BAM}"
}


# run function to correct chromosomes
for CHR in "${CORRECTION_CHROMOSOMES[@]}"; do
    extract_region "${CHR}"
done