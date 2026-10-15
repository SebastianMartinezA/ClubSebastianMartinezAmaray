# Design System — Panel de clubes (Figma) → App de reservas

> **Origen de este documento.** Analicé las capturas del **modo prototipo** de Figma
> (`proto-00.png`, `proto-01.png`, `proto-02.png`, `proto-03.png`, `proto-06.png`,
> `proto-07.png`, `proto-08.png`). El archivo de Figma es de **solo lectura**: no lo abrí,
> no lo modifiqué, no lo dupliqué ni comenté nada. Todo lo que sigue sale de medir los
> píxeles de esos PNG con **PIL 9.4.0**, no de mirar a ojo.
>
> **Capturas usadas:** las siete capturas del prototipo de la Entrega 1 (tres pantallas únicas: editar
> sede, panel de sedes y panel de espacios).
>
> **Método.** Para cada color hice histograma por región (fondo de pantalla, superficie de
> tarjeta, bordes, botones, chips) y me quedé con el color modal / el píxel más luminoso
> de cada elemento. Las medidas de tamaño salen de contar los píxeles del plano y dividir
> por la escala del frame.
>
> **Escala.** El frame es **Android Compact = 360 × 800 dp**. En las capturas la pantalla
> del dispositivo mide **345 × 765 px** (lo verifiqué: el run exacto de color de fondo va de
> `x=626` a `x=970`, y en vertical de `y=72` a `y=836`). Entonces:
>
> | | valor |
> |---|---|
> | escala horizontal | 345 / 360 = **0,958 px por dp** |
> | escala vertical | 765 / 800 = **0,956 px por dp** |
> | conversión | **1 px ≈ 1,04 dp** |
>
> Que las dos escalas coincidan con 3 decimales es lo que me confirma que el frame es 360×800.
> Toda medida en `dp` de este documento es `px / 0,958`, redondeada. **Los tamaños están
> estimados con ±1–2 dp de error** (los bordes de 1 px y los glifos finos se comen píxeles
> por antialiasing).

---

## 1. Paleta de colores

### 1.1 Colores base de superficie y texto

| Rol | Hex medido | De dónde salió |
|---|---|---|
| **Fondo de pantalla** | `#050508` | Histograma de las franjas de separación entre tarjetas en `proto-02.png` (region `x[660,940] y[470,476]`): **100 %** de los píxeles son `#050508`. También en `proto-01.png` y `proto-00.png`. Es un negro con una gota de azul, no `#000000`. |
| **Superficie (tarjeta)** | `#171719` | Histograma del cuerpo de tarjeta en `proto-02.png` (`x[900,440]`, sin texto ni íconos): color modal. Aparecen vecinos `#161619` y `#18181A` por ruido de compresión; el valor central es `#171719`. |
| **Superficie alterna (contenedor de tabs, inputs)** | `#141417` | `proto-01.png`, contenedor de tabs (`x[650,745] y[170,207]`): 3181 px de 3200. En `proto-00.png` es también el relleno de los campos de texto. |
| **Superficie de panel (formulario)** | `#0C0C0F` | `proto-00.png`: el panel que contiene "EDITAR SEDE" + inputs se ve apenas más claro que el fondo. Medido por columna en `x=650`: `y=319 → #0C0C0F`. **Diferencia muy sutil** (3 niveles sobre el fondo). |
| **Borde (normal)** | `#242427` | Borde interno de tarjetas en `proto-02.png`. |
| **Borde (más marcado / borde superior de tarjeta)** | `#2A2A2D` | Borde superior de la tarjeta 1 en `proto-02.png` (`y=357 → #2A2A2D`) y borde de botones secundarios. |
| **Borde de input** | `#2D2D30` | `proto-00.png`, borde superior del campo "Sede Morón" (`y=224 → #2D2D30`). |
| **Borde / separador sutil** | `#1C1C1E` | `proto-00.png` línea horizontal bajo la fila de chips (`y=179`) y contorno del contenedor de tabs en `proto-01.png`. |
| **Acento lima** | **`#D4FF00`** | Es el color más fuerte del sistema. Medido exacto en: tab activo (`proto-01.png`, `x=750..846 en y=200`), botón "GUARDAR CAMBIOS" (`proto-00.png`, 4347 px), botón "ALTA ESPACIO" (`proto-02.png`, 1315 px), chip "Todas", badge "ADMIN". No es `#CCFF00` ni `#C8FF00`: el canal R es 0xD4. |
| **Texto sobre lima** | `#000000` | Texto de "GUARDAR CAMBIOS", "ALTA SEDE", "Todas" y del tab activo: negro pleno sobre el lima. |
| **Texto primario (títulos)** | `#FFFFFF` | `proto-01.png`, título "SEDE MORÓN" sobre la foto: 265 px exactos en `#FFFFFF`. |
| **Texto de titulares** | `#F0F1F8` | `proto-01.png`, "PANEL" del header. Es un blanco levemente azulado; probablemente el mismo blanco con otro render. **Lo tomo como estimado**: puede ser `#FFFFFF`. |
| **Texto secundario (cuerpo, direcciones, precios, contadores)** | `#6C6C6E` | `proto-02.png`, línea "Fútbol 5 · $ 4.200/h" (`y=392`): píxeles `#6C6C6E`, `#616163`, `#535355`. El más claro es `#6C6C6E`, así que el color no puede ser más claro que eso. |
| **Texto de etiquetas (NOMBRE, DIRECCIÓN)** | `#545456` | `proto-00.png`, etiqueta "NOMBRE" (`x[635,720] y[208,224]`): modal `#545456`. |
| **Texto de tabs inactivos** | `#777778` | `proto-01.png`, "RESERVAS" (`x[665,745] y[175,205]`): modal `#777778`. Es el gris más claro del sistema (más que las etiquetas). |
| **Texto sobre foto (dirección en cabecera)** | ≈`#808488` | `proto-01.png`, "Av. Rivadavia 17500" sobre la imagen. Bajo contraste a propósito (sobre foto). |

