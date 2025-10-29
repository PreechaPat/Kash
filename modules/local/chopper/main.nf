process CHOPPER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/chopper:0.9.0--hdcf5f25_0'
        : 'biocontainers/chopper:0.9.0--hdcf5f25_0'}"

    input:
    tuple val(meta), path(fastq)
    path fasta

    output:
    tuple val(meta), path("*.fastq.gz"), emit: fastq
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def fasta_filtering = fasta.name != "NONONO" ? "--contam ${fasta}" : ""

    if ("${fastq}" == "${prefix}.fastq.gz") {
        error("Input and output names are the same, set prefix in module configuration to disambiguate!")
    }
    """
    zcat ${fastq} | \\
    chopper \\
        --threads ${task.cpus} \\
        ${fasta_filtering} \\
        --minlength ${params.chopper_minlength} \\
        --maxlength ${params.chopper_maxlength} \\
        -q ${params.chopper_minq} \\
        ${args} | \\
    gzip > ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chopper: \$(chopper --version 2>&1 | cut -d ' ' -f 2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo | gzip > ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        chopper: \$(chopper --version 2>&1 | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
