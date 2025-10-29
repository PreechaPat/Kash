// subworkflows/local/polishing.nf

include { NANANA_CLUSTER } from '../../modules/local/nanana/cluster/main'
include { NANANA_POLISH } from '../../modules/local/nanana/polish/main'

workflow POLISHING {
    take:
    fastx
    taxa_assignment

    main:
    ch_versions = Channel.empty()

    NANANA_CLUSTER(fastx)
    ch_versions = ch_versions.mix(NANANA_CLUSTER.out.versions)

    // ch_clustered_fastx = fastx | join(NANANA_CLUSTER.out.cluster_tsv)
    // ch_ready_for_polish = ch_clustered_fastx.join(taxa_assignment)

    ch_ready_for_polish = fastx
        | join(NANANA_CLUSTER.out.cluster_tsv)
        | join(taxa_assignment)

    NANANA_POLISH(ch_ready_for_polish)
    ch_versions = ch_versions.mix(NANANA_POLISH.out.versions)

    emit:
    csv = NANANA_CLUSTER.out.cluster_tsv
    consensus = NANANA_POLISH.out.consensus
    versions = ch_versions
}
