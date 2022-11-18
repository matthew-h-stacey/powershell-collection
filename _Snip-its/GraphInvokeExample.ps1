Invoke-RestMethod -Headers @{Authorization = "Bearer $($myAccessToken.AccessToken)" } `
                -Uri "https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate" `
                -Method Get)