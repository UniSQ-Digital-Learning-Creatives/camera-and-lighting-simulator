# Camera and Lighting Simulator

A browser-based virtual photo studio for teaching camera settings and studio lighting. Students set up a camera
and a three-point light rig around a photorealistic subject and see, live, the photo they would make. Every
control is tied to a simplified but physically grounded model, so what they learn carries over to a real camera.

Built with a WebGPU fork of the Godot engine and published as a web build.

## What students can do

- **Camera:** pick a sensor (Full Frame, APS-C, Micro Four Thirds) and a focal length (18–200mm). The field of
  view and crop factor follow from the sensor size.
- **Exposure:** set aperture, shutter speed and ISO (the exposure triangle) and white balance.
  - **Light meter:** an incident light meter shows over or under exposure in stops.
  - **Noise:** sensor noise is modelled from photon counts, so it grows with ISO, darker exposures and smaller
    sensors. An "Exaggerate noise" option makes it easier to see.
- **Focus and depth of field:** autofocus tracks the subject's face, and manual focus is a slider. Depth of
  field comes from the thin-lens model, and the panel reads out the zone of acceptable sharpness.
- **Lighting:** key, fill and rim lights, each with angle, distance, height, colour temperature and
  intensity.
- **Monitoring:** a live histogram that warns when highlights or shadows clip, zebra stripes, false colour,
  and rule-of-thirds, action-safe and title-safe guides.
- **Subject:** a MetaHuman sitter who blinks, breathes and sways slightly, with Play, Pause and Reset controls.
- **Presets and downloads:** save and reload set-ups. Download the photo the camera takes, or a screenshot of
  the whole screen.

The disclaimer in the app applies: this is an indicative representation of camera and lighting behaviour, and
it may not fully reflect real-world equipment or physical results.

## Requirements

- **The Godot WebGPU fork** ([godotwebgpu](https://github.com/dwalter/godotwebgpu), 4.8-dev), its editor, and its
  web export templates (`web_dlink_nothreads_release`). Stock Godot can't open this project properly, because the
  subject is a MetaHuman (`scenes/Ava/head.dna`) that only imports through the fork's MetaHuman importer.
- **Git LFS.** The MetaHuman, studio models and textures are stored with Git LFS (~550 MB). Install it before
  cloning (`git lfs install`), or the asset files will only be small pointer files.

## Getting started

```bash
git lfs install
git clone https://github.com/UniSQ-Digital-Learning-Creatives/camera-and-lighting-simulator.git
```

Open the folder in the fork's editor. The first import takes a while, because the MetaHuman's rig, clothing and
hair are built during import. The main scene is `scenes/camera_studio.tscn`; press Play to run it.

## Exporting for the web

Use the **Web** export preset, either from the editor or from the command line:

```bash
godot --path . --rendering-driver vulkan --export-release "Web" builds/index.html
```

- **The preset precompiles its shaders** ("shader baker"), so the page starts in a few seconds instead of
  compiling shaders in the browser for about a minute. Baking needs a real GPU and display, so **don't add
  `--headless`**: a headless export skips the bake without warning. A good export includes
  `index.shaders.pck`.
- **Download size:** `index.pck` (~90 MB), the shader pack (~97 MB), and one of the two texture packs (~68 MB;
  the browser fetches only the format its GPU uses).
- **Hosting:** serve the build over HTTP(S) with gzip or Brotli enabled. The text-based shader pack in
  particular compresses well.
- **Browser support:** the build needs a browser with WebGPU, such as current Chrome or Edge. On phones it uses
  smaller shadow maps and lighter effects.

## Project layout

| Path | Contents |
|---|---|
| `scenes/camera_studio.tscn` | The main scene: the studio, camera, lights, subject and all of the UI |
| `scripts/` | `main.gd` (lens, lights, white balance, depth of field, presets, downloads), `camera_settings.gd` (the settings resource and shared helpers), `exposure_controller.gd` (exposure, noise and light meter), `ava_idle.gd` (the subject's idle animation), and the 2D teaching diagrams |
| `scenes/*.gd` | Focus (`camera_controller.gd`), the monitor and its shader hooks, the histogram, and the guide overlays |
| `shaders/zebra.gdshader` | The monitor: sensor noise, zebras and false colour |
| `prefabs/` | The MetaHuman subject (`ava.tscn`) and the studio set (`studio_setup.scn`) |
| `scenes/Ava/` | The MetaHuman export the subject is imported from |
| `data/default_settings.tres` | Default camera and lighting settings |
| `UI/` | Theme, styles and fonts |
| `tools/ui_harness.gd` | A test tool that drives the UI and saves screenshots (not exported) |

## Credits

The Camera Studio Simulator was developed by **Innovative Media and Design | Learning and Teaching Futures,
University of Southern Queensland**. It is intended for educational purposes and not to be used commercially.

- MetaHumans by Epic Games: <https://www.metahuman.com/license>
- "Studio Setup" (<https://skfb.ly/opCzL>) by Render Blue, licensed under Creative Commons Attribution 4.0
  (<http://creativecommons.org/licenses/by/4.0/>)
- Open Sans, licensed under the SIL Open Font License 1.1

## Licence

The project's own code is under the MIT License (see `LICENSE`). The third-party assets listed above are
covered by their own licences and terms, which also apply to builds that include them.
