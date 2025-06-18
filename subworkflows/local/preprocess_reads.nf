// subworkflows/local/preprocess_reads.nf

include { PYCHOPPER } from '../../modules/local/pychopper/main'
include { CHOPPER } from '../../modules/local/chopper/main'
include { PORECHOP_ABI } from '../../modules/local/porechop/abi/main'

workflow PREPROCESS_READS {
    take:
    samplesheet

    main:
    ch_versions = Channel.empty()

    // Run pychoper or porechop_abi
    if (params.pychopper_run) {
        PYCHOPPER(samplesheet)
        ch_fastq_input = PYCHOPPER.out.fastq
        ch_versions = ch_versions.mix(PYCHOPPER.out.versions)
    }
    else if (params.porechop_run) {
        PORECHOP_ABI(samplesheet, file("NONONO", checkIfExists: false))
        ch_fastq_input = PORECHOP_ABI.out.reads
        ch_versions = ch_versions.mix(PORECHOP_ABI.out.versions)
    }
    else {
        ch_fastq_input = samplesheet
    }

    CHOPPER(
        ch_fastq_input,
        file("NONONO", checkIfExists: false),
    )
    ch_versions = ch_versions.mix(CHOPPER.out.versions)

    emit:
    fastq = CHOPPER.out.fastq
    versions = ch_versions
}
