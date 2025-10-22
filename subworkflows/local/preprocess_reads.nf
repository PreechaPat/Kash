// subworkflows/local/preprocess_reads.nf

include { PYCHOPPER } from '../../modules/local/pychopper/main'
include { CHOPPER } from '../../modules/local/chopper/main'
include { PORECHOP_ABI } from '../../modules/local/porechop/abi/main'

process COUNT_FILESIZE {
    tag "${meta.id}"
    label 'process_low'

    input:
    tuple val(meta), path(input_file)

    output:
    tuple val(meta), path(input_file), emit: reads
    path "versions.yml", emit: versions

    script:
    def fileSizeBytes = input_file.size()
    meta = meta + [filesize: fileSizeBytes]
}

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

    ch_multiqc = Channel.empty()
    ch_multiqc = ch_multiqc.mix(PYCHOPPER.out.reporttsv)
    ch_multiqc = ch_multiqc.mix(PYCHOPPER.out.reportbed)
    ch_multiqc = ch_multiqc.mix(PYCHOPPER.out.reportpdf)

    emit:
    fastq = CHOPPER.out.fastq
    versions = ch_versions
    multiqc = ch_multiqc
}
