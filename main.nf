#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PreechaPat/Kash
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/PreechaPat/Kash
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { KASH } from './workflows/kash'
include { FASTDB } from './modules/local/fastdb'

include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_kash_pipeline'
include { PIPELINE_COMPLETION } from './subworkflows/local/utils_nfcore_kash_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    //
    // SUBWORKFLOW: Run initialisation tasks
    //

    //
    // WORKFLOW: Run main workflow
    //
    if (params.mode == 'download') {
        log.info("Download only")
        FASTDB(params.emu_database)
    }
    else if (params.mode == 'init') {
        def templatePath = file("${projectDir}/assets/config_template.conf")
        def targetPath = workflow.launchDir.resolve('nextflow.config')

        if (!java.nio.file.Files.exists(templatePath)) {
            log.error("Missing config template at ${templatePath}")
            System.exit(1)
        }

        if (java.nio.file.Files.exists(targetPath)) {
            log.warn("nextflow.config already exists at ${targetPath}; skipping creation")
        }
        else {
            java.nio.file.Files.copy(templatePath, targetPath)
            log.info("Created nextflow.config at ${targetPath}")
        }
    }
    else {
        log.info("Initialize main pipeline")
        def rootConfig = file("${System.getenv('HOME')}/.kash")
        rootConfig.mkdirs()
        PIPELINE_INITIALISATION(
            params.version,
            params.validate_params,
            params.monochrome_logs,
            args,
            params.outdir,
            params.input,
        )
        log.info("Starting pipeline")
        KASH(
            PIPELINE_INITIALISATION.out.samplesheet
        )
        //
        // SUBWORKFLOW: Run completion tasks
        //
        PIPELINE_COMPLETION(
            params.email,
            params.email_on_fail,
            params.plaintext_email,
            params.outdir,
            params.monochrome_logs,
            KASH.out.multiqc_report,
        )
    }
}
