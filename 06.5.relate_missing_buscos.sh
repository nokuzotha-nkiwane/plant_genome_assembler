#!/bin/bash
#PBS -l ncpus=4
#PBS -l mem=8GB
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

#directories and files
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
DGENIES_INPUT="${OUTPUT_DIR}/dgenies input"