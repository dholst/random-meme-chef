define :rails_app do
  include_recipe "hipchat"
  include_recipe "nginx"
  include_recipe "postgresql::server"
  include_recipe "postgresql::client"
  include_recipe "imagemagick"

  env = node[:chef_environment] || node.chef_environment
  app_name = params[:name]
  home_dir = "/home/#{app_name}"
  database_credentials = Chef::DataBagItem.load(env, "database_credentials")
  app_config = Chef::DataBagItem.load("apps", app_name.to_s)
  app_environment_config = app_config["environments"][env]
  database_name = database_credentials["#{app_name}-name"]
  database_username = database_credentials["#{app_name}-username"]
  database_password = database_credentials["#{app_name}-password"]


  #-----------------------------------------------------------------------------------
  # user setup
  #-----------------------------------------------------------------------------------
  group app_name

  user app_name do
    gid app_name
    home home_dir
    shell "/bin/bash"
    supports :manage_home => true
  end

  directory "#{home_dir}/.ssh" do
    owner app_name
    group app_name
    mode 0700
  end

  cookbook_file "#{home_dir}/.ssh/known_hosts" do
    source "known_hosts"
    owner app_name
    group app_name
    mode 0600
  end


  #-----------------------------------------------------------------------------------
  # source and log directory setup
  #-----------------------------------------------------------------------------------
  directory "/var/www/#{app_name}" do
    owner app_name
    group app_name
    recursive true
  end

  directory "/var/log/www"

  %w{application stdout stderr}.each do |log|
    file "/var/log/www/#{app_name}.#{log}.log" do
      action :create_if_missing
      owner app_name
      group app_name
    end
  end


  #-----------------------------------------------------------------------------------
  # setup the unicorns
  #-----------------------------------------------------------------------------------
  template "/etc/init.d/#{app_name}" do
    source "unicorn.erb"
    owner app_name
    group app_name
    mode 0700
    variables(
      :environment => env,
      :name => app_name,
      :database_name => database_name,
      :database_username => database_username,
      :database_password => database_password
    )
  end

  service "#{app_name}" do
    action :enable
    supports [:start, :restart, :stop]
  end


  #-----------------------------------------------------------------------------------
  # nginx config
  #-----------------------------------------------------------------------------------
  template "/etc/nginx/sites-available/#{app_name}" do
    source "nginx.conf.erb"
    mode 0644
    variables(
      :name => app_name,
      :server_name => app_environment_config["server_name"]
    )
  end

  nginx_site app_name


  #---------------------------------------------------------------------
  # database setup
  #---------------------------------------------------------------------
  execute "create-database-user" do
    user "postgres"
    command "createuser -U postgres -SDRw #{database_username}"
    not_if "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='#{database_username}'\"|grep -q 1", :user => "postgres"
  end

  execute "set-database-user-password" do
    user "postgres"
    command "psql postgres -tAc \"ALTER USER #{database_username} WITH PASSWORD '#{database_password}'\""
  end

  execute "create-database" do
    user 'postgres'
    command "createdb -U postgres -O #{database_username} -E utf8 -l 'en_US.utf8' -T template0 #{database_name}"
    not_if "psql --list | grep -q randommeme", :user => "postgres"
  end

  #---------------------------------------------------------------------
  # database backup
  #---------------------------------------------------------------------
  cookbook_file "/usr/bin/aws" do
    source "aws"
    mode 0755
  end

  cookbook_file "/root/.awssecret" do
    source "awssecret"
    mode 0600
  end

  cookbook_file "/usr/local/bin/backup-postgres" do
    source "backup-postgres"
    mode 0755
  end

  cron "database backup" do
    hour 0
    minute 0
    command "/usr/local/bin/backup-postgres -f #{app_name}_#{env}.dump -d #{database_name} -u #{database_username} -w #{database_password} -t 'downtowndesmoines' -k 100"
  end

  #-----------------------------------------------------------------------------------
  # deploy key setup
  #-----------------------------------------------------------------------------------
  directory "/tmp/private_code/.ssh" do
    owner app_name
    recursive true
  end

  cookbook_file "/tmp/private_code/deploy-ssh-wrapper.sh" do
    source "deploy-ssh-wrapper.sh"
    owner app_name
    mode 0700
  end

  cookbook_file "/tmp/private_code/.ssh/id_deploy" do
    source "id_deploy"
    owner app_name
    mode 0600
  end

  #-----------------------------------------------------------------------------------
  # deploy
  #-----------------------------------------------------------------------------------
  unless node["skip_#{app_name}_deploy"]
    deploy_to = "/var/www/#{app_name}"
    shared_dir = "#{deploy_to}/shared"
    directory shared_dir

    %W{assets bundle pids sockets log index system}.each do |dir|
      directory "#{shared_dir}/#{dir}"
    end

    deploy_revision deploy_to do
      action app_environment_config["action"]
      repo app_config["repository"]
      revision app_environment_config["revision"]
      user app_name
      group app_name
      migrate false
      ssh_wrapper "/tmp/private_code/deploy-ssh-wrapper.sh"
      environment("RAILS_ENV" => env)
      shallow_clone true
      symlinks("pids" => "tmp/pids", "sockets" => "tmp/sockets", "log" => "log", "index" => "tmp/index", "system" => "public/system")
      symlink_before_migrate({})

      before_restart do
        execute "bundle install --path #{deploy_to}/shared/bundle --deployment --without development test" do
          cwd release_path
          user app_name
        end

        execute "bundle exec rake RAILS_ENV=#{env} APPLICATION_NAME=#{app_name} RAILS_GROUPS=assets assets:precompile:primary" do
          cwd release_path
          user app_name
        end

        execute "bundle exec rake RAILS_ENV=#{env} db:migrate --trace" do
          cwd release_path
          user app_name
          group app_name
          environment(
            "DATABASE_NAME" => database_name,
            "DATABASE_USERNAME" => database_username,
            "DATABASE_PASSWORD" => database_password
          )
        end
      end

      after_restart do
        #-------------------------------------------------------------
        # acts_as_index files are getting created as root on restart
        #-------------------------------------------------------------
        execute "chown -R #{app_name}:#{app_name} #{shared_dir}"
      end

      restart_command do
        execute "/etc/init.d/#{app_name} restart"
      end

      on_start do
        hipchat_message "deploying #{app_environment_config["revision"]}(#{short_release_slug}) of #{app_name} to #{env}"
      end

      on_complete do
        hipchat_message "deployed #{app_environment_config["revision"]}(#{short_release_slug}) of #{app_name} to #{env}"
      end

      on_error do
        hipchat_message "failed to deploy #{app_environment_config["revision"]}(#{short_release_slug}) of #{app_name} to #{env}" do
          color :red
          notify true
        end
      end
    end
  end
end

