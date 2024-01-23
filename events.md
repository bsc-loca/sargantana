# Performance Counters

Each of the 29 generic performance counters can be configured to count events from one of these sources:

1. Missed Branches
2. Executed Branches
3. Taken Branches
4. Executed Stores
5. Executed Loads
6. iCache Requests
7. iCache Kills
8. Stalls of Fetch
9. Stalls of Decode
10. Stalls of Read Register
11. Stalls of Execute
12. Stalls of Writeback
13. ICache fill from L2
14. ICache killed 
15. ICache busy
16. ICache miss cycles
17. Cycles of Load blocked by Store
18. Stalls by Data Dependencies
19. Stalls by Structural Risks
20. Stalls by Graduation List Full
21. Stalls by Free List Empty
22. iTLB access
23. iTLB miss
24. dTLB access
25. dTLB miss
26. PTW cache hit
27. PTW cache miss
28. Stalls by iTLB miss

**This mapping is done in the file top_drac.sv**

Event 0 is hardwired to always zero, as per the spec.
