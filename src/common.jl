import Base.push!

abstract Component
abstract SingleArg <: Component
==(sa1::SingleArg,sa2::SingleArg)=isa(sa1,typeof(sa2))&&sa1.x==sa2.x 
function getarg(c::Component,n::Integer=1)
	getfield(c,names(c)[n])
end
function setarg!(c::Component,newarg,argn::Integer=1)
	setfield!(c,names(c)[argn],newarg)
	return c
end
setarg(c::Component,newarg,argn::Integer=1)=setarg!(deepcopy(c),newarg,argn)
type Components <: Component 
	components 
	coef
end #maybe this type should be deprecated and sumsym rewritten
function ==(cs1::Components,cs2::Components)
	nc=length(cs1.components)
	if nc != length(cs2.components)
		return false
	else
		for c in 1:nc
			if length(indsin(cs1.components,cs1.components[c]))!=length(indsin(cs2.components,cs1.components[c]))
				return false
			end
		end
	end
	return true
end
type Term
	factors
end #this is not really used except in a experimental expression type that stores its addparse
function ==(t1::Term,t2::Term)
	for p in permutations(t2.factors)
		if t1.factors==p
			return true
		end
	end
	return false
end

type Expression #<: Component? Nope then there is no distinction between X and EX
	components::Array{Any}
end
type ApExpression 
	components::Array{Any}
	ap::Array{Term}
end
function expression(a::Array{Array})
	if isempty(a)
		return 0
	end
	ex=Expression(Any[])
	for cc in a
		for c in cc
			push!(ex.components,c)
		end
		push!(ex.components,:+)
	end
	deleteat!(ex.components,length(ex.components))
	return ex
end
function expression(a::Array{Term})
	if isempty(a)
		return 0
	end
	ex=Expression(Any[])
	for cc in a
		push!(ex.components,cc.factors)
		push!(ex.components,:+)
	end
	deleteat!(ex.components,length(ex.components))
	return ex
end
expression(t::Term)=Expression(t.factors)
ctranspose(t::Term)=Expression(t.factors)
#ctranspose(a::Array{Term})=expression(a)
function expression(cs::Array{Components})
	if isempty(cs)
		return Expression([0])
	end
	ex=Expression(Any[])
	for cc in cs
		if cc.coef!=0
			if cc.coef!=1||isempty(cc.components) 
				push!(ex.components,cc.coef)
			end
			for c in cc.components
				push!(ex.components,c)
			end
			push!(ex.components,:+)
		end
	end
	if length(ex.components)==0
		return Expression([0])
	else
		deleteat!(ex.components,length(ex.components))
		return ex
	end
end

==(ex1::Expression,ex2::Expression)=ex1.components==ex2.components
==(ex::Expression,zero::Integer)=length(ex.components)==1&&ex.components[1]==zero
push!(ex::Expression,a)=push!(ex.components,a)
function ==(ex1::ApExpression,ex2::ApExpression)
	if length(ex1.ap)!=length(ex2.ap)
		return false
	end
	for p1 in permutations(ex1.ap)
		cont=false
		for l in 1:length(p1)
			if p1[l]!=ex2.ap[l]
				cont=true
				break
			end
		end
		if cont
			continue
		end
		return true
	end
	return false
end

N=Union(Number,Symbol)
X=Union(Number,Symbol,Component)
Ex=Union(Symbol,Component,Expression)
EX=Union(Number,Symbol,Component,Expression)

expression(x::X)=Expression([x])

push!(x::X,a)=Expression([x,a])
+(ex1::Expression,ex2::Expression)=begin;ex=deepcopy(ex1);push!(ex.components,:+);push!(ex.components,ex2);ex;end
+(ex::Expression,a::X)=begin;ex=deepcopy(ex);push!(ex.components,:+);push!(ex.components,a);ex;end
-(ex::Expression,a::X)=begin;ex=deepcopy(ex);push!(ex.components,:+);push!(ex.components,-1);push!(ex.components,a);ex;end
-(a::X,ex::Expression)=a+(-1*ex)#begin;ex=deepcopy(ex);unshift!(ex.components,:+);unshift!(ex.components,-a);unshift!(ex.components,-1);ex;end
-(ex1::Expression,ex2::Expression)=begin;ex=deepcopy(ex1);push!(ex.components,:+);push!(ex.components,-1);push!(ex.components,ex2);ex;end
+(a::X,ex::Expression)=begin;ex=deepcopy(ex);insert!(ex.components,1,:+);insert!(ex.components,1,a);ex;end
*(ex1::Expression,ex2::Expression)=Expression([deepcopy(ex1),deepcopy(ex2)])
/(ex::Ex,n::Number)=*(1/n,ex)
function *(a::X,ex::Expression)
	ex=deepcopy(ex)
	insert!(ex.components,1,a)
	ps=findin(ex.components,[:+])
	nps=length(ps)
	if nps==0
		return ex
	else
		for p in ps
			insert!(ex.components,p+1,a)
		end
		return ex
	end
end

