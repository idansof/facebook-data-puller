puts """
facebook-data-puller configuration has the following parameters:

:group_id	This is the group ID we are trying to fetch the data from. You *must* be an administrator of the group.
		If you do not know the group ID, you may find it easily using the Graph API Explorer:
		
		https://developers.facebook.com/tools/explorer/145634995501895/?method=GET&path=me%2Fgroups&version=v2.6

		And extract the ID from the JSON

:since		Applies a time limit from which we'll fetch data. In normal groups, just set it to the group's opening day.
		For long-running groups, such as קבוצת הבוגרים, it is suggested to use the last two weeks

:es_index	facebook-data-puller generates JSON which can be then loaded into Elasticsearch via the bulk API. Since the bulk API requires
		an ES index name, it has to be specified here. Just follow the convention of 'june1', 'april3' etc

:manager	List of the group managers. This currently must be their profile ids. Ask Ruty or the current coordinator for their names.
		You can then get the list of members and their Ids from here:

		https://developers.facebook.com/tools/explorer/145634995501895/?method=GET&path=[group_id]%2Fmembers%3Flimit%3D10000&version=v2.6

		It can be used to extract id's for other parameters as well(mentor, merim etc)

		Tip: You will find their names near the bottom of the list. 

		(Replace [group_id] with the relevant group id of course)

:admin		List of staff who are always added to the group but have no specific role, coordinators, team leaders and evil dictators for life(some of them plan to make the entire world vegan. How vile of them!), People like Neta, Reut, Atar, Hagit etc. Just leave it as it is:)

:dietian	Kerem and her team of dietians. Mostly remains unchanged between cycles. 

:merim		Bar Azar and her team of minions. They demostrate to the participants how to use the group early on. Their identity is a secret, but are easy to identify. Just look for all group members added by Bar Azar and not by Tibi (Or whoever leads the צוות מרימים)

:mentor		List of mentors. Not to be confused with personal mentors(מדריך אישי). Ask Ruty to disclose her name. 

		Tip: You will find their names near the bottom of the list, but before the managers

personal_mentor	Similiar, but for personal mentors. Also include people who lead and guide inside tracks(מסלולים), as their role is similiar



"""
throw "Please remove this line from an actual configuration."

# In actual configuration, trim everything above this line



Config = {
	:group_id =>  "",
	:since => "2017-01-01",
	:es_index => "foo",
	:manager => [],
	:admin => ["10204311521040900","10152387649763766","10203245261989438","10154129110855204","10152907378215889","10152891296504662","10152789333702388","370163836488042","929563963722288","10152698338319879","10201813217632031","10152694327304931","10201068272627520","10152396284362952","10203924198090193","10152125705068182","10205525075833606","10152441051653114","10152989013587248","10205076623536409","10152992819561450","10202767650526034"],
	:dietian => ["1470505729850446","720633374626095","10152408077748210","743673725683175","10152460095598128","776123182433208"],
	:personal_mentor => [],
	:merim => [],
	:mentor => []
	

}

