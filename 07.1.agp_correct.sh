#!/bin/bash
#PBS -l select=1:ncpus=8:mem=20GB
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
THREADS=8

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
REF_DIR="${TOMATO_PATH}/data/reference_data"
REF_GENOME="${REF_DIR}/SL5.0.unplaced_removed.fasta.gz"
ALL_RESULTS_DIR="${WORKDIR}/results"
RAGTAG_SCAFFOLD_DIR="__RESULTS_DIR__"
INPUT_FASTA="${ALL_RESULTS_DIR}/05.1.ragtag_correct/ragtag.correct.fasta"
AGP="${ALL_RESULTS_DIR}/06.5.relate_missing_buscos/ragtag.scaffold_corrected.agp"
AGP2FASTA_DIR="${RAGTAG_SCAFFOLD_DIR}/agp2fasta"
OUTPUT_FASTA="${AGP2FASTA_DIR}/corrected.fasta"
OUTPUT_FASTA_RENAMED="${AGP2FASTA_DIR}/dSAMPLE_CLI.renamed_corrected.fasta"
RAGTAG_OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/ragtag_output"
MINIMAP_PAF="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_to_ref_aln5.paf"
MINIMAP_PAF_2="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_w-unplaced_to_ref_aln5.paf"
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

#run ragtag scaffold for new fasta
ragtag.py scaffold --remove-small -f 15000 -d 500000 -i 0.5 -a 0.5 -s 0.5 --mm2-params '-x asm5' -t "${THREADS}" \
    -j "${UNPLACED_LIST}" -C \
    -o "${RAGTAG_OUTPUT_DIR}" "${REF_GENOME}" "${OUTPUT_FASTA_RENAMED}" || { echo "ragtag scaffold failed for sample dSAMPLE_CLI"; exit 1; }

#make a copy of the output fasta and agp to make it easier to differentiate the two samples when used together
mv "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.fasta" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta"
mv "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.agp" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.agp"
mv "${RAGTAG_OUTPUT_DIR}/ragtag.scaffold.asm.paf" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.asm.paf"

#deactivate env and activate minimap 2
conda deactivate
conda activate seqkit

seqkit grep -n -r -p '_RagTag$' "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta" > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
seqkit grep -v -n -r -p '_RagTag$' "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta" > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.unplaced.fasta"

seqkit fx2tab --length --name --header-line "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" \
    > "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.lengths"

#deactivate env and activate minimap 2
conda deactivate
conda activate helper-tools

#run minimap2 alignment
minimap2 -cx asm5 -t "${THREADS}" --eqx "${REF_GENOME}" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta" > "${MINIMAP_PAF}"
minimap2 -cx asm5 -t "${THREADS}" --eqx "${REF_GENOME}" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta" > "${MINIMAP_PAF_2}"

#gzip the output fasta
gzip -k "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
gzip -k "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta"

#move outputs to dgenies folder
mv "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.fasta.gz" "${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta.gz" "${MINIMAP_PAF}" "${MINIMAP_PAF_2}" "${DGENIES_INPUT}/"
ln -s "${REF_GENOME}" "${DGENIES_INPUT}/"