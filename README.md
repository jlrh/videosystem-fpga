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

**Status: playable on MiSTer** — boot, video (both tilemap layers + sprites), inputs and DIP switches
run on hardware. **Flip Screen** (cocktail cabinet mirroring) is implemented in RTL from scratch — MAME's
own driver never supports it (`aerofgt.cpp` has no flip-screen code at all) — and was the subject of a
multi-session fix: the game compensates flip by adding a fixed bias to its own scroll registers
(`scrollx0 += 483`, `scrollx1 += 479`, confirmed deterministically against MAME on two different
frames), which the core must cancel out rather than compensate for a second time. Validated pixel-exact
against a 180°-rotation oracle in simulation and confirmed clean on hardware, with and without reset.

> ⚠️ Only the **`.rbf` and the `.mra`** are published for Aero Fighters: `cores/aerofgt/` holds just
> `mra/`, with no `hdl/` or `cfg/`. This core **cannot be built from this repo**.

## Build

This repo publishes **binaries only** — no core here can be rebuilt from source. See the `.rbf` in
[`releases/`](releases/) for each core, distributable as-is (every ROM is loaded at **runtime** from
the `.mra`; the bitstream bakes no game data).

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

**Estado: jugable en MiSTer** — arranque, vídeo (las dos capas de tilemap + sprites), entradas y DIP
switches funcionan en hardware. **Flip Screen** (espejado para cabina cocktail) está implementado en
RTL desde cero — el propio driver de MAME nunca lo soporta (`aerofgt.cpp` no tiene ni una línea de
código de flip screen) — y fue objeto de un arreglo de varias sesiones: el juego compensa el flip
sumando un sesgo fijo a sus propios registros de scroll (`scrollx0 += 483`, `scrollx1 += 479`,
confirmado de forma determinista contra MAME en dos fotogramas distintos), que el core tiene que
cancelar en vez de compensar una segunda vez. Validado píxel a píxel contra un oráculo de rotación
180° en simulación y confirmado limpio en placa, con y sin reset.

> ⚠️ De Aero Fighters **solo se publican el `.rbf` y el `.mra`**: `cores/aerofgt/` contiene únicamente
> `mra/`, sin `hdl/` ni `cfg/`. Este core **no se puede compilar desde este repo**.

## Compilar

Este repo publica **solo binarios** — ningún core de aquí se puede recompilar desde fuente. Ver el
`.rbf` de cada core en [`releases/`](releases/), distribuible tal cual (cada ROM se carga en
**runtime** desde el `.mra`; el bitstream no lleva ningún dato del juego).

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
