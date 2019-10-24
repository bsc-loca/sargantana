Top Folder Makefile                                                             
==================                                                              
                                                                                
Description                                                                     
------------                                                                    
This file is supposed to be a Makefile that provides all the interesting recipes
for this repository. In the future simulations, synthesis, CI tests,     
etc.. will be present in this file.                                             
                                                                                
Currently, it allows running linting of the project files. through recipes        
**lint** and **strict_lint**                                                        
                                                                                
Current recipies                                                                
---------------                                                                 
* lint:                                                                         
    It will lint all the verilog and sv files with verilator. An artifact with  
    the errors is generated in the path specified by $artifact in               
    ```/scripts/veri_lint.sh```                                                 
    **Files with tb_ and wip_ as prefix are excluded even if extension is .v or .sv**  
* strict_lint:                                                                  
    This script will lint all the Verilog and sv files with Verilator until an error is found. No artifacts are generated.
    **Files with tb_ and wip_ as prefix are excluded even if extension is .v or .sv**  
