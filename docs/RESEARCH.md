# Cube representation & solving — research notes

Compiled 2026-09-21. Raw scraped sources are in `.firecrawl/` (gitignored, local only).
Verification scripts that back the bug finding are in this folder: `perm2.py`, `scn.swift`.

---

## 1. Canonical representation (Kociemba)

Three levels, all used by serious implementations:

| Level | Stores | Used for |
|---|---|---|
| Facelet | 54 stickers `U1..U9, R1..R9, …` | I/O, rendering, camera scan |
| **Cubie** | 8 corners + 12 edges, each with permutation **and** orientation | the real state; move composition |
| Coordinate | ints indexing precomputed tables | search |

Cubie naming:
- Corners: `URF UFL ULB UBR DFR DLF DBL DRB`
- Edges: `UR UF UL UB DR DF DL DB FR FL BL BR`

State is four arrays:

```
cp[8]  corner permutation      co[8]  corner orientation (mod 3)
ep[12] edge permutation        eo[12] edge orientation (mod 2)
```

Move composition law (orientation is *not* just a permutation):

```
(A*B)(x).c = A(B(x).c).c
(A*B)(x).o = A(B(x).c).o + B(x).o
```

Orientation reference frame matters: with Kociemba's definition, 10 of the 18 moves
leave all orientations unchanged. That property is what makes the two-phase search work.

Structural invariants:
- Centers never move relative to each other — they *define* the colour scheme.
  "Solved" is relative to centers, not to world space.
- 26 visible cubies in three classes (8 corner / 12 edge / 6 center).
  **Rotations never move a piece between classes.**

Notation: Singmaster — `U D L R F B`, each with `'` and `2` → 18 face moves.
`M E S` slices, wide moves, and `x y z` rotations are conveniences on top.

---

## 2. Audit of this repo (as of 987b227)

**There is no cube state.** `RubiksCube.pieces` is never populated (`resetCube()` → `[]`),
`scramble()` is a no-op that discards its own result, and `CubePiece.colors` is assigned
in `init` and never read anywhere in 2237 lines. The `SCNNode` graph is the only state,
and identity lives in parsed strings (`cube_x_y_z`).

| Standard practice | This repo | |
|---|---|---|
| Cubie-level state | none — scene graph is truth | ✗ |
| Orientation tracked | not at all | ✗ |
| Moves as values (`U`, `R'`) | gestures call `rotateRow/Column/Layer` directly | ✗ |
| Move history / undo | none | ✗ |
| Solved detection | impossible | ✗ |
| Scramble = random moves | synthesises fake touch coords, replays through the gesture recogniser (`performAutoShuffle`) | ✗ |
| Centers anchor colour scheme | slice 1 rotatable, nothing anchors it | ⚠ |
| 26 cubies, 1/2/3 stickers | 27 cubies, 6 stickers each | ⚠ |
| Face-normal hit testing | `findHitWithFace` uses `worldNormal` | ✓ |
| axis = faceNormal × swipe | `planRotation` does exactly this | ✓ |

### What is genuinely right

- **The 6-coloured-die shortcut is visually sound.** Every cubie is red+X / orange−X /
  white+Y / yellow−Y / blue+Z / green−Z. Because rotations preserve piece class and the
  geometry carries its own stickers, solved renders correctly and so does every state
  after. Only cost is cosmetic: internal stickers show through the 0.02 gaps.
- **`planRotation` (ContentView.swift:976) is the textbook derivation.** Project swipe
  onto the touched face's tangent plane, cross with face normal, snap to dominant axis,
  slice index from the hit piece. It replaced ~300 lines of heuristics that are still in
  the file as dead code.

### Dead code (zero call sites — verified by grep)

`scramble()`, `determineRotationAxisAndSlice`, `determineAllowedRotation`,
`fallbackRotation`, `calculateFaceVisibility`, `determineSliceAndDirection`,
`performArbitraryAxisRotation`, `updatePiecePositionAfterArbitraryRotation`
(which is itself a no-op that returns without updating anything),
`rotateEntireCube`, `findHitCubePiece`.

### VERIFIED BUG — `rotateRow` logical permutation is inverted

