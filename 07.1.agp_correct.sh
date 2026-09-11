#!/bin/bash
#PBS -l select=1:ncpus=32:mem=20GB
#PBS -q bix
#PBS -l walltime=8:00:00
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
THREADS=32


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
MINIMAP_PAF="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI_to_ref_aln5.paf"
DGENIES_INPUT="${RAGTAG_SCAFFOLD_DIR}/dgenies_input"
SAMPLE="dSAMPLE_CLI"

#make dgenies input directory
mkdir -p "${DGENIES_INPUT}" "${AGP2FASTA_DIR}"

#check format of agp
ragtag.py agpcheck "${AGP}" > "${AGP2FASTA_DIR}/agpcheck.txt"

#convert agp to fasta
ragtag.py agp2fa "${AGP}" "${INPUT_FASTA}" > "${OUTPUT_FASTA}"

#replace the ragtag ending with something else so that when scaffolding to make new agp first and 6th column are different
sed 's/_RagTag/_Chromosome/g' "${OUTPUT_FASTA}" > "${OUTPUT_FASTA_RENAMED}"
rm "${OUTPUT_FASTA}"

#run ragtag scaffold for new fasta
ragtag.py scaffold --remove-small -f 15000 -d 500000 -i 0.5 -a 0.5 -s 0.5 --mm2-params '-x asm5' -t "${THREADS}" \
    -o "${RAGTAG_OUTPUT_DIR}" "${REF_GENOME}" "${OUTPUT_FASTA_RENAMED}" || { echo "ragtag scaffold failed for sample ${SAMPLE}"; exit 1; }

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

#map reads to corrected chromosomes
read_map(){
    #for CHRSM use 1,2,3,4,5,6,7,8,9,10,11,12 (no 0 in front of numbers)
    local CHRSM="$@"
    local INPUT_FASTA_MAPPING="${RAGTAG_OUTPUT_DIR}/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
    local OUTPUT_DIR="${RAGTAG_SCAFFOLD_DIR}/correction_checks/chromosome_${CHRSM}"
    local CONTIGS_LIST="${OUTPUT_DIR}/contigs.list"
    local OUTPUT_FASTA_MAPPING="${OUTPUT_DIR}/chromosome_${CHRSM}.fasta"
    local OUTPUT_BAM="${OUTPUT_DIR}/${SAMPLE}_chromosome_${CHRSM}.bam"

    #make output directory
    mkdir -p "${OUTPUT_DIR}"

    conda deactivate
    conda activate helper-tools

    #Check raw reads
    if [[ -s "${FILTERED_READS}" ]]; then
        echo "Found filtered reads; proceeding to minimap2"
    else
        echo "Filtering raw reads"
        #Filter on Q20 quality and minimum read length of 5000
        filtlong \
        --min_mean_q 20 \
        --min_length 5000 \
        "${READS}" | gzip -k > "${FILTERED_READS}" || { echo "Filtlong failed for ${READS}"; exit 1; }
    fi

    #deactivate seqkit environment and activate minimap2
    conda deactivate
    conda activate seqkit

    #extract the chromomosome b section of the agp and take 6th column of the tsv and pass it to a list
    echo "${CHRSM}_RagTag" > "${CONTIGS_LIST}"

    #use list to extract sequences from fasta and make new small fasta
    seqkit grep -f "${CONTIGS_LIST}" "${INPUT_FASTA_MAPPING}" > "${OUTPUT_FASTA_MAPPING}"

    #deactivate env and activate minimap 2
    conda deactivate
    conda activate pbmm2


    #align reads to that fasta
    pbmm2 align --sort -J "${THREADS}" --bam-index BAI "${OUTPUT_FASTA_MAPPING}" "${FILTERED_READS}" "${OUTPUT_BAM}"
}


#could actually be arrays built at the top of the script so the loop takes in an array
if [[ "${SAMPLE}" == "d03" ]];then
    #map reads to chromosome 6
    for chr in 6; do
        read_map "${chr}"
    done
else
    #map reads to chromosome 6 and 9 for d05
    for chr in 6 9; do
        read_map "${chr}"
    done
fi