#!/bin/bash
#PBS -l select=1:ncpus=64:mem=256GB
#PBS -q bix
#PBS -l walltime=240:00:00
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
module load app/Java/21.0.2
module load app/apptainer/1.2.5

#files and directories
WORKDIR="${TOMATO_PATH}"
ANNOT_OUT_DIR="__RESULTS_DIR__"
CUSTOM_CONFIG="/new-home/25086138/my_environments/genepal/custom.config"
PARAMS_YAML="/new-home/25086138/my_environments/genepal/params.yaml"
LIFTOFF_ANNOTATION_CSV="${ANNOT_OUT_DIR}/input_liftoff_annotation.csv"
REF_GFF3="${WORKDIR}/data/reference_data/SL5.0.gff3"
REF_FASTA_INPUT="${WORKDIR}/data/reference_data/SL5.0.fasta"
REF_TAG="reference"
SAMPLE_CSV="${ANNOT_OUT_DIR}/sample_assembly_sheet.csv"
SAMPLE_D03_TAG="sample_d03"
SAMPLE_D05_TAG="sample_d05"
RENAMED_FASTAS_AND_ID_MAPS="${ANNOT_OUT_DIR}/renamed_fastas_and_id_maps"
SAMPLE_D03_INPUT="${WORKDIR}/03/results/09.2.edta_repeat_masking/d03.ragtag.scaffold.chromosomes.fasta"
SAMPLE_D05_INPUT="${WORKDIR}/05/results/09.2.edta_repeat_masking/d05.ragtag.scaffold.chromosomes.fasta"
SAMPLE_D03_PATH="${RENAMED_FASTAS_AND_ID_MAPS}/d03.ragtag.scaffold.chromosomes.renamed.fasta"
SAMPLE_D05_PATH="${RENAMED_FASTAS_AND_ID_MAPS}/d05.ragtag.scaffold.chromosomes.renamed.fasta"
REF_PATH="${RENAMED_FASTAS_AND_ID_MAPS}/SL5.0.renamed.fasta"
REF_ID_MAP="${RENAMED_FASTAS_AND_ID_MAPS}/reference.id_map.tsv"
SAMPLE_D03_ID_MAP="${RENAMED_FASTAS_AND_ID_MAPS}/d03.id_map.tsv"
SAMPLE_D05_ID_MAP="${RENAMED_FASTAS_AND_ID_MAPS}/d05.id_map.tsv"
REPEAT_ANNOTATOR="edta"
EDTA_SENSITIVE="TRUE"
BRAKER_PROTEIN_EVIDENCE="${WORKDIR}/data/orthodb13/Viridiplantae.fa"
BUSCO_LINEAGE="solanales_odb10"
EGGNOG_MAPPER="${WORKDIR}/data/databases/eggnog_db"
EGGNOG_MAPPER_TAX_SCOPE=33090
EMAIL="PBS_EMAIL"
LOGFILE="${ANNOT_OUT_DIR}/genepal.log"

#move into output directory
cd "${ANNOT_OUT_DIR}"

#make renamed_fastas_and_id_maps directory
mkdir -p "${RENAMED_FASTAS_AND_ID_MAPS}"

#singularity cache directory
export NXF_SINGULARITY_CACHEDIR="/new-home/25086138/singularity_cache"

#rename FASTA headers so they pass genepal's FA-LINT check
#usage: rename_fasta_ids in.fasta out.fasta id_map.tsv
rename_fasta_ids () {
  local in="${1}" out="${2}" map="${3}"
  awk -v map="${map}" '
    BEGIN { OFS="\t" }
    /^>/ {
      #original ID without the ">" and without any description
      old = substr($0, 2)
      sub(/[ \t].*/, "", old)
      new = old

      #RagTag chromosomes: 10_RagTag -> Chromosome_10
      if (new ~ /^[0-9]+_RagTag$/) {
        sub(/_RagTag$/, "", new)
        new = "Chromosome_" new
      } else {
        #unplaced contigs: replace anything outside [A-Za-z0-9_] with _
        gsub(/[^A-Za-z0-9_]/, "_", new)
        #IDs must start with a letter
        if (new !~ /^[A-Za-z]/) new = "ctg_" new
      }

      #abort if two headers collapse to the same ID
      if (new in seen) { print "DUPLICATE ID: " new > "/dev/stderr"; exit 1 }
      seen[new] = 1

      #record old -> new mapping, then write the new header
      print old, new > map
      print ">" new
      next
    }
    #sequence lines pass through unchanged
    { print }
  ' "${in}" > "${out}"
}

#rename headers in assemblies
rename_fasta_ids "${REF_FASTA_INPUT}" "${REF_PATH}" "${REF_ID_MAP}"
rename_fasta_ids "${SAMPLE_D03_INPUT}" "${SAMPLE_D03_PATH}" "${SAMPLE_D03_ID_MAP}"
rename_fasta_ids "${SAMPLE_D05_INPUT}" "${SAMPLE_D05_PATH}" "${SAMPLE_D05_ID_MAP}"

#fail early if any renamed header is still invalid (grep -c exits 1 on zero matches, so guard it)
for fasta in "${REF_PATH}" "${SAMPLE_D03_PATH}" "${SAMPLE_D05_PATH}"; do
  n_bad=$(grep '^>' "${fasta}" | grep -vcE '^>[A-Za-z][A-Za-z0-9_]*$' || true)
  if [ "${n_bad}" -ne 0 ]; then
    echo "ERROR: ${n_bad} invalid FASTA IDs remain in ${fasta}" >&2
    exit 1
  fi
done

#make sample csv
printf 'tag,fasta,is_masked\n' > "${SAMPLE_CSV}"
printf '"%s","%s",no\n' "${REF_TAG}" "${REF_PATH}" >> "${SAMPLE_CSV}"
printf '"%s","%s",no\n' "${SAMPLE_D03_TAG}" "${SAMPLE_D03_PATH}" >> "${SAMPLE_CSV}"
printf '"%s","%s",no\n' "${SAMPLE_D05_TAG}" "${SAMPLE_D05_PATH}" >> "${SAMPLE_CSV}"

#make liftoff annotation csv
printf 'fasta,gff3\n' > "${LIFTOFF_ANNOTATION_CSV}"
printf '"%s","%s"' "${REF_FASTA_INPUT}" "${REF_GFF3}" >> "${LIFTOFF_ANNOTATION_CSV}"

#convert EGGNOG_MAPPER_TAX_SCOPE to integer
EGGNOG_MAPPER_TAX_SCOPE_INTEGER=$(("${EGGNOG_MAPPER_TAX_SCOPE}" + 0))

#run genepal
nextflow run plant-food-research-open/genepal \
  -revision 1.0.1 \
  -profile singularity \
  -c "${CUSTOM_CONFIG}" \
  --input "${SAMPLE_CSV}" \
  --email "${EMAIL}" \
  --repeat_annotator "${REPEAT_ANNOTATOR}" \
  --edta_is_sensitive "${EDTA_SENSITIVE}" \
  --busco_lineage_datasets "${BUSCO_LINEAGE}" \
  --protein_evidence "${BRAKER_PROTEIN_EVIDENCE}" \
  --eggnogmapper_db_dir "${EGGNOG_MAPPER}" \
  --eggnogmapper_tax_scope "${EGGNOG_MAPPER_TAX_SCOPE_INTEGER}" \
  --liftoff_annotations "${LIFTOFF_ANNOTATION_CSV}" \
  --outdir "${ANNOT_OUT_DIR}" \
  2>&1 | tee -a "${LOGFILE}"