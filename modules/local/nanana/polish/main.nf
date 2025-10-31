process NANANA_POLISH {
    tag "${meta.id}"

    label 'process_high'

    container 'ghcr.io/preechapat/nanana:v0.1.3'

    input:
    tuple val(meta), path(fastx), path(cluster_tsv), path(assignment_tsv)

    output:
    tuple val(meta), path("${meta.id}/output/consensus_c*.fasta"), path("${meta.id}/output/cluster_*.fastq.gz"), emit: consensus, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    nanana-polish \\
        --tsv ${cluster_tsv} \\
        --output-root ${meta.id} \\
        --keep-fastq \\
        --threads ${task.cpus} \\
        ${args} \\
        ${fastx}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanana-polish: \$(nanana-polish --version 2>/dev/null || echo 'unknown')
    END_VERSIONS
    """

    stub:
    def coutput_name = task.ext.output ?: "${meta.id}/output/consensus_c0.fasta"
    def fqoutput_name = task.ext.output ?: "${meta.id}/output/cluster_c00.fastq.gz"
    """

    mkdir -p ${meta.id}/output/
    touch ${coutput_name}
    touch ${fqoutput_name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanana-polish: \$(nanana --version 2>&1 | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
