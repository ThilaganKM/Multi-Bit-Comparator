# Solutions: eUVM Bug Hunt

> ⚠️ **Spoilers.** This branch contains the answers to [ACTIVITY.md](ACTIVITY.md).
> If you haven't tried Parts 4, 5 and 7 yet, go back to `main` and try them first.

All times are from the default run (`SEED=1`) and are in **ps**, as in `run.log` and the VCD. One clock cycle is 20 ns = 20000 ps.

To see each fix as its own commit:
```bash
git log --oneline main..solution
git show <commit>
git diff main solution -- Serialized_Comparator/testbench    # all testbench fixes at once
```

---

## Part 1 answers: build and run

1. **Three tools:**
   - `verilator --cc --euvm --trace` turns the RTL into a C++ model (`obj_dir/`) plus D bindings (`euvm_dir/VSerialized_Comparator_euvm.d`).
   - `g++` compiles the C++ model and the Verilator runtime.
   - `ldc2` compiles the D testbench and links everything into `./Serialized_Comparator`.
2. **`+UVM_TESTNAME=Test.test`** tells UVM which test class to build: class `test` in D module `Test`.
3. **`Nothing to be done`:** `make` only rebuilds a target that is missing or older than its inputs (see [FAQ.md](FAQ.md)).

## Part 2 answers: the DUT

1. **Latency:** after reset, there is 1 cycle to latch the inputs (`start` branch). Then:
   - one compare cycle per bit, until the bits differ;
   - if the MSBs differ, the result is ready 1 cycle after latching;
   - if the numbers are equal, it takes all 8 compares, then 1 more cycle for `equal_to` to be set.
2. **Shift direction:** **left** (`a << 1`). The comparator only ever looks at the MSB `a[n]`, so shifting left brings the next lower bit into the MSB position each cycle. It checks from MSB to LSB, which is how magnitude comparison works.
3. **`c`:** a bit counter. It's loaded with all ones on reset and shifted left with `a` and `b`. `counter = |c` becomes 0 after 8 shifts, meaning all bits have been compared.
4. **`solved` going low:** the outputs are registers, and only `reset` clears them. **`solved` stays high until the next reset.** This is the key to Bug #1.

## Part 3 answer: the timing table

| Time (ps) | `run.log` | Driver | DUT |
|---|---|---|---|
| 0 | `Got new item` | `get_next_item(req)` | – |
| 10000 | – | sets `reset = 1` | – |
| 30000 | `Inputs have been provided` | sets `reset = 0`, `a_in`, `b_in` | sees reset: clears outputs, `c` = all 1s |
| 50000 | – | – | `start` branch: latches `a`, `b` |
| 70000 | `[MONITOR] Output values obtained` | sees `solved`, then `item_done()` | MSBs differ: `greater_than = 1`, `solved = 1` |
| 90000 | `[MONITOR] Output values obtained` **(again)** | sets `reset = 1` for the next item | outputs still held high |
| 110000 | `Inputs have been provided` | sets `reset = 0`, next inputs | sees reset: clears outputs |

---

## Bug #1: the monitor checks the same result many times

### Symptom
5 items are generated, but there are about 15 `[MATCHED]` lines. Monitor sample times:
```
70000 90000 | 170000 190000 | 350000 370000 | 430000 450000 | 510000 530000 ... 630000
  item 0        item 1          item 2          item 3          item 4 (7 times)
```

### Cause
`Monitor.d` reported a result on **every clock edge where `solved` was 1**:
```d
if(vif.solved) { ... mon_analysis_port.write(comp); }
```
But `solved` is a **level** that stays high until the DUT is reset:
- **Items 0 to 3:** the driver only resets the DUT one edge *after* it sees `solved`, so each result is held for **2 edges**, and the monitor reports it twice.
- **Item 4 (the last):** no next item comes, so the driver never resets the DUT. `solved` stays high until the simulation ends, and the monitor reports it on **every** remaining edge.

The scoreboard passed every duplicate, because the duplicated data was identical. So the test reported "0 errors" while counting the wrong number of transactions. A test like this can't tell you whether every item was checked exactly once.

### Fix: report the *event*, not the *level*
A new result is the moment `solved` **changes from 0 to 1**. The monitor remembers last edge's value and reports only on that rising edge (`Monitor.d`):
```d
        bool prev_solved = false; // for edge detection
        while(true)
        {
            wait(vif.clock.posedge());

            if(vif.solved && !prev_solved)//sample only on rising edge
            {
                ... // read inputs and outputs, then
                mon_analysis_port.write(comp);
            }
            prev_solved = cast(bool) vif.solved;
        }
```

