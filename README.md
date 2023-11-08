# Sargantana

<p align="center">
  <img src="doc/sargantana_logo.svg" />
</p>

Sargantana is a 64-bit processor based on RISC-V that implements the RV64G ISA.
Sargantana features a highly optimized 7-stage pipeline implementing out-of-order write-back, register renaming, and a non-blocking memory pipeline.
Sargantana achieves a 1.26 GHz frequency in the typical corner, and up to 1.69 GHz in the fast corner using 22nm FD-SOI commercial technology.


## Table of Contents

- [Sargantana](#sargantana)
  - [Table of Contents](#table-of-contents)
  - [1. Simulating and Running on an FPGA](#1-simulating-and-emulating-on-an-fpga)
  - [2. Design](#2-design)
  - [3. License](#3-license)
  - [4. Authors](#4-authors)
  - [5. Citation](#5-citation)

## 1. Simulating and Emulating on an FPGA

To perform RTL simulations and/or emulating the design, please refer to the [core_tile](https://github.com/bsc-loca/core_tile) repo.

## 2. Design

![Sargantana Pipeline](doc/sargantana_pipeline.svg)

## 3. License

This work is licensed under the Solderpad Hardware License v2.1.

For more information, check the [LICENSE](LICENSE) file.

## 4. Authors

The list of authors can be found in the [CONTRIBUTORS.md](CONTRIBUTORS.md) file.

## 5. Citation

Víctor Soria-Pardos, Max Doblas, Guillem López-Paradís, Gerard Candón, Narcís Rodas, Xavier Carril, Pau Fontova-Musté, Neiel Leyva, Santiago Marco-Sola, and Miquel Moretó. ["Sargantana: A 1 GHz+ in-order RISC-V processor with SIMD vector extensions in 22nm FD-SOI"](https://upcommons.upc.edu/bitstream/handle/2117/384912/sargantana_preprint.pdf?sequence=1). 25th Euromicro, 2022.
