param(
  [string]$Pdf = "C:\Users\HP\Downloads\Telegram Desktop\LOGO KLR FINAL 2.pdf",
  [string]$Out = "C:\Users\HP\AppData\Local\Temp\claude\C--Users-HP-Documents-KLR-TECH-klr-app\9ef31925-7c3c-42e6-b754-f18868114070\scratchpad\logo.png",
  [int]$Width = 2048
)

Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]

function Await($op, $type) {
  $t = $asTaskGeneric.MakeGenericMethod($type).Invoke($null, @($op))
  $t.Wait(-1) | Out-Null
  $t.Result
}
$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
  $_.GetParameters()[0].ParameterType.FullName -eq 'Windows.Foundation.IAsyncAction'
})[0]

function AwaitAction($op) {
  $t = $asTaskAction.Invoke($null, @($op))
  $t.Wait(-1) | Out-Null
}

[Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null

$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Pdf)) ([Windows.Storage.StorageFile])
$doc  = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
"Pages : $($doc.PageCount)"

$page = $doc.GetPage(0)
"Taille page : $($page.Size.Width) x $($page.Size.Height)"

$ms = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
$opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
$opts.DestinationWidth = [uint32]$Width
# Fond transparent conservé (le logo n'a pas de fond blanc)
$opts.IsIgnoringHighContrast = $true

AwaitAction ($page.RenderToStreamAsync($ms, $opts))

$reader = New-Object Windows.Storage.Streams.DataReader($ms.GetInputStreamAt(0))
Await ($reader.LoadAsync([uint32]$ms.Size)) ([uint32]) | Out-Null
$bytes = New-Object byte[] $ms.Size
$reader.ReadBytes($bytes)
[System.IO.File]::WriteAllBytes($Out, $bytes)

"Ecrit : $Out ($($bytes.Length) octets)"
