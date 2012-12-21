# This package contains application-specific configuration values for the
# Instant Framework.

package ifconfig;
use Exporter;

$VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw($database $db_user $db_password $base_dir $html_base_dir 
             $site_name $mail_send_addr $org_name $use_navbar $sendmail 
             $domain $html_root_dir $output_template_dir $cgi_dir $url_base 
             $secure_url_base $if_template_dir $cookie_duration $logging 
             $mail_notify_addr $require_secure $secure_dir);

# Site setup
$base_dir = "/home/global07/www/h2arms.com"; # Install dir
$html_base_dir = "$base_dir";#/public_html";
$secure_dir = "$base_dir/protected";
$sendmail = "sendmail";

# Database login info
$database = "global07_expert";
$db_user = "global07_expert";
$db_password = '8XlS[[{3wR)v';

# Domain
$domain = "h2arms.com";
$site_name = "www." . $domain;

# Names and emails
$org_name = "h2arms.com";
$mail_send_addr = "admin\@$domain";
$mail_notify_addr = "admin\@$domain";

# Home dir (on the server)
$home_dir = $base_dir;

$use_navbar = 0; # If true, load the navbar template
$cookie_duration = "+7d"; # Duration of cookies (if "", skip cookies)

# Within this many days of subscription end, warn user (0 to disable)
$subscription_expiry_warn_days = "30"; 

# Other directory settings; usually these defaults (relative to the home_dir)
# are ok
$html_root_dir = $html_base_dir;
$output_template_dir = $html_root_dir;
$cgi_dir = "$html_root_dir/cgi-bin";
$url_base = "http://www.$domain/cgi-bin";
$secure_url_base = "https://www.$domain/cgi-bin";
$if_template_dir = "$home_dir/templates";

# Set to: "db", "stdout", or don't set
#$logging = "db";

# Require certain pages (members, admin, download) to use SSL
$require_secure = 1;

1;
