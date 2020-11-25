# Inline routing a HTTP request while parsing it

import Automa
import Automa.RegExp: @re_str, RE
const re = Automa.RegExp

# Transient state while processing the HTTP header
struct HttpRouterCtx
    cs::Int
    meth::Union{Nothing, String}
    arg::Vector{UInt8}
    args::Vector{Vector{UInt8}}
    route::Union{Nothing, String}
end

HttpRouterCtx(cs) = HttpRouterCtx(cs, nothing, UInt8[], Vector{UInt8}[], nothing)

# Place holder message handlers which would write back to the client
function def_handler(meth, route)
    @info "$meth $route"
end

function def_handler(meth, route, args...)
    @info "$meth $route $(String.(args))"
end

# Create the FSM which interprets the HTTP request header
# https://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html
http_machine = () -> begin
    getm = re"GET "
    getm.actions[:exit] = [:hm_get]
    meth = getm

    # Note that we do not try to parse all possible URI's as vast
    # majority would result in 404 (or whatever). For a real web
    # server we would need some level of handling for URI's not in our
    # set of routes, but we do not need complex URI structure.
    rootr = re"/ "
    rootr.actions[:exit] = [:rootr]
    echor = re"/echo/? "
    echor.actions[:exit] = [:echor]
    echo_arg = re"[a-z0-9_]+"
    echo_arg.actions[:enter] = [:start_arg]
    echo_arg.actions[:final] = [:add_arg]
    echo_arg.actions[:exit] = [:end_arg]
    echonr = re"/echo/" * echo_arg * re"/? "
    echonr.actions[:exit] = [:echonr]
    echomr = re"/echo/" * echo_arg * re"/" * echo_arg * re"/? "
    echomr.actions[:exit] = [:echomr]
    route = rootr | echor | echonr | echomr

    ver = re"HTTP/1\.1\r\n"
    ver.actions[:final] = [:ver1_1]

    Automa.compile(meth * route * ver)
end

# Bind quoted Julia code to action names specified above
http_acts = Dict(
    :hm_get => :(meth = "GET"),

    :start_arg => :(empty!(arg)),
    :add_arg => :(push!(arg, data[p])),
    :end_arg => :(push!(args, copy(arg))),

    :rootr => :(route = "/"),
    :echor => :(route = "/echo"),
    :echonr => :(route = "/echo/<name>"),
    :echomr => :(route = "/echo/<name>/<message>"),

    # This means the handler will be called as soon as the
    # Request-Line is complete. Of course we may want to read some
    # other headers first
    :ver1_1 => :(def_handler(meth, route, args...))
)

http_context = Automa.CodeGenContext(generator=:goto)

# Just creates our context to store transient data
@eval function http_parse(data::Vector{UInt8})
    $(Automa.generate_init_code(http_context, http_machine()))

    http_parse(HttpRouterCtx(cs), data)
end
    
# Generate the parser function from `http_machine` and `http_acts`
@eval function http_parse(router_ctx::HttpRouterCtx, data::Vector{UInt8})
    $(Automa.generate_init_code(http_context, http_machine()))

    # Load state from a partially completed request. In many cases
    # this will just be the state variable `cs` and the method
    meth = router_ctx.meth
    arg = router_ctx.arg
    args = router_ctx.args
    route = router_ctx.route
    cs = router_ctx.cs
    p_end = p_eof = lastindex(data)

    # Insert the generated Julia code which will be compiled to
    # machine code
    $(Automa.generate_exec_code(http_context, http_machine(), http_acts))

    if cs < 0
        error("This is where we should decide if we return 404 or just close the connection and block the IP address")
    elseif cs == 0
        # This request is complete so forget the context
        nothing
    else
        # Partially completed request, so return the context for the next read
        HttpRouterCtx(cs, meth, arg, args, route)
    end
end

to_vec8(s) = take!(IOBuffer(s))

hv = " HTTP/1.1\r\n"
root_req = to_vec8("GET /" * hv)
echo_req = to_vec8("GET /echo" * hv)
echon_req = to_vec8("GET /echo/foobar/" * hv)
echom_req = to_vec8("GET /echo/foobar/msg" * hv)

http_parse(root_req)
http_parse(echo_req)
http_parse(echon_req)

ctx = http_parse(UInt8[])
# butcher an array into pieces to simulate multiple reads
for rbuf in (echom_req[n:min(end, n+4)] for n in [1:5:length(echom_req)...])
    global ctx = http_parse(ctx, rbuf)
end
