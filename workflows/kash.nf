/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { getParams } from '../lib/common'

include { MULTIQC } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { paramsSummaryMultiqc } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_kash_pipeline'

// Subworkflow
include { PREPROCESS_READS } from '../subworkflows/local/preprocess_reads'

include { NANOPLOT } from '../modules/local/nanoplot/main'
include { CHOPPER } from '../modules/local/chopper/main'
include { PYCHOPPER } from '../modules/local/pychopper/main'
include { FASTDB } from '../modules/local/fastdb'
include { EMU_ABUNDANCE } from '../modules/local/emu/abundance/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process PRINT_SAMPLESHEET {
    tag "${meta.id}"

    input:
    tuple val(meta), val(fastq)

    output:
    path "versions.yml", emit: versions

    script:
    """
    echo "===== SAMPLE INFO ====="
    echo "META:"
    echo '${meta.toString().replaceAll("'", '"')}'
    echo "FASTQ:"
    echo '${fastq.toString().replaceAll("'", '"')}'
    echo "========================"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nothing: 0.1.0dev
    END_VERSIONS
    """
}

workflow KASH {
    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    def workflow_params = getParams()

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'kash_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )
        .set { ch_collated_versions }

    PRINT_SAMPLESHEET(ch_samplesheet)
    ch_versions = ch_versions.mix(PRINT_SAMPLESHEET.out.versions.first())

    // Doesn't work atm.
    if (params.mode == 'download') {
        FASTDB("emu/emudb/2023-03")
        // Provide a dummy MultiQC report if missing
        def dummy_multiqc_report = file("${workflow.workDir}/dummy_multiqc_report.html")

        // Only create the dummy file if needed
        dummy_multiqc_report.text = "<html><body><h1>Dummy MultiQC Report</h1><p>This is a placeholder.</p></body></html>"
        // Wrap in channel
        // def ch_multiqc_report = Channel.value(dummy_multiqc_report)
        // emit:multiqc_report = ch_multiqc_report // channel: /path/to/multiqc_report.html
        versions = ch_versions
        // channel: [ path(versions.yml) ]
        return null
    }

    // Prepare database
    FASTDB("emu/emudb/2023-03")

    // Log quality of each files
    NANOPLOT(ch_samplesheet)

    // Read cleaner
    PREPROCESS_READS(
        ch_samplesheet,
        Channel.value(params.pychopper_run),
    )

    ch_versions = ch_versions.mix(PREPROCESS_READS.out.versions)


    EMU_ABUNDANCE(
        PREPROCESS_READS.out.fastq,
        FASTDB.out.db_dir,
    )

    // Combine or report individually.

    // TODO: Simplify or just remove these multiqc later.

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config = Channel.fromPath(
        "${projectDir}/assets/multiqc_config.yml",
        checkIfExists: true
    )
    ch_multiqc_custom_config = params.multiqc_config
        ? Channel.fromPath(params.multiqc_config, checkIfExists: true)
        : Channel.empty()
    ch_multiqc_logo = params.multiqc_logo
        ? Channel.fromPath(params.multiqc_logo, checkIfExists: true)
        : Channel.empty()

    summary_params = paramsSummaryMap(
        workflow,
        parameters_schema: "nextflow_schema.json"
    )
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
    )
    ch_multiqc_custom_methods_description = params.multiqc_methods_description
        ? file(params.multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description)
    )

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true,
        )
    )

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        [],
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions = ch_versions // channel: [ path(versions.yml) ]
}
