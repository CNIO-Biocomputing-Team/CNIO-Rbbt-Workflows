Functionalities regarding genomic sequence analysis.

It supports multiple organisms. The format of the *organism* input is the
organism short code (Hsa for *H*omo *sa*piens, or Mmu for *M*us *mu*sculus)
optionally followed by the data of the build. For example, *Hsa/jan2013* for a
recent build or *Hsa/may2009* for the hg18 build.

The *watson* input is used to specify if the variants are described in
reference to the watson or forward strand, or in reference to the strand that
holds the overlapping gene. Using the wrong convention may make some mutations
coincide with the reference. The *is_watson* method can take a guess by
checking this criteria.
