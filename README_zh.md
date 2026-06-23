# UWB-TWHP 后处理工具链

**UWB-TWHP**（Ultra-Wideband Through-Wall Human Pose，超宽带穿墙人体姿态）数据集的后处理流水线。该工具链读取原始雷达回波和光学动作捕捉数据，经过对齐、清洗后，生成结构化的 `.mat` 数据集文件，可直接用于穿墙场景下的人体姿态估计模型训练。

## 功能概览

本流水线按顺序完成以下步骤：

1. **雷达数据读取** — 解析二进制 `.NOV` 文件，提取 FMCW 雷达 ADC 原始采样数据。
2. **距离像生成** — 通过 FFT 脉冲压缩、逐通道距离补偿和穿墙校准，生成复数值距离像。
3. **动捕数据读取** — 解码 NOKOV 光学动捕 JSON 文件，提取人体 16 个关键关节点的三维坐标。
4. **帧数对齐** — 将动捕帧数裁剪至与雷达帧数一致。
5. **异常帧检测** — 识别并剔除动捕丢帧（标记点丢失导致的异常值）。
6. **标签生成** — 从目录结构中解析出每个人员的动作标签和置信度掩码。
7. **训练/测试集划分** — 将每次采集的数据按前 80% 为训练集、后 20% 为测试集进行分割。
8. **持久化存储** — 将每个片段保存为 `-v7.3` 格式的 `.mat` 文件，变量均使用单精度浮点数。

## 项目结构

```
.
├── dataset_build.m                    # 主入口 — 编排完整流水线
├── gen_range_data_complex.m           # 距离像生成（FFT + 穿墙补偿）
├── read_NOV.m                         # 二进制 .NOV 文件读取器（FMCW 雷达 ADC 数据）
├── NOKOV_json_read.m                  # NOKOV JSON 动捕数据解析（16 关节点骨架）
├── detectAbnormalFramesVectorized.m   # 向量化异常帧检测
├── extractHNumbers.m                  # 从字符串中提取数值（正则表达式）
├── letterVarCombine.m                 # 字母 + 数值 → 标识符字符串
├── msTimestamp2beijing.m              # UTC 毫秒时间戳 → 北京时间字符串
├── data_info.mat                      # 系统参数（天线位置、采样配置等）
├── buchang_tieqiang_8m_wall.mat       # 穿墙距离补偿系数
```

## 数据流向

```
.NOV 文件 ──► read_NOV() ──► gen_range_data_complex() ──► 复数值距离像
                                                              │
NOKOV .json ──► NOKOV_json_read() ──► 关节点坐标 ────────────┤
                                                              │
                                          帧对齐 &              │
                                          异常帧清理 ──────────┤
                                                              │
                                          动作/置信度标签 ─────┤
                                                              │
                                          训练/测试集划分 ─────┤
                                                              │
                                          .mat 输出  ◄─────────┘
```

## 输入数据目录结构

流水线要求原始数据按以下层级组织：

```
<根目录>/
  <人数>/                  # 如 "1"、"2"、"3"（场景中的人数）
    <受试者>/              # 如 "H01"、"H02"（受试者编号）
      <动作>/              # 如 "A01_walk"、"A02_jump"（动作编号）
        <采集序号>/         # 同一动作的多次采集，按数字编号
          nokov.json       # 本次采集的动捕数据
          *.NOV            # 本次采集的雷达数据
```

- **人数** 目录名需包含人数数字（1/2/3）。
- 双人或三人场景下，**动作** 目录名可能带有数字前缀（如 `01_A01_walk`），程序会自动去除前缀。

## 输出文件格式

每个 `.mat` 文件包含以下变量：

| 变量               | 类型     | 维度                        | 说明                                |
|--------------------|----------|-----------------------------|-------------------------------------|
| `radar_data_real`  | `single` | `[512, 64, F]`              | 距离像实部                          |
| `radar_data_imag`  | `single` | `[512, 64, F]`              | 距离像虚部                          |
| `joint`            | `single` | `[maxBodies, 48, F]`        | 3D 关节点坐标（16 个关节 × x/y/z）  |
| `action`           | `single` | `[maxBodies, 1, F]`         | 每人的动作标签                      |
| `conf`             | `single` | `[maxBodies, 1, F]`         | 置信度掩码（1 = 有效，0 = 无效）    |

- `F` = 对齐和清理后的帧数。
- `maxBodies` = 所有帧中检测到的最大人体数量。
- 16 个关节点依次为：Head（头）、Neck（颈）、Spine（脊柱）、Spine3（脊柱3）、LeftArm（左上臂）、LeftForeArm（左前臂）、LeftHand（左手）、RightArm（右上臂）、RightForeArm（右前臂）、RightHand（右手）、LeftUpLeg（左大腿）、LeftLeg（左小腿）、LeftFoot（左脚）、RightUpLeg（右大腿）、RightLeg（右小腿）、RightFoot（右脚）。
- 关节点坐标已通过 `radar_x` 和 `radar_y` 参数转换至以雷达为原点的坐标系。

## 运行环境

- **MATLAB** R2020b 或更高版本（在 Windows 下测试；`.mat` 文件使用 `-v7.3` HDF5 格式存储）。
- 无需额外工具箱，仅依赖 MATLAB 核心功能。
- 需要预先准备好的校准文件：
  - `data_info.mat` — 需包含 `antenna_posi`（天线几何布局）及其他系统参数。
  - `buchang_tieqiang_8m_wall.mat` — 需包含 `L`（距离补偿长度）和 `P`（逐通道相位补偿系数）。

## 参数配置

运行前请修改 `dataset_build.m` 文件顶部的以下变量：

| 变量              | 说明                                   |
|-------------------|----------------------------------------|
| `radar_x`         | 雷达在动捕坐标系中的 x 偏移量（米）     |
| `radar_y`         | 雷达在动捕坐标系中的 y 偏移量（米）     |
| `pathSave_*`      | 训练/测试集的输出路径（按人数 1–3 分列）|
| `FolderRoot`      | 原始输入数据的根目录                   |

## 使用步骤

1. **检查校准文件** — 确保 `data_info.mat` 和 `buchang_tieqiang_8m_wall.mat` 存在且参数正确。
2. **配置路径参数** — 在 `dataset_build.m` 中设置 `FolderRoot` 和各 `pathSave_*` 变量。
3. **运行流水线**：
   ```matlab
   dataset_build
   ```
4. **观察输出** — 控制台会打印进度信息，包括帧数统计、异常帧检出情况以及每个文件的保存确认。

## 作者

- Toby Wong

## 许可

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。
