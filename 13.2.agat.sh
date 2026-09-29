#!/bin/bash
#PBS -l select=1:ncpus=24:mem=40GB
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

#resource allocation: AGAT jobs are single-threaded, so this is the number of
#concurrent jobs. Keep modest because AGAT loads whole GFFs into RAM.
JOBS=8

#load modules
module load app/agat/1.4.1
module load app/parallel/parallel

# directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
ANNOTATION_DIR="__RESULTS_DIR__"
INPUT_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
REF_GFF3="${TOMATO_PATH}/data/reference_data/SL5.0.gff3"
LIFTON_GFF3="${ALL_RESULTS_DIR}/11.lifton/dSAMPLE_CLI.ragtag.scaffold.chromosomes.lifton.gff3"
BRAKER_GFF3="${ALL_RESULTS_DIR}/10.BRAKER/output/dSAMPLE_CLI/results/braker.gff3"
AEGIS_LIFTON_GFF3="${ALL_RESULTS_DIR}/12.aegis/aegis_merge/liftoff/dSAMPLE_CLI_consolidated_LIFTON_first.gff3"
AEGIS_BRAKER_GFF3="${ALL_RESULTS_DIR}/12.aegis/aegis_merge/braker/dSAMPLE_CLI_consolidated_BRAKER_first.gff3"

#make output directory
mkdir -p "${ANNOTATION_DIR}"
cd "${ANNOTATION_DIR}"

# manifest: basename <tab> gff3 path
MANIFEST="${ANNOTATION_DIR}/manifest.tsv"
printf '%s\t%s\n' \
  "SL5.0"                    "${REF_GFF3}" \
  "dSAMPLE_CLI.lifton"       "${LIFTON_GFF3}" \
  "dSAMPLE_CLI.braker"       "${BRAKER_GFF3}" \
  "dSAMPLE_CLI.aegis_lifton" "${AEGIS_LIFTON_GFF3}" \
  "dSAMPLE_CLI.aegis_braker" "${AEGIS_BRAKER_GFF3}" > "${MANIFEST}"

# build the list of independent commands (one per line)
CMDS="${ANNOTATION_DIR}/stage1.cmds"
: > "${CMDS}"
while IFS=$'\t' read -r name gff; do
  # syntax check / duplicate ID fix
  echo "agat_convert_sp_gxf2gxf.pl --gff ${gff} -o ${ANNOTATION_DIR}/${name}.agat.gff3" >> "${CMDS}"
  # genic content statistics
  echo "agat_sp_statistics.pl --gff ${gff} -o ${ANNOTATION_DIR}/${name}.gene_stats.txt" >> "${CMDS}"
  # sequences are extracted for the annotations only, not the reference
  if [[ "${name}" != "SL5.0" ]]; then
    echo "agat_sp_extract_sequences.pl --gff ${gff} -f ${INPUT_FASTA} -t cds -o ${ANNOTATION_DIR}/${name}.cds.fasta" >> "${CMDS}"
    echo "agat_sp_extract_sequences.pl --gff ${gff} -f ${INPUT_FASTA} -t cds -p -o ${ANNOTATION_DIR}/${name}.proteins.fasta" >> "${CMDS}"
  fi
done < "${MANIFEST}"

# Stage 1: 14 independent jobs (5 convert + 5 stats + 4 cds + 4 protein = 18)
parallel -j "${JOBS}" --joblog "${ANNOTATION_DIR}/stage1.joblog" --halt soon,fail=1 < "${CMDS}"

# Stage 2: stats on the AGAT-cleaned GFFs (needs the stage 1 conversions)
cut -f1 "${MANIFEST}" | parallel -j "${JOBS}" \
  --joblog "${ANNOTATION_DIR}/stage2.joblog" --halt soon,fail=1 \
  "agat_sp_statistics.pl --gff ${ANNOTATION_DIR}/{}.agat.gff3 -o ${ANNOTATION_DIR}/{}.agat.gene_stats.txt"