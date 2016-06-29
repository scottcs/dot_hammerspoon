## UltiSnips (all filetypes)

    box                 A nice box with the current comment symbol
    lorem               Lorem Ipsum
    date                Current Date
    time                Current Time
    datetime            Current Date and Time
    c)                  Copyright message
    [L]GPL{2,3}         GNU [Lesser] General Public License v{2, 3}
    AGPL3               Affero General Public License v3
    GMGPL               GNU Public License linking exception
    BSD{2,3,4}          BSD{2,3,4} license
    MIT                 MIT license
    APACHE              Apache license v2.0
    BEERWARE            BEER-WARE license
    WTFPL               DO WHAT THE FUCK YOU WANT TO public license
    MPL2                Mozilla public license v2.0

## Custom Keybindings

    GENERAL:
    =======
    ,q                  QuickFix list toggle
    ,o                  Location list toggle
    ,,                  Switch to alt buffer
    ,<cr>               Remove current search highlighting
    ,xx                 Close and delete current buffer (keep window open)
    ,cd                 CD to directory of the file in the open buffer
    ,cp                 Copy the path of the current file to the clipboard
    ,p                  Paste from system clipboard
    ,'                  Toggle spell check

    [q                  Previous QuickFix line
    ]q                  Next QuickFix line
    [o                  Previous Location List line
    ]o                  Next Location List line
    gV                  Quickly select text just pasted
    <F7>                Spaces to Tabs
    <F8>                Tabs to Spaces
    <F11>               Resync syntax

    FZF:
    ===
    ,f                  Files in current dir (and subdirs)
    ,g                  Git Files (modified)
    ,G                  Git Files (all)
    ,b                  Open Buffers
    ,l                  Lines in the current buffer
    ,L                  Lines in all open buffers
    ,a                  Lines in all files in current dir (and subdirs)
    ,s                  UltiSnips snippets
    ,t                  Tags in the current buffer
    ,T                  Tags in the current project (ctags -R)

    <c-x><c-f>          (Insert Mode) complete path (using find)
    <c-x><c-j>          (Insert Mode) complete file (using ag)
    <c-x><c-l>          (Insert Mode) complete line (all open buffers)
    <c-x><c-k>          (Insert Mode) complete word

    DEOPLETE:
    ========
    <c-h>               (Popup active) close popup
    <bs>                (Popup active) close popup
    <cr>                (Popup active) select line and close popup
    <tab>               (Popup active) next line
    <s-tab>             (Popup active) previous line

    MARKED:
    ======
    ,m                  Open Marked2 for current Markdown file
    ,M                  Close Marked2

    INDENT GUIDES:
    =============
    ,i                  Toggle Indent Guides

    GITGUTTER:
    =========
    ]h                  Jump to next modified hunk
    [h                  Jump to previous modified hunk

    TABULARIZE:
    ==========
    ,A=                 (Visual or Normal Mode) Tabularize on =
    ,A:                 (Visual or Normal Mode) Tabularize on :
