<#
.SYNOPSIS
    Script para copia de arquivos com Robocopy 
.DESCRIPTION
    Copia todos os arquivos e subpastas de um diretorio para outro usando Robocopy
#>

# Configuracoes
$Origem = "D:\teste_copia"       # Alterar para o caminho de origem
$Destino = "D:\teste_copia1"     # Alterar para o caminho de destino
$LogDir = "d:\robocopy"         # Alterar para o caminho dos logs
$Threads = 32                            # Numero de threads
$Retries = 15                             # Numero de tentativas
$WaitTime = 10                           # Tempo de espera entre tentativas (em segundos)

# Criar diretorios se nao existirem
if (!(Test-Path -Path $Destino)) { New-Item -ItemType Directory -Path $Destino -Force | Out-Null }
if (!(Test-Path -Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

# Nomes dos arquivos de log com timestamp
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogCopia = Join-Path -Path $LogDir -ChildPath "copia_$Timestamp.log"
$LogOrigem = Join-Path -Path $LogDir -ChildPath "origem_$Timestamp.log"
$LogDestino = Join-Path -Path $LogDir -ChildPath "destino_$Timestamp.log"
$LogComparacao = Join-Path -Path $LogDir -ChildPath "comparacao_$Timestamp.log"

# Configurar encoding UTF-8 para a sess√£o PowerShell
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Funcao para registrar informacoes do diretorio
function Get-DirectoryReport {
    param (
        [string]$Path,
        [string]$LogFile
    )
    
    try {
        $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction Stop | 
                 Select-Object FullName, Length, LastWriteTime
        
        $totalFiles = $files.Count
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
        
        # Escrever cabecalho do log com encoding UTF-8
        "Relatorio do diretorio: $Path" | Out-File -FilePath $LogFile -Encoding UTF8
        "Gerado em: $(Get-Date)" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        "Total de arquivos: $totalFiles" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        "Tamanho total: $([math]::Round($totalSize / 1MB, 2)) MB" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        "" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        "Lista de arquivos:" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        "----------------------------------------" | Out-File -FilePath $LogFile -Encoding UTF8 -Append
        
        # Escrever detalhes dos arquivos
        foreach ($file in $files) {
            "$($file.FullName) - $($file.Length) bytes - Modificado em: $($file.LastWriteTime)" | 
                Out-File -FilePath $LogFile -Encoding UTF8 -Append
        }
        
        return $totalFiles
    }
    catch {
        "Erro ao aceder ao diretorio $Path : $_" | Out-File -FilePath $LogFile -Encoding UTF8
        return 0
    }
}

# Registar informacoes da origem
Write-Host "Registando arquivos de origem..." -ForegroundColor Cyan
$CountOrigem = Get-DirectoryReport -Path $Origem -LogFile $LogOrigem

# Executar copia com Robocopy (parametros)
Write-Host "Iniciando copia com Robocopy..." -ForegroundColor Cyan

# Configurar cabecalho do log de copia
"Robocopy - Relatorio da Copia" | Out-File -FilePath $LogCopia -Encoding UTF8
"Data: $(Get-Date)" | Out-File -FilePath $LogCopia -Encoding UTF8 -Append
"Origem: $Origem" | Out-File -FilePath $LogCopia -Encoding UTF8 -Append
"Destino: $Destino" | Out-File -FilePath $LogCopia -Encoding UTF8 -Append
"Threads: $Threads" | Out-File -FilePath $LogCopia -Encoding UTF8 -Append
"Tentativas: $Retries" | Out-File -FilePath $LogCopia -Encoding UTF8 -Append
"" | Out-File -FilePath $LogCopia -Encoding UTF8 -Append

# Argumentos do Robocopy
$RoboArgs = @(
    "`"$Origem`"",
    "`"$Destino`"",
    "/S",           # Copiar subdiretorios (exceto vazios)
    "/COPY:DAT",    # Copiar dados, atributos e timestamps
    "/MT:$Threads", # Numero de threads
    "/R:$Retries",  # Numero de tentativas
    "/W:$WaitTime", # Tempo de espera entre tentativas
    "/V",           # Sai≠da detalhada
    "/FP",          # Mostrar caminhos completos
    "/NDL",         # Nao logar nomes de diretorios
    "/NP",          # Nao mostrar progresso (%)
    "/LOG:`"$LogCopia`"", # Arquivo de log
    "/TEE"          # Mostrar sai≠da na consola e no log
)

# Executar Robocopy
try {
    $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $RoboArgs -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ge 8) {
        "ATENCAO: Robocopy completou com possi≠veis erros (Codigo: $($process.ExitCode))" | 
            Out-File -FilePath $LogCopia -Encoding UTF8 -Append
    }
}
catch {
    "ERRO: Falha ao executar Robocopy - $_" | Out-File -FilePath $LogCopia -Encoding UTF8 -Append
}

# Registrar informacoes do destino
Write-Host "Registando arquivos no destino..." -ForegroundColor Cyan
$CountDestino = Get-DirectoryReport -Path $Destino -LogFile $LogDestino

# Comparar origem e destino
Write-Host "Comparando origem e destino..." -ForegroundColor Cyan

"Relatorio de Comparacao" | Out-File -FilePath $LogComparacao -Encoding UTF8
"Gerado em: $(Get-Date)" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"Origem: $Origem" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"Total de arquivos: $CountOrigem" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"Destino: $Destino" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"Total de arquivos: $CountDestino" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"Diretorio de Logs: $LogDir" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append

if ($CountOrigem -eq $CountDestino) {
    "SUCESSO: Contagem de arquivos identica" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
} else {
    "AVISO: Contagem de arquivos diferente" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
    "Diferen√ßa: $($CountOrigem - $CountDestino) arquivos" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
}

# Listar logs gerados
"" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"Logs gerados:" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"- Log de copia: $LogCopia" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"- Log de origem: $LogOrigem" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append
"- Log de destino: $LogDestino" | Out-File -FilePath $LogComparacao -Encoding UTF8 -Append

# Resultado final
Write-Host "`nProcesso conclui≠do." -ForegroundColor Green
Write-Host "Dados copiados para: $Destino" -ForegroundColor Yellow
Write-Host "Logs gerados em: $LogDir" -ForegroundColor Yellow
#Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Cyan
#$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null