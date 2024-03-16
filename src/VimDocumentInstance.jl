export VimDocumentInstance

struct VimDocumentInstance
    document::String
    instanceName::String
end

function VimDocumentInstance()
    run(`alacritty -e vim`)
end
