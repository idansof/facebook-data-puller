require 'net/http'
require 'json'
require 'date'

require './'+ARGV[0]+"_conf"


Config[:access_token] = ARGV[1]



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


feed_url =  URI("https://graph.facebook.com/v2.6/#{Config[:group_id]}/feed?access_token=#{Config[:access_token]}&fields=from,created_time,link,message,type&format=json&limit=1000&since=#{Config[:since]}")
types = [:manager,:dietian,:personal_mentor,:mentor,:admin,:merim]

types.each {|type|
	Config[type].each { |person|
		puts JSON.generate(es_entry(person,type.to_s))
		puts JSON.generate({ :id => person})
	}


}
feed = JSON.parse(Net::HTTP.get(feed_url))
feed["data"].each { |post|
	post["reactions"] = reactions = JSON.parse(Net::HTTP.get(reactions_url(post["id"])))["data"].map {
		|reaction|
			reaction["is_member"] = true
			types.each { |type|
				reaction["is_"+type.to_s] = Config[type].count(reaction["id"]) > 0
				reaction["is_member"] = false if Config[type].count(reaction["id"]) > 0
			}
			reaction
	}
	post["is_member"] = true
	post["poster_type"] = "member"
	post['hour'] = DateTime.parse(post['created_time']).hour
	types.each { |type|
		if Config[type].count(post["from"]["id"]) > 0 then
			post["is_"+type.to_s] = true
			post["poster_type"] = type.to_s
			post["is_member"] = false if Config[type].count(post["from"]["id"]) > 0
		end
	}
	
	comments = JSON.parse(Net::HTTP.get(comments_url(post["id"])))
	comments_json = comments["data"].map { |comment|
		comment["is_member"] = true
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
		
		#subcomments = JSON.parse(Net::HTTP.get(comments_url(comment["id"])))
		subcomments = { "data" => [] }
#		
		subcomments_json = subcomments["data"].map { |subcomment|
			subcomment["is_member"] = true
			subcomment["poster_type"] = "member"
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
		

		JSON.generate(es_entry_parent(post["id"],comment["id"],"comment"))+"\n"+JSON.generate(comment)+"\n"+subcomments_json.join("\n")
	
#	
	}
	puts JSON.generate(es_entry(post["id"],"post"))
	puts JSON.generate(post) 
	puts comments_json.join("\n").strip
	sleep(2)


}