### 1.2 Estados semánticos

| Rol | Hex medido | De dónde salió |
|---|---|---|
| **Error / destructivo — texto** | **`#F87171`** | `proto-01.png`/`proto-02.png`, texto del botón "Baja": es el color más frecuente del hue 0–14° (162 px en `proto-02`). Coincide exacto con un rojo-400 genérico. |
| **Error / destructivo — fondo** | `#331D1F` | Fondo del botón "Baja" (`bbox_color` sobre `proto-02.png x[880,960] y[390,440]`). Variantes medidas `#321C1F`, `#341E20`: es un rojo muy oscuro desaturado. |
| **Error / destructivo — borde** | `#4C2225` | Borde del botón "Baja" (aparece 19–44 px por botón). |
| **Éxito** | `#0A8A5E` *(derivado)* | **No hay una pantalla de "éxito" en las capturas.** El verde del sistema es el del chip "Fútbol": fondo `#132F28`, borde `#104335`, texto medido entre `#028B5F` y `#0A6447`. Propongo `#0A8A5E` como verde de éxito, **marcado como derivado, no evidenciado**. |
| **Alerta / warning** | `#FBBF24` *(propuesto)* | **No existe en ninguna captura.** No hay estado de advertencia, ni toast, ni banner. Lo propongo para completar el set y el ThemeData, **pero no está medido**: no lo uses como si fuera del diseño original. |

### 1.3 Paleta por deporte (chips)

Medida en `proto-01.png` con clustering por hue sobre `x[645,950] y[210,850]`. Cada chip es
un rectángulo de fondo oscuro tintado + borde 1 px del mismo tono + texto en el tono brillante.

| Deporte | Fondo | Borde | Texto (medido) | Texto sugerido |
|---|---|---|---|---|
| ⚽ Fútbol | `#132F28` | `#104335` | `#028B5F` … `#0A6447` | `#10B981` |
| 🎾 Tenis | `#392315` | `#522C13` | `#C63F06` / `#C23C02` | `#F97316` |
| 🏑 Hockey (violeta) | `#3B2860` | `#3E206C` | `#6921CE` / `#6421C1` | `#7C3AED` |
| 🔴 Vóley (carmesí) | `#5B2041` | `#5C2142` | `#AF085F` / `#8F0E51` | `#DB2777` |
| ⛳ Golf (azul) | `#132C3A` | `#0F435D` | `#0379BE` / `#0474B5` | `#0EA5E9` |

> ⚠️ **Advertencia honesta:** los colores de *texto* de los chips están medidos sobre
> trazos de ~1 px, así que el antialiasing los oscurece. El fondo y el borde son fiables
> (áreas grandes); el texto es la **cota inferior** del color real. La columna "texto sugerido"
> es mi estimación de la forma que probablemente tenía en Figma, y está **sin confirmar**.
> El 🎾 del chip Tenis es amarillo-verde `#DBF10A` (es el emoji, no un color del sistema).

### 1.4 Otros medidos

| Elemento | Hex | Fuente |
|---|---|---|
| Badge "N canchas" (fondo) | negro translúcido ≈ `rgba(0,0,0,0.6)` | Sobre la foto renderiza `#00101B`/`#01101C` (foto azul + negro). |
| Badge "N canchas" (texto) | `#FFFFFF` | `proto-01.png`. |
| Ícono de fila en listado (Fútbol) | `#EFEFEF` (blanco hueso) | `proto-02.png`, `x=654 y=373`. En otras filas es verde. Cambia según el deporte. |
| Línea blanca del header (foto) | `#FFFFFF` | Cancha de tenis de la foto; no es un color de UI. |

---

## 2. Tipografía

### 2.1 Familias

Mirando los glifos ampliados 4×:

- **Títulos** ("PANEL ADMIN", "SEDE MORÓN", "EDITAR SEDE"): sans **grotesca, peso muy alto
  (800/900), en mayúsculas**. La inclinación es mínima o nula a 4× (en la vista general
  parecía itálica; ampliada, es recta o casi). Compatible con **Inter Black / Archivo Black /
  Poppins ExtraBold**. No puedo determinar la familia exacta desde un PNG.
- **Cuerpo y etiquetas**: la misma familia en pesos 400/500/600, mayúsculas en las etiquetas.
- **Nombres de espacios** (`Moron_Rivadavia_Futbol_F5_Cancha1`): **fuente monoespaciada**
  (todos los glifos con el mismo ancho, avance ≈ 7,2 dp/char), subrayada y en lima.
  Compatible con **Roboto Mono / JetBrains Mono / Space Mono**.

