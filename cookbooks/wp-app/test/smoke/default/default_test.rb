# # encoding: utf-8

# Inspec test for recipe wp-app::default

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

unless os.windows?
  # This is an example test, replace with your own test.
  describe user('root'), :skip do
    it { should exist }
  end
end

# This is an example test, replace it with your own test.
describe port(80), :skip do
  it { should_not be_listening }
end

ENV['EC2_ENDPOINT'] = 'localhost'
ENV['USER'] = 'wordpressuser'
ENV['PASSWORD'] = 'Drowssap1!'
describe command("curl -v --data \"log=${USER}&pwd=${PASSWORD}&wp-submit=Log+In&testcookie=1\" \
  --cookie 'wordpress_test_cookie=WP+Cookie+check' http://$EC2_ENDPOINT/wp-login.php 2>&1 | cat") do
    its('stdout') { should match (/.*wordpress_logged_in.*/) }
end

