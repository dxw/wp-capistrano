# Custom htaccess

Capistrano::Configuration.instance.load do
  after 'deploy:finalize_update' do
    if File.exist? 'htaccess'

      top.upload("htaccess", "#{latest_release}/finalized/.htaccess" , :via => :scp)

    else

      htaccess = <<END
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
END

      if deploy_profile.modules.include? 'wp-super-cache'
        htaccess = <<END + htaccess
# BEGIN WPSuperCache
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
AddDefaultCharset UTF-8
RewriteCond %{REQUEST_URI} !^.*[^/]$
RewriteCond %{REQUEST_URI} !^.*//.*$
RewriteCond %{REQUEST_METHOD} !POST
RewriteCond %{QUERY_STRING} !.*=.*
RewriteCond %{HTTP:Cookie} !^.*(comment_author_|wordpress|wp-postpass_).*$
RewriteCond %{HTTP:Accept-Encoding} gzip
RewriteCond %{DOCUMENT_ROOT}/wp-content/cache/supercache/%{HTTP_HOST}/$1/index.html.gz -f
RewriteRule ^(.*) /wp-content/cache/supercache/%{HTTP_HOST}/$1/index.html.gz [L]

RewriteCond %{REQUEST_URI} !^.*[^/]$
RewriteCond %{REQUEST_URI} !^.*//.*$
RewriteCond %{REQUEST_METHOD} !POST
RewriteCond %{QUERY_STRING} !.*=.*
RewriteCond %{HTTP:Cookie} !^.*(comment_author_|wordpress|wp-postpass_).*$
RewriteCond %{DOCUMENT_ROOT}/wp-content/cache/supercache/%{HTTP_HOST}/$1/index.html -f
RewriteRule ^(.*) /wp-content/cache/supercache/%{HTTP_HOST}/$1/index.html [L]
</IfModule>
# END WPSuperCache
END
      end

      put(htaccess, "#{latest_release}/finalized/.htaccess", :via => :scp)

    end

    run("chmod 755 #{latest_release}/finalized/.htaccess")

  end
end
