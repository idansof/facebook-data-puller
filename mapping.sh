curl -XDELETE http://localhost:9200/etgar-$1 
curl -XPUT http://localhost:9200/etgar-$1 -d '
{
 "mappings" : {
  "_default_" : {
   "properties" : {
    "created_time" : { "type" : "date", "format" : "date_optional_time" },
    "time_to_reply" : { "type" : "double"},
	
	"from" : { 
	"properties" : 
		{"name" : { "type" : "string", "index" : "not_analyzed" } }
	}
	
    
   }
  },
  "post" : { "properties" : {"reactions" : {"type" : "nested"} } },
  "comment" : { "_parent" : {"type" : "post"}, "properties" : {    "time_to_reply" : { "type" : "double"}}},
  "subcomment" : { "_parent" : {"type" : "comment"}}
 }
}
';