**Recomendación práctica:** `Inter` para todo + `Roboto Mono` (o `JetBrains Mono`) para los
identificadores. Está **estimado**, no medido: la familia exacta no es deducible de un bitmap.

### 2.2 Jerarquías y tamaños (en dp)

Medidos por altura de mayúscula / extensión ascender–descender, con la escala 0,958 px/dp.
Todos los valores son **estimaciones con ±2 dp**.

| Rol | Tamaño | Peso | Caja | Tracking | Evidencia |
|---|---|---|---|---|---|
| Título de pantalla | **22–24 dp** | 800/900 | MAYÚSCULAS | leve | "PANEL ADMIN": cap-height 16 px → 16,7 dp. El string ocupa 146 px = 152 dp para 11 caracteres. |
| Título de tarjeta | **16–17 dp** | 800 | MAYÚSCULAS | leve | "SEDE MORÓN" en la cabecera: cap-height ≈ 12 px → 12,5 dp. |
| Título de sección | **12–14 dp** | 800 | MAYÚSCULAS | **alto** (≈1,5–2 dp) | "EDITAR SEDE": cap ≈ 9 px, ocupa 68 px = 71 dp para 11 caracteres. Color lima. |
| Subtítulo de header | **10 dp** | 400 | normal | — | "Gestión completa del sistema": ascender+descender = 8 px = 8,4 dp; es el texto más chico del sistema. |
| Cuerpo / secundario | **10–11 dp** | 400/500 | normal | — | "Fútbol 5 · $ 4.200/h" y "4 sedes registradas" (9 px de alto con descendente). |
| Texto de input | **11 dp** | 400/500 | normal | — | "Sede Morón": cap-height 8 px = 8,3 dp. |
| Etiquetas de campo | **9–10 dp** | 600 | MAYÚSCULAS | 1,5 dp | "NOMBRE" / "DIRECCIÓN": 6 px de alto, ancho 39 px para 6 caracteres. Gris `#545456`. |
| Texto de botón | **10–11 dp** | 800 | MAYÚSCULAS | 0,5–1 dp | "GUARDAR CAMBIOS": 14 caracteres en un botón de 187 dp. |
| Texto de tab | **10–11 dp** | 700 | MAYÚSCULAS | 1 dp | "RESERVAS" / "ESPACIOS". |
| Texto de chip | **10 dp** | 600/700 | normal | — | "Fútbol", "Tenis", filtros "Todas/Morón/...". |
| Badge | **9 dp** | 800 | MAYÚSCULAS | 1 dp | "ADMIN" dentro de una píldora de 17 dp de alto. |
| Nombre de espacio (mono) | **11–12 dp** | 500 | normal | — | 32 caracteres en 222 px = 232 dp → 7,2 dp/char. |
| Título de fila ("Editar"/"Baja") | **11 dp** | 600/700 | normal | — | Botones chicos de fila. |

> **Ojo con esto:** la escala tipográfica es **chica** (cuerpo 10–11 dp). No es un error de
> medición: el frame es 360 dp de ancho y la pantalla ocupa 345 px, así que la conversión es
> directa. Es un panel de administración denso, con mucho texto. Si en la app de reservas
> necesitás más legibilidad, subí cuerpo a 12–13 dp y subtítulos a 12 dp, manteniendo la
> relación entre jerarquías.

---

## 3. Componentes reutilizables

Medidas en dp. Todas las geometrías son medidas; los radios son estimados por inspección
ampliada (los redondeos son lo más difícil de medir con precisión en un bitmap).

### 3.1 Header con logo/acción

- Estructura: botón atrás circular **34 dp** (rounded-square, radio ≈12 dp, fondo `#141417`,
  ícono chevron gris) a la izquierda; título `PANEL ADMIN` (blanco + palabra final en **lima**);
  badge píldora lima `ADMIN` (70 × 17 dp, radio píldora, texto negro 9 dp/800 con tracking) a la
  derecha del título; subtítulo `Gestión completa del sistema` en `#6C6C6E` 10 dp debajo.
- La fila entera no tiene fondo propio: va sobre el fondo de pantalla `#050508`.
- **No hay barra superior con borde/sombra**: el header es plano.
- En `proto-00` el header es distinto: **foto full-bleed** con `SEDE MORÓN` arriba a la izquierda,
  badge `7 canchas` (píldora negra translúcida, texto blanco) arriba a la derecha, un **botón
  circular oscuro centrado** con un glifo chico de acento (¿logo? ¿estado? — **no lo puedo
  determinar, marcado como dudoso**), y un **degradado oscuro** en la parte inferior de la foto.

### 3.2 Tabs (control segmentado)

- Contenedor: **328 × 42 dp** (ancho de contenido = 360 − 2×16 dp de margen), radio ≈ **16 dp**,
  fondo `#141417`, borde 1 px `#1C1C1E`.
- Tres segmentos iguales (`RESERVAS` / `SEDES` / `ESPACIOS`).
- **Activo**: píldora lima **104 × 31 dp** (radio ≈14 dp, inset ~5 dp), fondo `#D4FF00`,
  texto negro 10–11 dp/800 con tracking.
