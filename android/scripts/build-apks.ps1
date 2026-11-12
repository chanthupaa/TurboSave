param([ValidateSet('restricted','unrestricted','both')][string]$Variant='both')
$ErrorActionPreference='Stop'
$mobileProjectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$mobileTools=Join-Path $env:LOCALAPPDATA 'TurboSaveBuildTools'
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:GRADLE_USER_HOME=Join-Path $env:USERPROFILE '.gradle'
$env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:\gradle-uds -Djava.net.preferIPv4Stack=true -Djava.net.preferIPv6Addresses=false'
$env:ANDROID_HOME=Join-Path $mobileTools 'android-sdk'
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:TURBOSAVE_BUILD_PYTHON=Join-Path $mobileTools 'python311\python.exe'
$env:TURBOSAVE_SIGNING_PROPERTIES=Join-Path $env:LOCALAPPDATA 'TurboSaveAndroidSigning\release.properties'
if (-not (Test-Path -LiteralPath $env:TURBOSAVE_SIGNING_PROPERTIES)) { throw 'Configure the private local signing file before building a release APK.' }
Push-Location -LiteralPath $mobileProjectRoot
try {
    New-Item -ItemType Directory -Path 'artifacts\apks' -Force | Out-Null
    $mobileVariants=if ($Variant -eq 'both') {@('restricted','unrestricted')} else {@($Variant)}
    foreach ($mobileVariant in $mobileVariants) {
        flutter build apk --release --no-pub --flavor $mobileVariant --target-platform 'android-arm,android-arm64' --split-debug-info="artifacts/symbols/$mobileVariant"
        if ($LASTEXITCODE -ne 0) { throw ('Android build failed for '+$mobileVariant) }
        $mobileBuiltApk=Join-Path $mobileProjectRoot "build\app\outputs\flutter-apk\app-$mobileVariant-release.apk"
        $mobileLabel=if ($mobileVariant -eq 'restricted') {'Restricted'} else {'Open'}
        $mobileReleaseApk=Join-Path $mobileProjectRoot "artifacts\apks\TurboSave-$mobileLabel-1.5.3.apk"
        Copy-Item -LiteralPath $mobileBuiltApk -Destination $mobileReleaseApk -Force
        & (Join-Path $env:ANDROID_HOME 'build-tools\36.0.0\apksigner.bat') verify --verbose $mobileReleaseApk
        if ($LASTEXITCODE -ne 0) { throw ('APK signature check failed for '+$mobileVariant) }
        & (Join-Path $env:ANDROID_HOME 'build-tools\36.0.0\zipalign.exe') -c -P 16 4 $mobileReleaseApk
        if ($LASTEXITCODE -ne 0) { throw ('APK alignment check failed for '+$mobileVariant) }
        Get-FileHash -LiteralPath $mobileReleaseApk -Algorithm SHA256
    }
} finally { Pop-Location }
