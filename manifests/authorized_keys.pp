# Class ssh::authorized_keys
#
# This class deploys authorized keys for specific users and can export/import
# the root user's public key for certain patterns ($export_root, $import_root)
#
# Parameters:
#   $authorized_keys = undef
#     hash of authorized keys to be deployed
#   $import_root = false
#     String/List of tags which might lead to imported ssh authorized keys for root user
#   $export_root = false
#     String of tag to be exported
#   $hostname = $sys11name
#     used as resource title for authorized keys, must be unique with keyname
#   $purge = false
#     Only purges root's authorized_keys.
#     Be careful, if purge == true and no keys are specified or imported,
#     /root/.ssh/authorized_keys will be empty.
#     KNOWN TO BE COMPLICATED http://projects.puppetlabs.com/issues/1581
#
# Sample Usage:
#   ssh::authorized_keys:
#     purge: true
#     export_root: makevps
#     import_root:
#       - makevps
#       - makevps2
#     authorized_keys:
#        'root_sandres':
#          key: AAAAB3NzaC1yc2EAAAABIwAAAQEA5rKU2+4WlWxSoXg22Vciq88yxxr22LdAGD8HSPjOQfDxRvdIPJ4EDu6sqesehpJdOoSvOj+lxX8YbIqORpQlqBVRV7sUdiYGTRGgb7jBuPZFTVpl/Q5mIsFuv1odWwx3A12JrniQlo2GtJ/R7v0Y9JWdYsRB5QNW8Zx6pceu/UJM66lsvvFk8N2SzZGr2TWJDOrWvkicTTTynKHF37Znn+wbRJOQEm4jYLW1IXHz/6/StD+pPcn0QMjt1t4ixxXv9F+Xo3nDpKsXd0qGbvvfzBJAC7y/0y6QT2n9xyz1qr69uyaz/WDD/sRVROyLFKBDl2CxplFN2if/Wu1QhyP9qw==
#          type: rsa
#        'root_cglaubitz':
#          key: AAAAB3NzaC1yc2EAAAABIwAAAQEA5rKU2+4WlWxSoXg22Vciq88yxxr22LdAGD8HSPjOQfDxRvdIPJ4EDu6sqesehpJdOoSvOj+lxX8YbIqORpQlqBVRV7sUdiYGTRGgb7jBuPZFTVpl/Q5mIsFuv1odWwx3A12JrniQlo2GtJ/R7v0Y9JWdYsRB5QNW8Zx6pceu/UJM66lsvvFk8N2SzZGr2TWJDOrWvkicTTTynKHF37Znn+wbRJOQEm4jYLW1IXHz/6/StD+pPcn0QMjt1t4ixxXv9F+Xo3nDpKsXd0qGbvvfzBJAC7y/0y6QT2n9xyz1qr69uyaz/WDD/sRVROyLFKBDl2CxplFN2if/Wu1QhyP9qw==
#        'root':
#          key: AAAAB3NzaC1yc2EAAAABIwAAAQEA5rKU2+4WlWxSoXg22Vciq88yxxr22LdAGD8HSPjOQfDxRvdIPJ4EDu6sqesehpJdOoSvOj+lxX8YbIqORpQlqBVRV7sUdiYGTRGgb7jBuPZFTVpl/Q5mIsFuv1odWwx3A12JrniQlo2GtJ/R7v0Y9JWdYsRB5QNW8Zx6pceu/UJM66lsvvFk8N2SzZGr2TWJDOrWvkicTTTynKHF37Znn+wbRJOQEm4jYLW1IXHz/6/StD+pPcn0QMjt1t4ixxXv9F+Xo3nDpKsXd0qGbvvfzBJAC7y/0y6QT2n9xyz1qr69uyaz/WDD/sRVROyLFKBDl2CxplFN2if/Wu1QhyP9qw==
#          ensure: absent
#
class ssh::authorized_keys (
  $authorized_keys = undef,
  $import_root = false,
  $export_root = false,
  $hostname = $sys11name,
  $purge = false, ####### Should be false, since it is possible empty roots authorized_keys ########
) {
  # define manage_authorized_keys:
  #
  # Parameters:
  #   authorized_keys
  #     Hash of hashs :-O
  #
  define manage_authorized_keys($authorized_keys) {
    if $authorized_keys[$name]['type'] {
      $key_type = $authorized_keys[$name]['type']
    } else {
      $key_type = 'rsa'
    }

    if $authorized_keys[$name]['ensure'] {
      $ensure = $authorized_keys[$name]['ensure']
    } else {
      $ensure = 'present'
    }

    if $authorized_keys[$name]['user'] {
      $user = $authorized_keys[$name]['user']
      $comment = $name
    } elsif $name =~ /^([^_]+)_(.*)$/ {
      $user = $1
      $comment = $2
    } else {
      $user = $name
      $comment = $name
    }

    ssh_authorized_key_sys11 { $name:
      ensure => $ensure,
      user   => $user,
      key    => $authorized_keys[$name]['key'],
      type   => $key_type,
      name   => $comment,
      }
  }

  # define manage_import_keys:
  #
  # Parameters:
  #   none
  #
  define manage_import_keys() {
    Ssh_authorized_key_sys11 <<| tag == "${::puppet_environment}${$name}" |>>
  }

  if $authorized_keys {
    $host_key_keys = keys($authorized_keys)
    manage_authorized_keys { $host_key_keys:
      authorized_keys => $authorized_keys,
    }
  }

  if $export_root {
    if $::root_ssh_rsa_pub_key != '' {
      $keyname = strip(values_at(split($::root_ssh_rsa_pub_key, ' '), 2))
      $keyvalue = values_at(split($::root_ssh_rsa_pub_key, ' '), 1)
      $keytype  = values_at(split($::root_ssh_rsa_pub_key, ' '), 0)
    }
    exec { 'ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N "" -q':
      creates   => '/root/.ssh/id_rsa.pub',
      logoutput => true,
      path      => '/bin:/usr/bin/',
    }

    if $keyname != '' {
      $export_root_tag = "${::puppet_environment}${export_root}"
      @@ssh_authorized_key_sys11 { "${keyname}_$hostname":
        type => $keytype,
        key  => $keyvalue,
        tag  => $export_root_tag,
        user => root,
        }
      } else {
        notify {'Created new ssh key. Re-run me to export it.':}
      }
    }

  if $import_root {
    manage_import_keys { $import_root: }
  }

  if $purge {
    resources { 'ssh_authorized_key_sys11':
      purge => true
    }
  }
}
