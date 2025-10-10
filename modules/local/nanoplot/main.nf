process NANOPLOT {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/96/9633ba7d2adf5e17e7d219d60efebb1d1e76cbea6e3f7440320f11cc99da37ac/data'
        : 'community.wave.seqera.io/library/nanoplot:1.44.1--e754907b17cfacc2'}"

    input:
    tuple val(meta), path(ontfile)

    output:
    tuple val(meta), path("nanoplot_${meta.id}/*.html"), emit: html
    tuple val(meta), path("nanoplot_${meta.id}/*.png"), optional: true, emit: png
    tuple val(meta), path("nanoplot_${meta.id}/*.txt"), emit: txt
    tuple val(meta), path("nanoplot_${meta.id}/*.log"), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def outdir = "nanoplot_${meta.id}"
    // You can change this logic if needed
    def input_file = "${ontfile}".endsWith(".fastq.gz") || "${ontfile}".endsWith(".fq.gz")
        ? "--fastq ${ontfile}"
        : "${ontfile}".endsWith(".txt") ? "--summary ${ontfile}" : ''
    """
    NanoPlot \\
        ${args} \\
        -t ${task.cpus} \\
        ${input_file} \\
        --outdir ${outdir}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def outdir = "nanoplot_${meta.id}"
    """
    mkdir ${outdir}
    touch ${outdir}/LengthvsQualityScatterPlot_dot.html
    touch ${outdir}/LengthvsQualityScatterPlot_kde.html
    touch ${outdir}/NanoPlot-report.html
    touch ${outdir}/NanoPlot_20240301_1130.log
    touch ${outdir}/NanoStats.txt
    touch ${outdir}/Non_weightedHistogramReadlength.html
    touch ${outdir}/Non_weightedLogTransformed_HistogramReadlength.html
    touch ${outdir}/WeightedHistogramReadlength.html
    touch ${outdir}/WeightedLogTransformed_HistogramReadlength.html
    touch ${outdir}/Yield_By_Length.html


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """
}
