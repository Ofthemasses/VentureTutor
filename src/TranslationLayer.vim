
" Wait for input

" On input, send status
" line
" :echo line("w0")
" row
" :echo line(".")
" col
" :echo col(".")
" mode
" :echo mode()
set noswapfile
edit ~/Documents/VentureTutor/test/Curr.cpp

function SendToServer()
    let data_to_send = line("w0") . "," . line(".") . "," . col(".") . "," . mode()
    exec "!echo " . shellescape(data_to_send) . " | nc 127.0.0.1 8000 > /dev/null 2>&1"
endfunction
autocmd CursorMoved * call SendToServer()
