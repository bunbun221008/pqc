可以。這次我會把 SCA 章節重新整理成一條更完整、也更適合你們 ASIC 設計的故事線：

> **Why does SLH-DSA leak? → Why is `SK.seed` the main target? → Hardware key management already helps → What remains sensitive? → TI protection → Cost / design implication**

我建議 **6 頁**。

---

## Slide 1 — Side-Channel Sensitivity in SLH-DSA

這頁先回答：「到底哪些東西是 sensitive？」

### 投影片文字

**Secret values**

* `SK.seed` — master seed for WOTS+ and FORS secret-key generation
* `SK.prf` — used in message randomization

**Public / non-secret values**

* `PK.seed`
* `ADRS`
* Message / message digest
* Authentication paths

然後中間 highlight：

[
PRF(PK.seed,\ SK.seed,\ ADRS)
]

> **PRF directly processes the master secret `SK.seed`.**

最下面：

> **The PRF function is the primary target for side-channel protection.**

SLotH 明確把 PRF 視為主要 leakage target，因為它直接處理 secret variable。

### 你口頭講什麼

「雖然 SLH-DSA 幾乎全部都是 hash，但不是每一個 hash 都一樣敏感。像一般 tree-node 的 H，input 基本上不是 secret；真正最危險的是 PRF，因為它直接把 master secret `SK.seed` 丟進 hash。」

---

# Slide 2 — Why Is `SK.seed` Especially Vulnerable?

這頁講 repeated exposure。

### 投影片文字

### **The same master secret is used repeatedly**

[
PRF(PK.seed,SK.seed,ADRS_0)
]

[
PRF(PK.seed,SK.seed,ADRS_1)
]

[
PRF(PK.seed,SK.seed,ADRS_2)
]

[
\vdots
]

* A signature requires **thousands to hundreds of thousands of PRF calls**
* `ADRS` changes, but the same `SK.seed` is repeatedly processed
* Leakage from repeated occurrences can be combined

> **Repeated use of `SK.seed` enables horizontal side-channel attacks.**

SLotH 的 quantitative analysis 顯示，例如 128f signing 就有 8,272 次 PRF；其他參數甚至可達數十萬次。 作者也特別指出，這些 repeated PRF leakage 可以在 horizontal attack 中結合，因為每次都使用相同的 `SK.seed`。

### 這頁其實很重要

因為它解釋了：

**SLH-DSA 的 SCA 問題不是單純「secret 經過 Keccak」而已，而是同一個 secret 被使用非常非常多次。**

---

# Slide 3 — Experimental Evidence: CPU Implementation

這頁直接拿 SLotH Fig. 6。

標題也可以叫：

## **Unprotected Implementation Leaks Quickly**

### 投影片文字

**Fixed-vs-Random TVLA**

* Target: `SK.seed`
* SLH-DSA-SHAKE-128f
* Hash computation performed by RISC-V CPU
* Trace includes only the **first PRF invocation**

大字放：

> **1,000 traces → max (|t| = 24.5)**

旁邊：

> Typical TVLA threshold: (|t| = 4.5)

然後：

> **Leakage is already clearly visible from the first PRF computation.**

Fig. 6 的實驗只截取 signing 最前面的約 73k cycles、包含第一個 SHAKE256 PRF，就已經在 1,000 traces 達到 (|t|=24.5)；SHA2-256 PRF 也呈現類似 leakage。

---

# Slide 4 — Hardware Key Management Already Helps

這就是你剛剛特別指出、我覺得一定要放的一頁。

而且這頁非常適合你們做 ASIC。

### 投影片文字

## **Keep `SK.seed` Inside the Accelerator**

**CPU-based processing**

```text
Memory
   ↓
CPU register / datapath
   ↓
Hash input preparation
   ↓
PRF
   ↓
Repeated many times
```

**Hardware key management**

```text
        SK.seed Register
              │
              ↓
       Local PRF / Hash
              │
              ↓
      WOTS+ / FORS chain
```

旁邊：

* `SK.seed` is loaded into hardware storage
* PRF directly uses the hardware-stored secret
* Software does not need to repeatedly manipulate the secret
* Secret data movement through the system is reduced
* Hardware can complete secret-dependent operations much faster

最下面：

> **Hardware key management reduces secret exposure even without masking.**

