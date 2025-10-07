#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    yumyai/kash
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/yumyai/kash
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
        log.info("Init config")
    }
    else {
        PIPELINE_INITIALISATION(
            params.version,
            params.validate_params,
            params.monochrome_logs,
            args,
            params.outdir,
            params.input,
        )
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
