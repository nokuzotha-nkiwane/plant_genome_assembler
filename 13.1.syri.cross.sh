 #!/bin/bash
#PBS -l select=1:ncpus=16:mem=30GB
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
module load app/Java/21.0.2
module load app/apptainer/1.2.5

#files and directories
WORKDIR="${TOMATO_PATH}"
PLOTSV_OUT_DIR="__RESULTS_DIR__"
CUSTOM_CONFIG="/new-home/25086138/my_environments/nf-plotsv/custom.config"
PARAMS_YAML="/new-home/25086138/my_environments/nf-plotsv/parameters.yml"
PLOTSV="/new-home/25086138/my_environments/nf-plotsv"
SAMPLE_CSV="${PLOTSV_OUT_DIR}/sample_assembly_sheet.csv"
REF_FASTA_INPUT="${WORKDIR}/data/reference_data/SL5.0.fasta"
REF_TAG="reference"
SAMPLE_D03_TAG="sample_d03"
SAMPLE_D05_TAG="sample_d05"
RENAMED_FASTAS_AND_ID_MAPS="${PLOTSV_OUT_DIR}/renamed_fastas_and_id_maps"
SAMPLE_D03_INPUT="${WORKDIR}/03/results/05.2.ragtag_scaffold/f15000_d500000/d03.f15000_d500000.ragtag.scaffold.fasta"
SAMPLE_D05_INPUT="${WORKDIR}/05/results/05.2.ragtag_scaffold/f15000_d500000/d05.f15000_d500000.ragtag.scaffold.fasta"
SAMPLE_D03_PATH="${RENAMED_FASTAS_AND_ID_MAPS}/d03.ragtag.scaffold.chromosomes.renamed.fasta"
SAMPLE_D05_PATH="${RENAMED_FASTAS_AND_ID_MAPS}/d05.ragtag.scaffold.chromosomes.renamed.fasta"
REF_PATH="${RENAMED_FASTAS_AND_ID_MAPS}/SL5.0.renamed.fasta"
REF_ID_MAP="${RENAMED_FASTAS_AND_ID_MAPS}/reference.id_map.tsv"
SAMPLE_D03_ID_MAP="${RENAMED_FASTAS_AND_ID_MAPS}/d03.id_map.tsv"
SAMPLE_D05_ID_MAP="${RENAMED_FASTAS_AND_ID_MAPS}/d05.id_map.tsv"
LOGFILE="${PLOTSV_OUT_DIR}/plotsv.log"

#move into output directory
cd "${PLOTSV_OUT_DIR}"
mkdir -p "${RENAMED_FASTAS_AND_ID_MAPS}"

#singularity cache directory
export NXF_APPTAINER_CACHEDIR="/new-home/25086138/singularity_cache"

#rename FASTA headers so they pass nf-plotsv's FA-LINT check
#usage: rename_fasta_ids in.fasta out.fasta id_map.tsv
rename_fasta_ids () {
  (
    local in="${1}" out="${2}" map="${3}" tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "${tmpdir}"' EXIT

    awk -v map="${map}" -v tmpdir="${tmpdir}" '
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
        #reference chromosomes: bare numbers 1, 2, 3 -> Chromosome_1, Chromosome_2, ...
        } else if (new ~ /^[0-9]+$/) {
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

        #record old -> new mapping and route chromosomes to sortable buckets
        print old, new > map
        if (new ~ /^Chromosome_([0-9]+)$/) {
          target = tmpdir "/" new ".fasta"
        } else {
          target = tmpdir "/other.fasta"
        }
        print ">" new >> target
        next
      }
      #sequence lines pass through unchanged
      { print >> target }
    ' "${in}"

    : > "${out}"
    for chromosome in {1..12}; do
      [[ -f "${tmpdir}/Chromosome_${chromosome}.fasta" ]] && cat "${tmpdir}/Chromosome_${chromosome}.fasta" >> "${out}"
    done
    if [[ -f "${tmpdir}/Chromosome_0.fasta" ]]; then
      cat "${tmpdir}/Chromosome_0.fasta" >> "${out}"
    fi
    if [[ -f "${tmpdir}/other.fasta" ]]; then
      cat "${tmpdir}/other.fasta" >> "${out}"
    fi
  )
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
printf 'name,fasta\n' > "${SAMPLE_CSV}"
printf '%s,%s\n' "${REF_TAG}" "${REF_PATH}" >> "${SAMPLE_CSV}"
printf '%s,%s\n' "${SAMPLE_D03_TAG}" "${SAMPLE_D03_PATH}" >> "${SAMPLE_CSV}"
printf '%s,%s\n' "${SAMPLE_D05_TAG}" "${SAMPLE_D05_PATH}" >> "${SAMPLE_CSV}"

nextflow run "${PLOTSV}" -c "${CUSTOM_CONFIG}" -profile local,apptainer \
  -params-file "${PARAMS_YAML}" --samplesheet "${SAMPLE_CSV}" --pairwise 2>&1 | tee -a "${LOGFILE}"