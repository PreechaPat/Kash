process NANANA_CLUSTER {
    tag "${meta.id}"
    label 'process_high'

    container 'ghcr.io/preechapat/nanana:v0.1.0'
    containerOptions '-u 0:0'

    input:
    tuple val(meta), path(fastx)

    output:
    tuple val(meta), path("*.csv"), emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def output_name = task.ext.output ?: "${meta.id}.csv"
    def threads = task.cpus ?: 1
    """
    # // TODO: container option (-u 0:0) is temporary fixed since numba caching at the python's import location...
    # // but since nextflow run as non-root, numba couldn't cache it without this.
    # // More permanent fix is to make tmp folder in the image itself...

    export NUMBA_NUM_THREADS="${threads}"
    nanana-cluster \\
        --output ${output_name} \\
        ${args} \\
        ${fastx}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanana-cluster: \$(nanana-cluster --version 2>/dev/null || echo 'v0.1.0')
    END_VERSIONS
    """

    stub:
    def output_name = task.ext.output ?: "${meta.id}.csv"
    """
    touch ${output_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanana-cluster: 'v0.1.0'
    END_VERSIONS
    """
}
