Main

function RemoveDuplicateStrings {
    param(
        [Parameter()]
        [string[]]$arr
    )

    $new_arr = @()
    for ($i = 0; $i -lt ($arr.Length); $i++) {
        $row = $arr[$i]
        $alp = $row -eq ''
        if (!$alp) {

            if (!$new_arr.Contains($row)) {
                $new_arr += $row
            }
        }
        
    }
    return [string[]]$new_arr
}

function DockerBuild {
    param($service_name, $tag, $url)
    $docker_file=Test-Path .\Dockerfile
    if ($docker_file){
        $st = "${service_name}:${tag}"
        docker build -t $st .
        docker tag ${st} ${url}/${st}
        docker push ${url}/${st}
    }
    else {
        Write-Error "Dockfile not found"
    }
}


function ConnectToAws {
    param($region, $url)

    $connection_status = aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $url
    return [bool]$connection_status -eq "Login Succeeded"
}

function  Main {
    Clear-Host
    $value = @()
    $java = Test-Path pom.xml
    
    if (Test-Path .drone.yml) {
        $tmp = Get-Content .drone.yml
        foreach ($item in $tmp) {
            $value += $item
        }
    }
    if (Test-Path .drone-hml.yml) {
        $tmp = Get-Content .drone-hml.yml
        foreach ($item in $tmp) {
            $value += $item
        }
    }
    
    $registries = [string[]] ($value | findstr registry) -replace ('\s|registry:', '')
    $registries = RemoveDuplicateStrings -arr $registries
    $images = [string[]] ($value | findstr image_name) -replace ('\s|image_name:', '')
    $images = RemoveDuplicateStrings -arr $images
    $repo = ($value | findstr /r 'service:') -replace ('\s|service:|image.+', '')
    $repo = RemoveDuplicateStrings -arr $repo
    
    foreach ($item in $registries) {
        $i = $registries.IndexOf($item) + 1
        Write-Output "[ $i ] - $item"
    }
    
    $rsp = Read-Host "qual numero do repositorio:"
    $tag = Read-Host "digite a tag:"
    $url = $registries[$rsp - 1]
    $region = $url -replace ('.+?ecr|amazon.+|\.', '')
    
    Clear-Host
    Write-Output "**********[ATENCAO]**********"
    Write-Output "** REPO: $repo "
    Write-Output "** TAG: $tag  "
    Write-Output "** URL: $url  "
    Write-Output "*****************************"
    $confirm = Read-Host "confirma build [s/n]"
    $confirm = ($confirm -eq 's') -or ($confirm -eq 'S')
    
    if ($confirm) {
        if ($java) {
            Write-Output "Generating new java target.."
            mvn clean package
        }
        
        Clear-Host
        Write-Output "Connecting to aws.."
        $connected=ConnectToAws -region $region -url $url
        
        if ($connected) {
            Write-Output "Generating new docker image.."
            DockerBuild -service_name $repo -tag $tag -url $url
        }
       
    }
           
}
