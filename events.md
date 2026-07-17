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
29. DCache stalls
30. DCache refill stalls
31. DCache rtab rollback
32. DCache request on hold
33. DCache prefetch request
34. DCache read request
35. DCache write request
36. DCache CMO request
37. DCache uncached request
38. DCache read request miss
39. DCache write request miss
40. Stalls of Register Rename

When the `EXTERNAL_HPM_EVENT_NUM` compile-time macro is defined, the following
additional events are available depending on its value (supported
configurations are `4`, `6`, and `10`):

| Event | Available when `EXTERNAL_HPM_EVENT_NUM` is | Source |
| --- | --- | --- |
| 41 | 4, 6, or 10 | L2 miss |
| 42 | 4, 6, or 10 | L2 access |
| 43 | 4, 6, or 10 | L1.5 miss |
| 44 | 4, 6, or 10 | L1.5 access |
| 45 | 6 | NOC-S flit valid |
| 46 | 6 | NOC-S stall |
| 45 | 10 | NOC flit valid, channel 0 |
| 46 | 10 | NOC flit valid, channel 1 |
| 47 | 10 | NOC flit valid, channel 2 |
| 48 | 10 | NOC stall, channel 0 |
| 49 | 10 | NOC stall, channel 1 |
| 50 | 10 | NOC stall, channel 2 |

**This mapping is done in the file top_drac.sv**

Event 0 is hardwired to always zero, as per the spec.
