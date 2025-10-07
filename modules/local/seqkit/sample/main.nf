process SEQKIT_SAMPLE {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/seqkit:2.6.1--h9ee0642_0'
        : 'biocontainers/seqkit:2.6.1--h9ee0642_0'}"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta)
    path ("*.fasta.gz"), emit: fasta
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Prefer explicit args via task.ext.args. If not provided, default to sample 1000 reads reproducibly.
    def args = task.ext.args ?: '-n 1000 --rand-seed 1'
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqkit sample ${args} ${fasta} | gzip > ${prefix}.fasta.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$(seqkit version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo '>stub' > ${prefix}.fasta && echo 'ACGT' >> ${prefix}.fasta
    gzip ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: v2.6.1
    END_VERSIONS
    """
}
