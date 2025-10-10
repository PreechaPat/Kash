process EMU_ABUNDANCE {
    tag "${meta.id}"
    label 'process_high'

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
    tuple val(meta), path("results/${meta.id}/*_emu_alignments.bam"), emit: bamfile, optional: true
    tuple val(meta), path("results/${meta.id}/*.fasta"), emit: unclassified_fa, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def keepbamFlags = params.emu_keepbam ? '--keep-files' : ''
    def readName = reads.getName()
    def readNameTrim = readName.contains('.') ? readName[0..readName.lastIndexOf('.') - 1] : readName
    """
    emu \\
        abundance \\
        ${keepbamFlags} \\
        --keep-counts \\
        --keep-read-assignments \\
        --threads ${task.cpus} \\
        --min-abundance ${params.emu_minabundance} \\
        --db ${db} \\
        --output-dir results/${prefix} \\
        ${reads}

    export THREADS="${task.cpus}"
    export PREFIX="${prefix}"

    cat <<-PYCODEE > script.py
    import os, pysam
    from pathlib import Path

    threads = os.environ.get("THREADS","1")
    root = Path("results") / os.environ["PREFIX"]

    sam = next(root.glob("*_emu_alignments.sam"), None)
    if sam is None:
        raise SystemExit("No *_emu_alignments.sam found")

    bam = sam.with_suffix(".bam")
    with pysam.AlignmentFile(sam, "r") as ih, pysam.AlignmentFile(bam, "wb", header=ih.header) as oh:
        for rec in ih:
            oh.write(rec)

    sorted_bam = bam.with_suffix(".sorted.bam")
    pysam.sort("-@", threads, "-o", str(sorted_bam), str(bam))
    os.replace(sorted_bam, bam)
    pysam.index(str(bam))

    sam.unlink()
    PYCODEE

    if [ "${keepbamFlags}" = "--keep-files" ]; then
      python script.py
    fi

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
    """
    mkdir -p results/${prefix}
    touch results/${prefix}/${reads}_rel-abundance.tsv
    touch results/${prefix}/${reads}_read-asignment-distributions.tsv
    touch results/${prefix}/${reads}_emu_alignments.bam
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emu: \$(echo \$(emu --version 2>&1) | sed 's/^.*emu //; s/Using.*\$//' )
    END_VERSIONS
    """
}
