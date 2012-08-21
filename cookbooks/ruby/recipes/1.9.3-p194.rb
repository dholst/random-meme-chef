include_recipe "ruby_build"

ruby_build_ruby "1.9.3-p194" do
  action      :install
  prefix_path "/usr/local"
end

execute "bundler" do
  command "gem install bundler --no-ri --no-rdoc"
  not_if "which bundle"
end
