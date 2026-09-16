可以，**這次 Our Work 就定位成「設計方向與初步容量估算」**，不必在報告前完成逐 cycle 排程或 RTL 驗證。

建議整理成 **5 頁**，接在你的 paper study 後面。下面英文可以直接作為投影片內容，中文是你講解時的重點。

**第 1 頁：Design Goals and Existing Resources**

* Extend PQCore v1.0 to support SLH-DSA.
* Reuse the existing Keccak architecture with two rounds per cycle.
* Four independent single-port SRAM banks: 96 bits × 1280 words each.
* Store the complete signature on chip.

這頁先交代我們的問題：**如何利用現有的 Keccak 與 60 KiB SRAM 加入 FIPS 205**。完整 signature 常駐是重要限制，後面所有設計選擇都圍繞這件事。

---

**第 2 頁：Two Independent Hash Units**

* Add one Keccak unit for two-way parallelism.
* Preserve the existing core architecture.
* Schedule WOTS+ verification chains independently.
* Start the next chain as soon as a unit becomes available.

講解時補充兩個選擇理由：

* 採用兩個獨立單元，能較直接沿用現有設計；這次不採新論文的四級 pipeline。
* 目前沒有足夠理由為 Trident 的三平行分工重新設計。它節省暫存的優勢，對既有 SRAM macros 的整合效益仍需另外評估。

**不要寫「三平行不可擴充」或「一定比較慢」**；我們能支持的結論是，二平行更符合目前的整合目標。

---

**第 3 頁：Hash Input Preparation and Data Reuse**

* Keep seeds and per-unit ADRS in registers.
* Feed chain results directly into the next hash.
* Adapt the SW/PL/SS/AS concepts to two independent units.
* Use the full 96-bit SRAM word width.
* Let hash units access shared working data directly.

這頁把我們從論文得到的啟發，轉成自己的設計方向：

* 重複使用的 seed、ADRS 不必反覆從 SRAM 載入。
* WOTS chain 中間結果盡量直接 feedback。
* 借用四個操作的資料準備概念，具體 shift／載入結構依我們的架構調整。
* 整合記憶體配置，減少外部工作區與 hash tile 本地記憶體之間的複製。

這些目前是**預計採用的設計方法**，還沒有量化節省多少 cycles。

---

**第 4 頁：Merkle Tree Scheduling**

* Follow SPHINCSLET’s incremental tree construction.
* Merge four ready child nodes into two parent nodes.
* Retain only a small number of nodes at each level.
* Avoid buffering a complete subtree leaf layer.

重點是：**我們用排程限制暫存量，因此不需要採用新論文的四個 subtree 批次方案。**

這裡建議使用「每層少量節點」或「每層最多四個節點」描述 SPHINCSLET。若寫「每層兩個」，就必須另外交代正在處理的輸入、輸出放在哪裡，這次可以先不引入這個細節。

---

**第 5 頁：Preliminary SRAM Capacity Budget**

這頁直接放容量表：

| Item                          |                Capacity |
| ----------------------------- | ----------------------: |
| Existing SRAM                 |                61,440 B |
| Maximum SLH-DSA signature     |                49,856 B |
| Proposed signature allocation |                49,920 B |
| Remaining workspace           | **11,520 B（11.25 KiB）** |

下面放三句：

* Pack signature data across 96-bit word boundaries.
* Reuse workspace across computation phases.
* Preliminary capacity estimates support further development of the two-unit design.

講解時強調：**49,920 B 是我們提出的預留配置，前提是 signature 緊密打包。** 工作區主要要容納 WOTS endpoints、tree nodes、FORS roots 與控制資料；seed、ADRS 等則由 registers 保存。

如果想加一個具體量級，可以補：

> Two WOTS+ endpoint arrays require 4,824 B with 36-byte slots.

也就是 \(2\times67\times36\) bytes，放入工作區後還剩 6,696 B。這是部分資料的容量例子，不能當成完整配置已驗證。

頁尾只需一句界定本次成果：

> **Current scope: architecture selection and capacity estimation. Detailed bank scheduling remains future work.**

這五頁已經能清楚呈現你的研究成果：**選擇二平行、改善 hash 資料準備、减少 SRAM 搬運、採用小暫存的 tree 排程，並提出能容納完整 signature 的容量配置。**


可以，第二頁改成**平行度的選擇理由**，第三頁集中講**沿用 64-bit 介面、資料轉換與 seed caching**。

**第 2 頁：Power-of-Two Parallelism**

* Power-of-two parallelism fits binary Merkle tree scheduling.
* Start with two independent Keccak units to reuse the existing architecture.
* Trident’s memory savings may not reduce area with our existing SRAM macros.
* Four-way parallelism remains an option, subject to memory capacity and bandwidth analysis.

口頭補充：二元樹每層的節點數適合分成 2、4 等數量的工作，方便規律分組；三平行也能運作，只是我們目前優先採用這種排程。**這是架構適配性的選擇，不代表所有操作在 2／4 平行下都能滿載。**

**第 3 頁：Memory Interface and Data Reuse**

* Retain the existing 64-bit-per-cycle Keccak input interface.
* The reference design also uses a 64-bit RAM interface.
* Bridge 96-bit SRAM words to 64-bit inputs with a packing buffer or width-converting FIFO.
* Cache PK.seed and SK.seed in registers and keep per-unit ADRS locally.
* Reuse chain results through direct feedback.

頁面底部可以另外放一句待研究事項：

> **Further study: word alignment, accesses spanning two SRAM addresses, and buffer sizing.**

這裡用 **packing buffer or width-converting FIFO** 比只寫 FIFO 精確：除了暫存，它還需要重新組合資料。兩個 96-bit words 剛好能組成三個 64-bit words，其中一個 64-bit word 會由兩個 SRAM words 各取 32 bits。

另外，**介面寬度相同支持我們先保留現有設計，但不能直接當成吞吐量已足夠的證明**；本次報告把它列為設計基準即可。


可以，這點放在第二頁作為**不採用 Trident 架構的另一個理由**。英文用「已滿足頻率需求」會比「我們已經很快」更精確。

**Power-of-Two Parallelism**

* Power-of-two parallelism fits binary Merkle tree scheduling.
* Trident’s speed advantage mainly comes from a higher clock frequency enabled by pipelining, while cycle-count benefits vary across parameter sets.
* Our existing Keccak core already meets the frequency target without additional pipelining.
* Trident’s memory savings may not reduce area with our existing SRAM macros.
* Start with two independent units; consider four if memory capacity and bandwidth allow.

其中第二點報告時要說明**比較對象是 SPHINCSLET**，並依你比較的操作區分 sign／verify。這樣不會讓聽眾誤以為「三平行本身沒有加速效果」。

你的結論可以口頭說：**我們目前沒有為了提高頻率而改成 Trident pipeline 的需求，因此優先保留現有 Keccak，採用兩個獨立單元。**


Trident’s gains mainly stem from pipelining and reduced memory usage, with no clear evidence that three-way parallelism itself is better suited to our architecture.