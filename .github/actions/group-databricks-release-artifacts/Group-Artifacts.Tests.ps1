Describe "When grouping release artifacts" {
    BeforeAll {
        . $PSScriptRoot/Group-Artifacts.ps1
    }

    BeforeEach {
        New-Item -Path '.\test-files' -ItemType 'directory'
        New-Item -Path '.\test-files\dist' -ItemType 'directory'
        New-Item -Path '.\test-files\dist\test-wheel.whl' -ItemType 'file'
        New-Item -Path '.\test-files\dashboards' -ItemType 'directory'
        New-Item -Path '.\test-files\dashboards\test-dashboard-1.dbdash' -ItemType 'file'
        New-Item -Path '.\test-files\dashboards\test-dashboard-2.dbdash' -ItemType 'file'
    }

    It "should contain assets if ShouldContainAssets is true" {
        # Act
        Group-Artifacts `
        -DistPath '.\test-files\dist' `
        -DashboardPath '.\test-files\dashboards' `
        -Destination '.\test-files\artifacts' `
        -ShouldIncludeAssets $true

        # Assert
        Test-Path '.\test-files\artifacts\dist' | Should -Be $true
        Test-Path '.\test-files\artifacts\dist\test-wheel.whl' | Should -Be $true
        Test-Path '.\test-files\artifacts\dashboards' | Should -Be $true
        Test-Path '.\test-files\artifacts\dashboards\test-dashboard-1.dbdash' | Should -Be $true
        Test-Path '.\test-files\artifacts\dashboards\test-dashboard-2.dbdash' | Should -Be $true
    }

    It "should not contain assets if ShouldContainAssets is false" {
        # Act
        Group-Artifacts `
        -DistPath '.\test-files\dist' `
        -DashboardPath '.\test-files\dashboards' `
        -Destination '.\test-files\artifacts' `
        -ShouldIncludeAssets $false

        # Assert
        Test-Path '.\test-files\artifacts\test-wheel.whl' | Should -Be $true
        Test-Path '.\test-files\artifacts\dist' | Should -Be $false
        Test-Path '.\test-files\artifacts\dashboards' | Should -Be $false
    }

    AfterEach {
        Remove-Item -LiteralPath ".\test-files" -Force -Recurse
    }
}
