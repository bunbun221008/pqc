好，這樣交換之後確實更順：**先讓大家知道 SLotH 是誰，再拿它的觀察來講 overhead。**

那下一個主題 **WOTS+ and Merkle Tree Parallelization**，我建議做成 **6 頁**，而且主線要很清楚：

> **WOTS+ 的平行化很直觀，但 Merkle tree 的平行化牽涉 dependency、scheduling 和 memory，所以設計空間更大。**

---

## Slide 1 — Parallelism in SLH-DSA

這頁先把問題拆成 WOTS+ 和 Merkle tree。

可以放：

### **WOTS+**

* Each hash chain is sequential
* Different chains are independent
* Natural parallelism across multiple chains

### **Merkle Tree**

* Nodes at the same level can be computed in parallel
* Parent nodes depend on child nodes
* Parallelism is constrained by tree dependencies and memory availability

最下面一句：

> **WOTS+ parallelism is straightforward; Merkle-tree parallelism requires scheduling.**

這頁就是整個 section 的 thesis。

---

## Slide 2 — WOTS+ Parallelization

這頁畫多條 chain 最有效：

```text
Chain 0: PRF → F → F → ... → F
Chain 1: PRF → F → F → ... → F
Chain 2: PRF → F → F → ... → F
                    ...
```

旁邊文字可以放：

* Operations within one chain are data-dependent
* Different WOTS+ chains can be processed independently
* Multiple hash units can therefore process multiple chains simultaneously
* Existing designs mainly differ in **how many chains are processed in parallel**

SPHINCSLET 就是用兩個 hash modules 利用 chain-level parallelism；它明確說 WOTS+ public-key generation 採用 chain-parallel approach。

最後一句：

> **More hash units directly translate into more chain-level parallelism — if enough independent chains are available.**

---

## Slide 3 — Why Merkle Trees Are Different

這頁畫一棵小樹：

```text
K0   K1   K2   K3
 \   /     \   /
  N0        N1
      \    /
       Root
```

然後 highlight dependency：

* (N_0) must wait for (K_0,K_1)
* (N_1) must wait for (K_2,K_3)
* Root must wait for both (N_0,N_1)

旁邊列：

**Design questions**

* How many leaves should be generated in parallel?
* When should parent-node computation start?
* Should hash units have fixed roles?
* Which intermediate nodes should be stored?
* How much memory bandwidth is required?
* Can every hash unit remain busy?

最下面：

> **Merkle-tree acceleration is a scheduling and memory problem, not only a hash-throughput problem.**

這句很重要。

---

# 接著直接進 1 / 2 / 3-way

## Slide 4 — Single-Hash Baseline

這頁不用綁死某篇 paper，可以把 SLotH 當 representative baseline。

畫：

```text
Hash Unit

K0 → K1 → N0 → K2 → K3 → N1 → ... 
```

當然真實順序不一定長這樣，你只是在表達所有 hash 共用同一 datapath。

文字：

### **Single Hash Unit**

* Minimum hardware cost
* No scheduling conflict between hash units
* Simple memory architecture
* All WOTS+ and tree-node operations are serialized

最下面：

> **High utilization is possible, but no operation-level parallelism is exploited.**

然後口頭說：

「像前面 SLotH 的思路，是先把單一 hash unit 本身盡可能餵滿。」

這樣就把上一 section 接過來。

---

## Slide 5 — Two-Way Parallelism: SPHINCSLET

這頁放 SPHINCSLET Fig. 6 或 HASH_TILE + Fig. 6 的簡化圖。

它的 HASH_TILE 有兩個 hash modules：`L_HASH`、`R_HASH`。

Merkle tree 的操作方式很值得講：

* Four child nodes are prepared
* Two parent nodes are computed in parallel
* Intermediate nodes are stored in internal BRAM
* Computation proceeds level by level / partial traversal
* Only a limited number of nodes need to be retained

SPHINCSLET 明確說它以四個 node 為一個處理單位，兩個 hash module 同時產生 parent nodes，並透過 traversal 限制每層需保存的 intermediate values。

最下面：

> **Two hash units map naturally to pairs of independent tree-node computations.**

這頁最好同時講到 **parallelism + memory**，因為這就是它比單純「兩顆 hash」更有意思的地方。

---

## Slide 6 — Three-Way Parallelism: Trident

這頁開始講 Trident。

我建議直接用它 Fig. 5 的 tree dataflow。

可以把核心概念簡化成：

```text
Hash Connector 0 → leaf generation
Hash Connector 1 → leaf generation
Hash Connector 2 → parent-node generation
```

然後旁邊寫：

* Three concurrent hash operations
* Two units can generate WOTS+/leaf results
* The third unit can consume completed child nodes
* Cache BRAM keeps recently generated intermediate nodes
* Leaf generation and tree reduction can overlap

Trident 的實際排程就是讓 Connector 0/1 產生 leaf，而 Connector 2 在可用時處理 parent nodes；論文用這個方式試圖重疊兩種工作。

最下面：

> **The third hash path attempts to overlap leaf production with tree reduction.**

---

但我其實會再加 **第 7 頁**，因為這是你最值得講的東西。

## Slide 7 — Does More Parallelism Always Help?

這頁就是你的 analysis。

左邊畫：

```text
1 unit  → easy to utilize
2 units → natural pair-wise parallelism
3 units → producer / consumer balance?
4 units → more area, but enough work?
```

右邊列：

### **Potential limitations**

* Parent operations must wait for child nodes
* Leaf generation is much more expensive than one parent hash
* Hash units may become imbalanced
* Memory-access order may limit parallelism
* More units increase area even when idle

然後引用 Trident 自己的 observation：

* Larger (h') → better parallelization
* Smaller (h') in fast variants → memory access order reduces parallelization efficiency 

最下面大字：

> **The optimal number of hash units depends on utilization, not just theoretical parallelism.**

這句其實就是你們未來設計最重要的 takeaway。

---

所以這個 section 最後會是：

1. **Parallelism in SLH-DSA**
2. **WOTS+ Parallelization**
3. **Why Merkle Trees Are Different**
4. **Single-Hash Baseline**
5. **Two-Way: SPHINCSLET**
6. **Three-Way: Trident**
7. **Does More Parallelism Always Help?**

我覺得這比直接「SLotH / SPHINCSLET / Trident」各講一頁更好，因為你是在用三篇論文回答一個 architectural question。
