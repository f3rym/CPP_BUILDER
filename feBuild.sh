#!/bin/bash
# feBuild version v2 — 13.11.2025

getName() {
    sed -n "${1}p" build/listSRC.txt
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
    done < build/listSRC.txt
    echo "0"
    return 1
}
printCodeExec() {
    local error=$?
    echo ""
    if ((error == 0)); then
        echo -e "\e[32m✔ Return code ... ${error}\e[0m"
    else
        echo -e "\e[31m✗ Return code ... ${error}\e[0m"
    fi
}
compiler() {
    mkdir -p build/binary build/obj
    local numBlock=$1
    local list=$2
    local start=$(( (numBlock - 1) * 3 + 1 ))
    local end=$(( numBlock * 3 ))

    echo -e "\n\e[34m➤ Compiling block ${numBlock} (files ${start}–${end})...\e[0m"

    local tmpList="build/tmp_block_${numBlock}.txt"
    : > "$tmpList"
    for (( i = start; i <= end && i <= list; i++ )); do
        getName "${i}" >> "$tmpList"
    done

    local objs=""
    local objFile
    local success=1

    while IFS= read -r src; do
        objFile="build/obj/$(basename "${src%.*}").o"

        needs_rebuild=0
        if [[ ! -f "$objFile" ]]; then
            needs_rebuild=1
        else
            deps=$(find . -type f \( -name "*.h" -o -name "*.tpp" -o -name "*.ipp" \) -newer "$objFile" 2>/dev/null)
            [[ -n "$deps" ]] && needs_rebuild=1
        fi

        if (( needs_rebuild )) || [[ "$src" -nt "$objFile" ]]; then
            echo "g++ -c \"$src\" -o \"$objFile\""
            if ! g++ -c "$src" -o "$objFile"; then
                echo -e "\e[31m✗ Error compiling: $src\e[0m" >&2
                echo -e "\e[33m⚠ Cleaning binary archives due to compilation error...\e[0m"
                rm -rf build/binary build/obj
                rm -f "$tmpList"
                return 1
            fi
        else
            echo "✔ $objFile is up-to-date"
        fi
        objs+=" $objFile"
    done < "$tmpList"

    rm -f "$tmpList"

    local arFile="build/binary/block${numBlock}.a"
    echo "ar rcs $arFile $objs"
    if ! ar rcs "$arFile" $objs; then
        echo -e "\e[31m✗ Error creating archive $arFile\e[0m" >&2
        return 1
    fi

    if [[ ! -s "$arFile" ]]; then
        echo -e "\e[31m✗ Archive $arFile is empty\e[0m" >&2
        return 1
    fi

    echo -e "\e[32m✔ Block ${numBlock} -> ${arFile} created\e[0m"
}
blockBuild() {
    local list countBlock
    list=$(wc -l < build/listSRC.txt)
    countBlock=$(( (list + 2) / 3 ))

    for (( numBlock = 1; numBlock <= countBlock; numBlock++ )); do
        compiler "${numBlock}" "${list}" || return 1
    done
}
reBlockBuild() {
    local list countBlock
    list=$(wc -l < build/listSRC.txt)
    countBlock=$(( (list + 2) / 3 ))

    for (( numBlock = 1; numBlock <= countBlock; numBlock++ )); do
        local rebuild=0
        for (( i = (numBlock-1)*3+1; i <= numBlock*3 && i <= list; i++ )); do
            src=$(getName "$i")
            objFile="build/obj/$(basename "${src%.*}").o"

            needs_rebuild=0
            if [[ ! -f "$objFile" ]]; then
                needs_rebuild=1
            else
                deps=$(find . -type f \( -name "*.h" -o -name "*.tpp" -o -name "*.ipp" \) -newer "$objFile" 2>/dev/null)
                [[ -n "$deps" ]] && needs_rebuild=1
            fi

            if (( needs_rebuild )) || [[ "$src" -nt "$objFile" ]]; then
                rebuild=1
                break
            fi
        done

        if (( rebuild )); then
            if ! compiler "$numBlock" "$list"; then
                return 1
            fi
        else
            echo "Block $numBlock is up-to-date"
        fi
    done
}
g() {
    local libs
    libs=$(find build/binary/ -name "*.a")
    if [ -z "$libs" ]; then
        echo -e "\e[31m✗ No archives found! Cannot link.\e[0m"
        return 1
    fi

    echo "g++ -o build/main -Wl,--start-group $libs -Wl,--end-group"
    if ! g++ -o build/main -Wl,--start-group $libs -Wl,--end-group; then
        echo -e "\e[31m✗ Linking failed. Build aborted.\e[0m"
        exit 1
    fi
    echo -e "\e[32m✔ Linking done!\e[0m"
}
release() {
    mkdir -p build build/temp build/prev

    [[ -f "build/listSRC.txt" ]] && mv build/listSRC.txt build/prev/listSRC.txt 2>/dev/null
    find . -type f -name "*.cpp" > build/listSRC.txt
    find . -type f \( -name "*.h" -o -name "*.tpp" -o -name "*.ipp" \) > build/listH.txt

    if [ ! -s "build/listSRC.txt" ]; then
        echo "No source files (.cpp)"
        return 1
    fi

    echo "Found $(wc -l < build/listSRC.txt) .cpp files and $(wc -l < build/listH.txt) header/template files"
}
release || exit 1
echo "Checking if compilation is needed..."

first_build=0
if [ ! -f "build/main" ]; then
    echo "First compilation..."
    first_build=1
fi
build_project() {
    if (( first_build )); then
        blockBuild || return 1
    else
        updatedFiles=$(find . -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.tpp" -o -name "*.ipp" \) -newer build/main 2>/dev/null)
        if [[ -n "$updatedFiles" ]]; then
            echo "Changes detected, compiling..."
            reBlockBuild || return 1
        else
            echo "Compiling is not required"
            ./build/main
            printCodeExec
            return 0
        fi
    fi
}
if ! build_project; then
    echo -e "\e[33m⚠ Error detected. Cleaning archives and retrying full rebuild...\e[0m"
    rm -rf build/binary build/obj
    sleep 0.5
    if ! blockBuild; then
        echo -e "\e[31m✗ Full rebuild failed. Build aborted.\e[0m"
        exit 1
    fi
fi

if ! g; then
    echo -e "\e[31m✗ Final link failed. Build aborted.\e[0m"
    exit 1
fi

./build/main
printCodeExec

# feBuild version v2  by FEERRRRRRRYYYYYYYYMMMMMMMMMM