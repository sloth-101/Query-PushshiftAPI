<#
.SYNOPSIS
    Query Pushshift API
.DESCRIPTION
     Query Pushshift API for comments or submissions
.NOTES
    does only display comments, title and selftext, no submitted pictures or videos, doenst display external content
.LINK
    https://github.com/sloth-101/Query-PushshiftAPI
.EXAMPLE
    Query-PushShiftAPI
    queries the API for the last 100 comments of the default username you can set in the author parameter
.EXAMPLE
    Query-PushShiftAPI -type submission -author spez -results 20
    queries the API for the last 20 submissions of the user spez
.EXAMPLE
    Query-PushShiftAPI -before 2020-25-31 -after 2019-12-31 -subreddit askreddit
    queries the API for comments made between these dates in the subreddit "AskReddit"
#>
function Query-PushShiftAPI {
    [Alias('Find-RedditUserContent')]
    [Alias('redditlookup')]
    [cmdletbinding()]
    param (
        $searchterm = "",
        [ValidateSet("comment", "submission")]
        $type = "comment",
        [Parameter(Mandatory = $true)]
        [Alias('username')]
        $author = "",
        $subreddit = "",
        [int]$results = 100,
        [ValidatePattern("(\d{4}[-](0[1-9]|1[012])[-]\d{2})", ErrorMessage = "Pls enter date in this format: YYYY-MM-DD i.e. 2022-05-15")]
        $after = "",
        [ValidatePattern("(\d{4}[-](0[1-9]|1[012])[-]\d{2})", ErrorMessage = "Pls enter date in this format: YYYY-MM-DD i.e. 2022-05-15")]
        $before = $(get-date -f yyyy-MM-dd),
        [int]$ScoreAmount,
        [ValidateSet("GreatherThan", "LessThan")]
        $ScoreOperator = "LessThan",
        [ValidateSet("all_awardings", "author", "author_flair_background_color", "author_flair_css_class", "author_flair_richtext", "author_flair_template_id", "author_flair_text", "author_flair_text_color", "author_flair_type", "author_fullname", "author_patreon_flair", "body", "created_utc", "gildings", "id", "is_submitter", "link_id", "locked", "no_follow", "parent_id", "permalink", "retrieved_on", "score", "send_replies", "stickied", "subreddit", "subreddit_id", "subreddit_name_prefixed", "total_awards_received", "updated_utc")]
        [System.Collections.ArrayList]$fields = @()
    )
    Add-Type -AssemblyName System.Web
    $baseurl = "https://api.pushshift.io/reddit"
    $ubefore = (([DateTimeOffset]($before)).ToUnixTimeSeconds()).tostring()
    if ($after) {
        $tempafter = get-date $after
        $uafter = (([DateTimeOffset]($tempafter)).ToUnixTimeSeconds()).tostring()
    }
    if ($ScoreAmount) {
        switch ($ScoreOperator) {
            GreatherThan { $uscore = ">$scoreamount" }
            LessThan { $uscore = "<$scoreamount" }
            Default {}
        }
    }
    if ($results -gt 100) {
        $fullsearches = [math]::truncate($results / 100)
        $partialsearch = [math]::round(($results / 100 - $fullsearches) * 100)
    }
    else {
        $fullsearches = 1
    }
    $a = for ($i = 0; $i -lt $fullsearches; $i++) {
        switch ($type) {
            comment {
                $fields.add("author")
                $fields.add("body")
                $fields.add("subreddit")
            }
            submission {
                $fields.add("author")
                $fields.add("title")
                $fields.add("selftext")
                $fields.add("permalink")
                $fields.add("subreddit")
            }
            Default {}
        }

        $finalurl = "$baseurl/$type/search?html_decode=true&after=$uafter&before=$ubefore&author=$author&subreddit=$subreddit&q=$searchterm&size=$results&score=$uscore"

        $partial = Invoke-RestMethod $finalurl
        $ubefore = $partial.data[-1].created_utc
        $partial
    }
    if ($results -gt 100) {
        $uri = [Uri]$finalurl
        $queryString = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
        $queryString['before'] = $ubefore
        $queryString['size'] = $partialsearch
        $finalurl = 'https://api.pushshift.io/reddit/comment/search?{0}' -f $queryString.ToString()
        $partial = Invoke-RestMethod $finalurl
        $a += $partial
    }


    $head = @"
<title>Reddit/Pushshift Results</title>
<style>
table
{
font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;
border-collapse:collapse;
}
td
{
font-size:1em;
border:1px solid #98bf21;
padding:5px 5px 5px 5px;
}
th
{
font-size:1.1em;
text-align:center;
padding-top:5px;
padding-bottom:5px;
padding-right:7px;
padding-left:7px;
background-color:#A7C942;
color:#ffffff;
}
name tr
{
color: #060606;
background-color:#EAF2D3;
}
</style>
"@

    $temphtml = $a | Select-Object -expandproperty data -ErrorAction SilentlyContinue | select-object @(@{n = "date"; e = { ([System.DateTimeOffset]::FromUnixTimeSeconds($_.created_utc)).DateTime } }; @{n = "permalink"; e = { "<a href=`"" + $_.permalink + "`"></a>" } }; $fields) -ExcludeProperty permalink -ErrorAction SilentlyContinue | ConvertTo-Html -Fragment
    clear-variable out -ErrorAction SilentlyContinue
    foreach ($line in $temphtml) { $out += $line -replace '&lt;a href=&quot;', '<a href=https://www.reddit.com' -replace '&quot;&gt;&lt;/a&gt;', '>permalink</a>' }
    ConvertTo-Html -head $head -Body $out | Out-File -FilePath .\Redditsearchresults.html -Force
    Invoke-Item .\Redditsearchresults.html


}

