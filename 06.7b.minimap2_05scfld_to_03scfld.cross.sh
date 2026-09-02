#!/bin/bash
#PBS -l select=1:ncpus=23:mem=60GB
#PBS -q bix
#PBS -l walltime=5:00:00
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
conda activate helper-tools

#resource parameters
THREADS=23

#directories and files
WORKDIR_03="${TOMATO_PATH}/03"
WORKDIR_05="${TOMATO_PATH}/05"
ASM_ASM_ALN="__RESULTS_DIR__"
D03_CONTIGS_IN="${WORKDIR_03}/results/07.2.ragtag_scaffold_2/f15000_d500000/05.f15000_d500000.ragtag.scaffold.chromosomes.fasta"
D05_CONTIGS_IN="${WORKDIR_05}/results/07.2.ragtag_scaffold_2/f15000_d500000/05.f15000_d500000.ragtag.scaffold.chromosomes.fasta"
TEMP_DIR="${ASM_ASM_ALN}/${PBS_JOBID}_temp"
ASM_05_03="${ASM_ASM_ALN}/scaffold_05_03"

#make temp directory to fastas to so the original ones are accessible to other scripts
mkdir -p "${TEMP_DIR}" "${ASM_05_03}"

#automatically remove TEMP_DIR whenever the script exits (normal or error)
trap 'rm -rf "${TEMP_DIR}"' EXIT

#copy input file to temporary directory
cp "${D03_CONTIGS_IN}" \
 "${D05_CONTIGS_IN}" "${TEMP_DIR}/"

#reassign variables to the temp directory versions
D03_CONTIGS_IN="${TEMP_DIR}/$(basename "${D03_CONTIGS_IN}")"
D05_CONTIGS_IN="${TEMP_DIR}/$(basename "${D05_CONTIGS_IN}")"

#align assemblies to each other have 05 as reference
# minimap2 -ax asm5 -t "${THREADS}" "${D05_CONTIGS_IN}" "${D03_CONTIGS_IN}" > "${ASM_05_03}/aln5.sam"
minimap2 -cx asm5 --cs -t "${THREADS}" "${D05_CONTIGS_IN}" "${D03_CONTIGS_IN}" > "${ASM_05_03}/aln5.paf"