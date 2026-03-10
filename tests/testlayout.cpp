#include "fcitx-public.h"
#include "fcitx-utils/log.h"

int main() {
    setenv(
        "XKB_CONFIG_ROOT",
        "/Library/Input Methods/Fcitx5.app/Contents/share/xkeyboard-config-2",
        1);
    std::string result = getSymbolsOfLayout("us", true);
    FCITX_ASSERT(
        result ==
        R"raw([["~","!","@","#","$","%","^","&","*","(",")","_","+"],["Q","W","E","R","T","Y","U","I","O","P","{","}","|"],["A","S","D","F","G","H","J","K","L",":","\""],["Z","X","C","V","B","N","M","<",">","?"]])raw");
    result = getSymbolsOfLayout("us-dvorak", false);
    FCITX_ASSERT(
        result ==
        R"([["`","1","2","3","4","5","6","7","8","9","0","[","]"],["'",",",".","p","y","f","g","c","r","l","/","=","\\"],["a","o","e","u","i","d","h","t","n","s","-"],[";","q","j","k","x","b","m","w","v","z"]])");
    return 0;
}
