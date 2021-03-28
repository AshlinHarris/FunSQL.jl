# Syntactic structure of a SQL query.


# Rendering SQL.

mutable struct RenderContext <: IO
    dialect::SQLDialect
    io::IOBuffer
    level::Int
    nested::Bool

    RenderContext(dialect) =
        new(dialect, IOBuffer(), 0, false)
end

Base.write(ctx::RenderContext, octet::UInt8) =
    write(ctx.io, octet)

Base.unsafe_write(ctx::RenderContext, input::Ptr{UInt8}, nbytes::UInt) =
    unsafe_write(ctx.io, input, nbytes)

function newline(ctx::RenderContext)
    print(ctx, "\n")
    for k = 1:ctx.level
        print(ctx, "  ")
    end
end

# Base type.

"""
A part of a SQL query.
"""
abstract type AbstractSQLClause
end

Base.show(io::IO, c::AbstractSQLClause) =
    print(io, quoteof(c, limit = true))

Base.show(io::IO, ::MIME"text/plain", c::AbstractSQLClause) =
    pprint(io, c)

"""
    render(clause; dialect = :default) :: String

Convert the given SQL clause object to a SQL string.
"""
function render(c::AbstractSQLClause; dialect = :default)
    ctx = RenderContext(dialect)
    render(ctx, convert(SQLClause, c))
    String(take!(ctx.io))
end


# Opaque wrapper that serves as a specialization barrier.

"""
An opaque wrapper over an arbitrary SQL clause.
"""
struct SQLClause <: AbstractSQLClause
    content::AbstractSQLClause

    SQLClause(@nospecialize content::AbstractSQLClause) =
        new(content)
end

Base.getindex(c::SQLClause) =
    c.content

Base.convert(::Type{SQLClause}, c::SQLClause) =
    c

Base.convert(::Type{SQLClause}, @nospecialize c::AbstractSQLClause) =
    SQLClause(c)

Base.convert(::Type{SQLClause}, obj) =
    convert(SQLClause, convert(AbstractSQLClause, obj)::AbstractSQLClause)

PrettyPrinting.quoteof(c::SQLClause; limit::Bool = false, wrap::Bool = false) =
    quoteof(c[], limit = limit, wrap = true)

(c::AbstractSQLClause)(c′) =
    c(convert(SQLClause, c′))

(c::AbstractSQLClause)(c′::SQLClause) =
    rebase(c, c′)

rebase(c::SQLClause, c′) =
    convert(SQLClause, rebase(c[], c′))

rebase(::Nothing, c′) =
    c′

render(ctx, c::SQLClause) =
    render(ctx, c[])

function render(ctx, cs::AbstractVector{SQLClause}; sep = ", ", left = "(", right = ")")
    print(ctx, left)
    first = true
    for c in cs
        if !first
            print(ctx, sep)
        else
            first = false
        end
        render(ctx, c)
    end
    print(ctx, right)
end


# Concrete clause types.

include("clauses/as.jl")
include("clauses/from.jl")
include("clauses/identifier.jl")
include("clauses/literal.jl")
include("clauses/operator.jl")
include("clauses/select.jl")
include("clauses/where.jl")

