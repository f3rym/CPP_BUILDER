#!/bin/bash
unalias make 2>/dev/null
mkdir ~/bin
echo "
███████╗███████╗██████╗ ██╗   ██╗██╗██╗     ██████╗    
██╔════╝██╔════╝██╔══██╗██║   ██║██║██║     ██╔══██╗
█████╗  █████╗  ██████╔╝██║   ██║██║██║     ██║  ██║
██╔══╝  ██╔══╝  ██╔══██╗╚██╗ ██╔╝██║██║     ██║  ██║
██╗     ███████╗██████╔╝ ╚████╔╝ ██║██████╗ ███████╗
╚═╝     ╚══════╝╚═════╝   ╚═══╝  ╚═╝╚═════╝ ╚══════╝
"
export PATH="$HOME/bin:$PATH"
if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
fi
cp feBuild.sh ~/bin/make
chmod +x ~/bin/make
source ~/.bashrc
echo "Установка завершена. Команда make теперь доступна, можете удалить builder"