### A Pluto.jl notebook ###
# v0.11.14

using Markdown
using InteractiveUtils

# ╔═╡ 05130950-fe0d-11ea-3939-f58e496cd72a
begin
	import Pkg
	Pkg.add("CSV")	
	Pkg.add("DataFrames")
	Pkg.add("DataStructures")
	using CSV
	using DataFrames
	using DataStructures
# 	Pkg.add("Missings")
# 	Pkg.add("TextAnalysis")
# 	using Missings
# 	using TextAnalysis
	
end

# ╔═╡ fc47140e-ff8f-11ea-1cd1-9b0d5e19f136
"""
	TODOs
	* implement indexing multiple fields
	* implement BM25 
	* look for examples where TFIDF fails
"""

# ╔═╡ 2757f1d0-fe0d-11ea-1095-81a7865d17a5
df = DataFrame(CSV.File("20200909_gini_articles.csv"))

# ╔═╡ 18141ea8-ff8a-11ea-01b5-eb97762cb538
df[1,:]

# ╔═╡ 6300f12c-fe11-11ea-3aaa-4353ea11c5e1
# TextAnalysis package SUCKS
# OBJECTIVE: write your own fast multifield TFIDF search engine with boosting!

# ╔═╡ 0794d5fe-fef4-11ea-2ed9-59d9fdd7a2e8
function applyfilters(text)
	nospecial = replace(text, r"[^a-zA-Z0-9]" => " ")	
	lowercase(nospecial)
end

# ╔═╡ 8014c6a2-fe0d-11ea-0155-abfd36386965
function tokenize(texts)
	"""Tokenize text with the ff filters
		
		- removal of special characters
		- lowercase
	"""
	tokenized = []
	for t in texts					
		push!(tokenized, split(applyfilters(t)))
	end
	tokenized
end

# ╔═╡ 50bdeca2-fe0e-11ea-13bb-97a7ff037715
tokenize(df["title"])

# ╔═╡ 15088036-ff86-11ea-3379-7b5c80cc36e4
struct Posting 
	index::Int64
	term_frequency::Float64
end

# ╔═╡ e77ce35c-fede-11ea-0519-bf0a24a63f8c
mutable struct Term
	# docIDs where the term appears
	postings::Array{Posting}
	# inverse document frequency
	idf::Float64
end

# ╔═╡ c307b2a8-fedf-11ea-0eea-556c6fda1e13
function build_index(docs)::OrderedDict
	"""Builds the index
	"""
	index = OrderedDict()
	tokenized = tokenize(docs)
	# generate postings
	for (idx, doc) in enumerate(tokenized)
		doccounts = Dict()
		# create the count dict
		for token in doc
			if token in keys(doccounts)
				doccounts[token] += 1
			else
				doccounts[token] = 1
			end
		end
		# create a posting
		for (token, count) in doccounts		
			posting = Posting(idx, count / length(doc))			
			if token in keys(index)		
				term = index[token]
				push!(term.postings, posting)			
			else
				index[token] = Term([posting], 0)
			end
		end
	end
	# calculate IDF
	for token in keys(index)
		term = index[token]
		term.idf = log(length(docs) / length(term.postings))
		sort!(term.postings, by=x->x.term_frequency,rev=true)
	end
	sort!(index)
end

# ╔═╡ ac36bae4-ffd2-11ea-3d4d-9373d3298e79
function build_bm25f_index(docs)::OrderedDict
	"""Builds the index
	"""
	k1 = 1.2
	# NOTE: determining b per-field is super cool since we can control for 
	# really short documents e.g. titles
	b = 0.75
	index = OrderedDict()
	tokenized = tokenize(docs)
	avdl = sum([length(d) for d in tokenized]) / length(tokenized)
	sprint(show, avdl)
	# iterate through the documents, generating posts
	for (idx, doc) in enumerate(tokenized)
		doccounts = Dict()
		# create the count dict
		for token in doc
			if token in keys(doccounts)
				doccounts[token] += 1
			else
				doccounts[token] = 1
			end
		end
		# create a posting
		for (token, count) in doccounts
			tf = count / (1 + b * ((length(doc) / avdl) - 1))
			posting = Posting(idx, tf)			
			if token in keys(index)		
				term = index[token]
				push!(term.postings, posting)			
			else
				index[token] = Term([posting], 0)
			end
		end
	end
	# only then calculate IDF
	for token in keys(index)
		term = index[token]
		term.idf = log(length(docs) / length(term.postings))
		sort!(term.postings, by=x->x.term_frequency,rev=true)
	end
	sort!(index)
end

# ╔═╡ 5ff97b9a-fef0-11ea-0cd6-c5b679f76528
begin
	titleIdx = build_index(df["title"])
end

# ╔═╡ c0775930-ffd4-11ea-2f2e-050d59dcf096
begin
	titleIdxbm25 = build_bm25f_index(df["title"])
end

# ╔═╡ beb4a530-ff84-11ea-072e-9d53334ca9f5
begin
	entry = titleIdx["covid"]
	entry, length(entry.postings)
end

# ╔═╡ ac6e5e2c-fee2-11ea-0b75-3d438a95fa4e
# TODO: try this query
query = "covid flu"

# ╔═╡ 3128a900-ff8b-11ea-10d5-8bea5264d2a0
begin
	k = 3
	a = [1,3,5]
	a[1:k]
end

