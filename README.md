# cdm_gffread

CTS (CDM Task Service) job wrapper for [gffread](https://github.com/gpertea/gffread), which prepares GTF/GFF3 gene annotations for RNA-seq tools. It runs the two tasks of the WILDS [ww-gffread](https://github.com/getwilds/wilds-wdl-library/tree/main/modules/ww-gffread) module, `normalize_gtf` and `gff3_to_gtf`, with the same commands and output names.

## Container

Wraps the WILDS image [`getwilds/gffread`](https://hub.docker.com/r/getwilds/gffread) (v0.12.7), adding a non-root user and an entrypoint.

Published to `ghcr.io/firstnamehannah/cdm_gffread`.

**Entrypoint:** `gtf_prep` (`gtf_prep.sh`). The first argument is the task:
- `normalize_gtf <input.gtf>`: removes `gene` rows, then runs `gffread -T --force-exons`, so every transcript has exon rows.
- `gff3_to_gtf <input.gff3>`: removes rows with strand `?`, then runs `gffread -T`.
- `gffread <args>`: runs gffread directly.

Each task is two commands (a filter, then gffread). CTS runs a single entrypoint, so the wrapper runs them in order.

**Reference data:** none.

## Usage via CTS

### Example

```python
job = tscli.submit_job(
    "ghcr.io/firstnamehannah/cdm_gffread:0.1.0@sha256:<digest>",
    ["cts/io/<you>/rnaseq/ref/annotation.gtf.gz"],   # one GTF (or GFF3 for gff3_to_gtf)
    "cts/io/<you>/output/gffread/run1",
    cluster="kbase",
    declobber=True,
    output_mount_point="/out",
    args=[
        "normalize_gtf",                 # or "gff3_to_gtf"
        # "OUTPUT_PREFIX=ecoli.normalized",   # optional: output name without .gtf
        tscli.insert_files(),
    ],
    num_containers=1,                    # one input file per job
    cpus=1,
    memory="4GB",
    runtime="PT30M",
)
```

Input files must be in MinIO with CRC64NVME checksums (`aws s3 cp ... --checksum-algorithm CRC64NVME`). Gzipped inputs (`.gtf.gz`, `.gff3.gz`) are read directly.

**GFF3 input.** Run `gff3_to_gtf` first, then `normalize_gtf` on its `converted.gtf`. If a source offers both a GTF and a GFF3, use the GTF.

**Why normalize.** STAR (GeneCounts) and RSeQC only count `exon` rows. NCBI bacterial annotations describe most genes with `CDS` rows only, so without this step those genes silently get zero counts. Eukaryotic GTFs that already have exons come through unchanged. This is important for downstream analysis in an RNA-seq pipeline.

**Why the filters.** These are two gffread 0.12.7 quirks:
- NCBI GTFs put `transcript_id ""` on `gene` rows, and gffread stops with `Error: no valid ID found for GFF record`.
- GFF3 allows strand `?`, which gffread can't parse.

The rows removed are redundant gene rows and non-gene features such as origins of replication.
## Output

- `normalize_gtf` → `normalized.gtf`: every transcript has `exon` rows (`CDS` rows are kept). Use it for BED conversion (RSeQC) and STAR index building.
- `gff3_to_gtf` → `converted.gtf`: the annotation as GTF, input for `normalize_gtf`.

Set `OUTPUT_PREFIX=<name>` after the task to change the output name.

Normalizing keeps only the core attributes (`transcript_id`, `gene_id`, `gene_name`) and drops extras such as `gene_biotype` and `product`. When labeling genes downstream (e.g. DESeq2 results), use the original GTF or `converted.gtf`, not `normalized.gtf`.

The job fails, with a message saying what to fix, if:
- it gets anything other than exactly one input of the right type for the task,
- `normalized.gtf` would have no exon rows,
- `converted.gtf` would be empty.

## Testing locally

```bash
docker build -t cdm_gffread:test .
cd test && ./run_test.sh
```

`run_test.sh` covers the three cases the WILDS module tests, plus one error case:
- a bacterial GTF (exon count should jump),
- a eukaryotic GTF (exon count should stay about the same),
- a bacterial GFF3 (converted, then normalized),
- no input file (should fail with a clear message).
