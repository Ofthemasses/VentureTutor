
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
function SendToServer()
    let data_to_send = line("w0") . "," . line(".") . "," . col(".") . "," . mode()
    exec "!echo " . shellescape(data_to_send) . " | nc 127.0.0.1 8000"
endfunction
autocmd CursorMoved * call SendToServer()
