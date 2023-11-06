Structure
---------------

All modules have the following structure.
Try to follow it.

```            
nameOfModule
│       ├── doc
│       │   ├── digram.dwg
│       │   └── nameModule.md
│       ├── hdl
│       │   └── name\_top.sv
│       │   └── submodules.sv
│       ├── includes
│       └── tb
│           └── Makefile
│           └── Questa
│               └── files
│           └── Verilator
│               └── files
│           └── SBY
│               └── files
```            
Original folder
---------------

The original folder is just as reference, not a submodules, and it will be
removed at release. It does contain all the original code of lagarto but with
the spyglass warnings solved.
