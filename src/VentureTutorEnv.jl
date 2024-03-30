export VentureTutorEnv

struct VentureTutorEnv <: AbstractEnv 
    instance::VimDocumentInstance
    comp_document::String
    view_range::UInt8 # This should only be a small value, may change to UInt16 if it is to much trouble converting data types in julia
# I shouldn't need two documents    b::VimDocumentInstance
end

function VentureTutorEnv()
    VimDocumentInstance()
end
