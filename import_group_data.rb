#!/usr/bin/env ruby
require 'net/http'
require 'fileutils'
require 'json'
require 'date'

POST_SEP = "="*80
if ARGV.length == 3 then
	operation = ARGV[0]
	config_name = ARGV[1]
	access_token = ARGV[2]
else 
	puts """

This tool is used to generate statistics from a facebook group, which then can be importing into elasticsearch and analyzed with tools such as Kibana.

In order for it to work, you must execute it the following:

import_group_data.rb <operation> <config> <access_token>

operation : extract/generate/both
config : The name of the configuration file, based on config_template.rb. We will automaticlly add '_conf.rb' suffix, for example 'june1_conf.rb'
access_token : A valid access token, with the user_managed_groups permission.

You may generate it from here:

https://developers.facebook.com/tools/explorer/




"""


end

require './'+config_name+"_conf"
Config[:access_token] = access_token



def members_url 
	URI("https://graph.facebook.com/v2.6/#{Config[:group_id]}/members?access_token=#{Config[:access_token]}&limit=10000")
end


def reactions_url(post_id) 
	URI("https://graph.facebook.com/v2.6/#{post_id}/likes?access_token=#{Config[:access_token]}&format=json&limit=100")
end

def comments_url(post_id) 
	URI("https://graph.facebook.com/v2.6/#{post_id}/comments?access_token=#{Config[:access_token]}&fields=id,attachment,comment_count,like_count,created_time,from,message&format=json&limit=10000")
end

def es_entry(id,type)
	{ "index" => { "_index" => Config[:es_index], "_type" => type, "_id" => id}}
end

def es_entry_parent(parent,id,type)
	{ "index" => { "_index" => Config[:es_index], "_type" => type, "_id" => id, "_parent" => parent}}
end

def feed_url() 
	URI("https://graph.facebook.com/v2.6/#{Config[:group_id]}/feed?access_token=#{Config[:access_token]}&fields=from,created_time,link,message,type&format=json&limit=1000&since=#{Config[:since]}")
end

def extract(config_name,access_token)
	members = JSON.parse(Net::HTTP.get(members_url))
	existing_members = [];
	if File.exists?("members.json") then		
		existing_members = JSON.parse(existing_members = File.new("members.json","r").read)
	end
	existing_members_hash = existing_members.map { |member|
	  [member["id"],member]
	}.to_h
	members_hash = members["data"].map { |member|
	  [member["id"],member]
	}.to_h
	
	final_members = (members_hash.keys + existing_members_hash.keys).uniq.map { |id|
		member = members_hash[id]
		existing_member = existing_members_hash[id]
		final = if existing_member.nil? then
			member
		else
			if member.nil? and existing_member["left"].nil?
				existing_member["left"] = DateTime.now.to_s
			end
			existing_member
		end
		if final["joined"].nil?
			final["joined"] = DateTime.now.to_s
		end
		if final["created_time"].nil?
			final["created_time"] = final["joined"]
		end
		final
	
	
	}
	
	File.open("members.json","w") { |f| f << JSON.pretty_generate(final_members) }
	feed = JSON.parse(Net::HTTP.get(feed_url))
	File.open("posts.json","w") { |f| 
		feed["data"].each { |post|
			post["reactions"] = reactions = JSON.parse(Net::HTTP.get(reactions_url(post["id"])))["data"]
			post["comments"]  = JSON.parse(Net::HTTP.get(comments_url(post["id"])))["data"].map { |comment|
				comment["subcomments"] = 	if comment["comment_count"] > 0 then 
							JSON.parse(Net::HTTP.get(comments_url(comment["id"])))["data"]
						else				
							subcomments = []
						end
				comment
			}
			f << JSON.pretty_generate(post)
			f << POST_SEP
		}
	}
end

