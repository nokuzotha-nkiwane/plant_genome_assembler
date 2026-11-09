#!/bin/bash
#PBS -l ncpus=36
#PBS -l mem=60GB
#PBS -q bix
#PBS -l walltime=4:00:00
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
THREADS=34

#read length threshold used for the ragtag/busco inputs
MINLEN=8000

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
INPUT_FASTA="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
AGP="${ALL_RESULTS_DIR}/06.5.relate_missing_buscos/ragtag.scaffold_corrected.agp"
AGP2FASTA_DIR="${RAGTAG_SCAFFOLD_DIR}/agp2fasta"
RENAMED_AGP="${AGP2FASTA_DIR}/corrected.agp"
OUTPUT_FASTA="${AGP2FASTA_DIR}/corrected.fasta"
RAGTAG_OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/ragtag_output"
RAW_READS="${WORKDIR}/raw_reads/filtered_reads/dSAMPLE_CLI_filtered_minlen7000.fastq.gz"
FULL_SCAFFOLD_FASTA="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta"
FULL_SCAFFOLD_READS_BAM="${RAGTAG_SCAFFOLD_DIR}/dSAMPLE_CLI_full_scaffold_reads.bam"
MINIMAP_PAF="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_to_ref_aln5.paf"
MINIMAP_PAF_2="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_w-unplaced_to_ref_aln5.paf"
MINIMAP_PAF_3="${RAGTAG_OUTPUT_DIR}/ref_to_dSAMPLE_CLI_aln5.paf"
DGENIES_INPUT="${RAGTAG_SCAFFOLD_DIR}/dgenies_input"

#make dgenies input directory
mkdir -p "${DGENIES_INPUT}" "${AGP2FASTA_DIR}"

#check format of agp
ragtag.py agpcheck "${AGP}" > "${AGP2FASTA_DIR}/agpcheck.txt"

#rename only RagTag component AGP objects to their source sequence names
awk '
BEGIN { FS=OFS="\t" }
/^#/ { print; next }
$1 ~ /_RagTag/ {
    if ($5 == "W") { $1 = $6; $2 = 1; $3 = $8 - $7 + 1; $4 = 1; print }
    next
}
{ print }
' "${AGP}" > "${RENAMED_AGP}"

#convert the single renamed AGP to fasta
ragtag.py agp2fa "${RENAMED_AGP}" "${INPUT_FASTA}" > "${OUTPUT_FASTA}"

#run ragtag scaffold for new fasta
ragtag.py scaffold --remove-small -f 15000 -d 500000 -i 0.4 -a 0.4 -s 0.4 --mm2-params '-x asm5' -t "${THREADS}" -C \
    -o "${RAGTAG_OUTPUT_DIR}" "${REF_GENOME}" "${OUTPUT_FASTA}" || { echo "ragtag scaffold failed for sample dSAMPLE_CLI"; exit 1; }

#make a copy of the output fasta and agp to make it easier to differentiate the two samples when used together
mv "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.fasta" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta"
mv "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.agp" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.agp"
mv "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.asm.paf" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.asm.paf"

#deactivate env and activate minimap 2
conda deactivate
conda activate seqkit

seqkit grep -v -n -r -p 'Chr0_RagTag$' "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta" > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
seqkit grep -n -r -p 'Chr0_RagTag$' "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta" > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.unplaced.fasta"

seqkit fx2tab --length --name --header-line "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" \
    > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.lengths"

#deactivate env and activate minimap 2
conda deactivate
conda activate helper-tools

#run minimap2 alignment
minimap2 -cx asm5 -t "${THREADS}" --eqx "${REF_GENOME}" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" > "${MINIMAP_PAF}"
minimap2 -cx asm5 -t "${THREADS}" --eqx "${REF_GENOME}" "${FULL_SCAFFOLD_FASTA}" > "${MINIMAP_PAF_2}"
minimap2 -cx asm5 -t "${THREADS}" --eqx "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" "${REF_GENOME}"> "${MINIMAP_PAF_3}"

#align reads to the full scaffolded assembly
minimap2 -ax map-hifi -t "${THREADS}" --secondary=no -N 1 -p 0.8 --eqx "${FULL_SCAFFOLD_FASTA}" "${RAW_READS}" | \
    samtools view -b -q 30 -F 2308 -@ "${THREADS}" - | \
    samtools sort -@ "${THREADS}" -o "${FULL_SCAFFOLD_READS_BAM}" - \
    || { echo "minimap2/samtools full scaffold read alignment failed"; exit 1; }
samtools index "${FULL_SCAFFOLD_READS_BAM}"

#gzip the output fasta
gzip -k "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
gzip -k "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta"

#move outputs to dgenies folder
mv "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta.gz" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta.gz" "${MINIMAP_PAF}" "${MINIMAP_PAF_2}" "${MINIMAP_PAF_3}" "${DGENIES_INPUT}/"
ln -s "${FULL_SCAFFOLD_READS_BAM}" "${DGENIES_INPUT}/"
ln -s "${FULL_SCAFFOLD_READS_BAM}.bai" "${DGENIES_INPUT}/"
ln -s "${REF_GENOME}" "${DGENIES_INPUT}/"