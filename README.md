Introduction
=

This project is intended as a tool for group managers and coordinators, and to provide them with accurate statistics regarding activity within Challange 22 groups.

It comprises of a script written in Ruby, which uses the Facebook Graph API to extract posts and comments from the group, perform initial processing, and then create an output which can be inserted in bulk into Elasticsearch.

We can then analyze the data and get visual insights using Kibana or any data analyzer that can fit on top of Elasticsearch.


Prerequisites 
=

* Ruby intepreter. This was tested on Ruby 2.0.0p384 (shipped with Ubuntu 14.04LTS), but I believe that more recent version will work as well:

https://www.ruby-lang.org/en/

* Elasicsearch analytics engine(Tested on 2.3.x):

https://www.elastic.co/products/elasticsearch

* Kibana data visualizer (Tested on 4.5.x):

https://www.elastic.co/products/kibana

* Any kind of unix shell with curl

Usage
=


1. Create ES mapping

Use ./mapping.sh <name> to create the appropiate index for the group(Use one index per group), for example:

./mapping.sh june1

*Important* Running mapping.sh will destroy and re-create the index if it already exists

2. Configure import_group_data.rb

Follow the instructions inside import_group_data.rb and config_template.rb for creating the configuration file. You may also use the samples inside conf_samples as references

3. Run import_group_data.rb

./import_group_data.rb <config> <access_token> > output.json

4. Import the data using elastic search bulk API

curl -s -XPOST localhost:9200/_bulk --data-binary "@output.json"; echo

5. Now the data can be visualized using Kibana :) Included inside "visualizations.json" is an export of chart object I've used with Kibana. Just make sure to modify the index name and you are all set!


