#!/usr/bin/env python

import sys
import hashlib
import requests
import shutil
import tarfile
import zipfile
from pathlib import Path
from datetime import datetime
import logging

logger = logging.getLogger("fastdb")

# Set up logger
logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S"
)

# Cache directory
CACHE_DIR = Path.home() / ".fastdb"
CACHE_DIR.mkdir(exist_ok=True)

# Database definitions: tool → variant → version → [url, md5, filename]
EMBEDDED_DATABASES = {
    "kraken": {
        "standard-8": {
            "2025-04": {
                "url": "https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20250402.tar.gz",
                "md5": "e5f20daaa4b20a94f212698d792135b0",
                "filename": "k2_standard_08gb_20250402.tar.gz",
            },
            "2024-12": {
                "url": "https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20241228.tar.gz",
                "md5": "17666db25bc807cb284a13e6883660e9",
                "filename": "k2_standard_08gb_20241228.tar.gz",
            }
        }
    },
    "emu": {
        "emudb": {
            "2023-03": {
                "url": "https://osf.io/download/qrbne/",
                "md5": "a221d098eb6a32ba24df890b80231b82",
                "filename": "emu_db.tar.gz",
            }
        },
        "silva": {
            "2023-03": {
                "url": "https://osf.io/nfrgs/download",
                "md5": "5899619bcd73e480a08e5f06911feeae",
                "filename": "silva_database.tar.gz"
            }
        }
    }
}

def md5sum(filepath, block_size=65536):
    md5 = hashlib.md5()
    with open(filepath, 'rb') as f:
        for block in iter(lambda: f.read(block_size), b''):
            md5.update(block)
    return md5.hexdigest()

def unpack_archive(archive_path: Path, out_dir: Path):
    """
    Unpacks an archive to the specified output directory. Ensures the result contains
    exactly one top-level directory. If the archive extracts multiple files or directories
    at the top level, they are wrapped into a new directory named after the archive filename.

    Parameters:
        archive_path (Path): Path to the archive file to unpack.
        out_dir (Path): Directory where the unpacked data will reside. Will be created if needed.
    """
    logger.info(f"Unpacking to: {out_dir}")
    out_dir.mkdir(exist_ok=True)

    suffixes = "".join(archive_path.suffixes)
    temp_extract_dir = out_dir / "__temp_unpack"
    temp_extract_dir.mkdir(exist_ok=True)

    # --- Step 1: Extract archive contents to a temporary directory ---
    if suffixes.endswith((".tar.gz", ".tgz", ".tar.bz2", ".tbz2", ".tar.xz", ".txz")):
        with tarfile.open(archive_path, 'r:*') as tar:
            tar.extractall(temp_extract_dir)
    elif archive_path.suffix == ".zip":
        with zipfile.ZipFile(archive_path, 'r') as zip_ref:
            zip_ref.extractall(temp_extract_dir)
    elif archive_path.suffix in [".gz", ".bz2", ".xz"]:
        # For single-file compression formats
        out_file = temp_extract_dir / archive_path.stem
        with open(out_file, "wb") as out_f, open(archive_path, "rb") as in_f:
            shutil.copyfileobj(in_f, out_f)
    else:
        logger.error(f"Unknown archive type: {archive_path.name}")
        return

    # --- Step 2: Check what was extracted ---
    top_items = list(temp_extract_dir.iterdir())

    if len(top_items) == 1 and top_items[0].is_dir():
        # Archive already has a single top-level directory — move it directly
        logger.info(f"Archive already contains a single top-level directory: {top_items[0].name}")
        shutil.move(str(top_items[0]), out_dir)
    else:
        # Archive has multiple files or directories — wrap them in a new directory
        wrapper_name = archive_path.stem
        target_dir = out_dir / wrapper_name
        logger.info(f"Wrapping unpacked contents into: {target_dir}")
        target_dir.mkdir(exist_ok=True)
        for item in temp_extract_dir.iterdir():
            shutil.move(str(item), target_dir)

    # --- Step 3: Clean up temporary directory ---
    shutil.rmtree(temp_extract_dir)

