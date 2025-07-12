Describe 'Write-Log' {
    It 'should write to log file and rotate if size exceeds 5MB' {
        $testLog = "$env:TEMP\testlog.txt"
        $script:logFile = $testLog
        Remove-Item $testLog -ErrorAction SilentlyContinue
        $bigString = 'A' * 1024 * 1024
        for ($i = 0; $i -lt 6; $i++) { Add-Content $testLog $bigString }
        Write-Log -Message 'Test rotation' -Level 'INFO' -SuppressLogFile:$false
        Test-Path $testLog | Should -Be $true
        $archiveDir = Join-Path (Split-Path $testLog -Parent) 'Archive'
        Test-Path $archiveDir | Should -Be $true
        Get-ChildItem $archiveDir | Where-Object { $_.Name -like 'log_*.txt' } | Should -Not -BeNullOrEmpty
        Remove-Item $testLog -Force -ErrorAction SilentlyContinue
        Remove-Item $archiveDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
