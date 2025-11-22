# ======================================================================
# DEPLOY.PS1 — AUTOMATED TERRAFORM + ANSIBLE DEPLOYMENT + WORDCOUNT TEST
# ======================================================================

Write-Host "=== BIG DATA SPARK GCP DEPLOYMENT SCRIPT ===" -ForegroundColor Cyan

# ----------------------------------------
# 1. CHECK REQUIRED TOOLS
# ----------------------------------------
function Check-Tool {
    param ($name, $cmd)
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $name is not installed or not in PATH." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: $name found" -ForegroundColor Green
}

Check-Tool "gcloud" "gcloud"
Check-Tool "Terraform" "terraform"
Check-Tool "Docker" "docker"
Check-Tool "ssh" "ssh"
Check-Tool "scp" "scp"

# ----------------------------------------
# 2. FIXED PATHS
# ----------------------------------------
$RootDir       = (Get-Location).Path
$TerraformDir  = Join-Path $RootDir "terraform"
$AnsibleDir    = Join-Path $RootDir "ansible"
$KeysDir       = Join-Path $RootDir "keys"
$WordcountDir  = Join-Path $RootDir "wordcount"

# Files
$ServiceAccountJson = Join-Path $KeysDir "sa.json"
$SshPrivateKey      = Join-Path $env:USERPROFILE ".ssh\id_rsa"
$SshPublicKey       = Join-Path $env:USERPROFILE ".ssh\id_rsa.pub"

# ----------------------------------------
# 3. VALIDATE / GENERATE FILES
# ----------------------------------------
if (-not (Test-Path $ServiceAccountJson)) {
    Write-Host "ERROR: Service account JSON missing: $ServiceAccountJson" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SshPublicKey)) {
    Write-Host "INFO: Generating SSH key..." -ForegroundColor Yellow
    & ssh-keygen -t rsa -b 4096 -f $SshPrivateKey -N "" | Out-Null
}

if (-not (Test-Path $SshPublicKey)) {
    Write-Host "ERROR: Failed to generate SSH key!" -ForegroundColor Red
    exit 1
}

Write-Host "OK: JSON and SSH keys validated." -ForegroundColor Green

if (-not (Test-Path $KeysDir)) {
    New-Item -ItemType Directory -Path $KeysDir | Out-Null
}

Copy-Item -Path $SshPrivateKey      -Destination (Join-Path $KeysDir "id_rsa") -Force
Copy-Item -Path $SshPublicKey       -Destination (Join-Path $KeysDir "id_rsa.pub") -Force
Copy-Item -Path $ServiceAccountJson -Destination (Join-Path $KeysDir "sa.json") -Force

Write-Host "OK: Keys prepared." -ForegroundColor Green

# ----------------------------------------
# 4. LOGIN TO GCP
# ----------------------------------------
Write-Host "Logging into GCP..." -ForegroundColor Yellow
gcloud config set project ultimate-rig-477802-d4 --quiet

$env:GOOGLE_APPLICATION_CREDENTIALS = (Join-Path $KeysDir "sa.json")
Write-Host "Using credentials: $env:GOOGLE_APPLICATION_CREDENTIALS"

# ----------------------------------------
# 5. TERRAFORM DEPLOYMENT
# ----------------------------------------
Write-Host "=== RUNNING TERRAFORM ===" -ForegroundColor Cyan
Set-Location $TerraformDir

terraform init
terraform apply -auto-approve `
    -var "credentials_file=$(Join-Path $KeysDir 'sa.json')" `
    -var "ssh_public_key_path=$(Join-Path $KeysDir 'id_rsa.pub')"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform failed!" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Terraform completed successfully!" -ForegroundColor Green

# ----------------------------------------
# 6. GET VM IPs
# ----------------------------------------
Write-Host "Extracting instance IPs..." -ForegroundColor Yellow
$MASTER_IP  = terraform output -raw master_ip
$WORKER1_IP = terraform output -raw worker1_ip
$WORKER2_IP = terraform output -raw worker2_ip

Write-Host "Master:  $MASTER_IP"
Write-Host "Worker1: $WORKER1_IP"
Write-Host "Worker2: $WORKER2_IP"

# ----------------------------------------
# 7. UPDATE ANSIBLE INVENTORY
# ----------------------------------------
$InventoryFile = Join-Path $AnsibleDir "inventory\hosts.ini"

@"
[master]
spark-master ansible_host=$MASTER_IP ansible_user=ubuntu ansible_ssh_private_key_file=/ansible/.ssh/id_rsa

