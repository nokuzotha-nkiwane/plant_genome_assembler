#!/bin/bash
#PBS -l select=1:ncpus=24:mem=40GB
#PBS -q bix
#PBS -l walltime=8:00:00
#PBS -N SAMPLE_CLI_GENE_DENSITY_PBS
#PBS -o OUTPUT_FILE_PBS
#PBS -e ERROR_FILE_PBS
#PBS -m be
#PBS -M PBS_EMAIL

#kill execution at first error
set -euxo pipefail

#for evaluating variables in ~/.pbsrc
source ~/.pbsrc

#resource allocation: one single-threaded awk job per annotation
JOBS=5

#directories and files
WORKDIR="${TOMATO_PATH}/SAMPLE_CLI"
ALL_RESULTS_DIR="${WORKDIR}/results"
DENSITY_DIR="__RESULTS_DIR__"
INPUT_FASTA="${ALL_RESULTS_DIR}/07.1.agp_correct/ragtag_output/dSAMPLE_CLI.ragtag.scaffold.chromosomes.fasta"
REF_FASTA="${TOMATO_PATH}/data/reference_data/SL5.0.fasta"
REF_GFF3="${TOMATO_PATH}/data/reference_data/SL5.0.gff3"
LIFTON_GFF3="${ALL_RESULTS_DIR}/11.lifton/dSAMPLE_CLI.ragtag.scaffold.chromosomes.lifton.gff3"
BRAKER_GFF3="${ALL_RESULTS_DIR}/10.BRAKER/output/dSAMPLE_CLI/results/braker.gff3"
AEGIS_LIFTON_GFF3="${ALL_RESULTS_DIR}/12.aegis/aegis_merge/liftoff/dSAMPLE_CLI_consolidated_LIFTON_first.gff3"
AEGIS_BRAKER_GFF3="${ALL_RESULTS_DIR}/12.aegis/aegis_merge/braker/dSAMPLE_CLI_consolidated_BRAKER_first.gff3"

cd "${DENSITY_DIR}"

# awk: chromosome lengths from a FASTA (name <tab> length)
cat > fasta_lengths.awk << 'EOF'
/^>/ { if (name != "") print name "\t" len; name = substr($1, 2); len = 0; next }
{ len += length($0) }
END { if (name != "") print name "\t" len }
EOF

# awk: count genes per chromosome and report density
# usage: awk -F'\t' -f gene_density.awk lengths.tsv annotation.gff3
cat > gene_density.awk << 'EOF'
FNR == NR { len[$1] = $2; order[++n] = $1; next }
/^#/ { next }
$3 == "gene" && ($1 in len) { cnt[$1]++ }
END {
  print "chromosome\tgene_count\tlength_bp\tgenes_per_Mb"
  for (i = 1; i <= n; i++) {
    c = order[i]
    g = cnt[c] + 0
    printf "%s\t%d\t%d\t%.2f\n", c, g, len[c], g / (len[c] / 1e6)
    tg += g; tl += len[c]
  }
  printf "genome_total\t%d\t%d\t%.2f\n", tg, tl, tg / (tl / 1e6)
}
EOF

# Stage 1: chromosome lengths for both FASTAs (in parallel)
parallel -j 2 --joblog "${DENSITY_DIR}/stage1.joblog" --halt soon,fail=1 \
  "awk -f fasta_lengths.awk {1} > {2}" ::: \
  "${INPUT_FASTA}" "${REF_FASTA}" :::+ \
  "${DENSITY_DIR}/sample.lengths.tsv" "${DENSITY_DIR}/SL5.0.lengths.tsv"

# manifest: name <tab> gff3 <tab> lengths file
MANIFEST="${DENSITY_DIR}/manifest.tsv"
printf '%s\t%s\t%s\n' \
  "SL5.0"                    "${REF_GFF3}"          "${DENSITY_DIR}/SL5.0.lengths.tsv" \
  "dSAMPLE_CLI.lifton"       "${LIFTON_GFF3}"       "${DENSITY_DIR}/sample.lengths.tsv" \
  "dSAMPLE_CLI.braker"       "${BRAKER_GFF3}"       "${DENSITY_DIR}/sample.lengths.tsv" \
  "dSAMPLE_CLI.aegis_lifton" "${AEGIS_LIFTON_GFF3}" "${DENSITY_DIR}/sample.lengths.tsv" \
  "dSAMPLE_CLI.aegis_braker" "${AEGIS_BRAKER_GFF3}" "${DENSITY_DIR}/sample.lengths.tsv" > "${MANIFEST}"

# Stage 2: gene density per annotation (5 independent jobs)
parallel --colsep '\t' -j "${JOBS}" -a "${MANIFEST}" \
  --joblog "${DENSITY_DIR}/stage2.joblog" --halt soon,fail=1 \
  "awk -F'\t' -f gene_density.awk {3} {2} > ${DENSITY_DIR}/{1}.gene_density.tsv"

# combined table with an annotation column
{
  printf 'annotation\tchromosome\tgene_count\tlength_bp\tgenes_per_Mb\n'
  for f in "${DENSITY_DIR}"/*.gene_density.tsv; do
    n=$(basename "${f}" .gene_density.tsv)
    tail -n +2 "${f}" | awk -v n="${n}" 'BEGIN{OFS="\t"} {print n, $0}'
  done
} > "${DENSITY_DIR}/all_annotations.gene_density.tsv"