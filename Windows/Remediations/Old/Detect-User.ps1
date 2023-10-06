function Detect-User {

  param (
    # Name of the local user to check for the presence of
    [Parameter(Mandatory=$true)]
    [String]
    $UserName
  )

  $UserExists = (Get-LocalUser).Name -Contains $userName
  if ($UserExists) { 
    # $userName exists, exit without action 
    exit 0
  } 
  else {
    # $userName does not exist, trigger remediation
    exit 1
  }

}

Detect-User -UserName cloud_laps