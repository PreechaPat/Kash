// subworkflows/local/preprocess_reads.nf

include { PYCHOPPER } from '../../modules/local/pychopper/main'
include { CHOPPER } from '../../modules/local/chopper/main'

workflow PREPROCESS_READS {
    take:
    samplesheet
    run_pychopper

    main:
    ch_versions = Channel.empty()

    // Conditional execution of pychopper
    if (run_pychopper) {
        PYCHOPPER(samplesheet)
        ch_fastq_input = PYCHOPPER.out.fastq
        ch_versions = ch_versions.mix(PYCHOPPER.out.versions)
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
