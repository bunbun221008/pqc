建議用**同一個工作區在兩個階段的用途**呈現，讓聽眾一眼看出 message 與 tree／WOTS 資料共用空間，不會把容量重複相加。

投影片標題：**SRAM Capacity Budget and Workspace Reuse**

| Region / Phase                       | SRAM0                       | SRAM1                       | SRAM2                                              | SRAM3                                             |
| ------------------------------------ | --------------------------- | --------------------------- | -------------------------------------------------- | ------------------------------------------------- |
| **Signature — retained throughout**  | 1,040 words                 | 1,040 words                 | 1,040 words                                        | 1,040 words                                       |
| **Phase 1: Message hashing**         | Message storage             | Message storage             | Message storage                                    | Message storage                                   |
| **Phase 2: WOTS / tree computation** | WOTS endpoints<br>136 words | WOTS endpoints<br>132 words | Even-level nodes: 72 words<br>FORS roots: 72 words | Odd-level nodes: 64 words<br>FORS roots: 68 words |
| **Remaining workspace in Phase 2**   | 104 words                   | 108 words                   | 96 words                                           | 108 words                                         |

表格下方放這三句：

* **Each bank reserves 240 workspace words, shared between the two phases.**
* **Phase 1 uses all 96 bits per word, providing 11,520 B for messages up to 10 KiB.**
* **After message hashing, the workspace stores 64-bit working data, leaving 3,328 B for metadata and other temporary data.**

另外用一行小字交代釋放條件：

> **For signing, retain the message until both PRF_msg and H_msg complete.**

Signature 容量可放在表格旁或頁尾：

> **Signature allocation: 49,920 B ≥ maximum signature size of 49,856 B.**