def get_database_entry(tool: str, variant: str, version: str) -> dict:
    try:
        return EMBEDDED_DATABASES[tool][variant][version]
    except KeyError:
        raise ValueError(f"No entry found for: {tool}/{variant}/{version}")

def write_info_file(db_dir: Path, url: str, md5: str, filename: str):
    info_path = db_dir / "info.txt"
    with open(info_path, "w") as f:
        f.write(f"url: {url}\n")
        f.write(f"md5: {md5}\n")
        f.write(f"filename: {filename}\n")
        f.write(f"downloaded: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

def update_latest_symlink(base_dir: Path, version_dir: Path):
    symlink_path = base_dir / "latest"
    if symlink_path.exists() or symlink_path.is_symlink():
        symlink_path.unlink()
    symlink_path.symlink_to(version_dir, target_is_directory=True)

def download_with_progress(url, filename):
    import functools
    import pathlib
    import shutil
    import requests

    try:
        from tqdm.auto import tqdm
        use_tqdm = True
    except ImportError:
        tqdm = None
        use_tqdm = False

    r = requests.get(url, stream=True, allow_redirects=True)
    if r.status_code != 200:
        r.raise_for_status()
        raise RuntimeError(f"Request to {url} returned status code {r.status_code}")

    file_size = int(r.headers.get('Content-Length', 0))
    path = pathlib.Path(filename).expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)

    desc = "(Unknown total file size)" if file_size == 0 else filename.name
    r.raw.read = functools.partial(r.raw.read, decode_content=True)

    with path.open("wb") as f:
        if use_tqdm and file_size > 0:
            with tqdm.wrapattr(r.raw, "read", total=file_size, desc=desc, unit='B', unit_scale=True) as r_raw:
                shutil.copyfileobj(r_raw, f)
        else:
            shutil.copyfileobj(r.raw, f)

    return path

# def download_with_progress(url, filename):
#     import functools
#     import pathlib
#     import shutil
#     import requests
#     from tqdm.auto import tqdm
#
#     r = requests.get(url, stream=True, allow_redirects=True)
#     if r.status_code != 200:
#         r.raise_for_status()
#         raise RuntimeError(f"Request to {url} returned status code {r.status_code}")
#
#     file_size = int(r.headers.get('Content-Length', 0))
#     path = pathlib.Path(filename).expanduser().resolve()
#     path.parent.mkdir(parents=True, exist_ok=True)
#
#     desc = "(Unknown total file size)" if file_size == 0 else filename.name
#     r.raw.read = functools.partial(r.raw.read, decode_content=True)
#
#     with tqdm.wrapattr(r.raw, "read", total=file_size, desc=desc, unit='B', unit_scale=True) as r_raw:
#         with path.open("wb") as f:
#             shutil.copyfileobj(r_raw, f)
#
#     return path

def fetch_database(tool_variant_version: str) -> str:
    parts = tool_variant_version.strip().split("/")
    if len(parts) != 3:
        raise ValueError("Format must be 'tool/variant/version' (e.g. kraken/standard-8/2025-04)")

    tool, variant, version = parts
    entry = get_database_entry(tool, variant, version)
    url = entry["url"]
    expected_md5 = entry["md5"]
    filename = entry["filename"]
    # storage_type = entry.get("storage", "http")

    db_dir = CACHE_DIR / tool / variant / version
    base_variant_dir = CACHE_DIR / tool / variant
    archive_path = db_dir / filename
    unpacked_path = db_dir / "unpacked"

    db_dir.mkdir(parents=True, exist_ok=True)

    # --- Case 1: File doesn't exist → download ---
    need_download = False
    if not archive_path.exists():
        logger.info(f"[MISSING] Archive not found. Downloading from {url}")
        need_download = True

    # --- Case 2: Exists but MD5 mismatch → delete + download ---
    elif expected_md5:
        actual_md5 = md5sum(archive_path)
        if actual_md5.lower() != expected_md5.lower():
            logger.warning(f"[MD5 FAIL] Expected {expected_md5}, got {actual_md5}. Redownloading.")
            archive_path.unlink()
            need_download = True
        else:
            logger.info(f"[OK] Archive found and MD5 verified: {archive_path}")

    if need_download:
        logger.info(f"Downloading {url} -> {archive_path}")
        download_with_progress(url, archive_path)
        if expected_md5:
            actual_md5 = md5sum(archive_path)
            if actual_md5.lower() != expected_md5.lower():
                archive_path.unlink()
                raise ValueError(f"[ERROR] Checksum mismatch after download! Expected {expected_md5}, got {actual_md5}")
            logger.info(f"[OK] Downloaded and verified: {archive_path}")
        else:
            logger.info(f"[OK] Downloaded without checksum: {archive_path}")
        write_info_file(db_dir, url, expected_md5, filename)
        update_latest_symlink(base_variant_dir, db_dir)

    # --- Case 3 & 4: Check for unpacked content ---
    if not unpacked_path.exists() or not any(unpacked_path.iterdir()):
        logger.info(f"[EXTRACTING] Archive exists but not unpacked. Extracting now.")
        unpack_archive(archive_path, unpacked_path)
    else:
        logger.info(f"[READY] Archive already downloaded and extracted at: {unpacked_path}")

    return str(unpacked_path)