- **Inactivo**: sin fondo, texto `#777778` 10–11 dp/700 con tracking.
- No se distinguen estados hover/pressed/disabled (son capturas estáticas).

### 3.3 Chips de filtro

- Forma: **píldora** (radio = 50 % de la altura) de **≈49 × 26 dp**.
- **Activo** (`Todas`): fondo `#D4FF00`, texto negro 10 dp/700.
- **Inactivo** (`Morón`, `Ramos Mejía`, `San Justo`, `Castelar`): fondo `#171719`,
  borde 1 px `#2A2A2D`, texto `#6C6C6E` 10–11 dp/600.
- Van en una fila con scroll horizontal (la fila sangra fuera del margen de 16 dp, típico de
  un `ListView` horizontal).

### 3.4 Botón primario lima

- Caja: **187 × 30 dp** ("GUARDAR CAMBIOS"), radio ≈ **12 dp** (rectángulo redondeado,
  **no** píldora), fondo `#D4FF00`, **texto negro 10–11 dp/800 con tracking**.
- Variante píldora compacta: `ALTA SEDE` (69 × 27 dp), `ALTA ESPACIO` (81 × 26 dp) y `Cerrar`
  (62 × 24 dp) — mismo lima, mismo texto negro, pero radio píldora, y llevan un ícono
  (`+` en las de alta, lápiz en "Cerrar").
- Estado pressed/disabled: **no evidenciado**.

### 3.5 Botón secundario

- `Cancelar`: **≈93 × 30 dp**, radio ≈12 dp, fondo casi igual al panel (`#131316`/`#0C0C0F`),
  borde 1 px `#2A2A2D`, texto gris claro (`#B0B0B5`–`#9CA3AF`) 11 dp/600.
- Variante sin caja visible (link): no aparece en las capturas.

### 3.6 Botón destructivo rojo

- `Baja`: **≈48 × 23 dp**, radio ≈12 dp, fondo `#331D1F`, borde 1 px `#4C2225`,
  ícono de papelera + texto `#F87171` 11 dp/700. Es el único uso de rojo del sistema.

### 3.7 Campos de texto

- Caja: **≈315 × 31 dp**, radio ≈ **12 dp**, fondo `#141417`, borde 1 px `#2D2D30`.
- Texto: 11 dp, color claro (`#B9BAC0`–`#F0F1F8`), padding interno ≈12 dp.
- Etiqueta **arriba** del campo (no flotante): `NOMBRE`, `DIRECCIÓN`, mayúsculas 9–10 dp/600
  con tracking, color `#545456`.
- **No se ve estado de foco** (ni anillo ni borde más brillante) en la captura de `proto-00`.
  Tampoco hay ícono de validación, ni placeholder, ni texto de error.

### 3.8 Tarjetas de listado

Dos variantes convivendo en el sistema:

**(a) Tarjeta de sede** (con imagen) — `proto-01`
- Caja: **328 × ≈113 dp**, radio ≈16 dp, fondo `#171719`, borde 1 px `#2A2A2D`.
- Cabecera: **foto** de ≈69 dp de alto, ocupando el ancho completo con las esquinas
  superiores redondeadas, con un **degradado oscuro** abajo para que el texto se lea.
- Sobre la foto: título `SEDE MORÓN` (16–17 dp/800 blanco) + dirección con ícono de pin
  (10–11 dp, gris claro `#808488`); arriba a la derecha el badge `N canchas`
  (píldora negra translúcida, texto blanco 10 dp).
- Fila inferior: chips de deportes a la izquierda (los que tenga la sede) y, a la derecha,
  `Editar` + `Baja`. Padding interno ≈12 dp. Separación con la foto: cambio de superficie,
  sin línea divisoria explícita.

**(b) Tarjeta de espacio** (fila de listado) — `proto-02`
- Caja: ancho 328 dp, alto ≈ 76–80 dp, radio ≈16 dp, fondo `#171719`, borde 1 px `#242427`.
- Izquierda: **ícono circular chico** (glifo tipo flor/asterisco) de ≈16 dp, con color según
  el deporte (`#EFEFEF` para Fútbol, verde para "Polvo de Ladrillo").
- Línea 1: **nombre del espacio en lima `#D4FF00` + subrayado + fuente mono** 11–12 dp.
  (Medido sobre el trazo: `#A5C506`/`#758A0D` — el antialiasing del texto fino lo oscurece;
  el color de diseño es el lima del sistema.)
- Línea 2: `Fútbol 5 · $ 3.800/h` — deporte + separador `·` + precio/hora, en `#6C6C6E` 10–11 dp.
- Derecha: `Editar` (52 × 23 dp, fondo de tarjeta, borde 1 px `#2A2A2D`, texto gris, ícono lápiz)
  y `Baja` (rojo, ver 3.6).
- **Sin divisiones internas** entre filas: las tarjetas se separan por el fondo (`#050508`, gap ≈8 dp).

### 3.9 Badges

- **Píldora lima** (`ADMIN`): 70 × 17 dp, radio = alto/2, fondo `#D4FF00`, texto negro 9 dp/800
  con tracking, mayúsculas.
- **Píldora oscura sobre foto** (`7 canchas`): fondo negro translúcido ≈60–70 % de opacidad,
  texto blanco 10 dp/700, alto ≈20 dp, radio = alto/2.

