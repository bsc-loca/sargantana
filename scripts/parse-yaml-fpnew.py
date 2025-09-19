#!/usr/bin/env python3

import os
import sys
import yaml

def collect_from_yaml(yaml_path, filelist, visitedi, repo_root=".") :
    # parse one YAML file and collect file paths recursively
    yaml_path = os.path.abspath(yaml_path)
    if yaml_path in visited :
        return
    visited.add(yaml_path)

    with open(yaml_path, "r") as f :
        data = yaml.safe_load(f)

    if not isinstance(data, dict) :
        return
    
    base_dir = os.path.dirname(yaml_path)

    for block in data.values() :
        if not isinstance(block, dict) :
            continue
        # collect explicit files
        if "files" in block :
            for fpath in block["files"] :
                abs_path = os.path.normpath(os.path.join(base_dir, fpath))
                rel_path = os.path.relpath(abs_path, start=repo_root)
                filelist.add("./" + rel_path)
        
        # handle incdirs 
        if "incdirs" in block :
            for inc in block["incdirs"] :
                inc_path = os.path.normpath(os.path.join(base_dir, inc))
                if os.path.isdir(inc_path) :
                    for root, _, files in os.walk(inc_path) :
                        for fn in files :
                            if fn.endswith((".v", ".sv")) :
                                rel_file = os.path.relpath(abs_file, start=repo_root)
                                filelist.add("./" + rel_file)
                            elif fn.endswith(".yml") :
                                collect_from_yaml(os.path.join(root, fn), filelist, visited, repo_root)

# --------- main program code ---------

yaml_path = "./rtl/datapath/rtl/exe_stage/rtl/fpu/src_files.yml"
output_file = "./filelist.f"

filelist = set()
visited = set()

collect_from_yaml(yaml_path, filelist, visited)

existing = set()
if os.path.exists(output_file) :
    with open(output_file, "r") as f :
        existing = set(line.strip() for line in f if line.strip())

new_entries = sorted(filelist - existing)

with open(output_file, "a") as out :
    for fpath in sorted(new_entries) :
        print(fpath)
        out.write(fpath + "\n")

print("\nFinished appending all FPNEW files")


