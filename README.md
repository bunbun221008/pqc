**Proposed SRAM Allocation**

Each SRAM contains **1,280 × 96-bit words**. Signature storage uses all 96 bits per word; workspace uses 64 bits per word. Address ranges are inclusive.

| Region                    | SRAM0                                        | SRAM1                                       | SRAM2                                      | SRAM3                                     |
| ------------------------- | -------------------------------------------- | ------------------------------------------- | ------------------------------------------ | ----------------------------------------- |
| **Signature**             | 0–1039<br>1,040 words                        | 0–1039<br>1,040 words                       | 0–1039<br>1,040 words                      | 0–1039<br>1,040 words                     |
| **WOTS endpoints**        | 1040–1175<br>Even chain indices<br>136 words | 1040–1171<br>Odd chain indices<br>132 words | —                                          | —                                         |
| **Tree nodes**            | —                                            | —                                           | 1040–1111<br>Even tree heights<br>72 words | 1040–1103<br>Odd tree heights<br>64 words |
| **FORS roots**            | —                                            | —                                           | 1112–1183<br>18 roots, 72 words            | 1104–1171<br>17 roots, 68 words           |
| **Unallocated workspace** | 1176–1279<br>104 words                       | 1172–1279<br>108 words                      | 1184–1279<br>96 words                      | 1172–1279<br>108 words                    |
| **Total**                 | **1,280 words**                              | **1,280 words**                             | **1,280 words**                            | **1,280 words**                           |

* **Signature capacity:** 49,920 B, sufficient for the maximum 49,856-byte signature.
* **Remaining workspace:** 416 words, providing **3,328 B** of usable storage at 64 bits per word.
* **Tree allocation:** Two nodes per level, plus two additional node slots in each of SRAM2 and SRAM3.
* **Registers:** PK.seed, SK.seed, ADRS, and hash buffers are stored separately and excluded from this table.


Use separate 384-bit input and output buffers to access all four SRAM banks simultaneously. Batch signature transfers into 48-byte blocks to reduce access overhead.