def generate(config_name) 
	File.open("elastic.data","w") { |output|
		members = JSON.parse(File.new("members.json").read)
		members_map = Hash.new
		members.each { |member|
		  member["group"] = config_name
		  output.puts JSON.generate(es_entry(member["id"],"member"))
		  output.puts JSON.generate(member)
		  members_map[member["name"]] = member["id"]
		}

		types = [:manager,:dietian,:personal_mentor,:mentor,:admin,:merim]
		types.each {|type|
			Config[type].map! { |person|
				if members_map[person].nil?
				  STDERR.puts "Unknown person "+person
				  person
				else
				  members_map[person]
				end
			}
			Config[type].each { |person|
				output.puts JSON.generate(es_entry(person,type.to_s))
				output.puts JSON.generate({ :group => config_name, :id => person})
			}


		}
		
		
		File.new("posts.json").read.split(POST_SEP).map { |post| JSON.parse(post) }.each { |post|
			thread_id = post["id"]
			post["thread"] = thread_id
			post["is_member"] = true
			post["poster_type"] = "member"
			post["group"] = config_name
			post['hour'] = DateTime.parse(post['created_time']).hour
			types.each { |type|
				if Config[type].count(post["from"]["id"]) > 0 then
					post["is_"+type.to_s] = true
					post["poster_type"] = type.to_s
					post["is_member"] = false if Config[type].count(post["from"]["id"]) > 0
				end
			}
			post["reactions"].map! {
				|reaction|
					reaction["is_member"] = true
					types.each { |type|
						reaction["is_"+type.to_s] = Config[type].count(reaction["id"]) > 0
						reaction["is_member"] = false if Config[type].count(reaction["id"]) > 0
					}
					reaction
			}
			comments_json = post["comments"].map! { |comment| 
				comment["thread"] = thread_id
				comment["is_member"] = true
				comment["group"] = config_name
				comment["poster_type"] = "member"
				comment["parent"] = post["id"]
				comment['hour'] = DateTime.parse(comment['created_time']).hour
				types.each { |type|
						if Config[type].count(comment["from"]["id"]) > 0 then
							comment["is_"+type.to_s] = true
							comment["poster_type"] = type.to_s
							comment["is_member"] = false
						end
				}
				if (!post['time_to_reply'] and (comment["is_mentor"] or comment["is_manager"]))
					post['time_to_reply'] = (DateTime.parse(comment['created_time']).to_time.to_i - DateTime.parse(post['created_time']).to_time.to_i)/60.0
				end
				subcomments_json = comment["subcomments"].map {|subcomment| 
					subcomment["thread"] = thread_id
					subcomment["is_member"] = true
					subcomment["poster_type"] = "member"
					subcomment["group"] = config_name
					subcomment["parent"] = comment["id"]
					subcomment['hour'] = DateTime.parse(subcomment['created_time']).hour
					if !comment['time_to_reply'] and (subcomment["is_mentor"] or subcomment["is_manager"])
						comment['time_to_reply'] = (Date.parse(subcomment['created_time']).to_time.to_i - Date.parse(comment['created_time']).to_time.to_i)/60.0
					end
					types.each { |type|
						if Config[type].count(subcomment["from"]["id"]) > 0 then
							subcomment["is_"+type.to_s] = true
							subcomment["poster_type"] = type.to_s
							subcomment["is_member"] = false
						end
					}
					JSON.generate(es_entry_parent(comment["id"],subcomment["id"],"subcomment"))+"\n"+JSON.generate(subcomment) 
				}
				comment.delete("subcomments")
				JSON.generate(es_entry_parent(post["id"],comment["id"],"comment"))+"\n"+JSON.generate(comment)+"\n"+subcomments_json.join("\n")

			
			
			
			}
			post.delete("comment")
			output.puts JSON.generate(es_entry(post["id"],"post"))
			output.puts JSON.generate(post) 
			output.puts comments_json.join("\n").strip
		
		
		}
	}

end

outdir = config_name+"-data"	
FileUtils.mkdir_p(outdir)
Dir.chdir(outdir)


if operation == "extract" or operation == "both"
	extract(config_name,access_token);
end
if operation == "generate" or operation == "both"
	generate(config_name);
end

