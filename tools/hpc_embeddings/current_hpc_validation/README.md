# fastEmbedR 0.99.7 release validation

This workflow reruns the principal runtime and correctness benchmark against
one immutable fastEmbedR source tree. It does not relabel historical 0.99.0
results as 0.99.7 results.

The release lock pins:

- fastEmbedR version `0.99.7`;
- source commit `a74ce04633efe324c8137498320816a55b9fff61`;
- a clean package checkout;
- source-archive and package-tarball SHA-256 values;
- the installed `fastEmbedR` shared-library SHA-256;
- the CUDA image SHA-256; and
- the benchmark repository commit.

Every R worker rechecks the installed package version and shared-library hash.
Successful fastEmbedR rows record requested and observed backends. The final
gate rejects mixed identities and any backend mismatch.

## Synchronize without submitting jobs

From a clean clone of this benchmark repository on the Mac with the HPC mirror
mounted:

```bash
HPC_ROOT=/Users/stefano/HPC-firenze/NN \
FASTEMBEDR_PACKAGE_ROOT=/Users/stefano/Documents/umap \
bash tools/hpc_embeddings/current_hpc_validation/sync_current_validation_to_hpc.sh
```

This copies the validation scripts and a detached checkout of the locked
fastEmbedR commit to:

```text
/scratch/firenze/NN/current_fastembedr_validation
```

No Slurm job is submitted by the synchronization script.

## Submit on the HPC

```bash
cd /scratch/firenze/NN
bash current_fastembedr_validation/submit_current_validation_hpc.sh
```

The submission order is:

1. build and install the locked package into an isolated R library;
2. run CPU and CUDA benchmarks only after installation succeeds; and
3. run the identity gate only after both benchmark jobs succeed.

Results are written beneath a new
`/scratch/firenze/NN/fastEmbedR-results/current_<timestamp>` directory. A run
validates 0.99.7 only when `release_identity_validation.csv` exists and reports
`identity_validated`.

The benchmark includes complete matrix-input and precomputed-KNN openTSNE and
fuzzy/binary UMAP routes, reference R/Python methods, three seeds, total
runtime, memory, trustworthiness, neighborhood preservation, label accuracy,
t-SNE KL divergence, affinity/graph agreement, stability, and backend
agreement. Historical tables must remain labeled 0.99.0 until this rerun is
complete and the generated manuscript tables are rebuilt from the locked
result directory.
