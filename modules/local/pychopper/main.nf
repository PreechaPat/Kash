process PYCHOPPER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pychopper:2.7.10--pyhdfd78af_0'
        : 'biocontainers/pychopper:2.7.10--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(fastq)

    output:
    tuple val(meta), path("*.out.fastq.gz"), emit: fastq
    tuple val(meta), path("*_report.pdf"), emit: reportpdf, optional: true
    tuple val(meta), path("*_report.tsv"), emit: reporttsv, optional: true
    tuple val(meta), path("*_scores.bed"), emit: reportbed, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def PYCHOPPER_VERSION = '2.7.10'
    // Check if both fw and bc parameters are defined
    def use_custom_primer = params.pychopper_fwdprimer && params.pychopper_revprimer
    // Define how to run, with or without primer
    def running = use_custom_primer
        ? """
        echo '>MySSP' >> primers.fasta
        echo ${params.pychopper_fwdprimer} >> primers.fasta
        echo '>MyVNP' >> primers.fasta
        echo ${params.pychopper_revprimer} >> primers.fasta
        echo '+:MySSP,-MyVNP|-:MyVNP,-MySSP' >> primers.config
        pychopper \\
            ${args} \\
            -r ${prefix}_report.pdf \\
            -S ${prefix}_report.tsv \\
            -w ${prefix}_rescue.fq \\
            -u ${prefix}_unclassified.fq \\
            -A ${prefix}_scores.bed \\
            -m edlib -b primers.fasta -c primers.config \\
            -t ${task.cpus} \\
            ${fastq} > ${prefix}.out.fastq"""
        : """
    pychopper \\
        ${args} \\
        -t ${task.cpus} \\
        ${fastq} > ${prefix}.out.fastq"""

    """
    ${running}

    gzip -f ${prefix}.out.fastq > ${prefix}.out.fastq.gz
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pychopper: ${PYCHOPPER_VERSION} (hard coded- check container used for this module)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.out.fastq
    gzip ${prefix}.out.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pychopper: 2.7.10 (hard coded- check container used for this module)
    END_VERSIONS
    """
}