*(a::Number,c::Component)=Expression([a,c])
*(c1::Union(Component,Symbol),c2::Union(Component,Symbol))=Expression([c1,c2])
function *(ex::Expression,x::EX)
	ap=addparse(ex)
	for t in ap
		push!(t,x)
	end
	return expression(ap)
end
-(c1::Component,c2::Component)=+(c1,-1*c2)
+(c1::Component,c2::Component)=Expression([c1,:+,c2])
+(c::Component,ex::Expression)=Expression([c,:+,ex])
+(ex::Expression,c::Component)=Expression([ex,:+,c])

+(x1::X,x2::X)=Expression([x1,:+,x2])
-(x1::X,x2::X)=Expression([x1,:+,-1,x2])
-(x::X)=Expression([-1,x])
-(ex::Expression)=-1*ex
*(x1::X,x2::X)=Expression([x1,x2])

abstract Operation <: Component

function indin(array,item)
	ind=0
	for it in array
		ind+=1
		if it==item
			return ind
		end
	end
	return 0
end
function indsin(array,item)
	ind=Int64[]
	for it in 1:length(array)
		if array[it]==item
			push!(ind,it)
		end
	end
	return ind
end
function indsin(array,typ::Type)
	ind=Int64[]
	for it in 1:length(array)
		if isa(array[it],typ)
			push!(ind,it)
		end
	end
	return ind
end
function addparse(ex::Expression)
	#ex=componify(ex)
	adds=findin(ex.components,[:+])
	nadd=length(adds)+1
	parsed=Array(Array,0)
	s=1
	for add in adds
		push!(parsed,ex.components[s:add-1])
		s=add+1
	end
	push!(parsed,ex.components[s:end])
	return parsed
end
addparse(x::X)=Array[Any[x]]
function addparse(ex::Expression,term::Bool)
	adds=findin(ex.components,[:+])
	nadd=length(adds)+1
	parsed=Array(Term,0)
	s=1
	for add in adds
		push!(parsed,Term(ex.components[s:add-1]))
		s=add+1
	end
	push!(parsed,Term(ex.components[s:end]))
	return parsed
end
addparse(x::X,term::Bool)=Array[Term([x])]
function has(term1,term2)
	if length(term1)<length(term2)
		return false
	end
	for p1 in permutations(term1)
		for p2 in permutations(term2)
			for l in 1:length(term2)
				if p1[1:l]==p2[1:l]
					return true
				end
			end
		end
	end
	return false
end
function has(ex::Expression,x::Symbol)
	for c in ex.components
		if c==x || (isa(c,Expression)&&has(c,x)) || (isa(c,Component)&&has(c,x))
			return true
		end
	end
end
has(c::Component,x::Symbol)=has(getarg(c),x)
has(n::N,x::Symbol)=n==x
function componify(ex::Expression,raw=false)
	ap=addparse(ex)
	for term in 1:length(ap)
		exs=Expression[]
		xs=X[]
		for fac in ap[term]
			if isa(fac,Array)
				push!(exs,componify(Expression(fac)))
			elseif isa(fac,Expression)
				push!(exs,componify(fac))
			elseif isa(fac,Component)
				fac.x=componify(fac.x)
				push!(xs,fac)
			else
				push!(xs,fac)
			end
		end
		if isempty(exs)
			continue
		else
			tap=addparse(exs[1])
			for x in xs
				for tterm in tap
					unshift!(tterm,x)
				end
			end
			exs[1]=expression(tap)
			while length(exs)>1
				ap1=addparse(exs[1])
				ap2=addparse(exs[2])
				lap1,lap2=length(ap1),length(ap2)
				multed=Array[]
				for l in 1:lap1*lap2
					push!(multed,Any[])
				end
				for l1 in 0:lap1-1
					for l2 in 1:lap2
						for fac in ap1[l1+1]
							push!(multed[l2+l1*lap2],fac)
						end
						for fac in ap2[l2]
							push!(multed[l2+l1*lap2],fac)
						end
					end
				end
				exs[2]=expression(multed)
				deleteat!(exs,1)
			end
			ap[term]=exs[1].components
		end
	end
	if raw 
		return ap #this was needed for previous componify, maybe remove?
	else
		return expression(ap)
	end
end
componify(c::Component)=begin;c=deepcopy(c);c.x=componify(c.x);c;end
componify(x::N)=x
function extract(ex::Expression)
	if length(ex.components)==1
		return ex.components[1]
	end
	return ex
end
include("div.jl")
include("sqrt.jl")
function simplify(ex::Expression)
	ex=deepcopy(ex)
	tex=0
	nit=0
	while tex!=ex
		tex=ex
		ex=sumsym(sumnum(componify(ex)))
		ap=addparse(ex)
		for term in 1:length(ap)
			ap[term]=divify(ap[term])
			for fac in 1:length(ap[term])
				ap[term][fac]=simplify(ap[term][fac])
			end
		end
		ex=extract(expression(ap)) #better to check if res::N before calling expression instead of extracting?
		nit+=1
		if nit>90
			warn("Stuck in simplify! Iteration #$nit: $ex")
		end
	end
	return ex 