### 3.10 Bottom bar

**No existe en ninguna captura.** Ninguna de las pantallas muestra barra inferior de navegación,
ni tab bar, ni FAB inferior. Si la app del usuario final necesita bottom bar, hay que diseñarla:
el sistema **no la define**.

### 3.11 Buscador

**No hay buscador en las capturas.** `proto-02` filtra por chips de sede (`Todas`, `Morón`, …),
que no es un input de búsqueda. No hay ningún campo con ícono de lupa ni placeholder de búsqueda.
No copies un buscador "de estilo" de esta entrega: **no existe**.

### 3.12 Otros elementos vistos

- **Separador**: línea de 1 px `#1C1C1E` (bajo la fila de chips de `proto-00`).
- **Contador de resultados**: `4 sedes registradas` / `22 espacios` — texto 10–11 dp `#6C6C6E`
  a la izquierda, con el botón de alta a la derecha, en la misma fila.

---

## 4. Pantalla por pantalla

> **Aclaración central y honesta:** las 7 capturas son **del panel de administración**, no de la
> app del usuario final. Sólo hay **3 pantallas únicas**; las demás son repetidas:
> `proto-03` = `proto-01`, y `proto-06` / `proto-07` / `proto-08` = `proto-02`
> (estas últimas además con el panel "Flows" de Figma abierto sobre el canvas, que **no** es
> parte del diseño). Por lo tanto **ninguna captura corresponde 1:1 a una pantalla de la app de
> reservas**: lo que sí se puede hacer es reutilizar el design system y mapear los moldes.

### 4.1 `proto-00` — "Editar sede" (modal / formulario ABM)

- **Qué se ve:** cabecera con foto de cancha, `SEDE MORÓN`, badge `7 canchas`, botón circular
  arriba al centro, chips `⚽ Fútbol` / `🎾 Tenis` y botón lima `✏ Cerrar`. Debajo, un panel
  `#0C0C0F` con el título de sección `EDITAR SEDE` (lima, mayúsculas, tracking alto), dos campos
  (`NOMBRE` → "Sede Morón"; `DIRECCIÓN` → "Av. Rivadavia 17500") con etiqueta arriba y, abajo,
  `Cancelar` (secundario) + `GUARDAR CAMBIOS` (primario lima). Debajo del panel, vacío.
- **Función:** alta/edición de una sede del club (ABM del panel).
- **Correspondencia con la app de reservas:** **no corresponde a ninguna pantalla del usuario
  final** — es de administración. Pero su **molde sí es el que necesitan las pantallas de
  autenticación**: panel oscuro + título de sección lima + etiqueta sobre campo + campo oscuro
  con borde sutil + par Cancelar/Primario. Es el patrón directo para **login**, **registro** y
  **recuperación de contraseña**, y para los formularios de **perfil** y **reserva de turno**
  (datos del turno).

### 4.2 `proto-01` (y `proto-03`) — "Panel admin › SEDES"

- **Qué se ve:** header `PANEL ADMIN` + badge `ADMIN` + subtítulo. Tabs `RESERVAS | SEDES |
  ESPACIOS` con **SEDES** activo en lima. Fila `4 sedes registradas` + botón lima `+ ALTA SEDE`.
  Cuatro tarjetas con foto: `SEDE MORÓN` (Av. Rivadavia 17500, 7 canchas, chips Fútbol+Tenis),
  `SEDE RAMOS MEJÍA` (Calle Belgrano 1240, 4 canchas, Fútbol+Hockey+Vóley),
  `SEDE SAN JUSTO` (Av. Casanova 320, 8 canchas, Fútbol+Tenis+Golf),
  `SEDE CASTELAR` (Av. Rivadavia 22500, 6 canchas, Tenis+Vóley+Hockey). Cada tarjeta con
  `Editar` y `Baja`. Abajo, vacío (sin bottom bar).
- **Función:** listado y ABM de sedes.
- **Correspondencia:** el **listado de sedes** del usuario final (una de las pantallas pedidas)
  usa exactamente esta tarjeta: foto + nombre + dirección + badge de cantidad + chips de deportes.
  Lo que cambia en la app de reservas: los botones `Editar`/`Baja` se reemplazan por la acción de
  entrar a ver disponibilidad (o se eliminan, dejando la tarjeta clickeable).

### 4.3 `proto-02` (y `proto-06`/`proto-07`/`proto-08`) — "Panel admin › ESPACIOS"

- **Qué se ve:** mismo header y tabs, con **ESPACIOS** activo. Fila de chips de filtro por sede
  (`Todas` activa en lima, `Morón`, `Ramos Mejía`, `San Justo`, `Castelar`). `22 espacios` +
  botón lima `+ ALTA ESPACIO`. Listado de tarjetas-fila, cada una con ícono de deporte, nombre
  monoespaciado **en lima y subrayado** (`Moron_Rivadavia_Futbol_F5_Cancha1`), debajo
  `Fútbol 5 · $ 3.800/h`, y a la derecha `Editar` + `Baja`. Se ven 9 filas (Morón: F5 Cancha1
  $3.800/h, F5 Cancha2 $4.200/h, F7 Cancha1 $5.500/h, F11 Cancha1 $9.000/h, Tenis Polvo Cancha1
  $2.500/h, Tenis Polvo Cancha2 $2.500/h, Tenis Cemento Cancha1; Ramos Mejía: F11 $8.000/h, F5 $4.000/h).
