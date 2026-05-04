Set-Alias -Name k -Value kubectl
Set-Alias -Name kx -Value kubectx
Set-Alias -Name kn -Value kubens

function Get-DevSecOpsToolkitStateRoot {
    Join-Path $HOME '.devsecops-shell-toolkit'
}

function Get-DevSecOpsToolkitConfigPath {
    $override = $env:DEVSECOPS_TOOLKIT_CONFIG
    if ($override) {
        return $override
    }

    Join-Path (Get-DevSecOpsToolkitStateRoot) 'config.json'
}

function Get-DevSecOpsToolkitMetadataPath {
    Join-Path (Get-DevSecOpsToolkitStateRoot) 'install-metadata.json'
}

function Read-DevSecOpsToolkitJsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    $raw | ConvertFrom-Json
}

function Get-DevSecOpsToolkitConfig {
    $defaults = [ordered]@{
        JenkinsUrl            = ''
        JenkinsCredentialPath = (Join-Path $HOME '.jenkins_secret.xml')
        BmcRobotPath          = ''
        BmcRobotCommand       = 'npx tsx .\tests\request-sp.ts'
    }

    $configPath = Get-DevSecOpsToolkitConfigPath
    $savedConfig = Read-DevSecOpsToolkitJsonFile -Path $configPath

    if (-not $savedConfig) {
        return [PSCustomObject]$defaults
    }

    foreach ($key in $defaults.Keys) {
        if ([string]::IsNullOrWhiteSpace($savedConfig.$key)) {
            $savedConfig | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key] -Force
        }
    }

    return $savedConfig
}

function Update-DevSecOpsToolkit {
    param(
        [switch]$Reimport
    )

    $metadataPath = Get-DevSecOpsToolkitMetadataPath
    $metadata = Read-DevSecOpsToolkitJsonFile -Path $metadataPath

    if (-not $metadata) {
        throw "Install metadata not found. Run install.ps1 first. Expected: $metadataPath"
    }

    $repoRoot = $metadata.RepositoryRoot
    if (-not $repoRoot -or -not (Test-Path -LiteralPath $repoRoot)) {
        throw 'Repository root from install metadata is missing. Reinstall the toolkit.'
    }

    $gitFolder = Join-Path $repoRoot '.git'
    if (Test-Path -LiteralPath $gitFolder) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw 'Git is required to update from a repository checkout.'
        }

        Write-Host "Refreshing repository in $repoRoot ..." -ForegroundColor Cyan
        git -C $repoRoot pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            throw 'git pull failed. Resolve the repository state and try again.'
        }
    }
    else {
        Write-Host 'Repository checkout does not contain git metadata. Only local file sync will run.' -ForegroundColor Yellow
    }

    $sourceModulePath = Join-Path $repoRoot 'src\powershell\DevSecOpsToolkit'
    if (-not (Test-Path -LiteralPath $sourceModulePath)) {
        throw "Source module not found: $sourceModulePath"
    }

    Copy-Item -Path (Join-Path $sourceModulePath '*') -Destination $PSScriptRoot -Recurse -Force

    if ($Reimport) {
        $moduleName = $MyInvocation.MyCommand.Module.Name
        Remove-Module $moduleName -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot 'DevSecOpsToolkit.psd1') -Force
    }

    Write-Host 'DevSecOpsToolkit updated successfully.' -ForegroundColor Green
}

function aks-sync {
    Write-Host 'Buscando clusteres AKS en la suscripcion activa...' -ForegroundColor Cyan

    $seleccion = az aks list --query "[].[name, resourceGroup]" -o tsv | fzf -m --prompt="Selecciona AKS (TAB=Varios, Enter=Confirmar): " --height=15 --layout=reverse

    if (-not $seleccion) {
        Write-Host 'Operacion cancelada, no has elegido ningun cluster.' -ForegroundColor Yellow
        return
    }

    foreach ($line in $seleccion) {
        $parts = $line -split '\s+'
        if ($parts.Count -ge 2) {
            $aks_name = $parts[0]
            $aks_rg = $parts[1]
            Write-Host "Descargando credenciales de: $aks_name ..." -ForegroundColor Green
            az aks get-credentials --name $aks_name --resource-group $aks_rg --overwrite-existing
        }
    }

    $destino = if ($env:KUBECONFIG) { $env:KUBECONFIG } else { '~/.kube/config' }
    Write-Host "Todo inyectado en: $destino" -ForegroundColor Magenta
}

