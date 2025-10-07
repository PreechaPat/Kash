process EMU_ABUNDANCE {
    tag "${meta.id}"
    label 'process_high_cpu'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/emu:3.5.1--hdfd78af_0'
        : 'biocontainers/emu:3.5.1--hdfd78af_0'}"

    input:
    tuple val(meta), path(reads)
    path db

    output:
    tuple val(meta), path("results/${meta.id}/*_rel-abundance.tsv"), emit: report
    tuple val(meta), path("results/${meta.id}/*read-assignment-distributions.tsv"), emit: assignment_report, optional: true
    tuple val(meta), path("results/${meta.id}/*_emu_alignments.sam"), emit: samfile, optional: true
    tuple val(meta), path("results/${meta.id}/*.fasta"), emit: unclassified_fa, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def verbosityFlags = params.emu_verbose ? '--keep-files' : ''
    def readName = reads.getName()
    def readNameTrim = readName.contains('.') ? readName[0..readName.lastIndexOf('.') - 1] : readName
    """
    emu \\
        abundance \\
        ${verbosityFlags} \\
        --keep-counts \\
        --keep-read-assignments \\
        --threads ${task.cpus} \\
        --min-abundance ${params.emu_minabundance} \\
        --db ${db} \\
        --output-dir results/${prefix} \\
        ${reads}

    # Overwrite the standard file using threshold file.
    if [ -f "results/${prefix}/${readNameTrim}_rel-abundance-threshold-${params.emu_minabundance}.tsv" ]; then
        cp "results/${prefix}/${readNameTrim}_rel-abundance-threshold-${params.emu_minabundance}.tsv" "results/${prefix}/${readNameTrim}_rel-abundance.tsv"
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emu: \$(echo \$(emu --version 2>&1) | sed 's/^.*emu //; s/Using.*\$//' )
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def verbose = task.ext.verbose ?: false
    def verbosityFlags = verbose ? '--keep-files' : ''
    """
    mkdir -p results
    touch results/${prefix}/${reads}_rel-abundance.tsv
    touch results/${prefix}/${reads}_read-asignment-distributions.tsv
    touch results/${prefix}/${reads}_emu_alignments.sam
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emu: \$(echo \$(emu --version 2>&1) | sed 's/^.*emu //; s/Using.*\$//' )
    END_VERSIONS
    """
}