- **Función:** listado y ABM de canchas/espacios, filtrable por sede.
- **Correspondencia:** este es el molde del **detalle de sede con disponibilidad** (cada fila =
  una cancha con su deporte y su precio por hora) y de la **reserva de turno** en su paso de
  "elegir cancha". La fila (ícono + línea principal + línea secundaria + acción a la derecha)
  es también el molde natural para **mis reservas** y **historial** (donde la línea 1 sería
  fecha/cancha y la línea 2 el horario y el precio). El filtro por chips es reutilizable como
  filtro de sede o de deporte en esas pantallas.

### 4.4 Correspondencia resumida

| Pantalla de la app | ¿Hay captura? | De dónde sale |
|---|---|---|
| login | ❌ | Molde de formulario de `proto-00` (adaptado: sin panel foto). |
| registro | ❌ | Ídem login. |
| recuperación de contraseña | ❌ | Ídem login (más corto). |
| home | ❌ | No hay ninguna captura de home. Habría que diseñarla con la paleta; **no invento un layout**. |
| listado de sedes | ⚠️ parcial | Tarjeta de sede de `proto-01`, sin `Editar`/`Baja`. |
| detalle de sede con disponibilidad | ⚠️ parcial | Filas de `proto-02` (cancha + deporte + precio/h). |
| reserva de turno | ⚠️ parcial | Selección de cancha de `proto-02` + formulario de `proto-00`. |
| mis reservas | ⚠️ parcial | Fila de `proto-02` (línea 1 + línea 2 + acción). |
| historial | ⚠️ parcial | Ídem mis reservas. |
| perfil | ❌ | Molde de formulario de `proto-00`. |
| **panel admin (sedes/espacios/editar)** | ✅ | `proto-01`+`proto-03`, `proto-02`+`06/07/08`, `proto-00`. |

**Ninguna captura es una pantalla del usuario final.** Si el TP pide las 10 pantallas de la app
de reservas, todas menos el panel admin hay que diseñarlas reutilizando este sistema.

---

## 5. Cómo aplicarlo en Flutter

ThemeData listo para copiar, coherente con lo medido. Está pensado para **Material 3** y
**Flutter ≥ 3.27** (lo que pide el `pubspec.yaml` de la app: `CardThemeData`, el tipo que recibe
`cardTheme`, existe desde 3.27). Los colores marcados `// estimado`
o `// propuesto` son los que no pude determinar con certeza: revisalos antes de darlos por definitivos.

> **Verificación:** extraje el bloque de `AppTheme` y lo pasé por `dart format`
> con el SDK de Dart 3.13.5 (arm64): **parsea sin errores**.
> No hay Flutter SDK instalado en este host, así que **no pude compilarlo** ni verificar los
> tipos del framework.
>
> **Notas de compatibilidad** (el `pubspec.yaml` de la app pide `flutter: ">=3.27.0"`):
> - `CardThemeData` (en `cardTheme:`) es el tipo nuevo. En Flutter < 3.27 se llamaba `CardTheme`;
>   por eso el constraint subió a 3.27 (con `>=3.24` el proyecto no compilaba en 3.24-3.26).
> - Usé `WidgetStateProperty` (no `MaterialStateProperty`) y los `surfaceContainer*` del
>   `ColorScheme`: son de Flutter ≥ 3.22, así que con `>=3.27` están bien.
> - Las familias `'Inter'` y `'RobotoMono'` hay que declararlas en `pubspec.yaml`
>   (o usar `google_fonts`); el código no las trae.

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// Paleta medida con PIL sobre las capturas del prototipo (frame Android Compact 360x800 dp).
class AppColors {
  AppColors._();

  // --- Superficies ---
  static const bg            = Color(0xFF050508); // fondo de pantalla
  static const surface       = Color(0xFF171719); // tarjetas
  static const surfaceAlt    = Color(0xFF141417); // contenedor de tabs, inputs
  static const surfacePanel  = Color(0xFF0C0C0F); // panel de formulario (1 nivel sobre el fondo)

  // --- Bordes ---
  static const border        = Color(0xFF242427);
  static const borderStrong  = Color(0xFF2A2A2D); // borde superior de tarjeta / botón secundario
  static const inputBorder   = Color(0xFF2D2D30);
  static const hairline      = Color(0xFF1C1C1E); // separadores

  // --- Acento ---
  static const lime          = Color(0xFFD4FF00);
  static const onLime        = Color(0xFF000000);

  // --- Texto ---
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textHeadline  = Color(0xFFF0F1F8); // medido; probablemente el mismo blanco
  static const textSecondary = Color(0xFF6C6C6E);
  static const textLabel     = Color(0xFF545456);
  static const tabInactive   = Color(0xFF777778);

  // --- Estados ---
  static const danger        = Color(0xFFF87171);
  static const dangerBg      = Color(0xFF331D1F);
  static const dangerBorder  = Color(0xFF4C2225);
  static const success       = Color(0xFF0A8A5E); // derivado del chip Fútbol (no evidenciado)
  static const warning       = Color(0xFFFBBF24); // PROPUESTO: no aparece en las capturas

