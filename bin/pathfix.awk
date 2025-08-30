#!/usr/bin/awk

$1 == "*" && $2 == ".Pa" {
    print "* [`"$3"`]("blob_url"/"$3")"
    next
}

{ print }
