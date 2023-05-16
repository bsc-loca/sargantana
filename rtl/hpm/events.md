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
13. buffer_miss *TODO: Better description plz*
14. imiss_kill *TODO: Better description plz*
15. icache_bussy *TODO: Better description plz*
16. imiss_time *TODO: Better description plz*
17. Cycles of Load blocked by Store
18. Stalls by Data Dependencies
19. Stalls by Structural Risks
20. Stalls by Graduation List Full
21. Stalls by Free List Empty

**If any change is made to hpm_counters.sv event order, please change this file accordingly!**

Event 0 is hardwired to always zero, as per the spec.
