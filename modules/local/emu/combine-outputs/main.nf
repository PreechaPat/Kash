process EMU_MERGE {

    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/emu:3.5.1--hdfd78af_0'
        : 'biocontainers/emu:3.5.1--hdfd78af_0'}"

    input:
    path reports

    output:
    path "combined/"

    script:
    """
    mkdir aggregate_reports
    cp ${reports} aggregate_reports/
    emu combine-outputs aggregate_reports tax_id --counts
    emu combine-outputs aggregate_reports species --counts
    emu combine-outputs aggregate_reports tax_id
    emu combine-outputs aggregate_reports species

    mkdir combined &&
      mv aggregate_reports/emu-combined-tax_id-counts.tsv combined &&
      mv aggregate_reports/emu-combined-species-counts.tsv combined &&
      mv aggregate_reports/emu-combined-tax_id.tsv combined &&
      mv aggregate_reports/emu-combined-species.tsv combined
    """
}