  // --- Badge sobre foto ---
  static const scrim = Color(0x99000000); // negro ~60 %

  // --- Deportes (fondo / borde / texto) ---
  static const sportFutbol = SportStyle(Color(0xFF132F28), Color(0xFF104335), Color(0xFF10B981)); // fg estimado
  static const sportTenis  = SportStyle(Color(0xFF392315), Color(0xFF522C13), Color(0xFFF97316)); // fg estimado
  static const sportHockey = SportStyle(Color(0xFF3B2860), Color(0xFF3E206C), Color(0xFF7C3AED)); // fg estimado
  static const sportVoley  = SportStyle(Color(0xFF5B2041), Color(0xFF5C2142), Color(0xFFDB2777)); // fg estimado
  static const sportGolf   = SportStyle(Color(0xFF132C3A), Color(0xFF0F435D), Color(0xFF0EA5E9)); // fg estimado
}

class SportStyle {
  const SportStyle(this.bg, this.border, this.fg);
  final Color bg;
  final Color border;
  final Color fg;
}

class AppTheme {
  AppTheme._();

  /// Radio de tarjetas y del contenedor de tabs.
  static const rCard = 16.0;
  /// Radio de botones, inputs y botones de fila.
  static const rButton = 12.0;
  /// Radio del chip de deporte (casi cuadrado).
  static const rSportChip = 8.0;
  /// Margen lateral de contenido.
  static const padH = 16.0;

  static ThemeData light() => dark(); // la entrega es dark-only

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.lime,
      onPrimary: AppColors.onLime,
      primaryContainer: AppColors.lime,
      onPrimaryContainer: AppColors.onLime,
      secondary: AppColors.lime,
      onSecondary: AppColors.onLime,
      error: AppColors.danger,
      onError: AppColors.onLime,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.bg,
      surfaceContainerLow: AppColors.surfacePanel,
      surfaceContainer: AppColors.surfaceAlt,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.surface,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.hairline,
      scrim: AppColors.scrim,
      inverseSurface: AppColors.lime,
      onInverseSurface: AppColors.onLime,
    );

    // Escala tipográfica medida (dp). Inter + Roboto Mono (estimado).
    const text = TextTheme(
      // Título de pantalla: "PANEL ADMIN" ~22-24 dp / w800
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: 0.2),
      // Título de tarjeta: "SEDE MORÓN" ~16 dp / w800
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: 0.3),
      // Título de sección lima: "EDITAR SEDE" ~13 dp / w800, tracking alto
      titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: 1.8),
      // Encabezado de fila / botón: ~11 dp / w700
      titleSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 0.6),
      // Cuerpo: precios, direcciones, contadores ~11 dp
      bodyMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      bodySmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      // Etiqueta de campo: "NOMBRE" 10 dp / w600 mayúsculas
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textLabel),
      labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      fontFamily: 'Inter', // estimado
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),
    );

    return base.copyWith(
      // ---- Inputs ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(fontSize: 11, color: AppColors.textLabel),
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.textLabel),
        border: _inputBorder(AppColors.inputBorder),
        enabledBorder: _inputBorder(AppColors.inputBorder),
        // No hay estado de foco evidenciado en Figma: uso el lima por coherencia.
        focusedBorder: _inputBorder(AppColors.lime, width: 1.2),
        errorBorder: _inputBorder(AppColors.dangerBorder),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.2),
        errorStyle: const TextStyle(fontSize: 10, color: AppColors.danger),
      ),

      // ---- Botones ----
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onLime,
          disabledBackgroundColor: AppColors.surfaceAlt,
          disabledForegroundColor: AppColors.textLabel,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lime,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
        ),
      ),
      // Píldoras compactas de alta: "ALTA SEDE", "ALTA ESPACIO"
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onLime,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
      ),

      // ---- Chips de filtro ----
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.lime,
        disabledColor: AppColors.surfaceAlt,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        secondaryLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onLime),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),

      // ---- Tarjetas ----
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rCard),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),

      // ---- Control segmentado (tabs RESERVAS | SEDES | ESPACIOS) ----
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.lime : AppColors.surfaceAlt),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.onLime : AppColors.tabInactive),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.hairline)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          minimumSize: const WidgetStatePropertyAll(Size(0, 31)),
        ),
      ),

      // ---- AppBar plana ----
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),

      // ---- BottomNavigationBar (no está en las capturas: paleta coherente) ----
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.lime,
        unselectedItemColor: AppColors.tabInactive,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),

      listTileTheme: const ListTileThemeData(
        tileColor: AppColors.surface,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: TextStyle(fontSize: 11, color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.lime,
        selectionColor: Color(0x33D4FF00),
        selectionHandleColor: AppColors.lime,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color c, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(rButton),
        borderSide: BorderSide(color: c, width: width),
      );
}
```

### 5.1 Widgets concretos sugeridos

> Son **fragmentos** para pegar dentro de un `build()` (por eso no son un archivo Dart suelto):
> usalos como referencia de forma/color, no como programa.

```dart
// --- Botón destructivo "Baja" (rojo oscuro, borde, ícono) ---
TextButton.icon(
  onPressed: onDelete,
  icon: const Icon(Icons.delete_outline, size: 16),
  label: const Text('Baja'),
  style: TextButton.styleFrom(
    backgroundColor: AppColors.dangerBg,
    foregroundColor: AppColors.danger,
    side: const BorderSide(color: AppColors.dangerBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rButton)),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    minimumSize: const Size(0, 36),
    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
  ),
);

