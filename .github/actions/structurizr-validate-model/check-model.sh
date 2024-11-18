#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if URL is provided as an argument
if [ -z "$1" ]; then
    echo -e "${RED}Error: No URL provided${NC}"
    exit 1
fi

URL=$1

# Make the curl request and save the response to response.html
if ! curl -s -L "$URL" > response.html; then
    echo -e "${RED}Error: Failed to make the API request${NC}"
    rm response.html
    exit 1
fi

# Check if the response is HTML (looking for <html> tag)
if grep -q "<html" response.html; then
    # Extract error message from HTML
    error_message=$(awk '
        /<h1>Error<\/h1>/ {flag=1; next}
        flag && /<p>/ {
            capture=1
            sub(".*<p>", "")
        }
        capture {
            content = content $0
        }
        capture && /<\/p>/ {
            sub("</p>.*", "", content)
            gsub(/\n/, " ", content)
            print content
            exit
        }
    ' response.html)

    if [ -n "$error_message" ]; then
        echo -e "${RED}Error detected:${NC}"
        echo -e "${RED}$error_message${NC}"
        rm response.html
        exit 2
    else
        echo -e "${GREEN}No error message found in the response.${NC}"
        rm response.html
        exit 0
    fi
else
    echo -e "${RED}Response is not HTML. Unable to process.${NC}"
    rm response.html
    exit 3
fi
