// subworkflows/local/polishing.nf

include { NANANA_CLUSTER } from '../../modules/local/nanana/cluster/main'

workflow POLISHING {
    take:
    fastx

    main:
    ch_versions = Channel.empty()

    NANANA_CLUSTER(fastx)
    ch_versions = ch_versions.mix(NANANA_CLUSTER.out.versions)

    emit:
    csv = NANANA_CLUSTER.out.csv
    versions = ch_versions
}
