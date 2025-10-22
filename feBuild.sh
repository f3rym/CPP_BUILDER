#!/bin/bash

getName() {
    sed -n "${1}p" build/listCPP.txt
}

getIndex() {
    local search_name="${1%.*}"
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))
        local line_name="${line%.*}"
        if [[ "$line_name" == "$search_name" ]]; then
            echo "$line_num"
            return 0
        fi
    done < build/listCPP.txt

    echo "0"
    return 1
}

compiler() {
    mkdir -p build/binary build/obj

    local numBlock=$1
    local list=$2
    local start=$(( (numBlock - 1) * 3 + 1 ))
    local end=$(( numBlock * 3 ))

    echo -e "\ncompiling n ${numBlock}"

    local tmpList="build/tmp_block_${numBlock}.txt"
    : > "$tmpList"

    for (( i = start; i <= end && i <= list; i++ )); do
        getName ${i} >> "$tmpList"
    done
    local objFile
    while IFS= read -r src; do
        objFile="build/obj/$(basename "${src%.*}").o"
        echo "g++ -c \"$src\" -o \"$objFile\""
        if ! g++ -c "$src" -o "$objFile"; then
            echo -e "\e[31m✗ Error compiling: $src\e[0m" >&2
            return 1
        fi
    done < "$tmpList"

    local objs
    objs=$(while IFS= read -r src; do echo "build/obj/$(basename "${src%.*}").o"; done < "$tmpList")
    local arFile="build/binary/block${numBlock}.a"
    echo "ar rcs $arFile $objs"
    if ! ar rcs "$arFile" $objs; then
        echo -e "\e[31m✗ Error with create file $arFile\e[0m" >&2
        return 1
    fi

    echo -e "\e[32m✔ Block ${numBlock} -> ${arFile} create done\e[0m"
    rm "$tmpList"
}

blockBuild() {
    local list countBlock
    list=$(wc -l < build/listCPP.txt)
    countBlock=$(( (list + 2) / 3 ))

    for (( numBlock = 1; numBlock <= countBlock; numBlock++ )); do
        compiler ${numBlock} ${list}
    done
}

reBlockBuild() {
    local countNew list
    find . \( -name "*.cpp" -o -name "*.h" \) -newer build/main > build/newFiles.txt 2>/dev/null
    countNew=$(wc -l < build/newFiles.txt)
    list=$(wc -l < build/listCPP.txt)

    if (( countNew == 0 )); then
        echo "No UPD."
        return
    fi
    local str index
    for (( i = 1; i <= countNew; i++ )); do
        str=$(sed -n "${i}p" build/newFiles.txt)
        index=$(getIndex "$str")
        if (( index != 0 )); then
            local numBlock=$(( (index + 2) / 3 ))
            compiler ${numBlock} ${list}
        fi
    done
}

g() {
    local libs
    libs=$(find build/binary/ -name "*.a")

    if [ -z "$libs" ]; then
        echo -e "\e[31m✗ No files!\e[0m"
        return 1
    fi

    if [ -f "build/temp/prev" ]; then
        rm build/temp/prev
    elif [ -f "build/main" ]; then
        mv build/main build/temp/prev 2>/dev/null
    fi
    echo "g++ -o build/main -Wl,--start-group $libs -Wl,--end-group"
    if g++ -o build/main  -Wl,--start-group $libs -Wl,--end-group; then
        echo -e "\e[32m✔ Done!\e[0m"
        ./build/main
    else
        echo -e "\e[31m✗ Error link!\e[0m"
        if [ -f "build/temp/prev" ]; then
            cp build/temp/prev build/main
            echo -e "\e[33mPrev version restored\e[0m"
            ./build/main
        fi
    fi
}

release() {
    mkdir -p build build/temp build/prev

    [[ -f "build/listCPP.txt" ]] && mv build/listCPP.txt build/prev/listCPP.txt 2>/dev/null
    [[ -f "build/listH.txt" ]] && mv build/listH.txt build/prev/listH.txt 2>/dev/null

    find . -name "*.cpp" > build/listCPP.txt
    find . -name "*.h" > build/listH.txt

    if [ ! -s "build/listCPP.txt" ]; then
        echo "No CPP files"
        return 1
    fi

    echo "Found $(wc -l < build/listCPP.txt) .cpp files and $(wc -l < build/listH.txt) .h files"
}

release || exit 1
echo "Checking neeeed compilation..."

if [ ! -f "build/main" ]; then
    echo "First compilation..."
    blockBuild
    g
elif [[ -n "$(find . -name "*.cpp" -newer build/main -o -name "*.h" -newer build/main 2>/dev/null)" ]]; then
    echo "UPD, compiling..."
    reBlockBuild
    g
else
    echo "Compiling is not required"
    ./build/main
fi
