# Face Detection & Recognition on DE2-115 — User Manual

Quartus project: `designfile_testing/vj.qpf` (revision `top`), all logic in Verilog (`.v`).
Board: Terasic DE2-115 (Cyclone IV EP4CE115F29C7). Camera: OV7670 on the 40-pin GPIO header.

The system shows live camera video, finds faces (Viola-Jones), draws a green box around each face and labels it with the
name of the enrolled person it matches and a match score — or `UNKNOWN`. Up to **4 people** can be enrolled; they are
stored in the on-board flash and survive power-off. The design itself is stored in the EPCS boot memory, so the board
starts the system on its own at power-on (no PC needed).

---

## 1. Hardware setup

| Item | Setting |
|---|---|
| **SW19 (RUN/PROG)**, left edge near the LCD | **RUN** (otherwise the board does not boot the design) |
| Power | 12 V adapter, red power button |
| Monitor | VGA connector (blue, 15-pin); select **VGA input** on the monitor |
| USB-Blaster | Only needed to reprogram the board (USB port marked *USB-Blaster*) |

### Camera wiring (OV7670 → GPIO header)

The FPGA pins below are what the design uses (`top.qsf`). **D7 is on GPIO[8] (header pin 9), not GPIO[7]** — header
pin 8 on this board does not make reliable contact.

| Camera pin | FPGA pin | GPIO | Header pin |
|---|---|---|---|
| D0 | AB22 | GPIO[0] | 1 |
| D1 | AC15 | GPIO[1] | 2 |
| D2 | AB21 | GPIO[2] | 3 |
| D3 | Y17 | GPIO[3] | 4 |
| D4 | AC21 | GPIO[4] | 5 |
| D5 | Y16 | GPIO[5] | 6 |
| D6 | AD21 | GPIO[6] | 7 |
| **D7** | **AD15** | **GPIO[8]** | **9** |
| PCLK | AC19 | GPIO[10] | 13 |
| XCLK | AF16 | GPIO[11] | 14 |
| PWDN | AD19 | GPIO[12] | 15 |
| RESET | AF15 | GPIO[13] | 16 |
| SIOC (SCL) | AF24 | GPIO[14] | 17 |
| SIOD (SDA) | AE21 | GPIO[15] | 18 |
| VSYNC | AF25 | GPIO[16] | 19 |
| HREF | AC22 | GPIO[17] | 20 |
| 3.3 V / GND | — | — | 29 / 30 |

Use **LEDG0–LEDG7** (section 4) to check the data wires: all 8 must be lit with a normal scene in front of the camera.

---

## 2. Power-on

1. Turn the board on. Within about a second:
   * **LEDR0** (PLL locked) and **LEDR1** (camera configured) light,
   * **LEDR5** flashes briefly while the enrolled people are read from flash,
   * live video appears on the monitor.
2. With people in view, **LEDR2** starts toggling (one change per detection pass) and green boxes appear.

### Screen layout

* **Left, 320×240:** live camera video. Each detected face gets a green box and a label
  `NAME  NN%` on a black strip above it (below it if the box touches the top edge).
* **Right:** enrollment gallery — 4 slots, each with the stored photo (or a dark square), the name and `ENROLLED` / `EMPTY`.
  The slot selected for enrollment has a grey border, **yellow** while enrollment is waiting.

---

## 3. Switches and keys

Switches are the slide switches along the bottom edge; **up = 1**. Unlisted switches have no function.

| Control | Function |
|---|---|
| **SW17** | Reset. Keep **down**. Up holds the system in reset (no detection). |
| **SW16** | Resend camera registers. Hold **up for ~1 s** then down — use if colours look wrong after the camera was re-plugged. |
| **SW15** | Capture mode. **Down = continuous detection** (normal). Up = detect one frame each time KEY0 is pressed. |
| **SW14** | Test image. Up = freeze the screen and the detector on the built-in face-grid test image (camera ignored). Normal: down. |
| **SW13** | Overlay. Up = show boxes and labels. Down = clean live video. |
| **SW11–SW10** | Enrollment slot (see table below). |
| **SW2–SW0** | Minimum face-group size (binary 0–7). A face is shown only if more raw detections than this agree. Recommended **3** (SW0 + SW1 up). Raise if stray boxes appear, lower if real faces are missed. |
| SW3–SW9, SW12 | Not used. |
| **KEY0** | Capture one frame (only when SW15 is up). |
| **KEY1** | Enroll the person in front of the camera into the selected slot (section 5). |
| KEY2 | Not used. |
| **KEY3** | **Forget everyone**: clears all 4 slots and erases them from flash. |

Enrollment slot (names are set in `person_names.v`, section 7):

| SW11 | SW10 | Slot | Name (current) |
|---|---|---|---|
| down | down | 0 | ANNET MARIA |
| down | up | 1 | ANITA PAUL |
| up | down | 2 | SHAMEER |
| up | up | 3 | NAIDU SIR |

The recognition threshold is fixed at **75 %** — there is nothing to set.

---

