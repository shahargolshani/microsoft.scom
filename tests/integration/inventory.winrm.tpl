[windows]
scom_test_host ansible_host=$SCOM_HOSTNAME

[windows:vars]
ansible_user=$SCOM_USERNAME
ansible_password=$SCOM_PASSWORD
ansible_connection=winrm
ansible_winrm_transport=ntlm
ansible_winrm_server_cert_validation=ignore
ansible_port=5985

# support winrm connection tests (temporary solution, does not support testing enable/disable of pipelining)
[winrm:children]
windows

# support tests that target testhost
[testhost:children]
windows
