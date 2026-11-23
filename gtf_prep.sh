#!/bin/bash
# CTS entrypoint for gffread. Runs the two tasks of the WILDS ww-gffread module
# (https://github.com/getwilds/wilds-wdl-library/tree/main/modules/ww-gffread),
# with the same commands, defaults and output names. CTS runs one command per job, and
# each task is two commands (an awk filter, then gffread), so this script picks the task.
#
#   gtf_prep normalize_gtf <input.gtf>     → /out/normalized.gtf
#       Strips `gene` rows (NCBI GTFs have transcript_id "" on them, which gffread 0.12.7
#       rejects with "no valid ID found for GFF record"), then runs
#       gffread -T --force-exons so every transcript has exon features. Needed for
#       bacterial NCBI GTFs (mostly CDS rows), which STAR GeneCounts and RSeQC would
#       otherwise silently skip. Eukaryotic GTFs with exons come through unchanged.
#
#   gtf_prep gff3_to_gtf <input.gff3>      → /out/converted.gtf
#       Strips rows with strand `?` (legal GFF3, but gffread can't parse it; they are not
#       gene/transcript features), then runs gffread -T to write GTF.
#
#   gtf_prep gffread <args...>             runs gffread directly
#
# Settings, as KEY=VALUE arguments after the task name (or environment variables):
#   OUTPUT_PREFIX  output file name without .gtf (module defaults: normalized / converted)
#   OUT_DIR        output folder (default /out, the CTS output mount)
#
# Additions to the module, for CTS: gzipped inputs are accepted, and the job fails if the
# output is empty (normalize_gtf: if it has no exon rows), so a bad annotation stops here
# instead of producing zero counts in later steps.
set -euo pipefail

log() { echo "[gtf_prep] $*" >&2; }
die() { echo "error: $*" >&2; exit 2; }
usage="usage: gtf_prep normalize_gtf <input.gtf> | gtf_prep gff3_to_gtf <input.gff3> | gtf_prep gffread <args>"

task="${1:-}"; shift || true
case "$task" in
    gffread) exec gffread "$@" ;;
    normalize_gtf) default_prefix=normalized ;;
    gff3_to_gtf) default_prefix=converted ;;
    *) echo "$usage" >&2; exit 2 ;;
esac

# KEY=VALUE settings after the task name.
while [[ "${1:-}" =~ ^[A-Z][A-Z0-9_]*= ]]; do export "${1?}"; shift; done
OUT_DIR="${OUT_DIR:-/out}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-$default_prefix}"

# One input file, like the module's tasks.
(( $# == 1 )) || die "$task takes exactly one input file, got $#: $*"
input="$1"
[[ -f "$input" ]] || die "input not found: $input"
name="$(basename "$input")"; name="${name%.gz}"
case "$task:${name,,}" in
    normalize_gtf:*.gtf) ;;
    gff3_to_gtf:*.gff3|gff3_to_gtf:*.gff) ;;
    normalize_gtf:*) die "normalize_gtf needs a .gtf file, got $name (use gff3_to_gtf first for GFF3)" ;;
    *) die "gff3_to_gtf needs a .gff3 or .gff file, got $name" ;;
esac

work="$(mktemp -d "${TMPDIR:-/tmp}/gtf_prep.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$OUT_DIR"
out="$OUT_DIR/$OUTPUT_PREFIX.gtf"

# zcat -f reads both gzipped and plain files.
if [[ $task == normalize_gtf ]]; then
    log "normalize_gtf: $name → $(basename "$out")"
    zcat -f "$input" | awk -F'\t' '/^#/ || $3 != "gene"' > "$work/stripped.gtf"
    gffread "$work/stripped.gtf" -T --force-exons -o "$out"
    n_tx=$(awk -F'\t' '$3 == "transcript"' "$out" | wc -l)
    n_ex=$(awk -F'\t' '$3 == "exon"' "$out" | wc -l)
    (( n_ex > 0 )) || die "no exon features in the output (is $name an annotation GTF?)"
    log "done: $n_tx transcripts, $n_ex exons"
else
    log "gff3_to_gtf: $name → $(basename "$out")"
    zcat -f "$input" | awk -F'\t' '/^#/ || $7 != "?"' > "$work/stripped.gff3"
    gffread "$work/stripped.gff3" -T -o "$out"
    n=$(grep -cv '^#' "$out" || true)
    (( n > 0 )) || die "the converted GTF is empty"
    log "done: $n GTF rows"
fi
