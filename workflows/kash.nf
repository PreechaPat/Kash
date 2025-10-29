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
include { POLISHING } from '../subworkflows/local/polishing'

include { NANOPLOT } from '../modules/local/nanoplot/main'
include { CHOPPER } from '../modules/local/chopper/main'
include { PYCHOPPER } from '../modules/local/pychopper/main'
include { FASTDB } from '../modules/local/fastdb'
include { EMU_ABUNDANCE } from '../modules/local/emu/abundance/main'
include { MARK_PATHOGEN } from '../modules/local/hoshi/mark_pathogen/main'
include { EMU_MERGE } from '../modules/local/emu/combine-outputs/main'
include { HOSHI_REPORT } from '../modules/local/hoshi/report/main'

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

    PRINT_SAMPLESHEET(ch_samplesheet)
    ch_versions = ch_versions.mix(PRINT_SAMPLESHEET.out.versions.first())

    // Prepare database
    if (params.emu_localdatabase) {
        log.info("[KASH] Using local database from: ${params.emu_localdatabase}")
        log.info("[KASH] remote database is skipped")
        ch_db_dir = Channel.value(file(params.emu_localdatabase))
    }
    else {
        ("[KASH] Downloading and preparing database from remote: ${params.emu_database}")
        FASTDB(params.emu_database)
        ch_db_dir = FASTDB.out.db_dir
    }

    // Log quality of each files
    NANOPLOT(ch_samplesheet)

    // Read cleaner
    PREPROCESS_READS(
        ch_samplesheet
    )

    ch_versions = ch_versions.mix(PREPROCESS_READS.out.versions)

    if (!params.skip_classification) {
        EMU_ABUNDANCE(
            PREPROCESS_READS.out.fastq,
            ch_db_dir,
        )
        ch_versions = ch_versions.mix(EMU_ABUNDANCE.out.versions)

        MARK_PATHOGEN(
            EMU_ABUNDANCE.out.report
        )
        ch_versions = ch_versions.mix(MARK_PATHOGEN.out.versions)

        // Pair fastq with correct relative abundance using group
        POLISHING(
            PREPROCESS_READS.out.fastq,
            EMU_ABUNDANCE.out.assignment_report
        )
        ch_versions = ch_versions.mix(POLISHING.out.versions)

        // Merge
        EMU_ABUNDANCE.out.report | map { it[1] } | collect | set { report_ch }
        EMU_MERGE(report_ch)

        // Add info to reports
        EMU_ABUNDANCE.out.report
            | branch { v ->
                sample: v[0].type == "sample"
                negative: v[0].type == "negative"
            }
            | set { split_reports }

        split_reports.sample
            | map { it -> it[1] }
            | collect
            | set { positive_reports }

        HOSHI_REPORT(positive_reports)
    }

    // TODO: Simplify MultiQC

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

    // Collate and save software versions
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'kash_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )
        .set { ch_collated_versions }


    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true,
        )
    )

    // Add files from tools
    ch_multiqc_files = ch_multiqc_files.mix(
        PREPROCESS_READS.out.multiqc.map { item ->
            // log.info("[KASH] PREPROCESS_READS.out.multiqc => ${item}") // Debuging
            item[1]
        }
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
