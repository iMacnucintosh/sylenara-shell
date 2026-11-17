# Guía de uso (Sylenara)

Detalle de cómo usar las piezas del fork. Listado corto y cara pública: **[README.md](./README.md)**.  
Opciones `shell.json`: **[CONFIG.md](./CONFIG.md)**. Changelog: **[CHANGELOG.md](./CHANGELOG.md)**.

Repositorio: [iMacnucintosh/sylenara-shell](https://github.com/iMacnucintosh/sylenara-shell). Créditos en el README y en `NOTICE`.

---

## Activities (espacios agrupados)

Sistema opcional (activado por defecto en este fork) que agrupa desktops de Hyprland en **actividades**.

### En la barra

- En lugar del strip clásico de workspaces, ves una **pill por actividad** (icono + sus desktops).
- Clic en el icono de la actividad → salta a su primer desktop.
- Clic derecho en el icono → popout integrado junto a la barra (p. ej. cerrar todas las ventanas de esa activity).
- El scroll de workspaces se queda **dentro** de la actividad actual (no salta a otra actividad).

### Overview

- Atajo por defecto: **Super + Tab** (remapeable); también funciona con una app a pantalla completa (p. ej. un juego).
- Vista a pantalla completa de todas las actividades y sus desktops.
- Clic en un desktop para ir a él.
- Arrastra ventanas entre desktops (también entre activities); al soltar se enfoca el destino y se aplica su look.
- Apps **ancladas (pinned)** no se arrastran y muestran un icono de pin.
- Si una ventana tiene audio (PipeWire), un chip pequeño de volumen abajo a la izquierda permite silenciarla / reactivarla sin salir del overview.
- **Añadir y quitar desktops sin ir a Ajustes:** el botón **+** a la derecha del título de cada actividad añade un desktop al final de ella (hasta 10). Al pasar el ratón por un desktop **sin ventanas** aparece en su esquina superior derecha, algo hacia fuera, un badge discreto con un **−** para eliminarlo (nunca el último de la actividad, ni uno al que haya una app anclada con una regla de Ajustes → Actividades, aunque ahora esté cerrada). Los desktops de todas las actividades se numeran de seguido en Hyprland, así que al añadir o quitar uno se renumeran los siguientes: sus ventanas se mueven con ellos para seguir en su actividad, y las apps ancladas a un desktop posterior de la misma actividad lo siguen.
- Cierra con Escape o clic fuera.

### Cambiar de actividad

- Por defecto: **Super + Ctrl + ← / →** (al primer desktop de la activity anterior/siguiente).
- Remapeable en **Ajustes → Teclado y ratón**.

### Estilo por actividad

Al cambiar de actividad puedes aplicar (y recordar) de forma independiente:

- Wallpaper
- Esquema / colores
- Modo claro / oscuro
- Transparencia
- “Light apps” (apps Adwaita/Qt en claro aunque el shell esté oscuro)

Las actividades que no son la principal pueden **heredar** el look de Home o definir el suyo.

El apply es **un solo proceso** (`scripts/apply-activity-style.py`): evita carreras light/dark y respeta el modo de la activity aunque `smartScheme` esté activo. GTK/Thunar se actualizan con la paleta Material (recarga en vivo vía `colors.css` + `colorreload-gtk-module`).

### Apps ancladas a un desktop

Desde **Ajustes → Actividades** puedes asociar aplicaciones a un desktop concreto de una activity.  
Hyprland aplica esas reglas al arrancar (archivo generado `~/.config/hypr/sylenara-activity-rules.lua`).

### Configuración

**Ajustes → Actividades**:

- Siempre activas (puede haber solo Principal o varias; sin interruptor Activar/desactivar)
- Mostrar iconos de apps en los workspaces de la barra
- Crear, renombrar, elegir icono y número de desktops (1–10)
- Look por activity
- Pin de apps por desktop

Defaults de ejemplo: Principal (2 desktops), Juegos (1), Trabajo (2).
Principal no se puede eliminar.

### Setup Hyprland (importante)

En tu config Lua de Hyprland:

```lua
require("sylenara-binds")           -- atajos (Ajustes → Teclado y ratón)
require("sylenara-activity-rules")  -- reglas de activities / pins (Ajustes → Actividades)
```

---

## Launcher (menú de aplicaciones)

- Atajo: **Super + Espacio** por defecto (se cambia en Ajustes → Teclado y ratón).
- También se abre al llevar el puntero al **borde inferior**, en la zona centrada del launcher (como un panel).
- Se cierra al sacar el puntero (como el dashboard), con Escape, al elegir una app, o al perder el foco.
  Si lo abriste con el atajo, se mantiene hasta Escape / elegir app (igual que el resto de paneles por tecla).
- Se puede desactivar el hover en **Ajustes → Paneles → Lanzador → Mostrar al pasar el cursor**.
- La búsqueda normal compara el **nombre**; después de esos resultados se añaden las apps cuyo `Keywords` del `.desktop` tenga una palabra que empiece por lo escrito (mín. 3 letras). Así «seeker» encuentra *Archivos* y «things» encuentra *Paquetes*.
- **Clic derecho** sobre una app: menú contextual (un solo menú abierto a la vez) con:
  - Editar nombre / descripción / icono (diálogo centrado; el launcher no se cierra al editar)
  - Override guardado en `~/.local/share/applications`
  - Favoritos, ocultar o restablecer la personalización

---

## Capturas de pantalla

- Captura de una zona o de una ventana (al pasar por encima se marca con el redondeo de Hyprland y el color principal del esquema).
- Tras capturar sale una **previsualización** propia con herramientas para marcar encima: **línea libre**, **flecha**, **rectángulo** y **goma** (borra un trazo entero al pasar por encima), seis colores y deshacer (`Ctrl+Z`). Las marcas se graban en la imagen al copiar o guardar.
- **Copiar** (`Ctrl+C` o `Intro`), **Guardar** (`Ctrl+S`) o **Descartar** (`Esc`); cualquiera de las tres la cierra y avisa con un aviso emergente.
- Se guardan como `Captura de pantalla_AAAAMMDD_HHMMSS.png` en la carpeta de **Ajustes → Paneles → Utilidades → Carpetas** (`paths.screenshotsDir`). Vacía, es la carpeta de imágenes de XDG más «Capturas de pantalla» en el idioma de la shell, y se fija en la configuración la primera vez que se guarda algo: cambiar de idioma después no reparte las capturas en dos carpetas. Override: env `SYLENARA_SCREENSHOTS_DIR`.
- La captura «al portapapeles» no enseña la previsualización.

---

## Grabación de pantalla

- Card de **Screen recorder** en el panel de utilities (fullscreen / región, con o sin audio).
- El arranque va **desacoplado** del ciclo de vida del panel (`scripts/record-start.sh` / `record.sh`), así la captura **no se aborta** al sacar el ratón del panel o al cambiar de desktop.
- Mientras grabas, utilities/sidebar **permanecen abiertos** al salir el puntero (evita teardowns mid-capture).
- Indicador **REC** / **PAUSE** bajo el reloj en la barra mientras hay grabación activa.
- El chip principal del recorder no re-dispara start mientras ya está grabando (evita toggle-stop accidental).
- Archivos en la carpeta de **Ajustes → Paneles → Utilidades → Carpetas** (`paths.recordingsDir`; vacía = carpeta de vídeos de XDG + «Videocapturas de pantalla» en el idioma de la shell, fijada al primer uso; override: env `SYLENARA_RECORDINGS_DIR`).
- Desde la lista: reproducir, abrir carpeta (Seeker) o borrar.

---

## System updates

Inspirado en [arch-update-checker](https://github.com/iMacnucintosh/arch-update-checker):

- **Ajustes → Actualizaciones**: refrescar, contador, actualizar sistema, lista expandable (info / update / uninstall / URL).
- Engranaje → fuentes (Arch / AUR / Flatpak, todas on por defecto), wrapper AUR (**yay**), intervalo, notificaciones, single-package.
- Icono en status (junto a la VPN FortiClient) **solo si hay paquetes**; badge con el número; popout rápido.
- Poll cada **30 min**; toast al detectar paquetes nuevos (default on).
- **Actualizar sistema**: popup de contraseña → en **panel** corre en segundo plano; en **Ajustes** muestra log en vivo. Notificación al terminar + rechequeo. Paquete suelto / orphans siguen en terminal.
- **Seguridad del install**: la contraseña vive **solo en memoria** (helper Python + socket unix en `$XDG_RUNTIME_DIR`; no hay fichero `.pw`). yay/pacman usan **`sudo -A`** contra ese askpass — el timestamp de sudo es por TTY y no sobrevive a un Process sin TTY. El timeout de instalación (45 min) tiene *heartbeat*: solo corta si el instalador lleva 45 min **sin imprimir nada** — nunca mata un `pacman` en mitad de una transacción.

---

## Extensiones (v0.2)

Las funciones opcionales viven en `extensions/` y se activan en Ajustes: **widgets** del carrusel (Tareas, Hidratación) en `Paneles → Panel → Carrusel de widgets` y **extensiones** (VPN FortiClient, Juegos) en `Extensiones`. Nada está activado por defecto y desactivar una extensión no borra sus datos. Para escribir una, ver `AGENTS.md` (sección «Extensiones») y el ejemplo `docs/examples/extension-spike/`; las de usuario se instalan con Things (sección Sylenara) o con `scripts/ext.py` en `~/.local/share/sylenara/extensions/<id>/`.

## Extensiones

Página **Ajustes → Extensiones** (sustituye el placeholder de Plugins):

- Lista de features opcionales del fork, con icono identificativo por fila.
- **VPN FortiClient** (extensión aparte, se instala con Things: ver «Extensiones»); después, interruptor on/off. Al activarla aparece el tipo **FortiClient** en Ajustes → Red → Añadir proveedor.
- **Timers** (base): ya no está en Extensiones; su interruptor on/off y sus presets viven en **Ajustes → Paneles → Barra de tareas → Reloj** (`addons.timers.enabled`). Al desactivar se limpian timers activos y se oculta la sección del popout del reloj (el calendario sigue).
- **Hidratación** (extensión `hydration`, del hub: se instala con Things): se activa en `Paneles → Panel → Carrusel de widgets` (`extensions.enabled`); apagarla descarga el servicio (recordatorios y seguimiento) pero conserva los datos. Depósito con waves (shader propio `water.frag.qsb`), meta diaria (default 3000 ml), botones +20/+83/+250/+500 configurables, undo del último trago, y recordatorio con acciones si pasan N minutos (default 15) sin registrar un trago. Sus ajustes viven en `~/.config/sylenara/extensions/hydration.json` (se migran solos desde `addons.hydration`). Estado en `~/.local/state/sylenara/hydration.json`.
- **Juegos (Steam)** (extensión `games`, del hub: se instala con Things; ajustes en `~/.config/sylenara/extensions/games.json`): interruptor on/off (opt-in). Al activar añade la pestaña **Juegos** en el dashboard (a la derecha de Tiempo). Configura API key (oculta por defecto) + Steam ID / vanity / URL de perfil, y el intervalo de refresco (default 10 min). Muestra perfil y nivel, estadísticas globales en shapes Material You (juegos visibles — sin la colección Hidden —, horas, compleción media de logros y juegos al 100 %, amigos en línea), tarjeta del juego destacado con portada y progreso, y un selector de portadas ordenado por última partida. Logros en una lista con scroll: desbloqueados por rareza y bloqueados de más común a más raro, con insignia y descripción. Mapa de calor mensual (puntos = días con logros; el tiempo por día se registra con el shell en marcha). Juegos no Steam desde `shortcuts.vdf`, con horas de Millennium si está instalado. Los logros del perfil deben ser públicos. El muestreo de logros para la compleción media está **capado a 60 juegos** (los más jugados, por orden de playtime) y el refresco periódico **solo corre mientras el dashboard muestra la pestaña Juegos** (no quema API en segundo plano). Caché de logros/schema/% global en disco (`~/.local/state/sylenara/steam-achievements-cache.json`, TTL ~1 día) para arranques en frío más rápidos; el servicio QML es un façade (`Steam`) con capas en `services/steam/*`.

## Extensiones: instalar con Things

**Ajustes → Extensiones** lista las extensiones instaladas: cada una con su icono, nombre y descripción, un interruptor para activarla y, si tiene ajustes, un desplegable. Si una no puede correr, la tarjeta dice por qué (por ejemplo, «Necesita Sylenara >=0.3.0») o avisa de que le faltan sus piezas de sistema. La fila de arriba, **Buscar más en Things**, abre Things (desactivada, con aviso, si no está instalado).

**Instalar, actualizar y quitar se hace en Things**, en su sección **Sylenara** (`Ctrl+4`), que lee el catálogo del [Sylenara Hub](https://github.com/iMacnucintosh/sylenara-hub): extensiones disponibles, instaladas, actualizables y locales. Pide la contraseña solo si la extensión instala algo como administrador, comprueba la huella (`sha256`) y la compatibilidad antes de instalar, y activa la extensión al terminar (o recarga la shell si era una actualización de una ya cargada). Quitar una extensión borra también sus conexiones (por ejemplo las VPN de su tipo); desactivarla desde Ajustes las conserva.

Sin Things, lo mismo desde una terminal con `scripts/ext.py` (`list`, `install <zip>`, `install-hub`, `remove`, `enable`, `disable`, `rescan`). Una extensión instalada a mano en `~/.local/share/sylenara/extensions/` se muestra en Things como «local» y no se toca.

Una extensión de fuera trae sus **traducciones** en `i18n/<idioma>.json` (msgid, o `contexto\u0004msgid`, → traducción); `Tr` las usa cuando la shell no tiene la cadena. Para generarlas desde un `.po`: `scripts/extension-catalog.py <carpeta de la extensión> plugin/src/Sylenara/I18n/trs/es.po`.

### VPN FortiClient

La extensión `vpn-forticlient` (tipo de proveedor FortiClient para la VPN de Ajustes → Red: OTP opcional, certificados, host de comprobación, DNS, entradas de hosts; contraseña solo en `~/.config/sylenara/vpn/<id>.conf`) ya no viene con la shell: vive en su propio repo, junto a su zip y su documentación. Se instala con Things (pide la contraseña: ayudante root `sylenara-fortivpn` + regla de sudoers). Sus conexiones en `shell.json` (`type: "ext:vpn-forticlient"`) se conservan aunque no esté instalada: aparecen como «extensión desactivada».

---

## Configuración inicial

Una instalación nueva no arranca con los valores de fábrica sino con los ajustes con los que se usa Sylenara (barra, dashboard,
launcher, notificaciones, utilidades, apps por defecto: Seeker y kitty), **una sola actividad (Principal) con dos escritorios** y
su fondo de pantalla, que viene con la shell (`assets/wallpapers/`). Lo escribe `scripts/setup-defaults.py`
(`services/DefaultsSetup.qml`) **solo si no existe `~/.config/sylenara/shell.json`** (o está vacío): nunca toca una
configuración que ya tengas, y no vuelve a ejecutarse (`~/.local/state/sylenara/defaults.json`). La plantilla es
`assets/defaults/shell.json`: no lleva nada personal (apps favoritas, ubicación del tiempo, conexiones VPN, extensiones activas…).
`python3 scripts/setup-defaults.py --check` dice si haría algo. Los atajos por defecto son los del catálogo, no los tuyos.

## Asistente de bienvenida

Una ventana propia, **flotante y de tamaño fijo** (960×720, centrada: Hyprland flota las ventanas de tamaño fijo, sin reglas), con cinco pasos que sale **sola la primera vez** que arranca la shell (a los 4 s) y se puede volver a abrir con el **botón de varita** de la tarjeta de Sylenara en **Ajustes → Acerca de** (abajo a la izquierda; tooltip «Guía de bienvenida»):

1. **Qué es Sylenara:** el orbe, una frase, quién la hace (**iMacnucintosh**, con enlace a GitHub) (el crédito al proyecto original vive en el README y en `NOTICE`).
2. **Qué te ofrece:** tarjetas con Actividades, Ajustes, el panel, Material You, Extensiones y bloqueo/inicio de sesión.
3. **Aplicaciones hechas para Sylenara:** presenta **Seeker** (explorador de archivos), **Things** (gestor de paquetes), **Veo** (reproductor de vídeo) y **kitty** (la terminal, que la shell recolorea en vivo). Es **informativo**: no instala nada (las instala el paquete base); si una está instalada ofrece abrirla, y si no, indica «No instalada». Debajo, una nota aclara que **kitty viene preinstalada pero se puede usar cualquier otra terminal**, con un botón «Elegir terminal» que abre Ajustes → Aplicaciones.
4. **Tus atajos:** tabla de los atajos en uso ahora, por categorías y con las teclas dibujadas (los numerados se agrupan: «Ir al escritorio 1–10»). Sigue a Ajustes: si cambias uno allí, cambia aquí. Botón **Editar en Ajustes** (Ajustes → Teclado y ratón, donde también se exportan e importan).
5. **Todo listo:** abre Ajustes o termina. Incluye una invitación a **crear tus propias extensiones** (una carpeta con un manifiesto y unos pocos ficheros QML) y a compartirlas en el Sylenara Hub, con enlace a su repo. El paso 2 también lo menciona en la tarjeta de Extensiones.

Cerrarla, omitirla o terminarla cuenta como vista (`~/.local/state/sylenara/welcome.json`); para que vuelva a salir sola: `qs -c sylenara ipc call welcome reset`. Las capturas reales de la shell se añadirán más adelante (por ahora el orbe y tarjetas Material You).

En **Ajustes → Extensiones**, la fila **Buscar más en Things** abre Things (botón desactivado, con aviso, si no está instalado).


## Novedades tras actualizar

Después de una actualización, a los 5 s de arrancar la shell sale una ventana **Novedades** (como la bienvenida: flotante, 960×720) con lo que traen las versiones nuevas respecto a la que tenías, **una sola vez**:

1. **Portada:** el orbe, «Sylenara se ha actualizado a la X» y las novedades en pastillas (clic → su página).
2. **Una página por novedad:** captura con esquinas redondeadas (o un icono grande si no tiene), título y dos líneas.
3. **Todos los cambios:** las secciones de esas versiones del `CHANGELOG.md`, con formato.

Flechas `←`/`→` (o `RePág`/`AvPág`) o la rueda del ratón en cualquier punto de la ventana para pasar páginas (sobre la lista de cambios, la rueda la desplaza), `Esc` para cerrar. Si te saltaste varias versiones, las junta. En una instalación nueva no sale (sale la bienvenida). Se vuelve a ver con el botón **Novedades** (confeti, abajo a la derecha) de la tarjeta de Sylenara en **Ajustes → Acerca de**, o `qs -c sylenara ipc call welcome whatsnew` (`closeNews`, y `resetNews` para probarla).

**Al sacar una versión:** su entrada en `whatsnew/whatsnew.json` (novedades destacadas, en inglés y español, con `icon` de Material Symbols y, si se quiere, `image` → `whatsnew/<versión>/<nombre>.webp`, ~1280 px de ancho, 50-150 KB) y la sección «Sin publicar» del CHANGELOG renombrada a `## X.Y.Z (fecha)`.
## Pantalla (disposición, modos, escala, rotación, VRR)

Bloque **Pantalla** inline en **Ajustes → Dispositivos conectados** (categoría Dispositivos; sin entrada propia en el sidebar).

**Con varias pantallas** arriba hay un **esquema** con las pantallas dibujadas en proporción y en el sitio que ocupan:

- **Arrastra** una pantalla para colocarla como está en tu mesa: al soltarla se **pega al borde** de otra (alineada con su arriba, centro o abajo si queda cerca), nunca encima de otra, y el resto se junta para que el puntero pueda llegar a todas. Mientras arrastras, un contorno enseña dónde caería.
- La disposición queda **pendiente**: una barra avisa («Nueva disposición, aún sin aplicar») y hasta pulsar **Aplicar** no cambia nada en las pantallas; **Descartar** vuelve atrás.
- Las pantallas se **numeran** de izquierda a derecha. **Identificar** muestra ese número en grande, unos segundos, sobre cada monitor físico (imprescindible si hay dos iguales).
- Pulsa una pantalla (en el esquema o en los selectores de debajo) para ver **sus** ajustes. Las que están apagadas o duplicando a otra solo salen en los selectores.
- Los cambios que podrían dejar una pantalla inservible (resolución, frecuencia, escala, rotación, apagar, duplicar, cambiar la disposición) piden confirmación: **«¿Mantener estos ajustes? Se deshará en 15 s»** con **Mantener** y **Deshacer**; si nadie contesta, se deshacen solos.

Con una sola pantalla no hay esquema: solo sus ajustes. Una tarjeta por monitor:

- **Activada**: apaga la pantalla (nunca la última que queda encendida); al volver a encenderla recupera su modo preferido y Hyprland la coloca.
- **Rotación**: normal, 90°, 180° o 270°.
- **Duplicar otra pantalla**: copia lo que muestra otra (un proyector, por ejemplo).
- **Resolución** y **Frecuencia** por separado (la lista de Hz solo muestra modos de la resolución actual).
- **Escala**.
- **VRR / Adaptive Sync** con política estilo Plasma: **Nunca / Automático / Siempre** (Automático = solo mientras haya algo a pantalla completa).

Persistencia por conector en `~/.config/hypr/sylenara-monitors.lua` (modo, posición, escala, rotación, duplicado, apagado y VRR); al aplicar se ejecuta `hyprctl reload`, que es lo que hace que el apagado de VRR llegue de verdad al CRTC. La política vive en el Lua y el estado "activo" que reporta `hyprctl` no pisa tu elección. Requiere en tu config de Hyprland:

```lua
require("sylenara-monitors")
```

---

## Utilities / modo oscuro

- En **interruptores rápidos**: luna (**Modo oscuro**). Lo pone todo oscuro por encima del aspecto de cada actividad: esquema en modo oscuro y sin apps claras (GTK, Qt, portal, Chromium/Electron, kitty, Seeker, Things…).
- Es un ajuste **temporal**: no toca las actividades. Al apagarlo cada una vuelve a su aspecto tal cual. Mientras está activo, Ajustes marca «En pausa» el tema oscuro y las apps claras de cada actividad.
- Un sabor que solo es claro (Catppuccin Latte, Rosé Pine Dawn) pasa al primer sabor oscuro del mismo esquema.
- Persiste en `~/.local/state/sylenara/dark-mode.json`. Atajo **sin asignar** (Ajustes → Atajos → «Modo oscuro») e IPC: `qs -c sylenara ipc call darkMode toggle | enable | disable | status`.
- Se activa o quita de la fila en Ajustes → Paneles → Utilidades → Interruptores rápidos.

---

## Utilities / mantener activo

- En **interruptores rápidos**: icono de café (**Keep awake**), a la izquierda del gamepad.
- **Activado por defecto** (bloquea idle/suspend del compositor vía idle inhibitor).
- El estado del interruptor **persiste** entre reinicios de la shell (`syl shell -r`) vía `RuntimeState` (`/run/user/$UID/sylenara/state.json`). Tras un logout/reboot de sesión el runtime se pierde y vuelve el default ON.
- La card grande «Mantener activo» está oculta por defecto (se puede volver a mostrar en Ajustes → Paneles → Utilidades → Tarjetas).

---

## Explorador y theming GTK

- Explorador por defecto: **Seeker** (`general.apps.explorer: ["seeker"]` + Super+E + `xdg-mime` para carpetas). Repo aparte `~/Desarrollo/seeker`; tema M3 vía `~/.config/seeker/theme.json` (escrito por `sylenara-quiet.py`). Thunar sigue disponible como alternativa. Los pickers internos (wallpaper, avatar, icono de `.desktop`) usan `components/filedialog/FileDialog.qml` → `seeker --pick` (sin explorador QML embebido).
- Gestor de paquetes: **Things** (lanzador «Paquetes», repo aparte `~/Desarrollo/things`, pacman + AUR + Flatpak). Tema M3 vía `~/.config/things/theme.json`, escrito por `_sync_things` en `sylenara-quiet.py` (mismo formato que Seeker; hot-reload).
- Para que Thunar/GTK sigan el esquema de Sylenara: `adw-gtk-theme`, `papirus-icon-theme`, y `GTK_MODULES=colorreload-gtk-module` (Hyprland + `settings.ini`; el módulo está **vendorizado** en `~/.local/share/gtk-3.0/modules/`, ver abajo).
- Iconos de apps en el launcher: tema **Papirus** (sincronizado en `~/.config/qt6ct/qt6ct.conf [Appearance] icon_theme` al aplicar el esquema).
- Diálogos `pkexec` (Timeshift, VPN helper, etc.): activa `hyprpolkitagent.service` (`systemctl --user enable --now hyprpolkitagent`).

---

## Integración con el sistema

Sylenara no necesita un escritorio completo debajo: con Hyprland, qt6ct, Papirus y los portales gtk + hyprland, todo sigue sus colores.

- **Login**: **greetd + greeter Quickshell Material You** con el teclado del sistema y autologin inicial a `/usr/bin/start-hyprland`. Tras cerrar sesión, el greeter corre sobre un Hyprland mínimo y entrega la sesión con fundido negro corto: tanto el greeter como la sesión arrancan sin TTY de control (el logo ASCII de Hyprland no llega a tty1), la salida va a `session-startup.log` / `hyprland-greeter.log`, y el compositor desechable se desmonta de inmediato (Hyprland 0.57 se quedaba ~5 s y acababa en segfault al salir). systemd no retiene `user@` 10 s ni espera 90 s a coredumps (`UserStopDelaySec=0`, `TimeoutStopSec=8`). Si greetd no confirma el arranque, recupera la UI en vez de dejar una pantalla negra. Se instala/actualiza con `scripts/install-system.sh` (un solo prompt de root; `greeter/install-greeter.sh` hace lo mismo); al actualizar Sylenara se vuelve a copiar solo. Lo que ejecuta el login es de root: tu sesión solo le pasa el tema, el fondo y el avatar (`/etc/greetd/sylenara/user/`).
- **Apps Qt**: `QT_QPA_PLATFORMTHEME=qt6ct` en 3 sitios (pragma `Env` en `shell.qml`, env en `hyprland.lua`, `~/.config/environment.d/99-qt-platformtheme.conf`); aplica a procesos nuevos y la sesión completa se normaliza al volver a entrar. `scripts/sylenara-quiet.py` empuja en cada cambio de esquema (`_sync_qt6ct`), de forma atómica (temp+rename, lo pilla el QFileSystemWatcher de qt6ct):
  - `~/.config/qt6ct/colors/sylenara.conf`: paleta Qt (22 roles de `QPalette`) mapeada desde los tokens Material de la activity
  - `~/.config/qt6ct/qt6ct.conf`: `icon_theme=Papirus-{Mode}`, `custom_palette=true`, `style=Fusion`
- **Cursor**: alineado GTK/Qt/Hyprland a **Adwaita** (`gsettings cursor-theme`, `gtk-cursor-theme-name` de `settings.ini`, env `XCURSOR_THEME`/`HYPRCURSOR_THEME`).
- **Módulo `colorreload-gtk-module`**: copiado a `~/.local/share/gtk-3.0/modules/` (GTK resuelve el módulo por nombre en `$XDG_DATA_HOME`); recarga los colores de las apps GTK3 sin reiniciarlas. No existe versión para GTK4.
- **`org.freedesktop.FileManager1`**: lo sirve Seeker («Mostrar en carpeta» de navegadores y apps abre Seeker). Override a nivel de usuario en `~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service` (→ `~/.local/bin/seeker`), que gana a los de `/usr/share/dbus-1/services/`.

---

## Kitty y colores de la activity

Kitty no es un target nativo de Sylenara; este fork lo integra así. **Desde la 0.3 lo conecta la propia shell** (`services/KittySetup.qml` → `scripts/setup-kitty.py`): en el primer arranque con kitty instalado copia la plantilla (solo si no tienes una) y añade a tu `kitty.conf` un bloque marcado con lo de abajo, solo con lo que falte, dejando una copia `kitty.conf.sylenara-backup` y avisando con un toast. Respeta un `allow_remote_control no` o un `listen_on` tuyos (no los pisa). Para desconectarlo, borra el bloque (no vuelve a tocarlo: `~/.local/state/sylenara/kitty-setup.json`). A mano, `python3 scripts/setup-kitty.py --check | --force`. Lo que hace, en detalle:

1. Plantilla de usuario: `~/.config/sylenara/templates/kitty.conf` (variables `{{ surface.hex }}`, `{{ term0.hex }}`, …).
2. Generada en: `~/.local/state/sylenara/theme/kitty.conf`.
3. En `~/.config/kitty/kitty.conf`:

```conf
include ~/.local/state/sylenara/theme/kitty.conf
allow_remote_control yes
listen_on unix:${XDG_RUNTIME_DIR}/kitty-{kitty_pid}.sock
```

4. Recarga en vivo al cambiar wallpaper / esquema / activity:
   - `~/.config/sylenara/scripts/kitty-reload-colours.sh`
   - Hook en `cli.json` (`theme.postHook` / `wallpaper.postHook`)
   - `scripts/sylenara-quiet.py` (usado por la shell) llama a esa recarga tras aplicar colores
5. En zsh (ventanas nuevas): `cat ~/.local/state/sylenara/sequences.txt` en `~/.zshrc`.

Tras el primer arranque de Kitty con `listen_on`, al cambiar de activity (barra, atajos u overview) la paleta de las ventanas abiertas se actualiza sola.

---

## Reloj y temporizadores

Al pasar el ratón por el **reloj** de la barra:

1. **Calendario** (el mismo del dashboard).
2. **Temporizadores**:
   - Presets: **5 / 10 / 20 / 30** min
   - Duración manual (1–180 min): escribe el número y pulsa Enter o +
   - Lista de timers activos con cuenta atrás y cancelar
   - Al terminar: aviso (toast) + sonido del sistema
   - Se **conservan** si reinicias la shell (estado en `~/.local/state/sylenara/timers.json`)

El reloj lleva siempre la pastilla de fondo; al hover se resalta como el resto de la barra.

---

## Notificaciones

- **Clic izquierdo** en un popup o en la card de la **sidebar**: enfoca/abre la app (workspace, tray o `.desktop`) y cierra la notificación. No hay botón aparte de “abrir”.
- **Hover en la esquina superior derecha** (y la inferior derecha) abre la **sidebar** de notificaciones, no solo utilities.
- Botones de la card: cerrar, acciones de la app (si tienen texto/icono útil) y copiar; se ocultan acciones vacías (p. ej. Teams).
- Compatible con `actionOnClick` cuando hay una sola acción de notificación.
- **Avisos emergentes (toasts)**: salen integrados en el borde de la shell (mismo `PanelBg` que las notificaciones), con animación como los popups de notificación. **Posición** en Ajustes → Notificaciones → Avisos emergentes: **Superior** (esquina superior derecha; por defecto) o **Inferior** (esquina inferior derecha). Con la sidebar abierta el aviso queda a su izquierda en ambas posiciones. Config: `utilities.toasts.position` = `"top"` / `"bottom"`.
- **Now playing**: portada con `CoverArt` animado (shape al azar entre cookies / soft burst / sunny / gem / …; sin Oval ni ClamShell). No avisa en vistas previas mudas del listado de YouTube (URL MPRIS de resultados/inicio) ni al re-enfocar Zen con la misma pista; sí al cambiar de canción/vídeo real (`/watch`, `/shorts`, `/live`).
---

## Barra (otros retoques)

- **Tray**: muestra también ítems en estado Passive (p. ej. Teams en idle); highlight al hover / menú abierto; tamaño de icono estable. El **StatusNotifierWatcher** vive fuera de `qs` (`scripts/status-notifier-watcher.py`, arrancado por `scripts/start-shell-with-tray-watcher.sh` desde Hyprland) para que los trays Electron/Flatpak (Teams) sobrevivan a `syl shell -r` — sin Plasma ya no hay `xembedsniproxy` que rescate el fallback X11.
- **Iconos de estado**: pastilla al pasar el ratón, como la bandeja.
- **Popouts** de status un poco más anchos para que no se recorten.
- **Reloj** centrado de forma estable en su hueco de la barra; al pasar el ratón sale su pastilla, y el fondo respeta el interruptor «Fondo» de Ajustes (apagado, solo se pinta al pasar el ratón).
- Indicador de **grabación** bajo el reloj (ver sección anterior).
- La batería se muestra u oculta desde la lista de iconos de estado; sin batería, el icono y su popout muestran el **perfil de energía** activo.

---

## Ajustes y atajos

- **Atajos de Hyprland remapeables** desde Ajustes (genera `sylenara-binds.lua`), incluyendo teclas **F13+** y **Última ventana** (Super+\` por defecto; cruza escritorios/actividades vía Hyprland).
- **Exportar / importar atajos** (Ajustes → Teclado y ratón, botones «Exportar» e «Importar»): «Exportar» guarda `sylenara-keybinds.json` (formato `{format, version, binds}`: lo que difiere de los atajos por defecto) en la carpeta que elijas con Seeker; «Importar» lo lee, **sustituye** tus atajos y los aplica. Se ignoran las acciones desconocidas y los valores no válidos, y si dos acciones quedan con la misma tecla solo se conserva la primera. Un fichero que no es de atajos no cambia nada. Sirve para pasar la configuración a otro equipo o tener una copia.
- **Foco del ratón** en Ajustes → Teclado y ratón: al pasar por encima (Hyprland `follow_mouse = 1`) o al hacer clic (`= 2`). Genera `sylenara-input.lua`.
- **Distribuciones de teclado** en Ajustes → Idioma y región → Teclado: la lista de distribuciones (la primera es la principal; hasta cuatro, con variantes como catalán), un buscador para añadir más por idioma o código y el atajo para cambiar entre ellas (Alt+Mayús, Ctrl+Mayús o Bloq Mayús; sin atajo, desde la barra). Mientras no cambies nada se muestran las del sistema y Sylenara no las toca; al cambiar algo las guarda (`general.keyboardLayouts`, `general.keyboardSwitch`) y las escribe en `sylenara-input.lua`, aplicadas al momento.
- **Transiciones entre escritorios y entre actividades** en Ajustes → Actividades: una animación para moverte entre los escritorios de una actividad (`workspaceAnimation`, por defecto *Deslizar en vertical*) y otra para saltar a otra actividad (`activityAnimation`, por defecto *Fundido*). Estilos: *Fundido* (el de Hyprland), *Deslizar*, *Deslizar en vertical*, *Deslizar y fundir* y *Deslizar y fundir en vertical*; con los de deslizar aparece su *Velocidad* (`…Speed`: lenta, normal, rápida; en Hyprland `speed` es la duración en décimas de segundo, así que menos es más rápido). La de escritorios se escribe en `~/.config/hypr/sylenara-animation.lua` (se carga con `pcall(require, "sylenara-animation")` al final de `hyprland.lua`, tras las animaciones por defecto); al saltar a otra actividad por la shell (barra, atajos, vista general) se aplica la suya justo antes del salto y se repone la de escritorios a los ~1,2 s. Saltos que Hyprland haga sin pasar por la shell usan la de escritorios.
- Categoría **Activities** en el mapa de teclas (siguiente / anterior / overview).
- Apariencia **unificada en Activities**: una sola página para el comportamiento (iconos, desktops, apps ancladas) y el look — la tarjeta de **Principal** lleva la etiqueta "Look general" (es el estilo que heredan las demás) y cada activity personaliza o hereda (con botón "Usar look de Principal" para volver). Sin página global duplicada: el toggle "Mostrar fondo de pantalla" (switch maestro) vive en General.
- **Extensiones** — solo features opcionales (VPN FortiClient, Juegos/Steam). **Portapapeles y Temporizadores son base** (v0.2): el portapapeles se configura en **Ajustes → Paneles → Utilidades → Portapapeles** (interruptor + tamaño del historial) y los temporizadores en **Paneles → Barra de tareas → Reloj**.
- **Iconos que se ocultan solos**: el de actualizaciones solo sale cuando hay alguna (`bar.status.onlyShowUpdatesWithUpdates`) y el de la VPN, cuando hay una extensión de VPN activa; se ajusta en `Paneles → Barra de tareas → Iconos de estado → Auto-ocultar`. La batería se muestra u oculta desde la lista de iconos visibles; en un sobremesa su popout muestra el perfil de energía, con su selector.
- **Escritorios de la barra**: qué muestran (ventanas, escritorios especiales, número máximo de iconos) se ajusta en **Ajustes → Actividades**, junto al resto de los escritorios; su aspecto (número, indicador, fondo, por monitor), en `Paneles → Barra de tareas → Escritorios`. Cada página enlaza con la otra.
- **Órdenes de las extensiones desde la terminal:** `syl ext <id>` lista lo que ofrece una extensión y `syl ext <id> <orden>` lo ejecuta en la shell. Hidratación: `syl ext hydration show` (el recordatorio ahora), `add 250` (apunta 250 ml) y `status`.
- **Vista previa de ventanas:** al pasar el ratón por el icono de una app en los escritorios de la barra sale un popout con la miniatura en vivo de esa ventana, su título y su app; pulsar en la miniatura lleva a la ventana (aunque esté en otro escritorio). Se activa o desactiva en Ajustes → Paneles → Barra de tareas → Escritorios («Vista previa de la ventana al pasar el ratón», `activities.windowPreview`, activada por defecto).
- **Mostrar escritorio**: pulsar en la barra el escritorio que ya está activo desliza todas sus ventanas fuera de la pantalla (las de la mitad izquierda hacia la izquierda, las de la derecha hacia la derecha, con la animación de mover ventana de Hyprland); siguen en ese escritorio y sus iconos siguen en la barra, pero su pastilla pasa de relleno a solo borde para indicar que están ocultas. Pulsarlo otra vez las devuelve a su sitio. Lo hace `scripts/show-desktop.py` (estado en `$XDG_RUNTIME_DIR/sylenara/`, `Hypr.hiddenWs` en la shell); también `qs -c sylenara ipc call hypr toggleShowDesktop`. Ya no abre el scratchpad ni atenúa la pantalla.

---

## Clipboard (historial)

Popout flotante junto al cursor (estilo Sylenara), respaldado por **cliphist** + `wl-clipboard`:

- **Vista previa de imágenes:** al quedarte ~300 ms sobre una entrada de imagen (o al seleccionarla con las flechas) su miniatura sale de la fila hacia un panel que brota del borde de la tarjeta —a la izquierda, salvo que no quepa— como los drawers de la shell (una sola forma con esquinas cóncavas donde se unen) y crece desde la propia fila y la convierte en la imagen grande (hasta 480×360, sin ampliar de más); no captura el ratón.
- Atajo por defecto: **Super + Shift + V** (Super+V sigue siendo float de ventana; remapeable en Ajustes).
- Buscar, favoritos persistentes (estrella a la derecha; vacía solo al hover), borrar entradas o limpiar historial.
- Al elegir un ítem: se copia y se pega con **Ctrl+V** en la ventana que tenía el foco (`wtype`).
- Texto, imágenes del portapapeles (miniatura) y rutas/`file://` a imagen copiadas desde el explorador (también con preview). Un `preview` que acaba en `.jpg` solo se trata como imagen **si el fichero existe** (comprobado en lote tras cada parse; si no, queda como texto).
- Miniaturas decodificadas **al tamaño del thumb** (`sourceSize`), no al del fichero completo; los favoritos de imágenes binarias se emparejan por el **id de cliphist** de origen (el preview genérico `[[ binary data… ]]` ya no provoca estrellas cruzadas).
- Todos los comandos (`delete`, `wl-copy`, `cliphist decode`…) reciben el contenido del portapapeles **como argumento (`"$1"`)**, nunca metido en la orden: un texto copiado no puede ejecutar nada.
- Fondo igual que el panel izquierdo (`m3surface` + blur de Hyprland).
- Límite de historial configurable (por defecto **50**) en **Ajustes → Paneles → Utilidades → Portapapeles**.
- Dependencias: `cliphist`, `wl-clipboard`, `wtype`.

---

## Atajos por defecto (activities)

| Acción | Atajo por defecto |
| --- | --- |
| Overview de activities | Super + Tab |
| Activity anterior | Super + Ctrl + ← |
| Activity siguiente | Super + Ctrl + → |
| Última ventana (cualquier escritorio/actividad) | Super + \` (grave) |
| Historial del clipboard | Super + Shift + V |
| Ir a la actividad 1–4 | Super + Ctrl + 1…4 |
| Mover la ventana a la actividad siguiente / anterior (y seguirla) | Super + Ctrl + Shift + → / ← |
| Pantalla completa | Super + F |
| Mover la ventana con el teclado | Super + Shift + flechas |
| Fijar ventana (solo flotantes) | Super + Shift + P |
| Volumen +/−, silencio, silenciar micro | teclas XF86 (antes fijas en `hyprland.lua`; ahora remapeables) |

El resto de atajos de base son los de serie (cerrar Super + C, terminal Super + Q, launcher Super + Espacio, escritorios Super + 1…0, mover a escritorio Super + Shift + 1…0…). La lista completa y los que tengas cambiados salen en el paso «Tus atajos» del asistente de bienvenida, con un botón para editarlos en Ajustes.

Cámbialos en **Ajustes → Teclado y ratón**.

---

## OpenCode — plugin file-tree con estados git

**Fuera de la shell** (entorno de agente, no QML): el plugin TUI de OpenCode que muestra el
sidebar de ficheros usa en esta máquina un **fork local** en
`~/.config/opencode/plugins/opencode-file-tree` (se autodescubre; el paquete npm
`opencodev2-file-tree` está fuera de la config).

Extra sobre upstream (`Muyuu-wml/opencode-file-tree` v0.1.3): **colorea carpetas y ficheros
según el estado git**, con glifo delante del nombre:

| Glifo | Estado | Color |
| --- | --- | --- |
| `A` | añadido (staged / nuevo) | verde `diff.text.added` |
| `M` | modificado | ámbar `text.feedback.warning` |
| `D` | borrado | rojo `diff.text.removed` |
| `R` | renombrado/copiado | info `text.feedback.info` |
| `?` | sin seguimiento | verde `diff.text.added` |

- Las **carpetas agregan** el estado de su contenido, prioridad *deleted > modified > added > renamed > untracked* (como los IDEs).
- Un solo `git status --porcelain=v1 -z` por refresco (botón **Refresh**); rutas rebaseadas si el árbol arranca en un subdirectorio; fuera de un repo, árbol normal.
- La fila seleccionada conserva el color primario del tema.
- Cambios en los fuentes posteriormente: `bun run typecheck && bun run build` (bun, no npm) y `opencode service restart`.
- Verificación manual: `test.md` dentro del directorio del plugin. Pendiente de proponer upstream (PR/issue) tras validar.

## OpenCode — tema sincronizado con el esquema

**Fuera de la shell**: el TUI de OpenCode usa un tema `sylenara` generado desde el esquema
M3 de la activity activa. `scripts/sylenara-quiet.py` (paso `_sync_opencode_theme`, justo tras
el theming de GTK/iconos) invoca `scripts/generate-opencode-theme.py` + escribe `cli.json`.

- Salida: `~/.config/opencode/themes/sylenara.json` (formato hue de OpenCode V2, `$schema`
  `https://opencode.ai/theme.json`) + `~/.config/opencode/cli.json` → `{"theme":{"name":"sylenara","mode":...}}`.
- Genera la paleta del modo que llega (dark/light): gradas tonales M3 vía `materialyoucolor.hct`
  (bins de hue asignados por cercanía: red/orange/yellow/green/cyan/blue/purple + gray anclada a
  onSurface/outline/background) y overrides con los colores del esquema (background/surface
  containers, diff containers, syntax/markdown via keys catppuccin `k*`/`term*`).
- Hot-reload: OpenCode **solo** re-aplica el tema cuando cambia `theme.name` en `cli.json`
  (ni el contenido del theme file ni el resto de settings externos se re-leen en caliente, bugs
  conocidos upstream: issues #815/#37423). Por eso el tema vive en **dos gemelas idénticas**
  (`sylenara.json` y `sylenara-alt.json`): cada apply con paleta o modo nuevo flipea `cli.json`
  al otro nombre, lo que fuerza la recarga en los TUI abiertos. Si la paleta no cambió se salta
  (no-op, sin churn). La paleta del otro modo se conserva en la gemela entre runs.
- Peculiaridad del format: los hex DEBEN llevar `#` y **no se aceptan referencias entre tokens**
  (`$text.*`/`$background.*`) en temas de usuario — solo refs `$hue.<nombre>.<step>`; los
  built-in evitan esa validación, los nuestros no (lecciones del debug en este script).

## Lockscreen

La columna derecha del lock (tras CPU/RAM) se parte **35/65**:

- **Arriba**: notificaciones agrupadas por app, con scrollbar cuando no caben.
- **Abajo**: **Sylenara**, la misma compañera espíritu del viento del greeter Quickshell: saludo por hora, líneas idle a máquina de escribir, orbe SoftBurst y estados al escribir la contraseña, fallar PAM o desbloquear.

El panel del lock usa tokens Material de la sesión (`Tokens` / `Colours`) y PAM (`lock.pam`), no el `Theme`/`Auth` del greeter.

---

## Auriculares Bluetooth: modo de audio

El popout de Bluetooth (barra) es una lista de una línea por dispositivo: **el icono es el botón de
conectar/desconectar** (círculo de acento = salida de audio activa, tono suave = conectado, sin círculo =
desconectado), nombre, batería (un anillo con el porcentaje dentro; los AirPods muestran L · estuche · R),
un selector pequeño **Música / Llamadas / Auto** (solo iconos) y el botón de olvidar. El engranaje junto al título
abre una ventana normal de Ajustes en Dispositivos conectados. Los modos:

- **Música**: A2DP fijo (alta calidad, sin micro).
- **Llamadas**: perfil de manos libres fijo (micro siempre disponible). Sirve para Teams: solo lista
  el micro si existe al **entrar** en la reunión, así que conviene tener este modo antes de unirte.
- **Auto**: WirePlumber cambia a manos libres cuando una app graba y vuelve después (comportamiento por defecto).

Implementación: `services/BluetoothAudio.qml` (lee `pactl -f json list cards`, escucha `pactl subscribe`,
aplica con `pactl set-card-profile`). «Auto» es el ajuste **global** de WirePlumber
`bluetooth.autoswitch-to-headset-profile` (se guarda con `wpctl settings --save`), no es por dispositivo.

**Página del dispositivo (Ajustes → Dispositivos conectados → engranaje del dispositivo).** Con unos auriculares
conectados aparece una sección **Audio**: selector de modo (Música / Llamadas / Auto) con su descripción, el canal
actual (alta calidad o llamadas, con códec), la calidad de la música (AAC / SBC-XQ / SBC, si el dispositivo ofrece
varios) y el volumen de la salida con su silencio (el popout no los tiene: el volumen y el silencio solo se
tocan aquí). En **Batería**, los AirPods muestran los tres anillos (L, estuche y R) en una franja. Los componentes
(selector de modo, anillos, franja de baterías, volumen) son compartidos y viven en `components/bluetooth/`.

**Batería de AirPods.** BlueZ no la publica, así que `scripts/airpods-battery.py` la lee del propio auricular por el
canal de accesorios de Apple (L2CAP, solo lectura, ~2 s) y `BluetoothAudio` la sondea cada 2 min mientras haya unos
AirPods conectados. El popout muestra el nivel del auricular más bajo. Si el derecho no reporta (fuera de uso o en el
estuche), se usa el que sí lo hace. Para otros dispositivos se sigue usando la batería de BlueZ.

**mSBC desactivado (MediaTek).** El adaptador Bluetooth de este equipo (`0e8d:0616`) rompía el enlace SCO de los
AirPods con el códec de manos libres mSBC (`SCO packet for unknown connection handle`, nodos en `error`, micro
mudo). `~/.config/wireplumber/wireplumber.conf.d/52-bluetooth-no-msbc.conf` pone `bluez5.enable-msbc = false` y
fuerza CVSD (voz más «telefónica», sin tocar la música). Fichero fuera del repo: para revertir, borrarlo y
`systemctl --user restart wireplumber`.

## Carrusel de widgets del dashboard

El hueco central del dashboard (antes calendario/hidratación según un interruptor) es un **carrusel**: un
widget a la vez. Se cambia con los puntos (superpuestos abajo), la rueda del ratón o arrastrando en
horizontal (en el carrusel el calendario no consume la rueda: `Calendar.scrollable`; el popout del reloj sí); sin rotación automática. Con un solo widget activo no hay controles.

- **Ajustes**: `Ajustes → Paneles → Panel → Carrusel de widgets`. Cada widget es una fila con flechas ↑/↓ para
  **ordenarlo**; Hidratación lleva además su interruptor y sus ajustes desplegables (meta, intervalo, presets).
- **Nada viene activado por defecto**: cada widget (calendario incluido, `dashboard.calendarEnabled`) tiene su interruptor. Sin ninguno activo el carrusel muestra el botón **«Activa widgets»**, que abre Ajustes directamente en `Paneles → Panel`.
- **Tareas** (extensión `tasks`, se activa en el carrusel; `extensions.enabled`): checklist con lista vertical desplazable. Se crean escribiendo y pulsando Enter (o `+`), se marcan con el círculo, se eliminan con la ✕ que aparece al pasar el cursor, y las completadas bajan a una sección **«Completadas (n)» plegable** (con botón para vaciarlas). Al pulsar el campo, el panel toma el teclado y se mantiene abierto hasta `Esc` o clic fuera. Datos en `~/.local/state/sylenara/tasks.json`; desactivar el widget no borra las tareas.
- **Hidratación** on/off sigue siendo `addons.hydration.enabled` (apagarlo detiene también recordatorios y seguimiento).
- Config: `dashboard.widgetOrder` (lista de ids, por defecto `["calendar","hydration"]`). Ids desconocidos se ignoran y
  los que falten se añaden al final, así los widgets nuevos no rompen configs antiguas.
- Para añadir un widget: entrada en `services/DashWidgets.qml` (+ `isEnabled`), caso en
  `modules/dashboard/dash/WidgetCarousel.qml` y, si tiene opciones, su tarjeta en `modules/nexus/pages/panels/DashboardPanel.qml`.

## Plugin C++

Compilarlo e instalarlo en `~/.local` (y por qué la shell carga ese y no el del sistema) está en
[docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md).

## Notas

- Instalación y listado de features: [README.md](./README.md). Historial: [CHANGELOG.md](./CHANGELOG.md).
- Algunas piezas siguen en evolución; si algo no aparece tras actualizar, reinicia la shell (`syl shell -r`) y comprueba los `require(...)` de Hyprland.
- `scripts/sylenara-quiet.py` evita spamear OSC a todos los PTY al cambiar el tema (recarga Kitty, sync Papirus en qt6ct, GTK/`colors.css`).
- `scripts/apply-activity-style.py` aplica wallpaper + esquema de la activity en un solo proceso.