# ╔═╡ 2b6db0ec-ff8d-11ea-01b5-81cdafdfed97
sprint(show, "wow")

# ╔═╡ f5bdcd54-fef3-11ea-270f-bba8297bb0c0
function search(query::String, k::Int64=10)
	candidates = OrderedDict()
	println("wow")
	# TODO: check implementation
	# for each search term, look for the best matching document in the corpus
	for queryterm in split(applyfilters(query))
		if queryterm in keys(titleIdx)
			term = titleIdx[queryterm]
			for posting in term.postings
				tfidf = posting.term_frequency * term.idf
				if posting.index in keys(candidates)
					candidates[posting.index] += tfidf
				else
					candidates[posting.index] = tfidf
				end				  
			end
		else
			# handle OOV
		end
	end
	num_cands = length(keys(candidates))
	if k > num_cands
		k = num_cands
	end
	top_k = sort!([(df[i,:].title, v) for (i, v) in candidates], by=x->x[2], rev=true)[1:k]
end

# ╔═╡ 2fe2edb0-ffd6-11ea-3923-2386e6bcf006
mutable struct Candidate
	tfidf::Float64
	match_count::Int64
end

# ╔═╡ 6332cb2c-ffd4-11ea-01a0-d59b8de7d048
function bm25f_search(query::String, k::Int64=10)
	# temporarily: put boosting here
	boost = 1
	k1 = 1.2
	# Idea: perhaps a candidate can have another boost based on how many fields matched
	candidates = OrderedDict()
	# for each search term, look for the best matching document in the corpus
	for queryterm in split(applyfilters(query))
		if queryterm in keys(titleIdxbm25)
			term = titleIdx[queryterm]
			for posting in term.postings
				# apply search-time boosting like elasticsearch
				tf = boost * posting.term_frequency
				tfidf = (tf / (tf + k1)) * term.idf
				if posting.index in keys(candidates)
					candidate = candidates[posting.index] 
					candidate.tfidf += tfidf
					candidate.match_count += 1
				else
					candidates[posting.index] = Candidate(tfidf, 1)
				end				  
			end
		else
			# handle OOV
		end
	end
	num_cands = length(keys(candidates))
	if k > num_cands
		k = num_cands
	end
	# num match boosting
	for candidate in values(candidates)
		candidate.tfidf = candidate.match_count * candidate.tfidf
	end
	top_k = sort!([(df[i,:].title, v) for (i, v) in candidates], by=x->x[2].tfidf, rev=true)[1:k]
end

# ╔═╡ 234e3b54-ff8b-11ea-3fe5-e50bb8ecdf75
# interesting terms for BM25 example: covid artificial intelligence - the one with both is on index 38
# search("covid artificial intelligence", 100)
search("covid flu", 100)

# ╔═╡ 032e3e74-ffd5-11ea-2b6d-479eab47d0d1
bm25f_search("covid flu", 100)

# ╔═╡ f26774d4-ffd4-11ea-3784-d7bc1eab9cb5


# ╔═╡ b184689a-fee0-11ea-1cba-b51c021e0389
# begin
# 	docs = df["title"]
# 	d2f = docs2freqs(docs)
# 	# TODO: try SortedDict
# 	SortedDict("dict"=> d2f, "vocabsize"=> length(keys(d2f)), "numdocs"=> length(docs), o=x -> )
# end

# ╔═╡ Cell order:
# ╠═fc47140e-ff8f-11ea-1cd1-9b0d5e19f136
# ╠═05130950-fe0d-11ea-3939-f58e496cd72a
# ╠═2757f1d0-fe0d-11ea-1095-81a7865d17a5
# ╠═18141ea8-ff8a-11ea-01b5-eb97762cb538
# ╠═6300f12c-fe11-11ea-3aaa-4353ea11c5e1
# ╠═0794d5fe-fef4-11ea-2ed9-59d9fdd7a2e8
# ╠═8014c6a2-fe0d-11ea-0155-abfd36386965
# ╠═50bdeca2-fe0e-11ea-13bb-97a7ff037715
# ╠═15088036-ff86-11ea-3379-7b5c80cc36e4
# ╠═e77ce35c-fede-11ea-0519-bf0a24a63f8c
# ╠═c307b2a8-fedf-11ea-0eea-556c6fda1e13
# ╠═ac36bae4-ffd2-11ea-3d4d-9373d3298e79
# ╠═5ff97b9a-fef0-11ea-0cd6-c5b679f76528
# ╠═c0775930-ffd4-11ea-2f2e-050d59dcf096
# ╠═beb4a530-ff84-11ea-072e-9d53334ca9f5
# ╠═ac6e5e2c-fee2-11ea-0b75-3d438a95fa4e
# ╠═3128a900-ff8b-11ea-10d5-8bea5264d2a0
# ╠═2b6db0ec-ff8d-11ea-01b5-81cdafdfed97
# ╠═f5bdcd54-fef3-11ea-270f-bba8297bb0c0
# ╠═2fe2edb0-ffd6-11ea-3923-2386e6bcf006
# ╠═6332cb2c-ffd4-11ea-01a0-d59b8de7d048
# ╠═234e3b54-ff8b-11ea-3fe5-e50bb8ecdf75
# ╠═032e3e74-ffd5-11ea-2b6d-479eab47d0d1
# ╠═f26774d4-ffd4-11ea-3784-d7bc1eab9cb5
# ╠═b184689a-fee0-11ea-1cba-b51c021e0389