# def fetch_database(tool_variant_version: str) -> str:
#     parts = tool_variant_version.strip().split("/")
#     if len(parts) != 3:
#         raise ValueError("Format must be 'tool/variant/version' (e.g. kraken/standard-8/2025-04)")
#
#     tool, variant, version = parts
#     entry = get_database_entry(tool, variant, version)
#     url = entry["url"]
#     expected_md5 = entry["md5"]
#     filename = entry["filename"]
#     storage_type = entry.get("storage", "http")  # Optional default
#
#     db_dir = CACHE_DIR / tool / variant / version
#     base_variant_dir = CACHE_DIR / tool / variant
#     archive_path = db_dir / filename
#     unpacked_path = db_dir / "unpacked"
#
#     db_dir.mkdir(parents=True, exist_ok=True)
#
#     if archive_path.exists():
#         if expected_md5 and md5sum(archive_path).lower() == expected_md5.lower():
#             logger.info(f"Cached and verified: {archive_path}")
#         elif expected_md5:
#             logger.info(f"Checksum mismatch. Removing: {archive_path}")
#             archive_path.unlink()
#
#     if not archive_path.exists():
#         logger.info(f"Downloading {url} -> {archive_path}")
#         download_with_progress(url, archive_path)
#         # with requests.get(url, stream=True) as r:
#         #     r.raise_for_status()
#         #     with open(archive_path, 'wb') as f:
#         #         for chunk in r.iter_content(chunk_size=8192):
#         #             f.write(chunk)
#         if expected_md5:
#             actual_md5 = md5sum(archive_path)
#             if actual_md5.lower() != expected_md5.lower():
#                 archive_path.unlink()
#                 raise ValueError(f"Checksum mismatch! Expected {expected_md5}, got {actual_md5}")
#             logger.info(f"Downloaded and verified: {archive_path}")
#         write_info_file(db_dir, url, expected_md5, filename)
#         update_latest_symlink(base_variant_dir, db_dir)
#
#     if not unpacked_path.exists() or not any(unpacked_path.iterdir()):
#         unpack_archive(archive_path, unpacked_path)
#
#     return str(unpacked_path)

def list_available_databases():
    print("Available databases:")
    for tool, variants in EMBEDDED_DATABASES.items():
        for variant, versions in variants.items():
            for version in versions:
                print(f"{tool}/{variant}/{version}")


# CLI Usage
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch and unpack pre-defined bioinformatics databases.")
    parser.add_argument(
        "db", nargs="?", help="Database to fetch in the format tool/variant/version"
    )
    parser.add_argument(
        "--cacheDir", type=str, default=str(Path.home() / ".fastdb"),
        help="Directory to cache databases (default: ~/.fastdb)"
    )
    parser.add_argument(
        "--version", action="store_true",
        help="Show the version of this script"
    )

    args = parser.parse_args()

    if args.version:
        print("fastdb version 0.01-dev")
        sys.exit(0)

    CACHE_DIR = Path(args.cacheDir).expanduser().resolve()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    if not args.db:
        list_available_databases()
        sys.exit(0)

    try:
        local_path = fetch_database(args.db)
        print(f"Database ready at: {local_path}")
    except Exception as e:
        print(f"ERROR: {e}")