Column and layer are correct; row alone is wrong. Verified empirically by compiling
against real SceneKit on macOS (`docs/scn.swift`), not by assuming a sign convention:

```
rotateRow  cw=true   SCNAction y:-π/2  → visual lands (2,0,0)   code sets (0,0,2)   ✗
rotateRow  cw=false  SCNAction y:+π/2  → visual lands (0,0,2)   code sets (2,0,0)   ✗
rotateCol  cw=true   SCNAction x:+π/2  → visual lands (0,2,0)   code sets (0,2,0)   ✓
rotateLay  cw=true   SCNAction z:+π/2  → visual lands (2,0,0)   code sets (2,0,0)   ✓
```

Visible, not theoretical — `rotateRow` keeps the animated orientation via `worldTransform`
then **overwrites the translation** from the wrong logical position:

```swift
piece.node.transform = finalTransform   // correct orientation, from the animation
piece.position = (z, y, 2 - x)          // ← inverse of what the animation did
piece.node.position = cleanWorldPos     // ← teleports the cubie to the mirrored slot
```

Every U/D/E turn spins each cubie the right way, then drops it in the wrong slot.
Fix: swap the two branches (pre-fix line 1641; now applied — see "Step 0 — APPLIED" below).

This is **separate** from the `!plan.rightHandPositive` compensation in
`executePlannedRotation:950` — that patches the visual direction and leaves the
bookkeeping inverted either way.

---

## 3. Solving mathematics

State space:

```
8! · 3^7 · 12! · 2^11 / 2 = 43,252,003,274,489,856,000  ≈ 4.3 × 10^19
```

The three divisions are the **parity constraints**: corner twists sum to 0 (mod 3),
edge flips sum to 0 (mod 2), corner+edge permutation parity must match. This is why a
single twisted corner is unsolvable — and why a solver must *validate* input.

**God's number is 20** (half-turn metric), proved 2010 by Rokicki, Kociemba, Davidson,
Dethridge using ~35 CPU-years donated by Google. **26** in the quarter-turn metric.

| Approach | Moves | Cost | Human-explainable? |
|---|---|---|---|
| Korf IDA* (optimal) | 20 max, truly optimal | seconds–hours, big tables | no |
| Kociemba two-phase | ~20–22 typical | ms after table build | no |
| Thistlethwaite | ~45 | small tables | partly |
| Layer-by-layer / CFOP | 50–100 / ~55 | instant, no tables | **yes** |

### Kociemba two-phase

Exploits the subgroup `G1 = <U, D, R2, L2, F2, B2>`. An element is in G1 exactly when
all corner orientations are 0, all edge orientations are 0, and the four UD-slice edges
are somewhere in their slice.

- **Phase 1** — drive `(corner-ori, edge-ori, UD-slice)` to `(0,0,0)`.
  Space: `2187 × 2048 × 495 = 2,217,093,120`
- **Phase 2** — inside G1, restore using only `<U,D,R2,L2,F2,B2>`.
  Space: `40320 × 40320 × 24 / 2 = 19,508,428,800`

Both phases are IDA* over coordinate tables. The trick that makes it near-optimal: it
does **not** stop at the first solution — it keeps trying longer phase-1 maneuvers,
because a worse phase 1 often admits a much shorter phase 2.

---

## 4. Hint engine plan

Gated entirely on fixing the state model. You cannot hint about a cube whose state you
don't know.

**Solver choice is the decision that matters** — they optimise for opposite things:
Kociemba gives ~20 moves that are pedagogically useless; layer-by-layer gives ~60 moves
organised into named stages with recognisable cases, which is exactly what a hint is.
For teaching, LBL wins, and it's the smaller build (no pruning tables, ~500 lines).

The enabler is **stage detection**: LBL solves in strict order, so "what's the first
stage that isn't complete?" *is* the hint.

1. White cross — "Put the white-red edge on the bottom face"
2. White corners — "Bring the white-blue-orange corner above its slot, then `R U R' U'`"
3. Middle layer edges — "The red-blue edge is at UF. Do `U R U' R' U' F' U F`"
4. Yellow cross — "You have a line. Do `F R U R' U' F'`"
5. Yellow edge permutation
6. Yellow corner position
7. Yellow corner orientation

