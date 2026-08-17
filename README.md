"# PQC" 

好，這一段我會讓它完全圍繞 **SLotH 的核心觀念**：
**瓶頸不只在 hash core，而在每次 hash 之間的資料準備與控制 overhead。**

我建議這個 section 做 **5 頁**。

### Slide 1 — Why Faster Hash Is Not Enough

先把問題講清楚。

文字可以放：

* SLH-DSA requires a huge number of short, repetitive hash operations
* After the hash core is accelerated, **data preparation and control overhead become significant**
* Major overhead sources:

  * Padding / input formatting
  * ADRS update
  * Memory movement
  * CPU–accelerator communication
  * Starting and waiting for each hash operation

最下面一句：

> **The goal is not only to make each hash faster, but to reduce the gap between consecutive hashes.**

這頁就是這個 section 的 motivation。

---

### Slide 2 — Evidence: Hash Core Utilization Matters

這頁放 SLotH 論文那個很漂亮的例子。

標題也可以叫：

**A Faster Core Does Not Guarantee Faster SLH-DSA**

內容：

* Previous design reduced Keccak from **24 rounds to 12 rounds**
* Hash computation was almost 2× faster
* But overall signing improved by only **~3%**
* Most cycles were spent in **control logic and HW/SW interface**



最下面大字：

> **Interface overhead can dominate after hash acceleration.**

我覺得這頁非常重要，因為它不是你自己猜測，而是有直接 benchmark 支撐。

---

### Slide 3 — SLotH Architecture

這頁正式介紹 SLotH。

放論文 Fig. 5：

**RV32 Core + SHA2-256 + SHA2-512 + Keccak accelerators**

然後旁邊只寫：

* Generic RISC-V controller executes SLH-DSA algorithm
* Hash accelerators are memory-mapped
* SLH-DSA-specific operations are moved into hash hardware
* No custom RISC-V instruction is required



這頁核心不是 RISC-V 本身，而是：

> **Keep high-level control in software, but move repetitive low-level hash handling into hardware.**

---

### Slide 4 — What Does SLotH Move into Hardware?

這頁是這個 section 的核心。

我會分成兩欄：

**Conventional Hash Accelerator**

* Load message
* Format input
* Add padding
* Update ADRS
* Start hash
* Wait
* Read result
* Repeat

**SLotH**

* Cached `PK.seed`
* Cached `SK.seed`
* Internal ADRS register
* Automatic message formatting
* Automatic padding
* Automatic ADRS update
* Autonomous Winternitz-chain iteration

SLotH 的 Keccak 與 SHA2-256 control unit 都特別加入這些 SLH-DSA-specific features。

下面一句：

> **Reduce software involvement between consecutive hash operations.**

---

### Slide 5 — Autonomous WOTS+ Chain

最後用 WOTS 把這件事情講具體。

先畫：

[
X_0 = PRF(PK.seed,SK.seed,ADRS)
]

[
X_j = F(PK.seed,ADRS_j,X_{j-1})
]

然後左右比較：

**Without chain support**

```text
CPU prepares F
→ Hash
→ CPU reads result
→ Update ADRS
→ Prepare next F
→ Hash
→ ...
```

**SLotH**

```text
CPU sets:
X0 + ADRS + iteration count

↓
Hardware automatically executes
F → F → F → ... → F
```

SLotH 的 Winternitz chaining 在 hardware 中自動更新 ADRS 並反覆執行 F；Keccak 每次 chain iteration 除 permutation 本身外只增加最多約 2 cycles 的控制開銷。

頁尾：

> **SLotH optimizes the transitions between hashes, not just the hash itself.**

這句就是這一節的 takeaway。

---

所以整段的故事很簡單：

**Why faster hash is not enough**
→ **實驗證明 interface overhead 很重要**
→ **SLotH 的 architecture**
→ **它把哪些 overhead 搬進 hardware**
→ **用 WOTS chain 展示效果**

然後下一 section 就可以非常自然地接：

# WOTS+ and Merkle-Tree Parallelization

因為你剛講完「怎麼讓**一個 hash unit**不要閒著」，下一段就開始問：

> **那如果我們放更多 hash units，可以同時做多少事情？**
