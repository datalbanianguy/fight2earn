Write-Host "Deploying to GitHub..."

$gitPath = "C:\Program Files\Git\bin\git.exe"

& $gitPath config --global user.name "datalbanianguy"
& $gitPath config --global user.email "fight2earn@telegram.com"
& $gitPath init
& $gitPath add .
& $gitPath commit -m "Initial deployment - Fight2Earn"
& $gitPath branch -M main
& $gitPath remote add origin https://github.com/datalbanianguy/fight2earn.git
& $gitPath push -u origin main

Write-Host "Done! Check https://fight2earn.vercel.app in 2-3 minutes"