end
#simplify!(ex::Expression)=begin;warn("simplify! is incomplete.");ex=simplify(ex);end #this doesn't really save memory...
simplify(c::Component)=begin;deepcopy(c).x=simplify(getarg(c));c;end
simplify!(c::Component)=begin;c.x=simplify!(getarg(c));c;end
simplify(x::N)=x
simplify!(x::N)=x
function simplify!(a::Array)
	if length(a)==1
		return simplify(a[1])
	else
		for i in 1:length(a)
			a[i]=simplify(a[i])
		end
	end
	return a
end
simplify(a::Array)=simplify!(deepcopy(a))
function sumnum(ex::Expression)
	if ex==0
		return 0
	end
	terms=addparse(ex)
	nterms=Array[]
	numsum=0
	for term in terms
		prod=1
		allnum=true
		nterm=Any[]
		for t in term
			if typeof(t)<:Number
				prod*=t
			else
				if allnum
					allnum=false
				end
				push!(nterm,t)				
			end
		end
		if prod==0
			continue
		elseif allnum
			numsum+=prod
			continue
		else
			if prod!=1
				unshift!(nterm,prod)
			end
			push!(nterms,nterm)
		end
	end
	if numsum!=0
		push!(nterms,[numsum])
	end
	if length(nterms)==1&&length(nterms[1])==1
		return nterms[1][1]
	else
		return expression(nterms)
	end
end
sumnum(c::Component)=setarg(c,sumnum(getarg(c)))
sumnum(x::N)=x 
function sumsym(ex::Expression)
	ap=addparse(ex)
	nap=length(ap)
	cs=Array(Components,0)
	for add in 1:nap
		tcs=Array(Ex,0)
		coef=1
		for term in ap[add]
			if isa(term,Ex)
				push!(tcs,sumsym(term))
			elseif isa(term,Number)
				coef*=term
			else			
				warn("Don't know how to handle $term")
			end
		end
		com=Components(tcs,coef)
		ind=indin(cs,com)
		if ind==0
			push!(cs,com)
		else
			cs[ind].coef+=com.coef
		end
	end
	ret=expression(cs)
	if length(ret.components)==1
		return ret.components[1]
	else
		return ret
	end
end
sumsym(c::Component)=setarg(c,sumsym(getarg(c)))
sumsym(x::N)=x
function findsyms(ex::Expression)
	syms=Set{Symbol}()
	for c in ex.components
		if isa(c,Symbol)
			push!(syms,c)
		end
	end
	return syms
end
function findsyms(ex::Expression,symdic::Dict)
	syminds=Dict()
	for k in keys(symdic)
		inds=Integer[]
		for ci in 1:length(ex.components)
			if ex.components[ci]==k
				push!(inds,ci)
			end
		end
		syminds[k]=inds
	end
	return syminds
end
findsyms(C::Component,symdic::Dict)=findsyms(getarg(c),symdic)
function findsyms(c::N,symdic::Dict) #deprecated
	syminds=Dict()
	for k in keys(symdic)
		inds=Integer[] #this double array is somehow redundant but other functions may rely on it (
		if c==k
			push!(inds,1)
		end
		syminds[k]=inds
	end
	warn("findsyms for Union(Symbol,Number) is deprecated, use has(sym1,sym2) instead.")
	return syminds
end
function hasex(symdic::Dict)
	for v in values(symdic)
		if isa(v,Ex)
			return true
		end
	end
	return false
end
function delexs(symdic::Dict)
	sd=deepcopy(symdic)
	for k in keys(symdic)
		if isa(symdic[k],Ex)
			delete!(sd,k)
		end
	end
	return sd
end
import Base.replace
function replace(ex::Expression,symdic::Dict)
	ex=deepcopy(ex)
	for c in 1:length(ex.components)
		if isa(ex.components[c],Ex)
			ex.components[c]=replace(ex.components[c],symdic)
		end
	end
	syminds=findsyms(ex,symdic)
	for tup in symdic
		sym,val=tup
		for i in syminds[sym]
			ex.components[i]=val
		end
	end
	return componify(ex)
end
replace(c::Component,symdic::Dict)=setarg(c,replace(getarg(c),symdic))
function replace(s::Symbol,symdic::Dict)
	for tup in symdic
		sym,val=tup
		if s==sym
			return val
		end
	end
	return s
end
replace(n::Number,symdic::Dict)=n
function evaluate(ex::Ex,symdic::Dict)
	ex=simplify(replace(simplify(ex),symdic))
	if isa(ex,Expression)&&hasex(symdic)
		symdic=delexs(symdic)
		ex=evaluate(ex,symdic)
	end
	return ex
end
evaluate(x::Number,symdic::Dict)=x

import Base.start, Base.next, Base.done
start(ex::Expression)=(1,addparse(ex))
function next(ex::Expression,state)
	return (state[2][state[1]],(state[1]+1,state[2]))
end
done(ex::Expression,state)=state[1]>length(state[2])