| `prev_solved` | `solved` | Meaning | Report? |
|---|---|---|---|
| 0 | 0 | still computing | no |
| 0 | 1 | **new result** | **yes** |
| 1 | 1 | same result still held | no |
| 1 | 0 | DUT was reset | no |

### Result
```
Monitor samples: 70000 170000 350000 430000 510000     ← one per item
[MATCHED] Comparison is Correct: 5                       ← equals the items generated
```

---

## Bug #2: the test ends before the last item is finished

### Symptom
```
@ 430000  [SEQ]  5 ITEMS GENERATED
@ 430000  [TEST] Test is complete            ← objection dropped
@ 470000  [DRIVER] Inputs have been provided ← item 4 only driven now!
```
The simulation ends at 430 + 200 ns (drain time) = 630 ns. With the drain time cut to **60 ns**, item 4 is **never driven**: only 4 `Inputs have been provided` lines appear, and the test **still reports 0 errors**.

### Cause
The sequence used the low-level calls `wait_for_grant()` and `send_request()`:

| Call | Blocks until... |
|---|---|
| `wait_for_grant()` | the driver asks for an item (`get_next_item()`) |
| `send_request(item)` | **doesn't block.** It hands the item over and returns |

For items 0 to 3, the next iteration's `wait_for_grant()` waits until the driver asks again, which only happens after `item_done()`. So the pacing works. After the **last** item there is no next iteration: `body()` returns as soon as item 4 is *handed over*. `comp_seq.start()` returns, the test drops its objection, and only the drain time keeps the simulation alive.

Worst case: if the last item were two **equal** numbers, it would finish at about 670 ns (8 compares plus `equal_to`), which is past the 630 ns end. **The last check would be silently lost, even with the original 200 ns.**

### Fix: wait for the driver to finish each item
Add the missing wait after `send_request()` (`Sequence.d`):
```d
            send_request(cloned);
            wait_for_item_done();//blocks until the driver calls the item_done(), so body() can't return immediately before the last item finishes
```
Now `body()` returns only after the driver calls `item_done()` for item 4.

The standard UVM pair `start_item()` / `finish_item()` has this built in. In eUVM's `uvm_sequence_base.d`, `finish_item()` calls `send_request()` and then `wait_for_item_done()`:

| Low-level (this testbench) | Standard pair |
|---|---|
| `wait_for_grant()` | `start_item(item)` |
| `send_request(item)` + `wait_for_item_done()` | `finish_item(item)` |

### Then shrink the drain time (`Test.d`)
```d
        phase.get_objection().set_drain_time(this, 60.nsec);
```
This is the **same 60 ns that lost item 4 before the fix**. Now all 5 items are driven and checked, because the test no longer *relies* on drain time to finish its own pending work.

### Result
```
@ 510000  [TEST] Test is complete        ← after item 4's item_done(), not at 430000
Inputs have been provided: 5
UVM_ERROR : 0
```

---

## Part 6 answers (bonus): blocking assignments in a clocked block

1. **Does it work?** Yes. Within the single `always @(posedge clock)`, each statement's result is used by the statements after it in a deliberate order (compare `a[n]`, *then* shift). Blocking `=` executes in order, so the logic is correct.
2. **What could go wrong?** If the statements were reordered (for example, shift *before* compare) or split across two `always` blocks, the behaviour would change or become a simulation race. The usual rule is to use non-blocking `<=` for flip-flops in clocked blocks, so results don't depend on statement order or block scheduling. A reviewer would normally flag this style.

---

## intuition building

### DUT and waveform

**Q: Does the comparator shift right?**
No, it shifts **left** (`a << 1`). Each cycle it compares the MSB, and the left shift brings the next lower bit into the MSB position. In a binary waveform, the bits move left and zeros fill in from the right.

**Q: Once the inequality is found, does it shift again on the next cycle?**
No. The compare and the shift happen **on the same clock edge**, inside the same `always` block. On the deciding edge, the outputs are set *and* `a`, `b` and `c` shift. From the next edge on, `equal_bit = 0`, so the `else` branch runs, and it never shifts again.

