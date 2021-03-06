# frozen_string_literal: true

desc "Install required gems"
task :install do
  sh "bundle install"
end

desc "Build the TAP file"
task :tap do
  sh "bundle exec ruby yartz.rb"
end

desc "Find an emulator and try to run the TAP file"
task :run do
  sh "bundle exec zxrun yartz.tap"
end

desc "Build a music only test demo"
task :music do
  sh "bundle exec ruby music.rb"
end

desc "Build a music module suitable for the z80rb player"
task :mouvement do
  sh "bundle exec ruby mouvement.rb"
end
