#!/bin/bash
# Local tests for cdm_gffread: 
set -u
BACTERIA_GTF="Ecoli.gtf"     
EUKARYOTE_GTF="Yeast.gtf"    
BACTERIA_GFF="Ecoli.gff"

IMG=cdm_gffread:test
rm -rf out && mkdir -p out && chmod 777 out

run() {   # run <input folder> <task> [args...]
  local dir=$1; shift
  docker run --rm --user 1000 -v "$PWD/$dir:/in:ro" -v "$PWD/out:/out" "$IMG" "$@" 2>&1 | tail -1
}
exons() {  # count exon rows, gzipped or not
  gzip -dcf "$1" | awk -F'\t' '$3=="exon"' | wc -l | tr -d ' '
}

echo "== 1. Bacterial GTF → normalize_gtf (exons should jump)"
run test_in normalize_gtf OUTPUT_PREFIX=ecoli.normalized "/in/$BACTERIA_GTF"
echo "   exons before: $(exons "test_in/$BACTERIA_GTF")   after: $(exons out/ecoli.normalized.gtf)"

echo "== 2. Bacterial GFF → gff3_to_gtf → normalize_gtf"
run test_in gff3_to_gtf OUTPUT_PREFIX=ecoli_from_gff "/in/$BACTERIA_GFF"
run out normalize_gtf OUTPUT_PREFIX=ecoli_from_gff.normalized /in/ecoli_from_gff.gtf
echo "   exons before: $(exons "test_in/$BACTERIA_GFF")   after: $(exons out/ecoli_from_gff.normalized.gtf)"


echo "== 3. Eukaryotic GTF → normalize_gtf (exons should stay about the same)"
run test_in normalize_gtf OUTPUT_PREFIX=yeast.normalized "/in/$EUKARYOTE_GTF"
echo "   exons before: $(exons "test_in/$EUKARYOTE_GTF")   after: $(exons out/yeast.normalized.gtf)"

echo "== 4. Error check (no file given → should fail with a clear message)"
run test_in normalize_gtf

echo; ls out/
