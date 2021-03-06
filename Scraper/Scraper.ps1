#------------------------------------------------------------------------------
# Configuration Variables
#------------------------------------------------------------------------------
$datafile = "C:\Users\eddie\Documents\Code\Powershell\Scraper\urls.txt"
$excelfile = "C:\Users\eddie\Documents\Code\Powershell\Scraper\Data.xlsx"

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------
function Release-Ref ($ref) 
{
    ([System.Runtime.InteropServices.Marshal]::ReleaseComObject( [System.__ComObject]$ref) -gt 0)
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}    

# Load a url and make sure that it loads
# We check that it is loaded by looking for an element with $controlID as the id
function navigateToApp($browser, [string] $url, [string] $controlID, [int] $maxDelays, [int] $delayTime)
{
    $numDelays = 0
    $loaded = $false
    $browser.navigate($url)
    while ($loaded -eq $false -and $numDelays -lt $maxDelays) {
        $numDelays++
        [System.Threading.Thread]::Sleep($delayTime)
        $doc = $browser.document
        if ($doc -eq $null) {
            continue
        }
        $controlRef = $doc.getElementByID($controlID)
        if ($controlRef -eq $null) {
            write-host "Waiting for Web app to load $numDelays . . ."
        }
        else 
        {
            write-host "Web app loaded after $numDelays pauses"
            $loaded = $true
        }
    }

    if ($numDelays -eq $maxDelays) {
        throw "Browser not loaded after $maxDelays delays"
    }
}

#------------------------------------------------------------------------------
# Main Loop
#------------------------------------------------------------------------------

# Get urls from text file
$objUrls = Get-Content $datafile

# Start Excel
$objExcel = New-Object -comobject "excel.application"
# Stop the Resume.xlw error from popping up
$objExcel.DisplayAlerts = $false

$objWorkbook = $objExcel.Workbooks.Open($excelFile)
# First Worksheet
$objWorksheet = $objWorkbook.Worksheets.Item(1)

# Find first open row in the worksheet
$intRow = 1
for($z = 1;$objWorksheet.Cells.Item($z,1).Value() -ne $null; $z++) 
{
    $intRow++
}

# Start IE
$objIE = New-Object -com "InternetExplorer.Application"

foreach($url in $objUrls) {

    # Tell IE to Navigate to page
    navigateToApp $objIE $url "currentprice" 100 2000
    $objDoc = $objIE.document
    # Get the price
    $wait = $true
    $numWaits = 0
    while ($wait -and $numWaits -lt 100) {
        $numWaits++
        [System.Threading.Thread]::Sleep(1000)
        $strPrice = $objDoc.getElementByID("currentprice")
        if ($strPrice.value -ne "") {
            $wait = $false
        } else {
            write-host "Waiting for page to respond $numWaits . . ."
        }
    }
    if ($numWaits -eq 100) {
        throw "Web page did not respond after 100 delays"
    }
    else {
        write-host "Web page has responded"
    }

    # Add rows to worksheet
    $objWorksheet.Cells.Item($intRow, 1) = $url
    $objWorksheet.Cells.Item($intRow, 2) = $strPrice.textContent
    $objWorksheet.Cells.Item($intRow, 3) = (Get-Date)
    $intRow++
}

# Cleanup
$objIE.Quit()
$objExcel.Save()
$objExcel.Quit()
$objIE.Quit()

Release-Ref($objIE) | Out-Null
Release-Ref($objWorksheet) | Out-Null
Release-Ref($objWorkbook) | Out-Null
Release-Ref($objExcel) | Out-Null
