#!/bin/bash
#PBS -l select=1:ncpus=24:mem=40GB
#PBS -q bix
#PBS -l walltime=8:00:00
#PBS -N SAMPLE_CLI_BUSCO_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource allocation: 8 runs x 3 threads = 24 cores
JOBS=8
BUSCO_CPU=3

#load modules
module load app/miniconda/mamba
conda activate busco_6.1.0
export _JAVA_OPTIONS="-Xmx8g"
module load app/parallel/parallel

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
ANNOTATION_DIR="${ALL_RESULTS_DIR}/13.2.agat"
BUSCO_DIR="__RESULTS_DIR__"
BUSCO_DB_DIR="${TOMATO_PATH}/data"
LINEAGE="solanales_odb10"

mkdir -p "${BUSCO_DIR}"
cd "${BUSCO_DIR}"

NAMES=(
  "dSAMPLE_CLI.lifton"
  "dSAMPLE_CLI.braker"
  "dSAMPLE_CLI.aegis_lifton"
  "dSAMPLE_CLI.aegis_braker"
)

COMMON="--offline -l ${LINEAGE} --download_path ${BUSCO_DB_DIR} -c ${BUSCO_CPU} -f --out_path ${BUSCO_DIR}"

# build the command list: one BUSCO run per line (8 total)
CMDS="${BUSCO_DIR}/busco.cmds"
: > "${CMDS}"

for name in "${NAMES[@]}"; do
  echo "busco --in ${ANNOTATION_DIR}/${name}.proteins.fasta -m protein ${COMMON} -o ${name}_protein_busco" >> "${CMDS}"
  echo "busco --in ${ANNOTATION_DIR}/${name}.cds.fasta -m transcriptome ${COMMON} -o ${name}_cds_busco" >> "${CMDS}"
done

parallel -j "${JOBS}" --joblog "${BUSCO_DIR}/busco.joblog" --halt soon,fail=1 < "${CMDS}"

# one-line summary per run
for f in "${BUSCO_DIR}"/*_busco/short_summary.specific.*.txt; do
  printf '%s\t%s\n' "$(basename "$(dirname "$f")")" "$(grep -m1 'C:' "$f" | sed 's/^[[:space:]]*//')"
done > "${BUSCO_DIR}/busco_summary.tsv"