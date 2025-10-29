process NANANA_CLUSTER {
    tag "${meta.id}"
    label 'process_high'

    container 'ghcr.io/preechapat/nanana:v0.1.2'

    input:
    tuple val(meta), path(fastx)

    output:
    tuple val(meta), path("*_cluster.tsv"), emit: cluster_tsv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def output_name = task.ext.output ?: "${meta.id}_cluster.tsv"
    def threads = task.cpus ?: 1
    """
    # ensure numba use only allow number of amount cache
    export NUMBA_NUM_THREADS="${threads}"
    nanana-cluster \\
        --output ${output_name} \\
        ${args} \\
        ${fastx}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanana-cluster: \$(nanana-cluster --version 2>/dev/null || echo 'unknown')
    END_VERSIONS
    """

    stub:
    def output_name = task.ext.output ?: "${meta.id}_cluster.tsv"
    """
    touch ${output_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanana-cluster: \$(nanana --version 2>&1 | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
