project         = "devopsrepo"
region          = "eu-central-1"
ssh_key_name    = "soutenace"
tf_state_bucket = "devopsrepo-tfstate"
tf_lock_table   = "devopsrepo-tf-locks"

# HTTPS / Route 53
certificate_arn   = "arn:aws:acm:eu-central-1:850995567750:certificate/27cd6264-9fbf-44d1-be91-381b557b04cc"
route53_zone_name = "xdev-rdv.com."
route53_record_name = "xdev-rdv.com"

