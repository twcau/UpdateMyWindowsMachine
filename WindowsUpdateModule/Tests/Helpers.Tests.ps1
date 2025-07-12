Describe 'Invoke-PromptOrDefault' {
    It 'should return user input if provided' {
        Mock Read-Host { 'UserValue' }
        Invoke-PromptOrDefault -Prompt 'Test' -Current 'Cur' -HardDefault 'Def' | Should -Be 'UserValue'
    }
    It 'should return current if input is blank' {
        Mock Read-Host { '' }
        Invoke-PromptOrDefault -Prompt 'Test' -Current 'Cur' -HardDefault 'Def' | Should -Be 'Cur'
    }
    It 'should return hard default if both input and current are blank' {
        Mock Read-Host { '' }
        Invoke-PromptOrDefault -Prompt 'Test' -Current '' -HardDefault 'Def' | Should -Be 'Def'
    }
}
