
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
set noconfirm
edit ~/Documents/VentureTutor/test/Curr.cpp

let g:allowed_file = '/home/finlay/Documents/VentureTutor/test/Curr.cpp'

autocmd BufRead,BufNewFile * call LockToSingleFile()

function! LockToSingleFile()
  let l:current_file = expand('%:p')

  if l:current_file !=# g:allowed_file

	echohl ErrorMsg
	echom 'You are not allowed to edit this file. Returning to the allowed file...'
	echohl None

	execute 'edit ' . g:allowed_file
  endif
endfunction

function Refresh()
    silent edit!
    norm gg
    stopinsert
endfunction

function SendToServer()
    let data_to_send = line("w0") . "," . line(".") . "," . col(".") . "," . mode()
    silent exec "!echo " . shellescape(data_to_send) . " | nc 127.0.0.1 8000 > /dev/null 2>&1"
    silent write! /home/finlay/Documents/VentureTutor/test/output
endfunction

autocmd CursorMoved * call SendToServer()