[workers]
spark-worker1 ansible_host=$WORKER1_IP ansible_user=ubuntu ansible_ssh_private_key_file=/ansible/.ssh/id_rsa
spark-worker2 ansible_host=$WORKER2_IP ansible_user=ubuntu ansible_ssh_private_key_file=/ansible/.ssh/id_rsa
"@ | Set-Content -Path $InventoryFile -Encoding ASCII

Write-Host "OK: Ansible inventory updated." -ForegroundColor Green

Write-Host "Waiting 45 seconds for VMs to finish booting..." -ForegroundColor Yellow
Start-Sleep -Seconds 45

# ----------------------------------------
# 8. RUN ANSIBLE
# ----------------------------------------
Write-Host "=== STARTING ANSIBLE DEPLOYMENT ===" -ForegroundColor Cyan

# Use concatenation for mount path strings to avoid PowerShell parsing issues
$AnsibleMount = $AnsibleDir + ":/ansible"
$KeysMount    = $KeysDir + ":/ansible/.ssh"

# Run container (assumes ansible-gcp image exists and has ansible-playbook)
& docker run -it --rm `
    -v $AnsibleMount `
    -v $KeysMount `
    ansible-gcp `
    ansible-playbook -i inventory/hosts.ini playbook.yml --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

Write-Host "=== DEPLOYMENT FINISHED SUCCESSFULLY ===" -ForegroundColor Green

# ----------------------------------------
# 9. RUN WORDCOUNT TEST
# ----------------------------------------
Write-Host "=== RUNNING SPARK WORDCOUNT TEST ===" -ForegroundColor Cyan

if (-not (Test-Path $WordcountDir)) {
    Write-Host "ERROR: wordcount folder not found at $WordcountDir" -ForegroundColor Red
    exit 1
}

# build remote destination string safely (avoid PowerShell treating ":" as drive)
$RemoteDest = "ubuntu@" + $MASTER_IP + ":/home/ubuntu/"

# Remove previous hostkey entry for this IP (ignore errors)
try { & ssh-keygen -R $MASTER_IP | Out-Null } catch { }

# Upload files
Write-Host "Uploading WordCount.java..." -ForegroundColor Yellow
$srcJava = Join-Path $WordcountDir "WordCount.java"
if (-not (Test-Path $srcJava)) { Write-Host "ERROR: $srcJava not found" -ForegroundColor Red; exit 1 }
& scp -o StrictHostKeyChecking=no -i $SshPrivateKey $srcJava $RemoteDest

Write-Host "Uploading sample.txt..." -ForegroundColor Yellow
$srcSample = Join-Path $WordcountDir "sample.txt"
if (-not (Test-Path $srcSample)) { Write-Host "ERROR: $srcSample not found" -ForegroundColor Red; exit 1 }
& scp -o StrictHostKeyChecking=no -i $SshPrivateKey $srcSample $RemoteDest

# Build the remote bash script
$RemoteScript = @"
#!/usr/bin/env bash
set -euo pipefail

cd /home/ubuntu || exit 1
echo "Compiling WordCount.java..."
javac -cp "/opt/spark/jars/*" -d . WordCount.java

echo "Building JAR..."
jar cvf wordcount.jar foo/WordCount.class \|\| true

echo "Running spark-submit..."
/opt/spark/bin/spark-submit \
  --class foo.WordCount \
  --master spark://$MASTER_IP:7077 \
  wordcount.jar sample.txt output \|\| true

echo "=== WORDCOUNT RESULT (listing output dir) ==="
ls -la output \|\| true

echo "=== WORDCOUNT PARTS (first 200 lines of first part) ==="
firstpart=\$(ls output | head -n1 \|\| true)
if [ -n "\$firstpart" ]; then
  echo "Catting output/\$firstpart ..."
  sed -n '1,200p' "output/\$firstpart" \|\| true
else
  echo "No output parts found."
fi
"@

# Ensure LF-only and UTF-8 no BOM
$RemoteScript = $RemoteScript -replace "`r",""

# Write to temp file
$TempFile = Join-Path $env:TEMP ("spark_script_" + [System.Guid]::NewGuid().ToString() + ".sh")
[System.IO.File]::WriteAllText($TempFile, $RemoteScript, (New-Object System.Text.UTF8Encoding($false)))

# Execute remote script via SSH
Write-Host "Executing remote script via SSH..." -ForegroundColor Yellow
Get-Content -Raw -Encoding UTF8 $TempFile | & ssh -o StrictHostKeyChecking=no -i $SshPrivateKey ("ubuntu@" + $MASTER_IP) "bash -s"

# cleanup
if (Test-Path $TempFile) { Remove-Item $TempFile -Force }

Write-Host "=== WORDCOUNT TEST FINISHED ===" -ForegroundColor Green



Set-Location $RootDir
