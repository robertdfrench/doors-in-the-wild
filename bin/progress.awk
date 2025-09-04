#!/usr/bin/awk

BEGIN {
    fence=0
}

$1 == "```progress" && fence == 0 {
    print
    fence=1
    next
}

fence == 0 {
    print
}

$1 == "```" && fence == 1 {
    print
    fence=0
    next
}

fence == 1 {
    print progress"% Complete"
}