Payoff of the existing code: live `SCNNode` references mean you can **highlight the two
cubies a hint is about directly in the 3D scene** and ghost-animate the move.

### Sequencing (each step independently shippable)

- **Step 0** — fix `rotateRow`. One line. Everything below is untrustworthy until turns are correct.
- **Step 1** — introduce `CubeState` (cp/co/ep/eo, ~150 lines) + `enum Move` (18 face turns).
  State becomes truth; scene becomes a renderer. Deletes the string parsing, node renaming,
  and ~400 lines of dead heuristics. Immediately gives: real scramble, undo/redo, solved
  detection, save/restore.
- **Step 2** — gestures produce `Move` values, not direct animation calls. Add a move *queue*
  (today `isAnimating` silently drops anything during an animation — a solve animation would
  lose most of its moves).
- **Step 3** — LBL solver + stage detector driving the hint UI.

Kociemba can be added later behind the same `Solver` protocol for an optimal
"solve for me" mode. Bigger lift (pruning tables, first-launch generation) — separate decision.

**Caveat:** Step 1 is a genuine rewrite of the core, ~600–800 lines touched. Right move —
the current architecture cannot support hints at all — but not small, and how much of the
existing gesture tuning to preserve through it is a product call.

### OPEN DECISIONS (not yet made)

- Start with Step 0 alone, or commit to the full Step 1 rewrite?
- Hint target: **LBL cues** or **Kociemba optimal**? Shapes the whole solver layer.

---

## Sources

- Kociemba, *The Cubie Level* — https://kociemba.org/math/cubielevel.htm
- Kociemba, *The Two-Phase Algorithm Coordinates* — https://kociemba.org/math/twophase.htm
- Kociemba, *Two-Phase Algorithm Details* — https://kociemba.org/math/imptwophase.htm
- Rokicki et al., *God's Number is 20* — https://www.cube20.org/
- Rokicki, *The Diameter Of The Rubik's Cube Group Is Twenty* (PDF) — https://tomas.rokicki.com/rubik20.pdf
- J Perm, *CFOP Method* — https://jperm.net/3x3/cfop
- muodov/kociemba (C + Python reference port) — https://github.com/muodov/kociemba
- rhcpfan/ios-rubik-solver (iOS precedent) — https://github.com/rhcpfan/ios-rubik-solver

---

## Step 0 — APPLIED (rotateRow fix)

`ContentView.swift:1646` — the two branches swapped, so the permutation matches the
SCNAction sign. `executePlannedRotation:950` needs **no** change: `rotateRow(clockwise:true)`
is still RH− about +Y (only the bookkeeping moved, not the animation), so
`!plan.rightHandPositive` remains correct.

Verified three ways:

1. **Math** — all 6 primitives now agree with their own animations across all 27 cells;
   `x4 == identity` and `cw ∘ ccw == identity` hold.
2. **Build + run** — `xcodebuild` succeeds; app runs on iPhone 16 Pro sim, 7 rotations
   completed, 0 stuck animations, 0 slice collisions.
3. **Regression harness** — `docs/cubesim.swift`, 500 random moves against real SceneKit:

   ```
   swiftc -O -o cubesim cubesim.swift && ./cubesim
   ```

   | | baked-vs-claimed mismatches |
   |---|---|
   | patched | **0** / 4500 |
   | original | **1200** / 4500 |

   The assertion that matters is *baked vs claimed*: the translation the rotation actually
   produced, against the lattice point the updated node name implies. Failure signature was
   the 180° mirror — baked `(+0.34, 0, −0.34)` vs claimed `(−0.34, 0, +0.34)`.

### Note on the bug's actual symptom

The buggy permutation is still a **bijection**, so cubies always occupy 27 distinct lattice
points — `invariant violations: 0` even before the fix. The bug therefore could **never**
produce holes, overlaps or off-grid geometry. Its only symptom was **incoherent stickers**:
each cubie's orientation came from the (correct) baked transform while its slot came from
the (inverted) name, so U/D/E turns spun pieces the right way and filed them in the mirrored
slot. Don't look for visual misalignment when checking this class of bug — compare
geometry against bookkeeping.
