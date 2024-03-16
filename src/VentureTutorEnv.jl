export VentureTutorEnv

struct VentureTutorEnv <: AbstractEnv 
    a::VimDocumentInstance
    b::VimDocumentInstance
end

function VentureTutorEnv()
    VimDocumentInstance()
end
