我會建議 **4 頁主內容 + 1 頁 results，總共 5 頁**。你前面已經講過 SPHINCS+/SLH-DSA、WOTS+、Merkle tree，所以這篇完全不用再花頁數講 background，直接講它真正的新東西。論文自己也把 contribution 集中在 WOTS+、security switch、memory optimization 這幾塊。

我會這樣切：

1. **Overall Architecture & Main Idea**
   放它的 top-level architecture 圖，先一句話講定位：
   **Pure-hardware SPHINCS+ processor supporting all three security levels with a high-throughput pipelined Keccak core.**
   然後只點出後面三個重點：WOTS+ scheduling、reconfigurable HIL、memory optimization。這頁不要細講。

2. **Pipelined Keccak + WOTS+ Scheduling**
   這頁是性能主線。放 Keccak architecture / WOTS scheduling 圖。重點講：

   * 8-round Keccak datapath split into 4 pipeline stages
   * Four WOTS+ chains processed concurrently
   * On-the-fly feedback avoids writing intermediate chain values to RAM
   * Verify：independent chains，finished chain immediately starts the next one

   你自己的評價可以補一句：**Verify scheduling validates our idea of independently advancing WOTS chains.**

3. **Reconfigurable Hash Input Logic — Security Switch**
   這頁專門講我們剛才花很多時間釐清的東西，反而很值得報。
   可以直接畫成：

   ```text
   4 × 1088-bit input arrays
          ↓
   PL / SW / AS / SS
          ↓
   pipelined Keccak
   ```

   然後四個 operation 只用一句解釋：

   * PL: load static fields in fixed 256-bit-oriented layout
   * SW: 64-bit serial loading for long/intermediate data
   * AS: move prepared inputs through the four arrays
   * SS: 64-bit selective shifts to remove redundancy for n=128/192

   最重要的 takeaway：
   **Reuse a 64-bit shift structure to support n = 128/192/256 without a large variable-width formatting network.**

   這其實是這篇最「巧」的硬體技巧之一。論文最後也把 security switch 的目的明確描述成利用 idle cycles 解決不同 parameter width 的 misalignment，同時減少 logic。

4. **Memory Optimization**
   這頁我會放最多內容，因為跟我們現在的設計最相關。直接切成三個小框：

   **On-the-fly WOTS**
   → chain intermediate values bypass RAM

   **Grouped subtree**
   → height-9 FORS tree split into four height-7 subtrees，只留下 subroots，避免存 \(2^9\) leaves。

   **Segmented signature streaming**
   → 前一段 signature 傳出去時，同時計算下一段；只需保存最多 \(2\times2272\) bytes valid signature，而不是完整 49,856 bytes，作者報告約 90% signature-storage reduction。

   這頁最後放一句你真正要帶走的 insight：
   **“Reduce memory by avoiding unnecessary lifetime of intermediate data, rather than simply increasing memory bandwidth.”**

5. **Results & What We Can Learn**
   不要把整張大表塞進去，只抓數字：

   * Artix-7: **29,410 LUTs / 14,090 FFs / 4 BRAMs**
   * Memory: **16 KB**
   * Supports all three SPHINCS+ security levels
   * Reported **1.04× / 2.41× ATP improvement for Sign / Verify**。

   然後右邊放你自己的 assessment，這反而是報告價值最高的部分：
   **Useful for our design**

   * Independent WOTS chain scheduling
   * 64-bit-granularity reconfigurable input formatting
   * Avoid unnecessary SRAM traffic
   * Local tree storage

   **Probably not directly reusable**

   * 4-stage aggressive Keccak pipeline
   * Grouped subtree if SPHINCSLET-style traversal is already more memory-efficient
   * Signature streaming if full signature must remain in our SRAM

我會特別推薦 **不要把 grouped subtree 和 segmented streaming 各拆一頁**，因為它們各自原理都不難；真正值得你講的是「作者先分析 memory traffic，然後針對三種不同資料 lifetime 用三種不同方法」。這樣第 4 頁會非常完整。

所以如果你整場報告還有其他論文，**5 頁很剛好**；如果這篇只想快速帶過，甚至可以把第 1、5 頁合併，壓成 **4 頁**。以你目前已經理解到的深度，我自己會選 **5 頁**，因為 HIL/security switch 值得獨立一頁。
