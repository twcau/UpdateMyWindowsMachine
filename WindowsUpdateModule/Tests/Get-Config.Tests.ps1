# Pester test for Get-Config
Describe 'Get-Config' {
    It 'Should return a hashtable with expected keys' {
        $result = Get-Config
        $result | Should -BeOfType 'hashtable'
        $result | Should -ContainKey 'logDir'
        $result | Should -ContainKey 'DaysToKeep'
    }
}
