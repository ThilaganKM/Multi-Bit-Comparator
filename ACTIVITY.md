# eUVM Bug Hunt: Serialized Comparator

A hands-on activity for learning UVM-style verification with **eUVM** (UVM in the D language) and **Verilator**.

You get a working, passing testbench. It reports **0 errors**, and it still has bugs.
Your job is to run it, trace it in a waveform viewer, and find them.

> **Original design and testbench:** Soham Kapur ([SKpro-glitch/Multi-Bit-Comparator](https://github.com/SKpro-glitch/Multi-Bit-Comparator)).
> This activity is built on top of his work.

**How to use this activity:**
- Work through the parts in order. Each part ends with questions.
- Try each question yourself before opening a hint. Hints are layered: open them one at a time.
- If you're stuck, use the **"Ask your AI"** prompt. It's written so the AI guides you instead of handing you the answer.
- Answers and the fixed testbench are on the `solution` branch. Try not to look until you've attempted the fix yourself.

---

## Part 0: Setup

You need:

| Tool | Notes |
|---|---|
| eUVM (`ldc2`) | Tested with `euvm-1.0-beta61`. |
| Verilator, eUVM build | Must support the `--euvm` flag. Stock Verilator does not. |
| gtkwave | Any recent version. It can run on your local machine (see Part 2). |

Check your tools:
```bash
which verilator ldc2 gtkwave
verilator --version
ldc2 --version
```

> **Note for older eUVM versions (beta59 and earlier):** `sim/makefile` in this repo is set up for beta61 and later,
> where `esdl/intf/verilator/trace` ships as compiled `.di` interface files.
> On older versions, add `$(LDC2BINDIR)/../import/esdl/intf/verilator/trace.d \` back into the `Serialized_Comparator:` dependency list.

---

## Part 1: Build and run

```bash
cd Serialized_Comparator/sim
make 2>&1 | tee build.log        # build only
make run 2>&1 | tee run.log      # run the simulation (SEED=1)
```

Check the result:
```bash
grep "UVM_ERROR :\|UVM_FATAL :" run.log
grep -c "MATCHED\]" run.log
```

You should see 0 errors, 0 fatals and a number of `[MATCHED]` lines. ✅ The test passes.

**Questions**
1. Read `sim/makefile`. What are the three tools used to build the executable, and what does each one produce?
2. What does `+UVM_TESTNAME=Test.test` in the `run` target select?
3. Why does running `make` twice in a row print `Nothing to be done for 'all'`?

<details><summary>Hint</summary>

Look at the commands under the `verilator.stamp:` and `Serialized_Comparator:` rules. For question 3, look at how `make` decides whether a target is up to date.
</details>

---

## Part 2: Understand the DUT

Read `rtl/Serialized_Comparator.v`.

**Questions**
1. How many clock cycles does it take to compare two 8-bit numbers that differ in the MSB? And two equal numbers?
2. Which direction do `a`, `b` and `c` shift: left or right? Why that direction?
3. What is `c` for? When does `counter` become 0?
4. Once `solved` goes high, what makes it go low again?

<details><summary>Hint 1</summary>

`a[n]` is the MSB. Each cycle, the comparator looks at the MSB only, so the next bit has to move *into* the MSB position.
</details>
<details><summary>Hint 2</summary>

Question 4: `less_than`, `greater_than` and `equal_to` are registers. Search the RTL for every place they are assigned.
</details>

---

## Part 3: Trace a transaction in the waveform

The run writes `sim/Serialized_Comparator.vcd`. The timescale is **1 ps**. One clock cycle is **20 ns = 20000 ps**, and posedges are at 10000, 30000, 50000, ...

```bash
gtkwave Serialized_Comparator.vcd &
```

> **Running on a remote server with no display?** Download the `.vcd` (for example with `scp` or through VS Code), and open it with gtkwave on your own machine. On Windows, gtkwave under WSL works well.

Add these signals: `clock`, `reset`, `a_in`, `b_in`, `start`, `a`, `b`, `c`, `equal_bit`, `less_than`, `greater_than`, `equal_to`, `solved`.
Show `a_in`, `b_in`, `a`, `b` and `c` in **binary** (right-click, then Data Format, then Binary). Then save your layout with File, then Write Save File.

**Activity:** Fill in this table for the first item. Use `run.log` (the `@ <time>` values) together with the waveform:

| Time (ps) | Message in `run.log` | What the driver does (`Driver.d`) | What the DUT does (RTL) |
|---|---|---|---|
| 0 | | | |
| 10000 | | | |
| 30000 | | | |
| 50000 | | | |
| 70000 | | | |
| 90000 | | | |
| 110000 | | | |

<details><summary>Check your table</summary>

| Time (ps) | `run.log` | Driver | DUT |
|---|---|---|---|
| 0 | `Got new item` | `get_next_item(req)` | – |
| 10000 | – | sets `reset = 1` | – |
| 30000 | `Inputs have been provided` | sets `reset = 0`, `a_in`, `b_in` | sees reset: clears outputs, `c` = all 1s |
| 50000 | – | – | `start` branch: latches `a`, `b` |
| 70000 | `[MONITOR] Output values obtained` | sees `solved`, then `item_done()` | MSBs differ: `greater_than = 1`, `solved = 1` |
| 90000 | `[MONITOR] Output values obtained` (again!) | sets `reset = 1` for the next item | outputs still high |
| 110000 | `Inputs have been provided` | sets `reset = 0`, next inputs | sees reset: clears outputs |

Look at the 90000 row. Keep it in mind for Part 4.
</details>

---

## Part 4: Bug hunt #1: how many checks?

```bash
grep -c "Generated Item" run.log
grep "\[MATCHED\]" run.log | wc -l
grep "\[MONITOR\]" run.log | grep -o "@ [0-9]*" | tr '\n' ' '
```

The sequence generates **5 items**, but the scoreboard reports about **15 matches**.

**Questions**
1. Which item is checked more than once? Which item is checked the most, and why that one?
2. Look at `Monitor.d`. What condition does it use to decide that "a result is available"?
3. Why does the scoreboard still pass every duplicate check? Would that always be true?
4. In general, what should a monitor detect: a **level** or an **event**?

<details><summary>Hint 1</summary>

Compare the `[MONITOR]` timestamps with the times at which `solved` is high in the waveform.
</details>
<details><summary>Hint 2</summary>

`solved` stays high until the DUT is reset. Who resets the DUT, and when? What happens after the *last* item, when no next item ever comes?
</details>
<details><summary>Ask your AI</summary>

> I'm learning UVM verification. My monitor samples a DUT output on every clock edge with `if (vif.solved)`, and my scoreboard reports 15 matches for only 5 transactions. Don't give me the fix. Ask me guiding questions, one at a time, to help me work out why this happens and what a monitor should detect instead.
</details>

---

## Part 5: Bug hunt #2: when does the test end?

The test calls `set_drain_time(this, 200.nsec)` in `Test.d`.

```bash
grep "Test is complete\|ITEMS GENERATED\|Inputs have been provided" run.log | grep -o "@ [0-9]*.*\]"
```

**Questions**
1. At what time does the test drop its objection? At what time are the last item's inputs driven?
2. Why does the simulation end at 630 ns?

**Experiment:** Change the drain time to `60.nsec`, then run again:
```bash
make run 2>&1 | tee run_short_drain.log
grep "UVM_ERROR :" run_short_drain.log
grep -c "Inputs have been provided" run_short_drain.log
```

3. How many items were actually driven? Did the test still pass?
4. With the original 200 ns, what would happen if the **last** random item were two **equal** numbers? Work out the timing.
5. Is "increase the drain time" a good fix? Why or why not?

Undo the experiment when you're done: `git checkout -- ../testbench/Test.d`

<details><summary>Hint 1</summary>

Read `body()` in `Sequence.d`. When does `send_request()` return? Does anything wait for the driver to *finish* the item?
</details>
<details><summary>Hint 2</summary>

Find out what UVM drain time is meant for. Is it meant to cover work the test already *knows* is pending?
</details>
<details><summary>Ask your AI</summary>

> I'm learning UVM. My sequence uses `send_request()` in a loop and then returns. My test drops its objection when `seq.start()` returns, and relies on a 200 ns drain time. With a shorter drain time, the last item is never driven, but the test still passes with 0 errors. Don't give me the fix. Ask me guiding questions to help me understand the sequence–driver handshake and what drain time is really for.
</details>

---

## Part 6 (bonus): RTL review

The RTL uses blocking assignments (`=`) inside `always @(posedge clock)`.

1. Does it work correctly here? Why?
2. What could go wrong if someone reordered the statements, or split them into two `always` blocks?

---

## Part 7: Fix it

Fix both bugs in the testbench. Don't change the RTL.

Your fixed testbench should:
- check **every** item **exactly once**, so the number of `[MATCHED]` lines equals the number of generated items;
- still check every item with a **small** drain time (for example `40.nsec`).

When you're done, compare with the reference solution:
```bash
git fetch origin
git diff main origin/solution -- Serialized_Comparator/testbench
git checkout solution        # read SOLUTIONS.md
```

---

### Credits

- Design and original eUVM testbench: **Soham Kapur**
- Activity: **Thilagan KM**
