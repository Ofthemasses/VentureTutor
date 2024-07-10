export VimDocumentInstance
using Random

mutable struct VimDocumentInstance
    document::String
    windowID::String
    server::Sockets.TCPServer
    line::UInt16
    row::UInt16
    col::UInt16
    mode::Int8
    contents::Vector{Char}
end

function VimDocumentInstance()
    Threads.@spawn open_vim()
    # Get window ID
    get_id_cmd = `xdotool search --name 'DocInstance'`
    sleep(0.5)
    window_id = chomp(read(get_id_cmd, String))
    server = listen(8000)
    atexit(() -> shutdown_server(server))
    return VimDocumentInstance("test", window_id, server, 0, 0, 0, 0, [])
end

function open_vim()
    run(`alacritty --title 'DocInstance' -e vim --servername DOCINSTANCE -S \~/Documents/VentureTutor/src/TranslationLayer.vim`)
end

function reset(env::VimDocumentInstance)
    # In case there are changes to the document, refresh
    run(`vim --servername DOCINSTANCE --remote-expr "Refresh()"`)
    # Change this to create a new RANDOM file.
    env.contents = collect(randstring(' ':'~',50));
    for i in 1:50
        if (rand() < 4/50)
            env.contents[i] = '\n';
        end
    end
    open("/home/finlay/Documents/VentureTutor/test/output", "w") do file
        for i in env.contents
            print(file, i)
        end
    end
    # Refresh after document is updated with new value
    sleep(0.1)
    run(`vim --servername DOCINSTANCE --remote-expr "Refresh()"`)
end

function send(env::VimDocumentInstance, str::Char)
    run(`vim --servername DOCINSTANCE --remote-send "$str"`)
end

function send(env::VimDocumentInstance, str::String)
    run(`vim --servername DOCINSTANCE --remote-send "$str"`)
end

function run_update_state(env::VimDocumentInstance)
    while isopen(env.server)
        sock = accept(env.server)
        data = readline(sock)
        data_split = split(data, ",")
        env.line = parse(UInt16, data_split[1])
        env.row = parse(UInt16, data_split[2])
        env.col = parse(UInt16, data_split[3])
        env.mode = UInt8(data_split[4][1])
        close(sock)
    end
end

function shutdown_server(server)
    if isopen(server)
        close(server)
    end
    println("Server shutdown completed.")
end
