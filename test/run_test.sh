#!/bin/bash
# Local tests for cdm_gffread. Run from the folder that holds test_in/:
#   bash run_test.sh            outputs go to a temporary folder, deleted at the end
#   KEEP=1 bash run_test.sh  ->  keep the outputs (the folder is printed at the end)
set -u
BACTERIA_GTF="Ecoli.gtf"
EUKARYOTE_GTF="Yeast.gtf"
BACTERIA_GFF="Ecoli.gff"
 
IMG=cdm_gffread:test
OUT="$(mktemp -d)"                       # e.g. /var/folders/.../tmp.AbC123
chmod 777 "$OUT"                         # the container runs as uid 1000
if [[ "${KEEP:-0}" == 1 ]]; then
  trap 'echo; echo "outputs kept in: $OUT"' EXIT
else
  trap 'rm -rf "$OUT"' EXIT              # deleted even if the script fails or you press Ctrl-C
fi
 
run() {   # run <input folder> <task> [args...]
  local dir=$1; shift
  docker run --rm --user 1000 -v "$dir:/in:ro" -v "$OUT:/out" "$IMG" "$@" 2>&1 | tail -1
}
exons() {  # count exon rows, gzipped or not
  gzip -dcf "$1" 2>/dev/null | awk -F'\t' '$3=="exon"' | wc -l | tr -d ' '
}
 
echo "== 1. Bacterial GTF → normalize_gtf (exons should jump)"
run "$PWD/test_in" normalize_gtf OUTPUT_PREFIX=ecoli.normalized "/in/$BACTERIA_GTF"
echo "   exons before: $(exons "test_in/$BACTERIA_GTF")   after: $(exons "$OUT/ecoli.normalized.gtf")"
 
echo "== 2. Bacterial GFF → gff3_to_gtf → normalize_gtf"
run "$PWD/test_in" gff3_to_gtf "/in/$BACTERIA_GFF"
run "$OUT" normalize_gtf OUTPUT_PREFIX=ecoli_from_gff.normalized /in/converted.gtf
echo "   exons before: $(exons "test_in/$BACTERIA_GFF")   after: $(exons "$OUT/ecoli_from_gff.normalized.gtf")"
 
echo "== 3. Eukaryotic GTF → normalize_gtf (exons should stay about the same)"
run "$PWD/test_in" normalize_gtf OUTPUT_PREFIX=yeast.normalized "/in/$EUKARYOTE_GTF"
echo "   exons before: $(exons "test_in/$EUKARYOTE_GTF")   after: $(exons "$OUT/yeast.normalized.gtf")"
 
echo "== 4. Error check (no file given → should fail with a clear message)"
run "$PWD/test_in" normalize_gtf
 
echo; echo "outputs: $(ls "$OUT" | tr '\n' ' ')"