function asx {
    Write-Host 'Buscando suscripciones en tu cuenta...' -ForegroundColor Cyan

    $seleccion = az account list --all --query "[].[name, id]" -o tsv | fzf --prompt="Suscripcion (Enter=Cambiar): " --height=15 --layout=reverse

    if (-not $seleccion) {
        Write-Host 'Operacion cancelada.' -ForegroundColor Yellow
        return
    }

    $partes = $seleccion -split '\t'
    $nombre = $partes[0]

    Write-Host "Cambiando suscripcion a: $nombre ..." -ForegroundColor Green
    az account set --subscription $nombre
    Write-Host 'Hecho. Ya estas dentro.' -ForegroundColor Magenta
}

function k-clean {
    Write-Host 'Limpiando pods que han terminado con error...' -ForegroundColor Cyan
    kubectl get pods --all-namespaces | Select-String -Pattern 'Terminated|Evicted|Error' | ForEach-Object {
        $parts = $_ -split '\s+'
        kubectl delete pod $parts[1] -n $parts[0]
    }
    Write-Host 'Limpieza completada.' -ForegroundColor Magenta
}

function get-sp-expiry {
    Write-Host '--- Buscador de Caducidad de Secretos (SP) ---' -ForegroundColor Cyan

    Write-Host '1. Buscar por Nombre (DisplayName)'
    Write-Host '2. Buscar por Application ID (Client ID)'
    $metodo = Read-Host 'Selecciona una opcion (1 o 2)'

    if ($metodo -eq '1') {
        $nombre = Read-Host 'Introduce el nombre'
        $apps = az ad app list --display-name $nombre --query "[].{Name:displayName, AppId:appId}" -o json | ConvertFrom-Json
    }
    elseif ($metodo -eq '2') {
        $appid = (Read-Host 'Introduce el Application ID').Trim()
        $apps = az ad app list --filter "appId eq '$appid'" --query "[].{Name:displayName, AppId:appId}" -o json | ConvertFrom-Json
    }
    else {
        return
    }

    if (-not $apps) {
        Write-Host 'No se encontro nada.' -ForegroundColor Yellow
        return
    }

    $appSeleccionada = $apps[0]
    if ($apps.Count -gt 1) {
        for ($i = 0; $i -lt $apps.Count; $i++) {
            Write-Host "[$i] $($apps[$i].Name)"
        }
        $appSeleccionada = $apps[(Read-Host 'Selecciona el numero')]
    }

    Write-Host "Consultando secretos de: $($appSeleccionada.Name)..." -ForegroundColor Cyan
    $secretos = az ad app show --id $appSeleccionada.AppId --query "passwordCredentials[].{ID:keyId, Nombre:displayName, Fin:endDateTime}" -o json | ConvertFrom-Json

    if (-not $secretos) {
        Write-Host 'Sin secretos.' -ForegroundColor Yellow
        return
    }

    $hoy = Get-Date
    $resultado = foreach ($s in $secretos) {
        try {
            $fechaFin = [System.Xml.XmlConvert]::ToDateTime($s.Fin, [System.Xml.XmlDateTimeSerializationMode]::Local)
        }
        catch {
            $fechaFin = [datetime]::Parse($s.Fin, [System.Globalization.CultureInfo]::InvariantCulture)
        }

        [PSCustomObject]@{
            Nombre          = if ($s.Nombre) { $s.Nombre } else { '---' }
            Fecha_Caducidad = $fechaFin.ToString('dd-MMM-yyyy HH:mm')
            Estado          = if ($fechaFin -lt $hoy) { '🔴 CADUCADO' } else { '🟢 Activo' }
            ID              = $s.ID
            _sortDate       = $fechaFin
        }
    }

    $resultadoOrdenado = $resultado | Sort-Object { $_.Estado -eq '🔴 CADUCADO' }, _sortDate
    $resultadoOrdenado | Select-Object * -ExcludeProperty _sortDate | Format-Table -AutoSize | Out-Host

    $activos = $resultadoOrdenado | Where-Object { $_.Estado -eq '🟢 Activo' }
    if ($activos) {
        $proximaExpiracion = $activos[0]
        $fechaExpiracion = $proximaExpiracion._sortDate
        $diasRestantes = ($fechaExpiracion - $hoy).Days

        if ($diasRestantes -lt 45) {
            $fechaBmc = $fechaExpiracion.ToString('yyyy-MM-dd')
            Write-Host "`n⚠️ ATENCION: El secreto '$($proximaExpiracion.Nombre)' caduca en $diasRestantes dias ($($proximaExpiracion.Fecha_Caducidad))." -ForegroundColor Yellow
            $respuesta = Read-Host '¿Quieres lanzar el robot a BMC Helix para pedir la renovacion? (S/N)'
            if ($respuesta -match '^[sS]') {
                New-BmcAzureTicket -AppId $appSeleccionada.AppId -AppName $appSeleccionada.Name -ExpiryDate $fechaBmc
            }
        }
        else {
            Write-Host "`n✅ SP sana. El proximo secreto en caducar ($($proximaExpiracion.Fecha_Caducidad)) tiene $diasRestantes dias de margen." -ForegroundColor Green
        }
    }
    else {
        Write-Host '`n🚨 CRITICO: No hay ningun secreto activo para esta SP.' -ForegroundColor Red
    }
}

