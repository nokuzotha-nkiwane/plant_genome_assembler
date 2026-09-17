#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=8:00:00
#PBS -N SAMPLE_CLI_STEP_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

# for evaluating variables in ~/.pbsrc
source ~/.pbsrc

# load modules
module load app/miniconda/mamba
conda activate helper-tools

# resource parameters
THREADS=23

# directories and files
WORKDIR_03="${TOMATO_PATH}/03"
WORKDIR_05="${TOMATO_PATH}/05"
OUTPUT_DIR="__RESULTS_DIR__"
D03_FULL_SCFLD="${WORKDIR_03}/results/07.1.agp_correct/ragtag_output/d03.ragtag.scaffold.fasta"
D03_CHRSM_SCFLD="${WORKDIR_03}/results/07.1.agp_correct/ragtag_output/d03.ragtag.scaffold.chromosomes.fasta"
D03_FULL_SCFLD_GZ="${WORKDIR_03}/results/07.1.agp_correct/dgenies_input/d03.ragtag.scaffold.fasta.gz"
D03_CHRSM_SCFLD_GZ="${WORKDIR_03}/results/07.1.agp_correct/dgenies_input/d03.ragtag.scaffold.chromosomes.fasta.gz"
D03_UNPLACED_SCFLD="${WORKDIR_03}/results/07.1.agp_correct/ragtag_output/d03.ragtag.scaffold.unplaced.fasta"
D05_FULL_SCFLD="${WORKDIR_05}/results/07.1.agp_correct/ragtag_output/d05.ragtag.scaffold.fasta"
D05_CHRSM_SCFLD="${WORKDIR_05}/results/07.1.agp_correct/ragtag_output/d05.ragtag.scaffold.chromosomes.fasta"
D05_FULL_SCFLD_GZ="${WORKDIR_05}/results/07.1.agp_correct/dgenies_input/d05.ragtag.scaffold.fasta.gz"
D05_CHRSM_SCFLD_GZ="${WORKDIR_05}/results/07.1.agp_correct/dgenies_input/d05.ragtag.scaffold.chromosomes.fasta.gz"
D05_UNPLACED_SCFLD="${WORKDIR_05}/results/07.1.agp_correct/ragtag_output/d05.ragtag.scaffold.unplaced.fasta"

# array of each samples files
SAMPLE_03=("${D03_FULL_SCFLD}" "${D03_CHRSM_SCFLD}" "${D03_UNPLACED_SCFLD}")
SAMPLE_05=("${D05_FULL_SCFLD}" "${D05_CHRSM_SCFLD}" "${D05_UNPLACED_SCFLD}")

# array of gzipped files for full and chromosome scaffold files
SAMPLE_03_GZ=("${D03_FULL_SCFLD_GZ}" "${D03_CHRSM_SCFLD_GZ}" "")
SAMPLE_05_GZ=("${D05_FULL_SCFLD_GZ}" "${D05_CHRSM_SCFLD_GZ}" "")

# function to run alignments
run_alignment(){
    local ref_file="$1"
    local query_file="$2"
    local ref_gz="$3"
    local query_gz="$4"

    # extract filename without path and extension
    local base_name
    base_name=$(basename "${ref_file}" .fasta)

    mkdir -p "${OUTPUT_DIR}/${base_name}"
    minimap2 -cx asm5 --cs -t "${THREADS}" "${ref_file}" "${query_file}" > "${OUTPUT_DIR}/${base_name}/${base_name}.paf"

    if [[ -n "${ref_gz}" && -n "${query_gz}" ]]; then
        # symlink to the already-gzipped full/chromosome files
        ln -s "${ref_gz}" "${OUTPUT_DIR}/${base_name}/$(basename "${ref_gz}")"
        ln -s "${query_gz}" "${OUTPUT_DIR}/${base_name}/$(basename "${query_gz}")"
    else
        # gzip unplaced fastas straight into this alignment's output folder
        gzip -c "${ref_file}" > "${OUTPUT_DIR}/${base_name}/$(basename "${ref_file}").gz"
        gzip -c "${query_file}" > "${OUTPUT_DIR}/${base_name}/$(basename "${query_file}").gz"
    fi
}

# run alignment on target files
for i in "${!SAMPLE_03[@]}"; do
    run_alignment "${SAMPLE_03[$i]}" "${SAMPLE_05[$i]}" "${SAMPLE_03_GZ[$i]}" "${SAMPLE_05_GZ[$i]}"
done