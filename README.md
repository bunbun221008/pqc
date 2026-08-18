好，SCA 這章我建議抓 **5～6 頁**，而且主線不要變成「介紹 masking 技術」，而是回答一個很清楚的問題：

> **在 SLH-DSA 裡，到底哪些 hash operation 真的會洩漏秘密、值得付面積成本去保護？**

這樣會跟你前面 ASIC 設計主線一致。

## Slide 1 — What Is Secret in SLH-DSA?

先把 public / secret data 分清楚。

### Public / non-secret

* `PK.seed`
* `ADRS`
* message / digest
* authentication path

### Secret

* `SK.seed`
* `SK.prf`

然後 highlight：

[
PRF(PK.seed, SK.seed, ADRS)
]

文字可以放：

> **PRF directly processes the master secret `SK.seed`.**

> Repeated use of the same secret makes PRF the primary side-channel target.

SLotH 特別指出，`PRF` 因為直接反覆處理 `SK.seed`，是主要需要保護的 primitive。

---

## Slide 2 — Why Repeated PRF Calls Are Dangerous

這頁講「為什麼 SLH-DSA 特別容易」。

可以放：

* A single signature invokes PRF many times
* The same `SK.seed` appears repeatedly
* Only ADRS / index-related inputs change
* Leakage from repeated occurrences can be combined

最下面：

> **This enables horizontal side-channel analysis within one or a few traces.**

你可以再放一個小示意：

```text
PRF(SK.seed, ADRS0)
PRF(SK.seed, ADRS1)
PRF(SK.seed, ADRS2)
PRF(SK.seed, ADRS3)
        ...
     same secret
```

這頁是讓聽眾理解：不是因為 PRF 這個函數本身神秘，而是**同一 master secret 被大量重複使用**。

---

## Slide 3 — Experimental Evidence: TVLA

這頁直接放 SLotH 的 leakage figure。

標題可以：

**Unprotected SLH-DSA Leaks Quickly**

文字：

* Fixed-vs-random TVLA
* Target: `SK.seed`
* CPU-based SHAKE-128f implementation
* Leakage visible after only **1,000 traces**
* Maximum (|t| \approx 24.5)
* Common TVLA threshold: (|t| = 4.5)

最下面：

> **The repeated PRF computation exposes measurable leakage very quickly.**

這是 SLotH Section 6.1 的實驗。

---

## Slide 4 — Is Protecting PRF Enough?

這頁開始進更有意思的地方。

答案：

**Not necessarily.**

文字可以放：

* `PRF` directly exposes `SK.seed`
* The output of PRF becomes the beginning of a WOTS+/FORS hash chain
* Early chain values can still reveal useful secret-dependent information
* Therefore SLotH also protects selected subsequent `F` operations

然後分兩個：

### WOTS+

Protect:

> `PRF → F → F → ...`

during signing / public-key generation

### FORS

Protect:

> `PRF → F`

for secret-key generation / leaf binding

SLotH 明確說他們 mask 所有 PRF，並保護 WOTS signing / key generation 中後續 chaining，以及 FORS 中 PRF 後的 F。

最下面：

> **Sensitive intermediate values matter, not only the master key itself.**

---

## Slide 5 — SLotH Protection: Threshold Implementation

這頁介紹 solution，但不要陷太深數學。

內容：

### Three-share Threshold Implementation for Keccak

* Secret state represented by three Boolean shares
* PRF computation is masked
* Sensitive WOTS+/FORS chain operations are also masked
* Protected Keccak interface remains functionally similar to the normal accelerator

然後：

> **100,000-trace TVLA was used to evaluate the protected implementation.**



可以在旁邊註明 limitation：

> SCA protection is provided for **Keccak/SHAKE only** in SLotH.

SHA-2 units沒有等價的 protected implementation。

---

## Slide 6 — Security vs. Area Cost

我很建議保留這頁，因為你們是做 ASIC。

直接放 SLotH 的 area numbers 概念比較：

Normal full system：
**155.35 kGE**

With three-share TI Keccak：
**285.84 kGE**

也就是保護後整體面積接近翻倍。

所以右邊寫：

### Design implication

* Masking every hash operation is expensive
* Verification does not require `SK.seed`
* Different operations have different sensitivity
* Protection should be applied selectively

最下面大字：

> **Protect secret-dependent hash paths, not necessarily the entire hash datapath.**

這句我覺得就是這章最值得留給你們未來 ASIC 設計的 takeaway。

---

所以 SCA 章節的故事會非常完整：

**1. 哪些資料是秘密？**
→ **2. 為什麼 PRF 特別危險？**
→ **3. 實驗真的測到 leakage**
→ **4. PRF 後面的 chain 也可能需要保護**
→ **5. SLotH 用 TI 保護**
→ **6. 但代價很大，所以應 selective protection**

這樣會比單純講「SLotH 有做 TI」有研究價值很多。