function Get-AksSpExpiry {
    param(
        [Parameter(Mandatory = $false, HelpMessage = 'Escanea todas las suscripciones activas sin preguntar')]
        [switch]$All
    )

    Write-Host "`n--- 🔍 Escaner masivo de caducidad de SPs en AKS ---" -ForegroundColor Cyan
    Write-Host 'Descargando lista de suscripciones de tu cuenta...' -ForegroundColor DarkGray
    $subsDisponibles = az account list --query "[].{Name:name, ID:id, State:state}" -o json 2>$null | ConvertFrom-Json

    if (-not $subsDisponibles) {
        Write-Host '❌ No se encontraron suscripciones. ¿Te has logueado (az login)?' -ForegroundColor Red
        return
    }

    $subsActivas = $subsDisponibles | Where-Object { $_.State -eq 'Enabled' }
    $suscripcionesElegidas = @()

    if ($All) {
        Write-Host "Modo automatico activado: Escaneando TODAS las suscripciones activas ($($subsActivas.Count))..." -ForegroundColor Yellow
        $suscripcionesElegidas = $subsActivas.ID
    }
    else {
        $listaParaFzf = $subsActivas | ForEach-Object { "$($_.Name) $($_.ID)" }
        $seleccion = $listaParaFzf | fzf -m --prompt='Elige Suscripcion/es (TAB=Marcar varias, Enter=Confirmar): ' --height 50% --reverse

        if (-not $seleccion) {
            Write-Host 'Operacion cancelada, no has elegido ninguna suscripcion.' -ForegroundColor Yellow
            return
        }

        foreach ($linea in $seleccion) {
            $partes = $linea -split '\s+'
            $suscripcionesElegidas += $partes[-1]
        }
    }

    $resultados = @()

    foreach ($subId in $suscripcionesElegidas) {
        $subName = ($subsActivas | Where-Object { $_.ID -eq $subId }).Name
        Write-Host "Cambiando contexto a suscripcion: $subName ..." -ForegroundColor Yellow

        az account set -s $subId 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host '  ⚠️ Sin acceso a nivel de cuenta a esta suscripcion. Saltando...' -ForegroundColor DarkGray
            continue
        }

        $aksListJson = az aks list --query "[].{Name:name, ResourceGroup:resourceGroup, SP:servicePrincipalProfile.clientId}" -o json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host '  ⚠️ Permisos insuficientes para leer clusteres AKS aqui. Saltando...' -ForegroundColor DarkGray
            continue
        }

        $aksList = $aksListJson | ConvertFrom-Json
        if (-not $aksList) {
            Write-Host '  No hay clusteres AKS en esta suscripcion.' -ForegroundColor DarkGray
            continue
        }

        foreach ($aks in $aksList) {
            $spId = $aks.SP

            if ($spId -eq 'msi' -or [string]::IsNullOrWhiteSpace($spId)) {
                $resultados += [PSCustomObject]@{
                    SuscripcionNombre = $subName
                    SuscripcionID     = $subId
                    AKS               = $aks.Name
                    AppID             = 'Managed Identity'
                    Caducidad         = 'N/A'
                    Estado            = '🟢 No caduca (MSI)'
                }
                continue
            }

            $secretos = az ad app show --id $spId --query "passwordCredentials[].{Fin:endDateTime}" -o json 2>$null | ConvertFrom-Json
            if (-not $secretos) {
                $resultados += [PSCustomObject]@{
                    SuscripcionNombre = $subName
                    SuscripcionID     = $subId
                    AKS               = $aks.Name
                    AppID             = $spId
                    Caducidad         = '---'
                    Estado            = '🔴 SIN SECRETOS'
                }
                continue
            }

            $fechas = foreach ($s in $secretos) {
                [DateTime]::Parse($s.Fin, [System.Globalization.CultureInfo]::InvariantCulture)
            }

            $hoy = Get-Date
            $activas = $fechas | Where-Object { $_ -gt $hoy } | Sort-Object
            if ($activas.Count -gt 0) {
                $masProxima = $activas[0]
                $estado = if ($masProxima -lt $hoy.AddDays(45)) { '🟡 Riesgo (<45d)' } else { '🟢 Sana' }

                $resultados += [PSCustomObject]@{
                    SuscripcionNombre = $subName
                    SuscripcionID     = $subId
                    AKS               = $aks.Name
                    AppID             = $spId
                    Caducidad         = $masProxima.ToString('dd/MM/yyyy')
                    Estado            = $estado
                }
            }
            else {
                $masReciente = $fechas | Sort-Object -Descending | Select-Object -First 1
                $resultados += [PSCustomObject]@{
                    SuscripcionNombre = $subName
                    SuscripcionID     = $subId
                    AKS               = $aks.Name
                    AppID             = $spId
                    Caducidad         = $masReciente.ToString('dd/MM/yyyy')
                    Estado            = '🔴 CADUCADA'
                }
            }
        }
    }

    Write-Host "`n--- 📊 Resultados del analisis ---" -ForegroundColor Cyan
    if ($resultados) {
        $resultados | Out-GridView -Title 'Caducidad de Service Principals en AKS'

        Write-Host ''
        $respuestaCsv = Read-Host '¿Quieres exportar estos resultados a un archivo CSV en tu Escritorio? (S/N)'
        if ($respuestaCsv -match '^[sS]') {
            $timestamp = (Get-Date).ToString('yyyyMMdd_HHmm')
            $rutaDestino = "$HOME\Desktop\Caducidad_SPs_AKS_$timestamp.csv"
            $resultados | Export-Csv -Path $rutaDestino -NoTypeInformation -Encoding UTF8
            Write-Host "✅ ¡Hecho! Archivo guardado en: $rutaDestino" -ForegroundColor Green
        }
        else {
            Write-Host '👍 Perfecto, los datos se quedan solo en pantalla.' -ForegroundColor DarkGray
        }

        return $resultados
    }

    Write-Host 'No se encontraron datos para mostrar.' -ForegroundColor DarkGray
}

