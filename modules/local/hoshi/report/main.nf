process HOSHI_REPORT {

    label 'process_low'

    container 'ghcr.io/preechapat/hoshi:v0.1.0'

    input:
    path emu_positive_reports

    output:
    path ("output.html"), emit: html_report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """

    hoshi-html_report ${emu_positive_reports} -o output.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hoshi: \$(hoshi --version 2>/dev/null || echo "UNKNOWN")
    END_VERSIONS
    """

    stub:
    """

    touch output.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | awk '{print \$2}')
        mark_pathogen: project-bin
    END_VERSIONS
    """
}
