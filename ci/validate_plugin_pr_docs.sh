#!/bin/bash

bundle install
bundle exec ruby versioned_plugins.rb --repair --skip-existing --output-path=$WORKSPACE/
bundle exec ruby validate_plugin_pr_docs.rb --docs-path=../logstash-docs