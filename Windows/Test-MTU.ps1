#https://rcmtech.wordpress.com/2015/03/08/powershell-find-mtu/

#set BufferSizeMax to the largest MTU you want to try, usually 1500 or up to 9000 if using Jumbo Frames
$BufferSizeMax = 1500
#set TestAddress to the name or IP address you wish to test against
$TestAddress   = "www.google.com"

$LastMinBuffer=$BufferSizeMin
$LastMaxBuffer=$BufferSizeMax
$MaxFound=$false

#calculate first MTU attempt, halfway between zero and BufferSizeMax
[int]$BufferSize = ($BufferSizeMax - 0) / 2

Write-Host "Testing maximum MTU size. Green = supported, Red = unsupported."

while($MaxFound -eq $false){
    try{
        $Response = ping $TestAddress -n 1 -f -l $BufferSize
        #if MTU is too big, ping will return: Packet needs to be fragmented but DF set.
        if($Response -like "*fragmented*"){throw}
        if($LastMinBuffer -eq $BufferSize){
            #test values have converged onto the highest working MTU, stop here and report value
            $MaxFound = $true
            Write-Host "found."
            break
        } else {
            #it worked at this size, make buffer bigger
            Write-Host "$BufferSize" -ForegroundColor Green -NoNewline
            $LastMinBuffer = $BufferSize
            $BufferSize = $BufferSize + (($LastMaxBuffer - $LastMinBuffer) / 2)
        }
    } catch {
        #it didn't work at this size, make buffer smaller
        Write-Host "$BufferSize" -ForegroundColor Red -NoNewline
        $LastMaxBuffer = $BufferSize
        #if we're getting close, just subtract 1
        if(($LastMaxBuffer - $LastMinBuffer) -le 3){
            $BufferSize = $BufferSize - 1
        } else {
            $BufferSize = $LastMinBuffer + (($LastMaxBuffer - $LastMinBuffer) / 2)
        }
    }
    Write-Host "," -ForegroundColor Gray -NoNewline
}

$mtu = $BufferSize + 28
Write-Host “MTU Size: $mtu”