這不是我們自己延伸出來的 claim。SLotH 作者明確說，他們另外考慮了 **「即使不使用 masking，hardware key management 本身所帶來的 practical security increase」**；而且所有 PRF 都使用 hardware-stored secret keys。 

另外從 register map 也可以很直接看到：

* Keccak 有內部 `SK.seed` register
* SHA2-256 也有 `S256_SKSD` 專門保存 `SK.seed`



### 這頁口頭要特別講清楚

不要講成：

> 「把 SK.seed cache 起來就安全了。」

應該說：

> 「它沒有消除 hash core 本身對 secret 的 data-dependent switching，所以不是 masking 的替代品；但是把 secret 留在 local hardware、避免反覆經過 CPU/bus/datapath，本身就是一層有意義的 protection。」

這點我覺得非常適合你們未來 ASIC。

---

# Slide 5 — Is Protecting PRF Enough?

接下來讓故事自然進到「還是不夠」。

### 投影片文字

## **Secret Sensitivity Decreases Along the Hash Chain**

WOTS+：

[
X_0 = PRF(PK.seed,SK.seed,ADRS)
]

[
X_1=F(...,X_0)
]

[
X_2=F(...,X_1)
]

[
\cdots
]

可以用顏色或深淺表示：

**Highest sensitivity**

`SK.seed → PRF → X0 → F → X1 → F → X2 ...`

**decreasing sensitivity →**

文字：

* PRF directly contains the master secret
* Early WOTS+ chain values are still security-sensitive
* Randomized `idx` and `ADRS` reduce sensitivity of later chain values
* Low chain elements may still be useful in forgery attacks

因此 SLotH 保護：

### WOTS+

* PRF
* Subsequent F-chain in **key generation and signing**

### FORS

* PRF
* The following **F binding operation**

作者明確說 sensitivity 隨 chain 往後降低，但仍可能需要 protection，因此 protected implementation mask 所有 PRF，以及 key generation / signing 中後續 WOTS chaining；FORS signing 也保護 PRF 後的 F。 

頁尾：

> **Protection should follow the propagation of secret-dependent intermediate values.**

這句很適合你的 ASIC design perspective。

---

# Slide 6 — Threshold Implementation and Its Cost

最後才正式講 TI。

### 左半：Protection

## **Three-Share Threshold Implementation of Keccak**

* Secret key and Keccak state represented by **three Boolean shares**
* Protects PRF
* Protects sensitive WOTS+ / FORS chaining
* Same general interface as the normal Keccak accelerator
* Full-signing leakage assessment with **100,000 traces**

SLotH 對 TI Keccak 的完整 SHAKE-128f signing 做了 100,000-trace TVLA。

---

### 右半：Cost

你可以放兩種 cost。

#### Performance

Protected signing 約增加：

**~20–33% cycles**

例如：

* 128f: +21.5%
* 192f: +30.1%
* 256f: +28.5%



#### Area

這個對你們更重要。

ASIC synthesis：

* Full SLotH, all parameters: **155.35 kGE**
* TI Keccak adds about **130 kGE**

也就是整體接近翻倍。

FPGA 上也是類似：

* normal: 14,428 LUT
* with TI: 30,717 LUT



另外一定註明：

> **Current SLotH SCA protection supports Keccak/SHAKE only.**

SHA-2 沒有 equivalent protected implementation，作者認為 SHA-2 masking 因為 addition/XOR domain conversion 等問題會更昂貴。

---

## 最後可以在 Slide 6 底下放一個 Takeaway

我會寫：

> **SCA protection is a hierarchy, not an all-or-nothing choice.**

然後三層：

**1. Local secret storage**
Reduce secret movement and exposure

↓

**2. Protect secret-dependent datapaths**
PRF + early chain operations

↓

**3. Masking / TI**
Strong protection, but high area cost

---

這樣整個 SCA section 就不只是：

> CPU 會漏 → TI 解決

而變成一個很完整、而且對你們做 ASIC 特別有價值的 design story：

**`SK.seed` 為什麼危險**
→ **CPU implementation 確實 leak**
→ **先把 secret 留在 local hardware 就可以降低暴露**
→ **但 secret-dependent intermediate values 還存在**
→ **因此 selective masking PRF + early chains**
→ **完整 TI 很貴，所以 protection boundary 本身也是 architecture design choice**

我覺得這版比前一版好很多，因為「**secret 放在哪裡**」和「**mask 哪一段 datapath**」都直接是 ASIC architecture 問題。