## 4. LEDs

### Red LEDs (LEDR)

| LED | Meaning |
|---|---|
| **LEDR0** | PLL locked (clocks running). Always on in normal operation. |
| **LEDR1** | Camera configuration finished. Always on in normal operation. |
| **LEDR2** | Detection pass completed — **toggles** after every pass (about every 1–2 s). Steady = detection is not running (check SW17/SW15). |
| **LEDR3** | The last pass found at least one raw face detection. |
| **LEDR4** | Enrollment waiting / in progress (KEY1 pressed). Goes off after 4 views are stored. |
| **LEDR5** | Flash busy: reading at power-on, saving after an enrollment (1–2 s), or erasing (KEY3). |
| LEDR6–LEDR9 | Main state machine state (diagnostic, binary, LEDR6 = bit 0). Flickers in normal operation. |
| LEDR10–LEDR13 | Recognizer state (diagnostic, binary, LEDR10 = bit 0). Flickers when faces are present. |
| LEDR14–LEDR17 | Not used. |

### Green LEDs (LEDG)

| LED | Meaning |
|---|---|
| **LEDG0–LEDG7** | Camera data line D0–D7 is toggling. All 8 should be lit with a normal scene. A **dark or blinking** LED means that data wire is loose or on the wrong header pin (wrong colours, cyan highlights, speckle). |
| LEDG8 | Not used. |

### Diagnostic state codes (only needed for troubleshooting)

LEDR6–9 = main state machine (value = LEDR9·8 + LEDR8·4 + LEDR7·2 + LEDR6):

| Value | State | If it stays here |
|---|---|---|
| 0 | RESET | SW17 is up |
| 1 | CAPTURE_START | SW15 is up and KEY0 not pressed, or no camera frames (check PCLK/VSYNC wires) |
| 2 | CAPTURE | camera frames not arriving |
| 3–8 | detection (integral image / cascade / next scale) | normal, changes quickly |
| 9–10 | FACEBOX_START / FACEBOX | normal, changes quickly |
| 11 | POST | waiting for flash (LEDR5 on) |
| 12 | ENROLL | recognizer running (LEDR10–13 flicker) |

LEDR10–13 = recognizer (value = LEDR13·8 + LEDR12·4 + LEDR11·2 + LEDR10): 0 idle, 1 next face, 2 crop, 3–6 LBP
histogram, 7 store enrollment view, 8 compare, 9–10 search positions, 11–13 score, 14 done.

---

## 5. Enrolling people

Enroll each person once; they stay stored across power-off.

1. Set **SW13 up** (overlay), **SW15 down**, **SW17 down**.
2. Select the slot with **SW11–SW10** (section 3). The slot gets a grey border in the gallery.
3. The person stands **alone** in front of the camera, at the distance and **lighting** that will be used later, until a green box appears.
4. Press **KEY1** once. **LEDR4** lights and the border turns **yellow**.
5. **While LEDR4 is on (about 4 detection passes, a few seconds), the person slowly changes pose:**
   looking straight → head a little left → a little right → chin a little up or down.
   Each pass stores one of 4 separate views. Keep the movements small so the face stays detected.
6. LEDR4 goes off, the photo appears with `ENROLLED`, and **LEDR5** lights for 1–2 s while it is saved to flash.
7. Select the next slot and repeat.

* **Re-enroll** a person: select their slot and press KEY1 again — the 4 new views replace the old ones.
* **Forget everyone:** press **KEY3** (all slots `EMPTY`, flash erased).
* If LEDR4 stays on, no face is being detected — move closer, improve lighting, check SW13/SW15/SW17.

---

## 6. Recognition

* Every detected face (up to 4 at once) is compared with every enrolled person after each detection pass.
* The label shows the best matching name and its **match score**. A score of **75 % or more** shows the name; below
  75 % the label shows `UNKNOWN` with the score.
* Typical scores: enrolled person **80–95 %**, strangers **55–75 %**. The score is a similarity value, not a probability.
* Measured on a 40-person face database with this exact algorithm: correct name for enrolled people about 95 %, about
  85 % correct overall including rejecting strangers. On the board, results are best when enrollment and use happen
  in the **same lighting**, faces look roughly at the camera, and faces are at least ~50 pixels wide on the screen.

---

## 7. Changing names, rebuilding, reprogramming

### Change a name

Edit `designfile_testing/person_names.v` — each name is **exactly 12 characters** (pad with spaces), letters A–Z,
digits, space and `- . _`:

```verilog
localparam [95:0] NAME0 = "ANNET MARIA ";
```

Enrolled faces are not affected by a name change (they stay in flash, linked to the slot).

### Rebuild and make it permanent (from a terminal)

```bash
cd designfile_testing
```

```bash
D:/intelFPGA/quartus/bin64/quartus_sh.exe --flow compile vj -c top
```

Check in `output_files/top.sta.rpt` that every clock has positive setup slack, then write the boot memory and load it:

