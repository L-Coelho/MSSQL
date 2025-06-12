# Caminho do diretório onde estão os ficheiros
$diretorio = "C:\SQL2019\teste2"

# Caminho para o ficheiro de texto com a lista de ficheiros (um por linha)
$listaFicheiros = "C:\SQL2019\teste2\lista.txt"

# Modo de operação: "ReadOnly" ou "ReadWrite"
$modo = "ReadWrite"  # ou "ReadWrite"

# Cabeçalho do relatório
Write-Host "Modo: $modo"
Write-Host "---------------------------------------------"

# Lê cada linha do ficheiro de lista
Get-Content $listaFicheiros | ForEach-Object {
    $ficheiro = Join-Path $diretorio $_

    if (Test-Path $ficheiro) {
        $item = Get-Item $ficheiro
        $atributosAntes = $item.Attributes

        $tinhaReadOnly = $atributosAntes -band [System.IO.FileAttributes]::ReadOnly

        if ($modo -eq "ReadOnly") {
            if (-not $tinhaReadOnly) {
                $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::ReadOnly
            }
        } elseif ($modo -eq "ReadWrite") {
            if ($tinhaReadOnly) {
                $item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
            }
        } else {
            Write-Warning "Modo inválido: $modo"
            return
        }

        $atributosDepois = (Get-Item $ficheiro).Attributes
        $temReadOnlyAgora = $atributosDepois -band [System.IO.FileAttributes]::ReadOnly

        # Relatório
        Write-Host "Ficheiro: $ficheiro"
        Write-Host "  Antes:  $(if ($tinhaReadOnly) {'ReadOnly'} else {'ReadWrite'})"
        Write-Host "  Depois: $(if ($temReadOnlyAgora) {'ReadOnly'} else {'ReadWrite'})"
        Write-Host ""
    } else {
        Write-Warning "Ficheiro nao encontrado: $ficheiro"
    }
}

