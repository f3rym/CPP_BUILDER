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
    echo -e "\n\e[34m➤ Compiling block ${numBlock} (files ${start} to ${end})...\e[0m"

    local tmpList="build/tmp_block_${numBlock}.txt"
    : > "$tmpList"
    for (( i = start; i <= end && i <= list; i++ )); do
        getName ${i} >> "$tmpList"
    done

    local objs=""
    local objFile
    local success=1

    while IFS= read -r src; do
        objFile="build/obj/$(basename "${src%.*}").o"
        if [[ ! -f "$objFile" || "$src" -nt "$objFile" ]]; then
            echo "g++ -c \"$src\" -o \"$objFile\""
            if ! g++ -c "$src" -o "$objFile"; then
                echo -e "\e[31m✗ Error compiling: $src\e[0m" >&2
                success=0
            fi
        else
            echo "✔ $objFile is up-to-date"
        fi
        objs+=" $objFile"
    done < "$tmpList"

    if (( success == 0 )); then
        rm "$tmpList"
        return 1
    fi

    local arFile="build/binary/block${numBlock}.a"
    echo "ar rcs $arFile $objs"
    if ! ar rcs "$arFile" $objs; then
        echo -e "\e[31m✗ Error creating archive $arFile\e[0m" >&2
        rm "$tmpList"
        return 1
    fi

    if [[ ! -s "$arFile" ]]; then
        echo -e "\e[31m✗ Archive $arFile is empty\e[0m" >&2
        rm "$tmpList"
        return 1
    fi

    echo -e "\e[32m✔ Block ${numBlock} -> ${arFile} created\e[0m"
    rm "$tmpList"
}

blockBuild() {
    local list countBlock
    list=$(wc -l < build/listCPP.txt)
    countBlock=$(( (list + 2) / 3 ))

    for (( numBlock = 1; numBlock <= countBlock; numBlock++ )); do
        compiler ${numBlock} ${list} || return 1
    done
}

reBlockBuild() {
    local list countBlock
    list=$(wc -l < build/listCPP.txt)
    countBlock=$(( (list + 2) / 3 ))

    for (( numBlock = 1; numBlock <= countBlock; numBlock++ )); do
        local rebuild=0
        for (( i = (numBlock-1)*3+1; i <= numBlock*3 && i <= list; i++ )); do
            src=$(getName "$i")
            objFile="build/obj/$(basename "${src%.*}").o"
            if [[ ! -f "$objFile" || "$src" -nt "$objFile" ]]; then
                rebuild=1
                break
            fi
        done
        (( rebuild )) && compiler "$numBlock" "$list" || echo "Block $numBlock is up-to-date"
    done
}

g() {
    local libs
    libs=$(find build/binary/ -name "*.a")

    if [ -z "$libs" ]; then
        echo -e "\e[31m✗ No files!\e[0m"
        return 1
    fi

    mkdir -p build/temp
    [[ -f "build/main" ]] && mv build/main build/temp/prev 2>/dev/null

    echo "g++ -o build/main -Wl,--start-group $libs -Wl,--end-group"
    if g++ -o build/main -Wl,--start-group $libs -Wl,--end-group; then
        echo -e "\e[32m✔ Done!\e[0m"
        ./build/main
    else
        echo -e "\e[31m✗ Link error!\e[0m"
        [[ -f "build/temp/prev" ]] && cp build/temp/prev build/main && echo -e "\e[33mPrev version restored\e[0m" && ./build/main
        return 1
    fi
    rm -rf build/temp
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
echo "Checking if compilation is needed..."

if [ ! -f "build/main" ]; then
    echo "First compilation..."
    blockBuild || exit 1
    g || exit 1
else
    updatedFiles=$(find . -name "*.cpp" -o -name "*.h" -newer build/main 2>/dev/null)
    if [[ -n "$updatedFiles" ]]; then
        echo "Changes detected, compiling..."
        reBlockBuild || exit 1
        g || exit 1
    else
        echo "Compiling is not required"
        ./build/main
    fi
fi
