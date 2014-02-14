require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'

set :domain, 'peat.io'
set :deploy_to, '/var/www/peatio'
set :repository, 'https://13bb05c5c4c1459a92287cded4d66be25a939c4f@github.com/peatio/peatio.git'
set :branch, 'develop'

set :shared_paths, ['config/unicorn_peatio.sh', 'config/database.yml', 'config/application.yml', 'config/currency.yml', 'tmp', 'log']

task :environment do
  invoke :'rbenv:load'
end

task :setup => :environment do
  queue! %[mkdir -p "#{deploy_to}/shared/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/log"]

  queue! %[mkdir -p "#{deploy_to}/shared/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/config"]

  queue! %[mkdir -p "#{deploy_to}/shared/tmp"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/shared/tmp"]

  queue! %[touch "#{deploy_to}/shared/config/database.yml"]
  queue! %[touch "#{deploy_to}/shared/config/currency.yml"]
  queue! %[touch "#{deploy_to}/shared/config/application.yml"]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'

    to :launch do
      invoke :'unicorn:upgrade'
    end
  end
end

desc "Production Log"
task :prodlog => :environment do
  queue echo_cmd("cd #{deploy_to}/current && tail -f log/production.log")
end

desc "Rails Console"
task :console => :environment do
  queue echo_cmd("cd #{deploy_to}/current && RAILS_ENV=production bundle exec rails console")
end

desc "Upgrade Unicorn"
task :'unicorn:upgrade' => :environment do
  queue 'service unicorn_peatio upgrade && echo Upgrade Unicorn DONE!!!'
end

desc "Start Daemons"
task :'daemons:start' => :environment do
  queue "cd #{deploy_to}/current && RAILS_ENV=production bundle exec ./bin/rake daemons:start && echo Daemons START DONE!!!"
end

desc "Stop Daemons"
task :'daemons:stop' => :environment do
  queue "cd #{deploy_to}/current && RAILS_ENV=production bundle exec ./bin/rake daemons:stop && echo Daemons STOP DONE!!!"
end

desc "Stop Resque"
task :'resque:stop' => :environment do
  queue "kill -s QUIT `cat #{deploy_to}/current/log/resque.pid` && echo Resque STOP DONE!!!"
end

desc "Start Resque"
task :'resque:start' => :environment do
  queue "cd #{deploy_to}/current && RAILS_ENV=production PIDFILE=./log/resque.pid BACKGROUND=yes QUEUE=* bundle exec rake environment resque:work && echo Resque START DONE!!!"
end