```bash
D:/intelFPGA/quartus/bin64/quartus_cpf.exe -c -d EPCS64 -s EP4CE115 output_files/top.sof output_files/top.jic
```

```bash
D:/intelFPGA/quartus/bin64/quartus_pgm.exe -c "USB-Blaster [USB-0]" -m JTAG -o "pvi;output_files/top.jic"
```

```bash
D:/intelFPGA/quartus/bin64/quartus_pgm.exe -c "USB-Blaster [USB-0]" -m JTAG -o "p;output_files/top.sof"
```

The last command starts the new design immediately; otherwise it starts at the next power-on. If a programming step
fails with "Can't scan JTAG chain", run it again (the USB-Blaster connection occasionally drops).
Enrolled people survive reprogramming — they are in the separate parallel flash.

The USB-Blaster driver that works on this PC is the re-signed one from
`C:\intelFPGA\22.1std\qprogrammer\drivers\usb-blaster` (the Quartus 20.1 driver's certificate has expired).

---

## 8. Troubleshooting

| Symptom | Check |
|---|---|
| Monitor says "no signal" | Monitor input set to VGA; VGA cable seated; LEDR0 on. |
| Black screen, LEDs dark after power-on | SW19 on RUN; power-cycle fully (blue LED off for 5 s). |
| Colours wrong (cyan highlights, green/magenta, speckle) | LEDG0–7 all lit? Reset the wire of a dark/blinking LEDG. Toggle SW16 to resend camera settings. |
| No boxes | SW13 up; LEDR2 toggling? If not: SW17 and SW15 down. Try SW2–SW0 lower. |
| Many stray boxes | Raise SW2–SW0 (e.g. 4 or 5). |
| Everyone `UNKNOWN` | Enroll again in the current lighting (section 5), with the 4 pose changes. |
| Wrong name | Re-enroll that person and the person it confuses them with, same lighting as use. |
| LEDR4 stays on | No face detected during enrollment — see section 5. |
| Enrolled people missing after power-on | LEDR5 should flash at power-on; re-enroll once (old saves from earlier design versions are ignored). |

---

## 9. Design files (in `designfile_testing/`)

| File | Role |
|---|---|
| `top.v` | Top level: data flow, clocks, main state machine, switches/LEDs |
| `ov7670_controller.v`, `ov7670_registers.v`, `i2c_sender.v` | Camera configuration over SCCB |
| `ov7670_capture.v` | Camera capture, 320×240 colour + full-precision grey |
| `dp_ram.v` | Dual-clock RAM used for all frame buffers and tables |
| `vga.v`, `Address_Generator.v`, `RGB.v` | VGA timing and output |
| `ii_gen.v`, `pixel_offset.v` | Integral images for detection |
| `subwindow_top.v`, `subwindow.v`, `feature_calc.v`, `rect_calc.v`, `var_norm_calc.v`, `register_file*.v`, `ii_address_*.v`, `iix2_address_decoder.v`, `parallel_dataPath_mux.v`, `ram.v` | Viola-Jones cascade (16 subwindows in parallel); parameters in the `.txt` / `.mif` files |
| `faceBox.v` | Collects raw detections and replays them as boxes |
| `face_cluster.v` | Groups raw detections into faces (min group size SW2–SW0) |
| `face_crop.v`, `lbp_uniform.v`, `face_recognizer.v` | Face crop and LBP recognition (4 views per person, fixed 75 % threshold) |
| `flash_store.v` | Saves/loads enrolled people in the parallel flash |
| `box_overlay.v`, `enroll_gallery.v`, `font8x8.v`, `person_names.v` | On-screen boxes, labels, gallery, font, names |
| `cam_bit_monitor.v` | LEDG camera-wire monitor |
| `my_altpll.*`, `ii_buffer.*`, `iix2_buffer.*`, `faceBox_buff.*`, `altsqrt_varianceCalc.*` (`.v`, `.qip`, `.bsf`, `_inst.v`, `_bb.v`, `my_altpll.ppf`) | Quartus MegaWizard-generated PLL/RAM/square root — do not edit by hand, keep each set complete |

Data and project files:

| File | Role |
|---|---|
| `*_rect*.txt`, `weight*.txt`, `weakThresh.txt`, `weakStageNum.txt`, `strongThresh.txt`, `left_tree.txt`, `right_tree.txt` | Cascade parameters loaded into the ROMs (`ram.v`, `$readmemh`) — **required** |
| same names `.mif` | Original source of those parameters (the `.txt` files were generated from them) |
| `test_image_grey8.mif`, `test_image_rgb444.mif` | Built-in face-grid test image (SW14) |
| `vj.qpf`, `top.qsf`, `top.out.sdc` | Quartus project, settings/pin assignments, timing constraints |
| `output_files/top.sof`, `output_files/top.jic` | Ready-to-program files (JTAG / EPCS boot memory) |

Every `.v` file starts with a header comment describing its function, clock domain and where it is used.
Unused files from the original design were removed; a full copy of the project before that clean-up is in
`designfile_testing_full_backup_before_cleanup.zip` next to the project folder.
