process FASTDB {
    label 'need_internet'
    label 'process_low'
    cpus 1
    memory '2 GB'

    input:
    val db_key

    output:
    path 'fastdb_output', emit: db_dir
    path "versions.yml", emit: versions

    script:
    """
    mkdir -p fastdb_output

    # Run the downloader and capture the full output
    fastdb.py ${db_key} | tee fastdb_output/db_log.txt

    # Extract only the last line and parse the actual path
    unpacked_path=\$(tail -1 fastdb_output/db_log.txt | awk -F': ' '{print \$2}')
    echo "Detected unpacked path: \$unpacked_path"

    # Find top-level directories inside unpacked_path
    mapfile -t top_dirs < <(find "\$unpacked_path" -mindepth 1 -maxdepth 1 -type d)

    # Ensure only one top-level directory is present
    if [ \${#top_dirs[@]} -ne 1 ]; then
        echo "[ERROR] Expected exactly one top-level directory inside unpacked_path, found \${#top_dirs[@]}"
        exit 1
    fi

    top_dir="\${top_dirs[0]}"
    echo "Top-level dir: \$top_dir"

    # Copy contents of the top-level directory into output
    cp -r "\$top_dir"/. fastdb_output/

    # Save version info
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastdb: \$(fastdb --version 2>&1 | cut -d ' ' -f 2)
    END_VERSIONS
    """
}
