process MARK_PATHOGEN {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pandas:2.2.1'
        : 'biocontainers/pandas:2.2.1'}"

    input:
    tuple val(meta), path(emu_report)

    output:
    tuple val(meta), path("*.tsv"), emit: report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def basename = meta.id
    def output_name = meta.id
    def output_suffix = task.ext.output_suffix ?: "pathogens"
    def output_file = "${output_name}_${output_suffix}.tsv"
    """
    mkdir -p results/${prefix}

    python "${projectDir}/bin/mark_pathogen.py" ${args} \\
        "${emu_report}" \\
        --output "results/${prefix}/${output_file}"
    cp "results/${prefix}/${output_file}" "${output_file}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | awk '{print \$2}')
        mark_pathogen: project-bin
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def output_name = meta.id
    def output_suffix = task.ext.output_suffix ?: "pathogens"
    def output_file = "${output_name}_${output_suffix}.tsv"
    """
    mkdir -p results/${prefix}
    touch "${output_file}"
    cp "${output_file}" "results/${prefix}/${output_file}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | awk '{print \$2}')
        mark_pathogen: project-bin
    END_VERSIONS
    """
}
