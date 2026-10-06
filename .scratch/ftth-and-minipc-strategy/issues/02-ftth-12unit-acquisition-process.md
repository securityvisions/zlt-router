# 02 - End-to-End FTTH Acquisition Process for 12-Unit Building

**Type:** `task`  
**Status:** resolved

## Resolution

Documented the complete end-to-end acquisition strategy for the 12-unit building:
1. **Leveraging the Complex Scale:** Neither TCI nor Shatel will trench for a single flat, but a 12-unit newly built building meets the commercial qualification threshold for 100% subsidized FAT installation and free riser labor.
2. **Action Sequence:**
   - Collect agreement from building manager and 4–8 units.
   - File parallel applications:
     - TCI: Visit امور مشترکین مرکز شهید نظری (سردار جنگل) with building postal code and manager letter.
     - Shatel: Contact residential complex desk directly at `021-91000911` (free survey within 48h).
3. **Physical Topology:**
   - Outdoor: Feeder fiber from street manhole to parking/basement telecom rack -> 16-port FAT box.
   - Indoor: Vertical drop cable via central riser pipe to each floor -> ATB wall socket.
   - Unit Hardware: Bridge ONT (Huawei HG8010H / EchoLife) plugged into AX3000T WAN port (`wan`). The AX3000T handles gigabit PPPoE and proxy interception.
4. **Economics:** Infrastructure cost to building is ~0 Toman under promotional campaigns; individual per-unit setup (metered drop cable + ONT modem + initial high-speed package) ranges from 4M to 15M Toman.  
**Blocked by:** 01  

## Question

What is the exact, step-by-step operational procedure to pull fiber optic into a newly built 12-unit residential building in Tehran (TCI Tanoma vs Private FCP), including FAT box installation, building manager application, drop cabling, costs, and timeline?

## Execution Plan

1. Document the group application requirements (نامه درخواست هیئت مدیره ساختمان / متقاضیان).
2. Detail the physical topology (ODF/FAT installation on building wall, microducts, vertical risers, ATB socket in units, ONT modem).
3. Detail realistic costs (infrastructure cost vs monthly plan vs ONT hardware) and split among 12 units.
