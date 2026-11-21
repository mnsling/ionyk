# Run in PowerShell while your local API is running.
# This prompts for credentials instead of storing passwords in the script.
$oldUsername = Read-Host 'Current Admin username (e.g. admin01)'
$oldPassword = Read-Host 'Current Admin password' -AsSecureString
$newUsername = Read-Host 'New Admin username (e.g. 000)'
$newPassword = Read-Host 'New Admin password' -AsSecureString
$ptr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($oldPassword)
$ptr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($newPassword)
try {
    $oldPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr1)
    $newPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr2)
    $loginBody = @{ username = $oldUsername; password = $oldPlain } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/login' -Method Post -ContentType 'application/json' -Body $loginBody
    if ($login.role -ne 'admin') { throw 'The current user is not an Admin.' }
    $changeBody = @{ current_password = $oldPlain; new_username = $newUsername; new_password = $newPlain } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/admin/change-credentials' -Method Post -ContentType 'application/json' -Headers @{Authorization = "Bearer $($login.token)"} -Body $changeBody
    Write-Host "Updated Admin username to $($result.username). Sign out and log in with the new credentials."
} finally {
    if ($ptr1 -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr1) }
    if ($ptr2 -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr2) }
    Remove-Variable oldPlain,newPlain,loginBody,changeBody,login -ErrorAction SilentlyContinue
}