**Q: The outputs stay high for 2 cycles. Is that on purpose, to give the testbench time to read them?**
No. The DUT holds its outputs **until reset**. The "2 cycles" come from the driver's timing: it sees `solved` at one edge and only applies reset at the next. The DUT doesn't promise any particular hold time, and this is exactly what caused Bug #1.

**Q: The waveform ends at 620 ns. Is the drain time too short to reach 900 ns?**
This is two mix-ups. First, the units: `@ 90000` is **90 ns**, since times are in ps. Second, the end time: the simulation ends at 430 ns (objection dropped) + 200 ns (drain) = 630 ns, and the VCD's last value change is recorded at 620 ns. The guess that drain time sets the end is correct, and it leads straight to Bug #2.

### The sequence–driver handshake (Bug #2)

**Q: Without `finish_item()`, does the sequence ignore `item_done()` and send the next item early?**
No. It can never send early: `wait_for_grant()` at the top of the next iteration blocks until the driver calls `get_next_item()` again, and the driver only does that after `item_done()`. **Items 0 to 3 are paced correctly.** The problem is only the **last** item, which has no next `wait_for_grant()` to wait on. An analogy: you post 5 letters, waiting at the counter before each one, and announce "all delivered!" as soon as the 5th is in the postbox, while it's still in the van.

**Q: Also, isn't `start_item()` the alternative to `send_request()`?**
Not quite. `start_item()` corresponds to `wait_for_grant()`, and `finish_item()` corresponds to `send_request()` **plus** `wait_for_item_done()`. That missing second half is the bug.

**Q: Does `wait_for_item_done()` stop simulation time?**
No. Every UVM component runs in its own thread, and the clock, driver, DUT and monitor keep running. Only the **sequence's** thread waits. What changes is *when the test decides it's done*: `body()` now returns at 510 ns (item 4 finished) instead of 430 ns (item 4 handed over).

**Q: Why not just increase the drain time?**
It works, but it's a band-aid:
- **It's a magic number tied to this design.** The worst case is about 240 ns after the last item is generated. Make the comparator wider or the clock slower, and the number silently becomes too short again. A lost check never *fails*, so you wouldn't notice.
- **It hides intent.** What you mean is "end when all items are done", and that's what `wait_for_item_done()` says.
- **Drain time is for activity that's already in flight** (for example, the monitor passing the last result to the scoreboard), not for waiting on work the test knows is still pending.

### The monitor (Bug #1)

**Q: Is the monitor fix some trick to compute the comparison early?**
No. The scoreboard isn't changed at all. The fix only changes **when the monitor reports**: once, when `solved` rises, instead of on every edge where it's high. This is ordinary edge detection.

**Q: Why not just `wait(vif.solved.posedge())` instead of keeping `prev_solved`?**
In eUVM, `solved` **can't** produce a posedge event:
- `clock` is an eUVM `Signal`. The testbench writes it, so the eUVM simulator knows when it changes, and can wake up anything waiting on `posedge()`.
- `solved` is a `VlPort`: a window into Verilator's C++ model memory. It changes silently when `dut.eval()` runs, and nothing notifies eUVM. You can *read* it, but you can't *wait* on it. `VlPort` has no `posedge()`. (See the comments in `Interface.d`.)

Even where it *is* possible (for example, in SystemVerilog), sampling on the **clock** and comparing with the previous value is the preferred style. Synchronous outputs are only meaningful at clock edges, and waiting directly on a data signal can fire on glitches or race with the clock edge.

**Q (a common mistake): with the fix, only 1 item is matched. Is it a timing issue?**
No. The check is in the wrong place:
```d
if(vif.solved && !prev_solved) {
    ...
    prev_solved = cast(bool) vif.solved;   // ✗ only updates when reporting
}
```
`prev_solved` becomes `true` at the first result, and it never sees `solved` drop back to 0 after reset, because the update only runs inside the `if`. So no later rising edge is ever detected. **The previous value must be recorded on every edge**, after the `if`:
```d
if(vif.solved && !prev_solved) { ... }
prev_solved = cast(bool) vif.solved;       // ✓ every edge
```

---

## Going further

- **Constrain the stimulus.** Add constraints to `Item.d` so some items are equal pairs, or differ only in the LSB (the slowest cases). Does the testbench still check them all?
- **Coverage.** How would you *prove* that the random stimulus hit the `less_than`, `greater_than` and `equal_to` outcomes?
- **Reuse the item object.** The monitor writes the *same* `comp` object every time. This works because the scoreboard checks it immediately. What would go wrong if the scoreboard stored items in a queue to check later?
