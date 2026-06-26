# UWB-TWHP Post-processing

English | [简体中文](README_zh.md)

Post-processing pipeline for the **UWB-TWHP** (Ultra-Wideband Through-Wall Human Pose) dataset. This toolchain ingests raw radar returns and optical motion-capture data, aligns and cleans them, and produces structured `.mat` datasets ready for training human pose estimation models in through-wall scenarios.

## Dataset link

Please visit the UWB-TWHP dataset details page<https://github.com/Toby154/UWB-TWHP_Page>

## Overview

The pipeline performs the following steps end-to-end:

1. **Radar reading** — Parses binary `.NOV` files containing raw FMCW radar ADC samples.
2. **Range processing** — Applies FFT-based pulse compression, per-channel range compensation, and through-wall calibration to produce complex-valued range profiles.
3. **Mocap reading** — Decodes NOKOV optical motion-capture JSON files and extracts 3D positions of 16 key body joints.
4. **Frame alignment** — Trims mocap frames to match the radar frame count.
5. **Anomaly detection** — Identifies and removes frames where mocap tracking is lost (marker dropouts).
6. **Label generation** — Derives per-person action labels and confidence masks from the directory structure.
7. **Train/test split** — Splits each recording into training (first 80% of frames) and test (last 20%) subsets.
8. **Persistence** — Saves each clip as a `-v7.3` `.mat` file containing single-precision tensors.

## Repository Structure

```
.
├── dataset_build.m                    # Main entry point — orchestrates the full pipeline
├── dataset_visualizer.m               # Interactive MAT dataset viewer
├── gen_range_data_complex.m           # Range-profile generation (FFT + through-wall compensation)
├── read_NOV.m                         # Binary .NOV file reader (FMCW radar ADC data)
├── NOKOV_json_read.m                  # NOKOV JSON mocap parser (16-joint skeleton)
├── detectAbnormalFramesVectorized.m   # Vectorized abnormal-frame detector
├── extractHNumbers.m                  # Numeric extraction from strings (regex)
├── letterVarCombine.m                 # Letter + number(s) → identifier string
├── msTimestamp2beijing.m              # UTC ms timestamp → Beijing time string
├── data_info.mat                      # System parameters (antenna positions, sampling config)
├── buchang_tieqiang_8m_wall.mat       # Through-wall range compensation coefficients
```

## Data Flow

```
.NOV files ──► read_NOV() ──► gen_range_data_complex() ──► complex range data
                                                                 │
NOKOV .json ──► NOKOV_json_read() ──► joint positions ─────────┤
                                                                 │
                                            Frame alignment &    │
                                            anomaly cleanup ─────┤
                                                                 │
                                            Action/conf labels ──┤
                                                                 │
                                            Train/test split ────┤
                                                                 │
                                            .mat output  ◄───────┘
```

## Input Data Layout

The pipeline expects a directory tree organised as:

```
<RootFolder>/
  <PersonCount>/           # e.g. "1", "2", "3" (number of people)
    <Subject>/             # e.g. "H01", "H02" (subject identifier)
      <Action>/            # e.g. "A01_walk", "A02_jump" (action identifier)
        <Clip>/            # Sequential clip number
          nokov.json       # Mocap data for this clip
          *.NOV            # Radar data for this clip
```

- **PersonCount** directory names must start with or contain the person count (1/2/3).
- **Action** directory names for multi-person cases (2–3 people) may have a numeric prefix that is stripped automatically (e.g. `01_A01_walk` → `A01_walk`).

## Output Format

Each saved `.mat` file contains the following variables:

| Variable           | Type     | Dimensions                  | Description                                   |
|--------------------|----------|-----------------------------|-----------------------------------------------|
| `radar_data_real`  | `single` | `[512, 64, F]`              | Real part of the range profile                |
| `radar_data_imag`  | `single` | `[512, 64, F]`              | Imaginary part of the range profile           |
| `joint`            | `single` | `[maxBodies, 48, F]`        | 3D joint positions (16 joints × x/y/z)        |
| `action`           | `single` | `[maxBodies, 1, F]`         | Per-person action label                       |
| `conf`             | `single` | `[maxBodies, 1, F]`         | Confidence mask (1 = valid, 0 = invalid)      |

- `F` = number of frames after alignment and cleanup.
- `maxBodies` = maximum number of bodies detected across all frames.
- The 16 joints (in order): Head, Neck, Spine, Spine3, LeftArm, LeftForeArm, LeftHand, RightArm, RightForeArm, RightHand, LeftUpLeg, LeftLeg, LeftFoot, RightUpLeg, RightLeg, RightFoot.
- Joint coordinates are transformed into a radar-centric coordinate system using `radar_x` and `radar_y` offsets.

## Dependencies

- **MATLAB** R2020b or later (tested on Windows; `.mat` files use `-v7.3` HDF5 format).
- No external toolboxes required beyond core MATLAB.
- Pre-computed calibration files:
  - `data_info.mat` — must contain `antenna_posi` (antenna geometry) and other system parameters.
  - `buchang_tieqiang_8m_wall.mat` — must contain `L` (range compensation lengths) and `P` (per-channel phase compensation).

## Configuration

Edit the following variables at the top of `dataset_build.m` before running:

| Variable          | Description                                                  |
|-------------------|--------------------------------------------------------------|
| `radar_x`         | Radar x-coordinate offset for mocap coordinate transform (m) |
| `radar_y`         | Radar y-coordinate offset for mocap coordinate transform (m) |
| `pathSave_*`      | Output directories for train/test splits (persons 1–3)       |
| `FolderRoot`      | Root directory of the raw input data                         |

## Usage

### Dataset Visualization

Run the interactive viewer in MATLAB:

```matlab
dataset_visualizer
```

Click **Select MAT File** to load a generated dataset file. The viewer shows the full range-time map, the selected frame's real and imaginary radar data, the 3D skeleton, and per-person action labels. Playback, pause, previous-frame, next-frame, and slider controls are available in the top control bar.

### Dataset Generation

1. **Verify calibration files** — Ensure `data_info.mat` and `buchang_tieqiang_8m_wall.mat` are present and contain the correct system parameters.
2. **Configure paths** — Set `FolderRoot` and `pathSave_*` variables in `dataset_build.m`.
3. **Run the pipeline**:
   ```matlab
   dataset_build
   ```
4. **Monitor output** — The console will print progress messages including frame counts, detected anomalies, and per-file save confirmations.

## Authors

- Toby Wong

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
