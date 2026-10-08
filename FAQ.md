# FAQ: setup and workflow problems

Real questions from students who worked through [ACTIVITY.md](ACTIVITY.md).
There are no spoilers for the bug hunts here. Those questions are answered in `SOLUTIONS.md` on the `solution` branch.

---

## Getting the code

### `git clone https://github.com/.../tree/main/Serialized_Comparator` fails
A `/tree/...` link points to a GitHub *web page*, not to a repository, so you can't clone it.
Clone the whole repo instead and `cd` into the folder you want:
```bash
git clone https://github.com/<owner>/Multi-Bit-Comparator.git
cd Multi-Bit-Comparator/Serialized_Comparator
```

---

## Building

### Build fails: "No rule to make target ... trace.d"
```
make: *** No rule to make target '.../import/esdl/intf/verilator/trace.d', needed by 'Serialized_Comparator'.  Stop.
```
(`make: ***` is how `make` marks any error that stops the build. It isn't part of the problem.)

Your eUVM version doesn't match the makefile.
- **eUVM beta61 and later** ship `esdl/intf/verilator/trace` as compiled `.di` interface files, and the code is inside `libesdl-ldc-shared.so`.
  This repo's makefile is already set up for that.
- **eUVM beta59 and earlier** ship `trace.d` as source, and it must be compiled in.
  Add `$(LDC2BINDIR)/../import/esdl/intf/verilator/trace.d \` back into the `Serialized_Comparator:` dependency list.

Check which version you have with `ls $(dirname $(which ldc2))/../import/esdl/intf/verilator/`.

### `make: Nothing to be done for 'all'.`
This isn't an error. `make` only rebuilds a target when it's missing or older than one of its inputs.
The executable is already up to date, so there's nothing to do.
To force a full rebuild: `make clean && make`.

### `make` vs `make run`: I ran `make` but there's no simulation output
`make` with no target builds the **first** target in the makefile, `all`. That only **compiles**.
`make run` compiles if needed **and runs** the simulation.

| Command | What it does |
|---|---|
| `make` | build the executable only |
| `make run` | build if needed, then run `./Serialized_Comparator +UVM_TESTNAME=Test.test ...` |
| `make clean` | delete all build products, **including the `.vcd` waveform** |

### `error while loading shared libraries: libuvm-ldc-shared.so`
The program can't find the eUVM runtime libraries. Add the eUVM `lib` folder to the library search path:
```bash
export LD_LIBRARY_PATH=<euvm-install>/lib:$LD_LIBRARY_PATH
```

---

## Running and checking

### `grep "UVM_ERROR :" run.log` prints nothing
`run.log` doesn't contain a simulation. You probably ran `make 2>&1 | tee run.log` (build only) instead of `make run 2>&1 | tee run.log`.
`tee` **overwrites** the file each time, so `run.log` only ever holds the output of the last command you piped into it.

### I edited a testbench file but the results didn't change
Check these in order:
1. **Did the file save?** Run `git diff`. Your change should appear. If it doesn't, the editor didn't save.
2. **Are you on the right branch?** Run `git branch`. The `*` marks the current branch.
3. **Did you re-run the simulation?** Run `make run`, not just `make`. It rebuilds automatically when a `.d` file changes, and you'll see an `ldc2 ...` line.
4. **Is your log fresh?** Run `ls -l run.log ../testbench/*.d`. The log should be **newer** than the file you edited.

### The `.vcd` file disappeared
`make clean` runs `rm -rf Serialized_Comparator*`, and that pattern also matches `Serialized_Comparator.vcd`.
Run `make run` again to regenerate it.

---

## Waveforms

### `Could not initialize GTK! Is DISPLAY env var/xhost set?`
gtkwave is a graphical program, and your terminal (usually an SSH session to a server) has no display to draw on.
`echo $DISPLAY` will print nothing. You have three options:

1. **X forwarding:** reconnect with `ssh -X user@server`. Your local machine needs an X server:
   Linux has one built in; on macOS install XQuartz; on Windows use MobaXterm or VcXsrv.
2. **In VS Code (Remote-SSH):** install a VCD viewer extension such as *VaporView*, and click the `.vcd` file.
3. **Download and view locally:** copy the `.vcd` to your machine (`scp`, or right-click and choose **Download** in VS Code), and open it with a local gtkwave.

### Opening a downloaded VCD with gtkwave in WSL (Windows)
Windows drives appear under `/mnt/` in WSL: `D:\path\to\folder` becomes `/mnt/d/path/to/folder`.
```bash
cd /mnt/d/path/to/folder
gtkwave Serialized_Comparator.vcd &
```
Windows 11 shows the window automatically (WSLg).

### The waveform ends at 620 ns, but the log mentions times like 90000
The VCD timescale is **1 ps** (look for `$timescale` at the top of the file), and the `@ <time>` values in `run.log` are also in ps.
So `@ 90000` means **90 ns**, not 900 ns. One clock cycle is 20 ns = 20000 ps.
gtkwave shows the time of the last recorded value change, which is slightly before the simulation's end time.

### Re-adding all the signals every time is tedious
After setting up your signals, use **File → Write Save File** (for example, `comp.gtkw`).
Next time, open both files: `gtkwave Serialized_Comparator.vcd comp.gtkw &`.

---

## Git

### `git diff` shows strange `ESCOC` / `ESCOD` text, and then `[1]+ Stopped git diff`
- Long `git diff` output opens in a **pager** (`less`). Press **`q`** to quit, **Space** to scroll and **`/word`** to search.
- `ESCOC` / `ESCOD` are terminal escape codes (for example, from window focus changes) shown as text. They're harmless.
- **Ctrl+Z doesn't quit.** It *suspends* the program as a background job. Type `fg` to bring it back, then press `q`.
- To skip the pager: `git --no-pager diff`.

### How do I undo my changes to a file?
`git checkout -- <file>` (or `git restore <file>`) discards uncommitted changes and puts the file back to the last commit.

### How do I see the reference solution?
```bash
git checkout solution
```
Try the fix yourself first. To compare your version with the reference: `git diff main solution -- Serialized_Comparator/testbench`.
