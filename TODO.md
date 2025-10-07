## Publishable
1. Add clustering and polishing (automated)
1.1 Instead of automatigically convert thing, maybe assigned some confidence? This require me to check 16s in general.
2.

## Feature
1. Allow to skip a very shallow sample ( maybe lower than 5k at the start and lower than 1k after filtering )
1.1 Look at this for the implementation https://github.com/epi2me-labs/wf-metagenomics/blob/v2.13.0/modules/local/common.nf
2. Logging
3. Allow to set the upperbound ( the amount of reads to use ).
4. Shallow statisics, especially
  4.1 Rarefaction ( so I would know that we should stop)
  4.2 Read stats ( always keep them )
  4.3 Stats at amplification ( read lenght vs amount )

## QOL
1. When combine feature tables, fill 0.0 on empty ( since emu didn't do it )
1.1 Also, rename sample data to exclude .fastq (or maybe write my own combine)