function Find-JenkinsUserUsage {
    param(
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [string[]]$TargetUsers,
        [string]$JenkinsUrl,
        [string]$CredentialPath
    )

    Write-Host '--- Buscador multiple de credenciales en Jenkins ---' -ForegroundColor Cyan

    $config = Get-DevSecOpsToolkitConfig
    if (-not $JenkinsUrl) {
        $JenkinsUrl = $config.JenkinsUrl
    }
    if (-not $CredentialPath) {
        $CredentialPath = $config.JenkinsCredentialPath
    }

    if ([string]::IsNullOrWhiteSpace($JenkinsUrl)) {
        throw 'JenkinsUrl is not configured. Update $HOME/.devsecops-shell-toolkit/config.json or pass -JenkinsUrl.'
    }

    if (-not $CredentialPath) {
        $CredentialPath = Join-Path $HOME '.jenkins_secret.xml'
    }

    if (-not (Test-Path -LiteralPath $CredentialPath)) {
        $cred = Get-Credential -Message 'Introduce tu Usuario de Jenkins y API Token'
        $cred | Export-Clixml -Path $CredentialPath
    }

    $credGuardada = Import-Clixml -Path $CredentialPath
    $apiUser = $credGuardada.UserName
    $apiToken = $credGuardada.GetNetworkCredential().Password

    Write-Host "`n¿Qué tipo de credencial buscas?" -ForegroundColor Gray
    Write-Host '1. Usuario / Contraseña'
    Write-Host '2. Azure Service Principal (Client ID)'
    $tipoBusqueda = Read-Host 'Selecciona (1 o 2)'
    $searchMode = if ($tipoBusqueda -eq '2') { 'sp' } else { 'user' }

    if (-not $TargetUsers -or $TargetUsers.Count -eq 0) {
        $inputStr = Read-Host 'Introduce los valores a buscar (separados por comas)'
        if (-not $inputStr) {
            return
        }

        $TargetUsers = $inputStr -split ',' | ForEach-Object { $_.Trim() }
    }

    $JenkinsUrl = $JenkinsUrl.TrimEnd('/')
    $joinedUsers = ($TargetUsers | ForEach-Object { '"{0}"' -f $_ }) -join ', '
    $targetArrayGroovy = "[$joinedUsers]"

    $groovyScript = @'
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.common.*
import hudson.model.*
import jenkins.model.Jenkins
import hudson.security.ACL
import groovy.json.JsonOutput

def targetValues = TARGET_ARRAY_PLACEHOLDER
def mode = "SEARCH_MODE_PLACEHOLDER"

def finalResults = [:]
targetValues.each { finalResults[it] = [found: false, creds: [], count: 0, jobs: []] }

def checkCred = { cred, target ->
    if (mode == "user") {
        return (cred instanceof UsernamePasswordCredentialsImpl && cred.username == target)
    } else if (mode == "sp") {
        def className = cred.getClass().getName()
        if (className.contains("AzureCredentials") || className.contains("AzureServicePrincipal")) {
            return (cred.clientId == target)
        }
    }
    return false
}

def getUpdateUrl = { cred, context ->
    def id = cred.id
    if (context instanceof Jenkins) {
        return "credentials/store/system/domain/_/credential/${id}/update"
    } else {
        def folderPath = context.fullName.split('/').collect { "job/${it}" }.join('/')
        return "${folderPath}/credentials/store/folder/domain/_/credential/${id}/update"
    }
}

def mapCredInfo = { cred, context ->
    targetValues.each { target ->
        if (checkCred(cred, target)) {
            finalResults[target].found = true
            finalResults[target].creds.add([id: cred.id, url: getUpdateUrl(cred, context)])
        }
    }
}

SystemCredentialsProvider.getInstance().getCredentials().each { mapCredInfo(it, Jenkins.instance) }
Jenkins.instance.getAllItems(ItemGroup.class).each { folder ->
    CredentialsProvider.lookupCredentials(StandardCredentials.class, folder, ACL.SYSTEM, Collections.emptyList()).each {
        mapCredInfo(it, folder)
    }
}

def credentialIdToTarget = [:]
targetValues.each { target ->
    if (finalResults[target].creds) {
        finalResults[target].creds = finalResults[target].creds.unique { it.id }
        finalResults[target].creds.each { credInfo -> credentialIdToTarget[credInfo.id] = target }
    }
}

if (!credentialIdToTarget.isEmpty()) {
    Jenkins.instance.getAllItems(Job.class).each { job ->
        def xml = job.configFile.asString()
        credentialIdToTarget.each { credId, target ->
            if (xml.contains(credId)) {
                finalResults[target].jobs.add(job.fullName)
                finalResults[target].count++
            }
        }
    }
}

println JsonOutput.toJson(finalResults)
'@

    $groovyScript = $groovyScript -replace 'TARGET_ARRAY_PLACEHOLDER', $targetArrayGroovy
    $groovyScript = $groovyScript -replace 'SEARCH_MODE_PLACEHOLDER', $searchMode

    $authString = "${apiUser}:${apiToken}"
    $encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authString))
    $headers = @{ Authorization = "Basic $encodedAuth" }

    Write-Host "`nEscaneando Jenkins para $($TargetUsers.Count) valores... (Puede tardar un rato)" -ForegroundColor DarkGray

    try {
        $webResponse = Invoke-WebRequest -Uri "$JenkinsUrl/scriptText" -Method Post -Headers $headers -Body @{ script = $groovyScript } -TimeoutSec 300
        if ($webResponse.Content -match '(?s)(\{.*\})') {
            $data = $matches[1] | ConvertFrom-Json
            $allJobsToExport = @()

            foreach ($target in $TargetUsers) {
                $info = $data.$target
                Write-Host "`n--------------------------------------------------" -ForegroundColor DarkCyan
                Write-Host 'RESULTADOS PARA: ' -NoNewline
                Write-Host $target -ForegroundColor White

                if (-not $info.found) {
                    Write-Host '❌ No se encontro ninguna credencial con este identificador.' -ForegroundColor Red
                    continue
                }

                foreach ($c in $info.creds) {
                    Write-Host '  👉 ID Credencial: ' -NoNewline -ForegroundColor Gray
                    Write-Host $c.id -ForegroundColor Green
                    Write-Host '     URL edicion:   ' -NoNewline -ForegroundColor Gray
                    Write-Host "$JenkinsUrl/$($c.url)" -ForegroundColor Blue
                }

                Write-Host '  📊 Usado en ' -NoNewline -ForegroundColor Gray
                Write-Host "$($info.count) Jobs" -ForegroundColor Yellow

                if ($info.count -gt 0) {
                    $info.jobs | ForEach-Object {
                        $allJobsToExport += [PSCustomObject]@{ Target = $target; Job = $_ }
                    }
                }
            }

            Write-Host '--------------------------------------------------' -ForegroundColor DarkCyan
            Write-Host ''

            if ($allJobsToExport.Count -gt 0) {
                $respuesta = Read-Host '¿Exportar TODOS los jobs encontrados a un unico CSV? (S/N)'
                if ($respuesta -match '^[sS]') {
                    $ruta = "$HOME\Desktop\Jenkins_Report_Multi.csv"
                    $allJobsToExport | Export-Csv -Path $ruta -NoTypeInformation -Encoding UTF8 -Delimiter ';'
                    Write-Host "📁 Reporte unificado guardado en: $ruta" -ForegroundColor Magenta
                }
            }
        }
        else {
            Write-Host '⚠️ La respuesta de Jenkins no contenia datos validos.' -ForegroundColor Yellow
            Write-Host 'Detalle del error de Jenkins (revisa si te ha caducado algun acceso):' -ForegroundColor Red
            Write-Host $webResponse.Content
        }
    }
    catch {
        Write-Host "Error al conectar o timeout: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function New-BmcAzureTicket {
    param(
        [Parameter(Mandatory = $true)][string]$AppId,
        [Parameter(Mandatory = $true)][string]$AppName,
        [Parameter(Mandatory = $true)][string]$ExpiryDate,
        [Parameter(Mandatory = $false)][string]$Entorno,
        [string]$RobotPath,
        [string]$RobotCommand
    )

    $config = Get-DevSecOpsToolkitConfig
    if (-not $RobotPath) {
        $RobotPath = $config.BmcRobotPath
    }
    if (-not $RobotCommand) {
        $RobotCommand = $config.BmcRobotCommand
    }

    if (-not $Entorno) {
        Write-Host "`nSelecciona el Entorno:" -ForegroundColor Yellow
        Write-Host '1. Productivo (PRO)'
        Write-Host '2. No Productivo (DES, UAT, QA, etc.)'
        $choice = Read-Host 'Elige una opcion (1 o 2)'

        if ($choice -eq '1') {
            $Entorno = 'Productivo (PRO)'
        }
        else {
            $Entorno = 'No Productivo (DES, UAT, QA, etc.)'
        }
    }

    if ([string]::IsNullOrWhiteSpace($RobotPath)) {
        throw 'BmcRobotPath is not configured. Update $HOME/.devsecops-shell-toolkit/config.json or pass -RobotPath.'
    }

    if (-not (Test-Path -LiteralPath $RobotPath)) {
        throw "Configured robot path not found: $RobotPath"
    }

    $env:NODE_TLS_REJECT_UNAUTHORIZED = '0'
    Write-Host "`n🤖 Iniciando robot para entorno: $Entorno" -ForegroundColor Cyan

    Push-Location $RobotPath
    try {
        Invoke-Expression "$RobotCommand $AppId $AppName $ExpiryDate \"$Entorno\""
    }
    finally {
        Pop-Location
    }
}

Export-ModuleMember -Function aks-sync, asx, k-clean, get-sp-expiry, Get-AksSpExpiry, Find-JenkinsUserUsage, New-BmcAzureTicket, Get-DevSecOpsToolkitConfig, Update-DevSecOpsToolkit -Alias k, kx, kn
