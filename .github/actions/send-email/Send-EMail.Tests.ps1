Describe "When running script" {
    BeforeAll {
        Set-Alias -Name Sut -Value $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    }

    Context "Given script is reachable" {
        It "Should write EMail parameter" {
            # Act
            Sut -EMail "test@test.com"
        }
    }
}
