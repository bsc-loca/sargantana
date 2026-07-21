# Sargantana

<p align="center">
  <img src="doc/sargantana_logo.svg" />
</p>

Sargantana is a 64-bit processor based on RISC-V that implements the RV64GB ISA.
Sargantana features a highly optimized 7-stage pipeline implementing out-of-order write-back, register renaming, and a non-blocking memory pipeline.
Sargantana achieves a 1.26 GHz frequency in the typical corner, and up to 1.69 GHz in the fast corner using 22nm FD-SOI commercial technology.


## Table of Contents

- [Sargantana](#sargantana)
  - [Table of Contents](#table-of-contents)
  - [1. Cloning](#1-cloning)
  - [2. Simulating and Emulating on an FPGA](#2-simulating-and-emulating-on-an-fpga)
  - [3. Design](#3-design)
  - [4. License](#4-license)
  - [5. Authors](#5-authors)
  - [6. Citation](#6-citation)

## 1. Cloning

The `csr` and `mmu` submodules are declared with relative URLs so that the internal GitLab mirror resolves them correctly. When cloning a personal fork on GitHub, those URLs resolve against the fork and the recursive clone fails. After cloning a fork, point the two submodules at the upstream repositories:

```sh
git config submodule.rtl/csr.url https://github.com/bsc-loca/csr.git
git config submodule.rtl/mmu.url https://github.com/bsc-loca/mmu.git
git submodule update --init --recursive
```

## 2. Simulating and Emulating on an FPGA

To perform RTL simulations and/or emulating the design, please refer to the [core_tile](https://github.com/bsc-loca/core_tile) repo.

## 3. Design

![Sargantana Pipeline](doc/sargantana_pipeline.svg)

## 4. License

This work is licensed under the Solderpad Hardware License v2.1.

For more information, check the [LICENSE](LICENSE) file.

## 5. Authors

The list of authors can be found in the [CONTRIBUTORS.md](CONTRIBUTORS.md) file.

## 6. Citation

Víctor Soria-Pardos, Max Doblas, Guillem López-Paradís, Gerard Candón, Narcís Rodas, Xavier Carril, Pau Fontova-Musté, Neiel Leyva, Santiago Marco-Sola, and Miquel Moretó. ["Sargantana: A 1 GHz+ in-order RISC-V processor with SIMD vector extensions in 22nm FD-SOI"](https://upcommons.upc.edu/bitstream/handle/2117/384912/sargantana_preprint.pdf?sequence=1). 25th Euromicro, 2022.
