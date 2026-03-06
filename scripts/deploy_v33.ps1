# [PATCH v33 | 2026-03-06 11:35]
# WHAT: Automazione Deploy Statico (v33).
# WHY: Eliminare dipendenza da GitHub Actions instabili.
# AUTH: Antigravity AI

$env:JAVA_HOME = "C:\Users\tony1\.jdks\openjdk-25.0.2"
$env:ANDROID_HOME = "C:\Users\tony1\AppData\Local\Android\Sdk"
$env:PATH += ";C:\flutter\bin;C:\Users\tony1\.jdks\openjdk-25.0.2\bin"

Write-Host "🚀 Inizio Build CRM Toscana v33..." -ForegroundColor Cyan

# 1. Pulizia e Build
flutter clean
flutter build apk --release

if ($?) {
    Write-Host "✅ Build Completata con Successo!" -ForegroundColor Green
    
    # 2. Copia i file nella cartella di hosting
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" -Destination "ota_hosting\app-release.apk" -Force
    Write-Host "📂 APK copiato in ota_hosting/" -ForegroundColor Yellow
    
    Write-Host "`n🔔 PROSSIMO PASSO:" -ForegroundColor White -BackgroundColor Blue
    Write-Host "Trascina il contenuto della cartella 'ota_hosting' su Vercel o Netlify."
    Write-Host "Una volta online, l'app si aggiornerà da sola!"
} else {
    Write-Host "❌ Errore durante la build. Controlla i log." -ForegroundColor Red
}

pause
