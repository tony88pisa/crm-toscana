# 📱 CRM Toscana — Guida Installazione Completa

## Cosa ti serve per iniziare

- PC Windows, Mac o Linux
- Smartphone Android (Android 8.0 o superiore)
- Connessione internet
- 30-45 minuti di tempo

---

## PASSO 1 — Installa Flutter

### Windows
1. Vai su https://docs.flutter.dev/get-started/install/windows
2. Scarica il file ZIP di Flutter SDK
3. Estrailo in `C:\flutter` (NON in `C:\Program Files`)
4. Apri **Pannello di Controllo → Sistema → Variabili d'ambiente**
5. Nella variabile `Path`, aggiungi `C:\flutter\bin`
6. Apri il **Prompt dei comandi** e scrivi:
   ```
   flutter doctor
   ```

### Mac
1. Apri il **Terminale**
2. Installa Homebrew se non ce l'hai: https://brew.sh
3. Esegui:
   ```bash
   brew install flutter
   flutter doctor
   ```

### Linux
```bash
sudo snap install flutter --classic
flutter doctor
```

---

## PASSO 2 — Installa Android Studio

1. Scarica da: https://developer.android.com/studio
2. Installalo con le opzioni predefinite
3. All'avvio, vai in **SDK Manager**
4. Spunta "Android SDK Command-line Tools"
5. Nel **Terminale/Prompt**, accetta le licenze:
   ```
   flutter doctor --android-licenses
   ```
   Premi `y` a tutto.

---

## PASSO 3 — Ottieni la API Key Google Maps

1. Vai su: https://console.cloud.google.com
2. Crea un nuovo progetto (es. "CRM Toscana")
3. Clicca **"Abilita API e servizi"**
4. Cerca e abilita: **"Places API (New)"**
5. Vai in **Credenziali → Crea credenziali → Chiave API**
6. Copia la chiave (es. `AIzaSyA...`)

### ⚠️ Limita la chiave per sicurezza (facoltativo ma consigliato)
- In Credenziali → clicca sulla chiave → **Restrizioni applicazione**
- Seleziona **App Android**
- Aggiungi il package name: `it.crm.toscana`

### 💰 Costi Google Maps
- Prime **1.000 ricerche/mese** GRATIS
- Per le ricerche con telefono e website: $35/1.000 richieste
- Per uso normale (10-20 ricerche a settimana): **rimane gratuito**

---

## PASSO 4 — Inserisci la API Key nel progetto

1. Apri il file: `lib/services/maps_service.dart`
2. Trova questa riga:
   ```dart
   const String kGoogleApiKey = 'INSERISCI_LA_TUA_API_KEY_QUI';
   ```
3. Sostituiscila con:
   ```dart
   const String kGoogleApiKey = 'AIzaSyA_LA_TUA_VERA_CHIAVE';
   ```
4. Salva il file.

---

## PASSO 5 — Scarica le dipendenze

Apri il Terminale nella cartella del progetto `crm_toscana/` ed esegui:

```bash
flutter pub get
```

Dovresti vedere: `Got dependencies!`

---

## PASSO 6 — Configura il telefono Android

### Sul telefono:
1. Vai in **Impostazioni → Info sul telefono**
2. Tocca **"Numero build"** 7 volte di fila
3. Torna in Impostazioni → trovi **"Opzioni sviluppatore"**
4. Attiva **"Debug USB"**

### Sul PC:
- Collega il telefono via USB
- Sul telefono, quando appare "Consenti debug USB?" → tocca **OK**

Verifica che il telefono sia riconosciuto:
```bash
flutter devices
```
Deve apparire il tuo telefono nella lista.

---

## PASSO 7 — Compila e installa l'APK

### Opzione A — Installa direttamente sul telefono collegato
```bash
flutter run --release
```
L'app si apre automaticamente sul telefono.

### Opzione B — Genera il file APK da trasferire
```bash
flutter build apk --release
```
Il file APK si trova in:
```
build/app/outputs/flutter-apk/app-release.apk
```
Copialo sul telefono (WhatsApp, email, USB) e aprilo per installarlo.

> **Se il telefono blocca l'installazione:**  
> Vai in Impostazioni → Sicurezza → Attiva "Origini sconosciute" (o "Installa app sconosciute")

---

## PASSO 8 — Primo avvio dell'app

1. Apri **CRM Toscana** sul telefono
2. Accetta i permessi GPS quando richiesto
3. Vai nella scheda **🔍 Cerca**
4. Seleziona una provincia (es. Firenze)
5. Seleziona il tipo di attività (es. Ristoranti & Bar)
6. Premi **"Avvia ricerca"**
7. Aspetta 10-20 secondi
8. I prospect appaiono in **Lista** e **Mappa**

---

## Funzionamento dell'app

### 🗺️ Scheda Mappa
- **Pin rossi** = Nuovi (non ancora contattati)
- **Pin arancioni** = Da visitare
- **Pin blu** = Visitati
- **Pin viola** = Interessati
- **Pin verdi** = Clienti acquisiti
- **Punto blu** = La tua posizione
- Tocca un pin per vedere i dettagli

### 📋 Scheda Lista
- Ordinata per **distanza da te** (puoi cambiare con l'icona in alto a destra)
- Scorri i filtri per stato in alto
- Premi **↓** per esportare in CSV
- Il badge rosso mostra quanti prospect nuovi hai

### 🔍 Scheda Cerca
- Ripeti la ricerca quando vuoi aggiornare
- I duplicati vengono automaticamente ignorati
- Fai più ricerche con tipi diversi di attività

### 📍 Notifiche di prossimità
- L'app ti avvisa se sei entro **400 metri** da un prospect non visitato
- Funziona mentre l'app è aperta o in background

### 📤 Esportazione CSV
- Premi l'icona **↓** nella Lista
- Si apre la finestra di condivisione di Android
- Puoi inviarlo via email, WhatsApp, Google Drive
- Aprilo con Excel: **Dati → Da testo/CSV → Separatore: punto e virgola**

---

## Struttura stati del CRM

```
Nuovo → Da visitare → Visitato → Interessato → Proposta → Cliente acquisito ✓
                                              ↘ Non interessato
```

Aggiorna lo stato direttamente dalla scheda lista (bottoni rapidi)
o dalla scheda dettaglio (tutti gli stati disponibili).

---

## Problemi comuni

### "flutter: comando non trovato"
Riavvia il terminale dopo aver aggiornato le variabili d'ambiente.

### "No connected devices"
- Verifica il cavo USB
- Riattiva il Debug USB sul telefono
- Prova un diverso cavo USB

### "Errore API Google (403)"
- L'API Key non è valida o l'API Places non è attivata
- Verifica nel Google Cloud Console che "Places API (New)" sia abilitata

### "Errore API Google (429)"
- Hai superato il limite gratuito
- Aspetta il giorno successivo o attiva la fatturazione su Google Cloud

### L'app si chiude al click su "Cerca"
- Assicurati di aver inserito la vera API Key nel file `maps_service.dart`

---

## Aggiornamenti futuri

Per aggiornare l'app dopo modifiche al codice:
```bash
flutter build apk --release
```
E reinstalla il nuovo APK sul telefono.

---

## Supporto

Tutto il codice sorgente è nella cartella `lib/`.  
I dati dell'app sono salvati localmente sul telefono in un database SQLite — non vengono mai inviati a nessun server esterno tranne Google Maps (solo durante la ricerca).
