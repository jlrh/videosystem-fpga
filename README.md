# videosystem-fpga

🇬🇧 English (below) · [🇪🇸 Español](#español)

FPGA recreations of **Video System Co.** arcade boards, built on the **JTFRAME** framework (GPLv3).
MiSTer target.

> ℹ️ Independent project — **NOT** an official jotego core. Built on his GPLv3 JTFRAME framework.

## Cores

### Aero Fighters (Video System, 1992)
Vertical shoot-'em-up (newer Aero Fighters hardware, `aerofgt.cpp` MAME driver). Hardware: **MC68000**
main CPU + **Z80** sound CPU + **YM2610** (FM/ADPCM) + two independent tilemap layers and a sprite
engine (`vsystem_spr`, shared across several Video System boards of the era) — no public datasheet for
the video customs, decoded entirely by reverse-engineering against MAME.

**Status: W.I.P.** — playable on MiSTer (boot, video with both tilemap layers + sprites, inputs, DIP
switches and Flip Screen run on hardware); horizontal/vertical timing is now calibrated against
timing data read from a related board's ROM (see `cores/aerofgt/cfg/macros.def`).

### Patch to the framework

This build relies on a **local, unpublished** change to JTFRAME that widens the OSD `H-Position`
range in `target/mister/{cfgstr,hdl/jtframe_mister.sv}` from ±16 to ±32. Without it, the CRT
calibration this core was tuned with (`H-Position=-18`) is out of reach and the picture shows a
larger gap on one side than intended. It only affects the OSD adjustment range, not gameplay or
synthesis timing — the core builds and runs without it.

## Build

1. Clone [jtcores](https://github.com/jotego/jtcores) (brings JTFRAME + the modules listed below).
2. Copy this repo's `cores/aerofgt/` into your jtcores checkout.
3. Build: `jtcore aerofgt -mister -c`.

Core layout:
```
cores/aerofgt/
├── hdl/     Core Verilog
├── mister/  memgen-generated SDRAM top (jtaerofgt_game_sdram.v) + mem_ports.inc
├── cfg/     macros.def, mem.yaml, files.yaml, mame2mra.toml
└── mra/     .mra definition (how to assemble the ROMs)
```

Prebuilt `.rbf` are also published as-is in [`releases/`](releases/) for anyone who'd rather not
build (every ROM is loaded at **runtime** from the `.mra`; the bitstream bakes no game data).

## ROMs

**Not included** (copyrighted material). Everyone provides the original ROMs of their own board for each
game. The `.mra` describes how to assemble them; every ROM is loaded at runtime, so the `.rbf` carries
no copyrighted data.

## Credits

- **JTFRAME** — the GPLv3 framework this core is built on
- **MAME** — hardware reference (`vsystem/aerofgt.cpp` driver, `vsystem/vsystem_spr.cpp` sprite chip,
  `vsystem/vs9209.cpp` I/O)

## Acknowledgements

- To **Sorgelig** and the whole **MiSTer FPGA** project and community.
- To the **MAME community**, for the preservation and reverse-engineering work without which this core
  would not be possible.
- And to **Anthropic**, for **Claude**.

## License

**GPLv3** (see [`LICENSE`](LICENSE)) — required by the JTFRAME dependency; its copyright notices are
preserved in the sources.

---

## Español

🇪🇸 Español · [🇬🇧 English ↑](#videosystem-fpga)

Recreaciones en FPGA de placas arcade de **Video System Co.**, construidas sobre el framework
**JTFRAME** (GPLv3). Objetivo MiSTer.

> ℹ️ Proyecto independiente — **NO** es un core oficial de jotego. Construido sobre su framework
> JTFRAME (GPLv3).

## Cores

### Aero Fighters (Video System, 1992)
Shoot-'em-up vertical (hardware "newer Aero Fighters", driver de MAME `aerofgt.cpp`). Hardware: CPU
principal **MC68000** + CPU de sonido **Z80** + **YM2610** (FM/ADPCM) + dos capas de tilemap
independientes y un motor de sprites (`vsystem_spr`, compartido por varias placas de Video System de la
época) — sin datasheet público de los customs de vídeo, decodificados enteramente por ingeniería
inversa contra MAME.

**Estado: W.I.P.** — jugable en MiSTer (arranque, vídeo con las dos capas de tilemap + sprites,
entradas, DIP switches y Flip Screen funcionan en hardware); el timing horizontal/vertical ya está
calibrado contra un dato de timing leído de la ROM de una placa emparentada (ver
`cores/aerofgt/cfg/macros.def`).

### Parche al framework

Este build depende de un cambio **local, no publicado**, sobre JTFRAME que amplía el rango de
`H-Position` del OSD en `target/mister/{cfgstr,hdl/jtframe_mister.sv}` de ±16 a ±32. Sin él, la
calibración de CRT con la que se ajustó este core (`H-Position=-18`) queda fuera de rango y la
imagen muestra un hueco mayor a un lado del previsto. Solo afecta al rango de ajuste del OSD, no a
la jugabilidad ni al timing de síntesis — el core compila y funciona sin él.

## Compilar

1. Clonar [jtcores](https://github.com/jotego/jtcores) (trae JTFRAME + los módulos listados abajo).
2. Copiar `cores/aerofgt/` de este repo al checkout de jtcores.
3. Compilar: `jtcore aerofgt -mister -c`.

Estructura del core:
```
cores/aerofgt/
├── hdl/     Verilog propio del core
├── mister/  top de SDRAM generado por memgen (jtaerofgt_game_sdram.v) + mem_ports.inc
├── cfg/     macros.def, mem.yaml, files.yaml, mame2mra.toml
└── mra/     definición .mra (cómo ensamblar las ROMs)
```

También se publican `.rbf` ya compilados tal cual en [`releases/`](releases/) para quien prefiera
no compilar (cada ROM se carga en **runtime** desde el `.mra`; el bitstream no lleva ningún dato
del juego).

## ROMs

**No se incluyen** (material con copyright). Cada cual aporta las ROMs originales de su propia placa
para cada juego. El `.mra` describe cómo ensamblarlas; cada ROM se carga en runtime, así que el `.rbf`
no lleva ningún dato con copyright.

## Créditos

- **JTFRAME** — el framework GPLv3 sobre el que se construye este core
- **MAME** — referencia de hardware (driver `vsystem/aerofgt.cpp`, chip de sprites
  `vsystem/vsystem_spr.cpp`, E/S `vsystem/vs9209.cpp`)

## Agradecimientos

- A **Sorgelig** y todo el proyecto y comunidad **MiSTer FPGA**.
- A la **comunidad MAME**, por el trabajo de preservación e ingeniería inversa sin el cual este core no
  sería posible.
- Y a **Anthropic**, por **Claude**.

## Licencia

**GPLv3** (ver [`LICENSE`](LICENSE)) — obligado por la dependencia JTFRAME; sus avisos de copyright se
conservan en las fuentes.

<!-- omf_release:dependencias:ffaerofgt -->
## Dependencias externas de `ffaerofgt`

Este repositorio contiene **solo el código de los cores**. Para compilar `ffaerofgt`
hacen falta estas piezas, que se distribuyen desde su propio origen:

| Qué | De dónde | Dónde va |
|---|---|---|
| jtframe — framework de compilacion y modulos comunes: edge/counter, video (vtimer, resync), cpu (m68k via fx68k, z80/T80 interno), ram (dual_ram, obj_buffer), sound (dcrm). Incluye CRT_ADJUST vendorizado (rmonic79, GPLv3, github.com/rmonic79/MiSTer-CRT-Adjust) en hdl/video/rmonic79/crt_adjust.sv. ⚠ Este build usa una ampliacion LOCAL de H-Position en jtframe_mister.sv/cfgstr (+-16 a +-32) -- documentada en prosa en el README publico (seccion "Patch to the framework"/"Parche al framework"), no versionada como diff: ver la nota de la regla del .rbf mas abajo | [https://github.com/jotego/jtframe](https://github.com/jotego/jtframe) | `modules/jtframe` |
| fx68k — MC68000 (CPU principal) -- entra via jtframe_m68k.yaml, pero es un repo aparte: fx68k.sv, fx68kAlu.sv, uaddrPla.sv | [https://github.com/jtfpga/fx68k](https://github.com/jtfpga/fx68k) | `modules/fx68k` |
| jt12 — YM2610 (FM+ADPCM, sonido). Incluye jt49 (YM2149) vendorizado en su propio subdirectorio (jt12/jt49) | [https://github.com/jotego/jt12](https://github.com/jotego/jt12) | `modules/jt12` |
<!-- /omf_release:dependencias:ffaerofgt -->
