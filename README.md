# El ahorcado · la vuelta al mundo

El juego del ahorcado para el móvil y el ordenador con **palabras de todo el mundo**: países, capitales, comida del mundo, animales, maravillas, naturaleza, palabras viajeras (las que el español tomó de otros idiomas) e instrumentos. El tema **Todo el mundo** las mezcla todas.

- **Cada palabra tiene una pista** (por ejemplo, *Japón: arroz con pescado crudo*). Al acertar se ven también las tildes.
- **30 niveles por tema.** Cada nivel tiene palabras más largas, más palabras que adivinar, menos fallos permitidos, la pista tapada (y luego con coste) y menos letras regaladas.
- **Puntos** por cada palabra, un extra por los fallos que te sobren y un **premio** al terminar cada nivel. Si te ahorcan, los puntos se quedan, pero repites el nivel con palabras nuevas.
- **Teclado en pantalla con Ñ**, o el teclado del ordenador.
- **Puntos online con código de jugador** (por ejemplo `AH-7K3Q-9XPA`): sirve para recuperar el progreso en cualquier dispositivo y salir en la **clasificación**.
- Opciones del jugador: cambiar el nombre (2 veces como máximo), generar un código nuevo y borrar el jugador.
- **Aviso de versión nueva** para quien tenga el juego abierto cuando se publica una actualización.

## Publicarlo con GitHub Pages

**Settings → Pages → Deploy from a branch → main / (root) → Save.** La web queda en `https://pctecnikk.github.io/el_ahorcado/`.

En el móvil, abre el enlace y usa **Añadir a pantalla de inicio** para tenerlo como una app.

## Base de datos (Supabase)

Usa el mismo proyecto de Supabase que la sopa de letras, pero con sus propias tablas (`ah_players` y `ah_presence`), así que los puntos de un juego no se mezclan con los del otro.

1. En Supabase, abre **SQL Editor → New query**, pega `supabase.sql` y pulsa **Run**. Hasta que no lo hagas, el juego funciona igual pero sin código online ni clasificación.
2. La URL del proyecto y la clave pública (*publishable*) están en `supabase-config.js`.

La URL y la clave pública no son secretas. Las tablas están cerradas: solo se pueden usar a través de las funciones de `supabase.sql`, que guardan el código cifrado y en la clasificación solo muestran el nombre de jugador y los puntos.

### Ver quién está jugando ahora (solo tú)

Supabase → **Table Editor** → **ahorcado_jugando_ahora**. Salen las personas que han dado señales en los últimos 2 minutos, con su nombre de jugador y el tema y nivel en que están.

## Avisar de una versión nueva

La web consulta `version.json` cada minuto. Si cambias `index.html`, pon el mismo número en `APP_VERSION` (dentro de `index.html`) y en `version.json` (por ejemplo `{"version": "1.1.0"}`) y crea la release `v1.1.0`.

## Añadir palabras

En `index.html`, dentro de `THEMES`, cada palabra se escribe como `"Palabra|pista"`, por ejemplo `"Sushi|Japón: arroz con pescado crudo"`. Las tildes se ponen normal; para adivinar basta con la letra sin tilde.

## Archivos

| Archivo | Para qué sirve |
|---|---|
| `index.html` | El juego completo |
| `supabase-config.js` | URL y clave pública de Supabase |
| `supabase.sql` | Script para preparar la base de datos |
| `version.json` | Número de versión para avisar de actualizaciones |
| `manifest.webmanifest`, `icon-*.png`, `icon.svg` | Nombre e icono al añadirlo a la pantalla de inicio |
