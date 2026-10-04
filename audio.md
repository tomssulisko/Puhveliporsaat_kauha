# Äänilista

**Formaatti:** kaikki pelissä käytettävät äänet → **WAV**  
Merkintä: ✅ ok · ❌ puuttuu · ⚠️ epäselvä / nimeämätön · 🔄 väärä formaatti (konvertoi WAV:ksi)

## AudioManager

Autoload: `AudioManager` (`addons/AudioManager/`) — ldjam59-tyylinen, siistimpi toteutus.
Yhteensopiva Storylinen kanssa (`masterVolume` / `fxVolume` / `volume_changed`).

```gdscript
AudioManager.play_ambient("sirkat")
AudioManager.stop_ambient()
AudioManager.play_sfx("lepakko")              # random 1..n
AudioManager.play_sfx_at("luuranko", pos)     # 2D
AudioManager.volume_change(100, 100, 80)
```

Uudet äänet: lisää polku `SFX_LIBRARY` / `AMBIENT_LIBRARY` -dictiin `audio_manager.gd`:ssä.

---

## Viholliset (3 varianttia per vihu)

| Ääni | 1 | 2 | 3 | Formaatti | Tiedostot |
|------|---|---|---|-----------|-----------|
| Luuranko (luiden kolina) | ✅ | ✅ | ✅ | WAV | `Audio/luuranko1-3.wav` |
| Lepakko (vikisee) | ✅ | ✅ | ✅ | WAV | `Audio/lepakko1-3.wav` |
| Silmät (örisee) | ✅ | ✅ | ✅ | WAV | `Audio/silmät1-3.wav` |

## Muut SFX

| Ääni | Status | Formaatti | Tiedosto / muistiinpano |
|------|--------|-----------|-------------------------|
| Lepakon lentoääni (“fuh fuh fuh”) | ❌ | — | — |
| Reitin / portin avautuminen (kalikat → matalaksi “kivipaasi”) | ❌ | — | — |
| Silmämonsterin askel | ❌ | — | — |
| Silmämonsterin katoaminen | ❌ | — | — |
| Pelaajan askel | ❌ | — | — |
| Pelaajan kuolema | ✅ | 🔄 MPEG | `Audio/kuolema1.mpeg`, `kuolema2.mpeg` → konvertoi `kuolema1-2.wav` |
| Pelaaja “nonii” | ✅ | WAV | `Audio/pelaaja_no_niin.wav` |

## Jatkuvat taustaäänet (loop)

| Ambient | Kenttä | Status | Formaatti | Tiedosto |
|---------|--------|--------|-----------|----------|
| Auton ajoääni | Intro (kunnes hyytyy) | ❌ | — | — |
| Sirkkojen siritys | Summon-kenttä | ✅ | WAV | `Audio/sirkatsoittaa.wav` |
| Tuulen suhina | Alku + hautausmaa | ✅ | WAV | `Audio/tuuli.wav` (level 1) |
| Naakat | Hautausmaa | ❌ | — | — |
| Narina (roskiksen kansi tms.) | Autoromuttamo | ❌ | — | — |

## Puhujaäänet (tavoite 5 / hahmo)

| Hahmo | Tavoite | Nyt | Formaatti | Tiedostot |
|-------|---------|-----|-----------|-----------|
| Pelaaja (muminaa) | 5 | 3 | WAV | `addons/Storyline/puhe/pelaaja/pelaaja1-3.wav` → **+2 puuttuu** |
| Auttaja (hienostunut höpinä) | 5 | 3 | WAV | `addons/Storyline/puhe/auttaja/auttaja1-3.wav` → **+2 puuttuu** |

## Formaatti / siivous

| Tiedosto | Ongelma | Toimenpide |
|----------|---------|------------|
| `Audio/kuolema1.mpeg`, `kuolema2.mpeg` | MPEG, ei WAV | Konvertoi → `kuolema1.wav`, `kuolema2.wav` (pelaajan kuolema) |
| WhatsApp `*.mpeg` / `*.mpg` | MPEG/MPG, nimeämätön | Konvertoi WAV:ksi ja nimeä, tai poista |
| `Fart with reverb...mp3` | MP3 | Poista jos ei käytössä, muuten → WAV |
| `Audio/nimetön.wav` | WAV ok, nimi epäselvä | Tunnista ja nimeä |
| `Audio/pölöpölö.wav` | WAV ok, nimi epäselvä | Tunnista ja nimeä |

---

## Prioriteetti (ehdotus)

1. ~~AudioManager + ambient-vaihto kentittäin~~ (sirkat level 1:ssä)  
2. Konvertoi kuolema + muut MPEG/MP3 → WAV  
3. Askeläänet (pelaaja + silmä)  
4. Portin avautuminen  
5. Lepakon lento + silmän katoaminen  
6. Puuttuvat puhujaäänet (+2 per hahmo)  
7. Tuuli / naakat / narina / auton ajo  
8. Wire SFX vihollisiin kun entiteetit valmistuvat (`play_sfx_at`)
