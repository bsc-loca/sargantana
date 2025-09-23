#!/usr/bin/env python3

import os
import sys
import yaml

def collect_from_yaml(yaml_path, filelist, visited, repo_root="."):
    """
    Recursively parse all YAML files and collect referenced source files.
    Will explore all directories under repo_root to discover *.yml files.
    """
    yaml_path = os.path.abspath(yaml_path)
    if yaml_path in visited:
        return
    visited.add(yaml_path)

    with open(yaml_path, "r") as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        return

    base_dir = os.path.dirname(yaml_path)

    for block in data.values():
        if not isinstance(block, dict):
            continue

        # Collect explicit files
        if "files" in block:
            for fpath in block["files"]:
                abs_path = os.path.normpath(os.path.join(base_dir, fpath))
                rel_path = os.path.relpath(abs_path, start=repo_root)
                print("exploring", rel_path)
                filelist.add("./" + rel_path)
            # Collect incdirs if present
            for include in block.get("incdirs", []):
                abs_inc = os.path.normpath(os.path.join(base_dir, include))
                print("including", abs_inc)
                filelist.add("+incdir+" + abs_inc)

    # Recursively explore all subdirectories for YAML files
    for root, _, files in os.walk(base_dir):
        for fn in files:
            if fn.endswith("src_files.yml"):
                abs_file = os.path.join(root, fn)
                if abs_file not in visited:
                    print("adding references from", abs_file)
                    collect_from_yaml(abs_file, filelist, visited, repo_root)

# --------- main program code ---------

yaml_path = "./rtl/datapath/rtl/exe_stage/rtl/fpu/src_files.yml"
output_file = "./filelist.f"

filelist = set()
visited = set()
collect_from_yaml(yaml_path, filelist, visited)

print("\n\nFinished exploring. Starting writing\n")

# Read existing entries if any
existing = set()
if os.path.exists(output_file):
    with open(output_file, "r") as f:
        existing = set(line.strip() for line in f if line.strip())

# Merge everything (dedup)
all_entries = existing | filelist

# Order: *_pkg.sv first (both groups sorted)
pkg_files   = sorted([e for e in all_entries if e.endswith("_pkg.sv")])
other_files = sorted([e for e in all_entries if not e.endswith("_pkg.sv")])
ordered_entries = pkg_files + other_files

# Rewrite the file with new order
with open(output_file, "w") as out:
    for p in ordered_entries:
        print(p)
        out.write(p + "\n")

print("\nFinished writing all files (pkg.sv first)")
