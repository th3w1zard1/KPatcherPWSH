@{
    RootModule        = 'KPatcher.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'c3a7e8f4-1b2d-4c5e-9f0a-6d8e7b3c1a2f'
    Author            = 'KPatcher Contributors'
    Description       = 'Pure PowerShell port of KPatcher - KOTOR mod installation tool'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Read-TwoDA', 'Write-TwoDA',
        'Read-TLK', 'Write-TLK',
        'Read-GFF', 'Write-GFF',
        'Read-ERF', 'Write-ERF',
        'Read-RIM', 'Write-RIM',
        'Read-SSF', 'Write-SSF',
        'Read-PatcherConfig',
        'Install-KPatcherMod'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
}
