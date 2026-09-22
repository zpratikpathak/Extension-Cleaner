if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $powerShellExecutable = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName;
    try {
        Start-Process -FilePath $powerShellExecutable -Verb RunAs -WorkingDirectory $PSScriptRoot -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ErrorAction Stop;
    } catch {
        Write-Error("Administrator access is required. $($_.Exception.Message)");
        exit 1;
    }
    exit;
}

Clear-Host;
$ProgressPreference = 'SilentlyContinue';
$spinnerChars = @('|', '/', '-', '\');$spinCount = 0;
$uiWidth = [Math]::Min(92, [Math]::Max(20, [Console]::WindowWidth - 1));
$iconCleaner = [char]::ConvertFromUtf32(0x1F9F9);
$iconLock = [char]::ConvertFromUtf32(0x1F512);
$iconAuthor = [char]::ConvertFromUtf32(0x1F464);
$iconSearch = [char]::ConvertFromUtf32(0x1F50E);
$iconExtensions = [char]::ConvertFromUtf32(0x1F4E6);
$iconKeyboard = ([string][char]0x2328) + [char]0xFE0F;
$separatorLine = [string]::new([char]0x2500, [int]$uiWidth);
Add-Type -AssemblyName System.Net.Http;
$webClient = [System.Net.Http.HttpClient]::new();
$webClient.Timeout = [TimeSpan]::FromSeconds(5);
$webClient.DefaultRequestHeaders.UserAgent.ParseAdd('Mozilla/5.0');

function Format-CenteredLine {
    param([string]$Text);

    if ($Text.Length -gt $script:uiWidth) { $Text = $Text.Substring(0, $script:uiWidth - 3) + '...'; }
    $leftPadding = [Math]::Max(0, [Math]::Floor(($script:uiWidth - $Text.Length) / 2));
    (' ' * $leftPadding + $Text).PadRight($script:uiWidth);
}

function Show-Header {
    Write-Host(Format-CenteredLine "$script:iconCleaner BROWSER EXTENSION CLEANER") -ForegroundColor Cyan;
    Write-Host(Format-CenteredLine "$script:iconLock Offline cleanup for Chrome, Edge, and Brave") -ForegroundColor DarkGray;
    Write-Host(Format-CenteredLine "$script:iconAuthor Pratik Pathak  |  https://github.com/zpratikpathak") -ForegroundColor Gray;
    Write-Host($script:separatorLine) -ForegroundColor DarkCyan;
    Write-Host('');
}

function Step-Spinner {
    param([string]$BrowserName = 'browser');

    [Console]::CursorVisible = $false;
    Write-Host("`r$script:iconSearch Scanning $BrowserName extensions... " + $spinnerChars[$script:spinCount % $spinnerChars.Count]) -NoNewline -ForegroundColor Cyan;
    $script:spinCount++;
}

Show-Header;
$browserConfigs = @(
    [PSCustomObject]@{
        Name = 'Chrome';
        ManifestRoot = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data';
        RegistryPaths = @('HKCU:\Software\Google\Chrome\Extensions', 'HKLM:\Software\Google\Chrome\Extensions', 'HKLM:\Software\WOW6432Node\Google\Chrome\Extensions');
        PolicyPaths = @('HKCU:\Software\Policies\Google\Chrome\ExtensionInstallForcelist', 'HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist');
    },
    [PSCustomObject]@{
        Name = 'Edge';
        ManifestRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data';
        RegistryPaths = @('HKCU:\Software\Microsoft\Edge\Extensions', 'HKLM:\Software\Microsoft\Edge\Extensions', 'HKLM:\Software\WOW6432Node\Microsoft\Edge\Extensions');
        PolicyPaths = @('HKCU:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist', 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist');
    },
    [PSCustomObject]@{
        Name = 'Brave';
        ManifestRoot = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data';
        RegistryPaths = @('HKCU:\Software\BraveSoftware\Brave-Browser\Extensions', 'HKLM:\Software\BraveSoftware\Brave-Browser\Extensions', 'HKLM:\Software\WOW6432Node\BraveSoftware\Brave-Browser\Extensions');
        PolicyPaths = @('HKCU:\Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist', 'HKLM:\Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist');
    }
);
$foundItems = [System.Collections.Generic.List[PSCustomObject]]::new();

function Get-ExtensionName {
    param(
        [string]$extId,
        [string]$manifestRoot,
        [string]$browserName
    );
    if ($extId -eq "efaidnbmnnnibpcajpcglclefindmkaj") { "Adobe Acrobat"; return; }

    $manifestPattern = Join-Path $manifestRoot "*\Extensions\$extId\*\manifest.json";
    $manifestFile = Get-ChildItem($manifestPattern) -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1;
    if ($manifestFile) {
        try {
            $manifest = Get-Content($manifestFile.FullName) -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop;
            $extensionName = [string]$manifest.name;
            if ($extensionName -match '^__MSG_(.+)__$' -and $manifest.default_locale) {
                $messageKey = $matches[1];
                $messagesPath = Join-Path $manifestFile.DirectoryName "_locales\$($manifest.default_locale)\messages.json";
                $messages = Get-Content($messagesPath) -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop;
                $extensionName = [string]$messages.PSObject.Properties[$messageKey].Value.message;
            }
            if ($extensionName) { $extensionName; return; }
        } catch { }
    }

    if ($extId -match '^[a-p]{32}$') {
        $storeLookups = @();
        if ($browserName -eq 'Edge') {
            $storeLookups += [PSCustomObject]@{ Name = 'Edge Add-ons'; Url = "https://microsoftedge.microsoft.com/addons/detail/$extId"; Suffix = 'Microsoft Edge Add-ons' };
        }
        $storeLookups += [PSCustomObject]@{ Name = 'Chrome Web Store'; Url = "https://chromewebstore.google.com/detail/$extId"; Suffix = 'Chrome Web Store' };

        foreach ($store in $storeLookups) {
            try {
                $requestTask = $script:webClient.GetStringAsync($store.Url);
                while (-not $requestTask.IsCompleted) {
                    Step-Spinner($store.Name);
                    Start-Sleep -Milliseconds 100;
                }
                $storePage = $requestTask.GetAwaiter().GetResult();
                if ($storePage -match '<title[^>]*>(.*?)<\/title>') {
                    $storeName = [System.Net.WebUtility]::HtmlDecode($matches[1]);
                    $storeName = ($storeName -replace "\s*-\s*$([regex]::Escape($store.Suffix)).*$", '').Trim();
                    if ($storeName -and $storeName -notin @('Chrome Web Store', 'Item not available', 'This item is not available')) { $storeName; return; }
                }
            } catch { }
        }
    }

    "Unknown / Third-Party Extension"; return;
}

$browserConfigs.ForEach({
    $browser = $_;
    Step-Spinner($browser.Name);
    $browser.RegistryPaths.ForEach({
        $currentPath = $_;
        if (Test-Path($currentPath)) {$childKeys = Get-ChildItem($currentPath);$childKeys.ForEach({
                Step-Spinner($browser.Name);
                $id = $_.PSChildName;
                $name = Get-ExtensionName $id $browser.ManifestRoot $browser.Name;$foundItems.Add([PSCustomObject]@{Id=$id; Name=$name; Browser=$browser.Name; Type="Registry Key"; Path=$_.PSPath; Value=$null; Location=$currentPath;});
            });
        }
    });
    $browser.PolicyPaths.ForEach({
        $currentPath = $_;
        if (Test-Path($currentPath)) {$props = Get-ItemProperty($currentPath);$props.PSObject.Properties.ForEach({
                if ($_.Name -notmatch '^PS') {
                    Step-Spinner($browser.Name);
                    $rawVal = $_.Value.ToString();$id = ($rawVal -split ';')[0].Trim();$name = Get-ExtensionName $id $browser.ManifestRoot $browser.Name;$foundItems.Add([PSCustomObject]@{Id=$id; Name="$name (Forced Policy)"; Browser=$browser.Name; Type="Policy Property"; Path=$currentPath; Value=$_.Name; Location=$currentPath;});
                }
            });
        }
    });
});

[Console]::CursorLeft = 0;
Write-Host(' ' * $uiWidth) -NoNewline;
[Console]::CursorLeft = 0;

if ($foundItems.Count -eq 0) { Write-Host("`nNo external or policy-installed extensions were found.") -ForegroundColor Green; [Console]::CursorVisible = $true; return; }

$currentIndex = 0;
$selectedState = New-Object bool[] $foundItems.Count;
$menuTop = [Console]::CursorTop;
[Console]::CursorVisible = $false;

function Draw-Menu {
    [Console]::SetCursorPosition(0, $menuTop);
    $selectedCount = @($selectedState | Where-Object { $_ }).Count;
    $statusText = "$script:iconExtensions EXTENSIONS   $($foundItems.Count) found across $($browserConfigs.Count) browsers   $selectedCount selected";
    $controlsText = "$script:iconKeyboard  [UP/DOWN] Move   [SPACE] Select   [ENTER] Remove   [ESC/CTRL+C] Exit";
    Write-Host(Format-CenteredLine $statusText) -ForegroundColor Cyan;
    Write-Host(Format-CenteredLine $controlsText) -ForegroundColor DarkGray;
    Write-Host($script:separatorLine) -ForegroundColor DarkCyan;
    $heading = "      {0,-7} {1,-20}  {2,-32}  {3}" -f 'BROWSER', 'NAME', 'EXTENSION ID', 'SOURCE';
    if ($heading.Length -gt $script:uiWidth) { $heading = $heading.Substring(0, $script:uiWidth); }
    Write-Host($heading.PadRight($script:uiWidth)) -ForegroundColor DarkGray;
    for ($i = 0; $i -lt $foundItems.Count; $i++) {
        $item =$foundItems[$i];$box = if ($selectedState[$i]) { "[X]"; } else { "[ ]"; };
        $pointer = if ($i -eq$currentIndex) { ">"; } else { " "; };
        $displayName = if ($item.Name.Length -gt 20) { $item.Name.Substring(0, 17) + '...' } else { $item.Name };
        $source = if ($item.Type -eq 'Policy Property') {
            if ($item.Location.StartsWith('HKCU:')) { 'USER POLICY' } else { 'MACHINE POLICY' }
        } elseif ($item.Location -like '*WOW6432Node*') {
            'MACHINE x86'
        } elseif ($item.Location.StartsWith('HKCU:')) {
            'USER'
        } else {
            'MACHINE'
        };
        $line = "{0} {1} {2,-7} {3,-20}  {4,-32}  {5}" -f $pointer, $box, $item.Browser, $displayName, $item.Id, $source;
        if ($line.Length -gt $script:uiWidth) { $line = $line.Substring(0, $script:uiWidth - 3) + '...'; }
        $line = $line.PadRight($script:uiWidth);
        if ($i -eq $currentIndex) { Write-Host($line) -ForegroundColor Cyan; }
        elseif ($selectedState[$i]) { Write-Host($line) -ForegroundColor Green; }
        else { Write-Host($line) -ForegroundColor Gray; }
    }
    Write-Host($script:separatorLine) -ForegroundColor DarkCyan;
}

Draw-Menu;

$keepRunning =$true;
$cancelled = $false;
$previousTreatControlCAsInput = [Console]::TreatControlCAsInput;
[Console]::TreatControlCAsInput = $true;
try {
    while ($keepRunning) {
        $keyInfo = [Console]::ReadKey($true);
        $isControlC = $keyInfo.Key -eq [ConsoleKey]::C -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control);
        if ($isControlC -or $keyInfo.Key -eq [ConsoleKey]::Escape) {
            $cancelled = $true;
            $keepRunning = $false;
            continue;
        }
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) { if ($currentIndex -gt 0) {$currentIndex--; }; Draw-Menu; }
            ([ConsoleKey]::DownArrow) { if ($currentIndex -lt ($foundItems.Count - 1)) {$currentIndex++; }; Draw-Menu; }
            ([ConsoleKey]::Spacebar) { $selectedState[$currentIndex] = -not $selectedState[$currentIndex]; Draw-Menu; }
            ([ConsoleKey]::Enter) { $keepRunning =$false; }
        }
    }
} finally {
    [Console]::TreatControlCAsInput = $previousTreatControlCAsInput;
    [Console]::CursorVisible = $true;
}

if ($cancelled) {
    Write-Host("`nOperation cancelled. Nothing was removed.") -ForegroundColor Yellow;
    $ProgressPreference = 'Continue';
    return;
}

Write-Host("`n");
$countRemoved = 0;
for ($i = 0; $i -lt $foundItems.Count; $i++) {
    if ($selectedState[$i]) {
        $target = $foundItems[$i];
        try {
            if ($target.Type -eq "Registry Key") { Remove-Item($target.Path) -Recurse -Force -ErrorAction Stop; }
            elseif ($target.Type -eq "Policy Property") { Remove-ItemProperty($target.Path) -Name($target.Value) -Force -ErrorAction Stop; }
            Write-Host("[DELETED] $($target.Name) ($($target.Id))") -ForegroundColor Green;
            $countRemoved++;
        } catch { Write-Host("[ERROR] Failed to delete $($target.Id): $($_.Exception.Message)") -ForegroundColor Red; }
    }
}
if ($countRemoved -gt 0) { Write-Host("`nSuccessfully removed $countRemoved item(s).") -ForegroundColor Green; }
else { Write-Host("No items were selected for removal.") -ForegroundColor Yellow; }
$ProgressPreference = 'Continue';