// --- Chip de deporte (fondo tintado + borde + emoji + texto) ---
Container(
  height: 24,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(
    color: style.bg,
    border: Border.all(color: style.border),
    borderRadius: BorderRadius.circular(AppTheme.rSportChip),
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Text(emoji, style: const TextStyle(fontSize: 11)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: style.fg)),
  ]),
);

// --- Nombre de espacio: mono, lima, subrayado ---
Text(
  'Moron_Rivadavia_Futbol_F5_Cancha1',
  style: const TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.lime,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.lime,
  ),
);

// --- Badge "N canchas" sobre la foto ---
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: const BoxDecoration(color: AppColors.scrim, borderRadius: StadiumBorder()),
  child: const Text('7 canchas',
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
);

// --- Título de sección lima: "EDITAR SEDE" ---
const Text('EDITAR SEDE',
    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
        letterSpacing: 1.8, color: AppColors.lime));
```

### 5.2 Cuidados al portar

1. **Es dark-only.** No hay variante clara en las capturas; no inventes un `light()` distinto.
2. **Los tamaños táctiles del diseño son chicos** (botones de fila de 23 dp de alto). Para
   producción subí el área táctil a 44–48 dp aunque el dibujo sea de 23–27 dp
   (usá `SizedBox` + `InkWell` con hitbox extendido).
3. **El lima `#D4FF00` es agresivo**: usalo sólo en el acento (1 acción por pantalla), como en
   el original (un único CTA lima por vista).
4. **El verde/rojo de los chips no son estados**: son identidad de deporte. No los uses para
   validaciones.
5. **No hay sombras.** Todas las superficies se separan por color y borde de 1 px. Sombras
   romperían el estilo.
6. **El nombre del espacio va en monoespaciada subrayada** — es una decisión explícita del diseño
   (parece un ID técnico), no un default. Respetala en las pantallas que muestren IDs.

---

## 6. Qué quedó estimado o dudoso (resumen honesto)

**Medido con alta confianza:** fondo `#050508`, superficie `#171719`, superficie alterna
`#141417`, panel `#0C0C0F`, bordes `#242427`/`#2A2A2D`/`#2D2D30`/`#1C1C1E`, acento `#D4FF00`,
texto primario `#FFFFFF`, texto sobre lima `#000000`, rojo de "Baja" `#F87171` sobre `#331D1F`
con borde `#4C2225`, y los fondos/bordes de los 5 chips de deporte.

**Estimado, con incertidumbre declarada:**

- **Colores de texto de los chips de deporte** (verde `#028B5F`, naranja `#C63F06`, violeta
  `#6921CE`, carmesí `#AF085F`, azul `#0379BE`): medidos sobre trazos de ~1 px, el antialiasing
  los oscurece. Los valores sugeridos (`#10B981`, `#F97316`, `#7C3AED`, `#DB2777`, `#0EA5E9`)
  son mi reconstrucción, sin confirmar.
- **Colores de texto secundario** (`#6C6C6E`) y de etiquetas (`#545456`): son el píxel más claro
  medido, o sea la **cota superior** del color real. Podrían ser algo más oscuros, no más claros.
- **`#F0F1F8` vs `#FFFFFF`** en el título del header: los dos aparecen; probablemente sea el
  mismo blanco con distinto render.
- **Toda la escala tipográfica** (±2 dp) y los **radios de esquina** (los redondeos son lo más
  difícil de medir en un PNG): 16 dp tarjetas, 12 dp botones/inputs, 8 dp chips de deporte.
- **Las familias tipográficas**: no son deducibles de un bitmap. Digo "Inter-like" + "mono para
  los IDs".
- **El botón circular oscuro arriba al centro del header de `proto-00`**: no pude determinar qué
  es (¿logo? ¿indicador de estado? ¿menú?). No lo repliqué en el ThemeData.
- **Estados de los componentes**: las capturas son estáticas, así que **hover, pressed, focus,
  disabled y loading no están evidenciados**. Los completé con criterio (foco en lima) y lo marqué.
- **Éxito y alerta**: **no existen en las capturas**. `#0A8A5E` (éxito) lo derivé del chip Fútbol
  y `#FBBF24` (alerta) lo propuse. No son colores del diseño original.
- **Bottom bar y buscador**: **no aparecen en ninguna captura**. Si la app los necesita, hay que
  diseñarlos; el sistema no los define.
- **Home, perfil, login, registro, recuperación, reserva de turno, mis reservas e historial**:
  no hay capturas. Lo único que se puede afirmar es qué **molde** de los tres existentes conviene
  reutilizar en cada caso (ver sección 4.4).
- **Tamaño absoluto de la tipografía**: todo depende de que el frame sea 360×800 dp. La evidencia
  es fuerte (las dos escalas medidas coinciden), pero si el frame fuera otro, **todos los dp de
  este documento escalan proporcionalmente**.
