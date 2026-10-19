-- Sample work file (fictional): create an organisation customer account with the TCA API
DECLARE
  l_acct  hz_cust_account_v2pub.cust_account_rec_type;
  l_org   hz_party_v2pub.organization_rec_type;
  l_prof  hz_customer_profile_v2pub.customer_profile_rec_type;
  l_cust_account_id NUMBER;
  l_account_number  VARCHAR2(30);
  l_party_id        NUMBER;
  l_party_number    VARCHAR2(30);
  l_profile_id      NUMBER;
  l_status VARCHAR2(1);
  l_count  NUMBER;
  l_msg    VARCHAR2(2000);
BEGIN
  fnd_global.apps_initialize(1318, 50559, 222);
  mo_global.init('AR');
  l_acct.account_name      := 'Acme Retail';
  l_acct.created_by_module := 'TCA_V2_API';
  l_org.organization_name  := 'Acme Retail LLC';
  l_org.created_by_module  := 'TCA_V2_API';

  hz_cust_account_v2pub.create_cust_account(p_init_msg_list => fnd_api.g_true, p_cust_account_rec => l_acct,
      p_organization_rec => l_org, p_customer_profile_rec => l_prof, p_create_profile_amt => fnd_api.g_false,
      x_cust_account_id => l_cust_account_id, x_account_number => l_account_number, x_party_id => l_party_id,
      x_party_number => l_party_number, x_profile_id => l_profile_id,
      x_return_status => l_status, x_msg_count => l_count, x_msg_data => l_msg);

  IF l_status <> 'S' THEN
    FOR i IN 1 .. l_count LOOP
      dbms_output.put_line(fnd_msg_pub.get(p_msg_index => i, p_encoded => 'F'));
    END LOOP;
  END IF;
END;
/

SELECT p.party_id, p.party_name, a.account_number, a.status
  FROM hz_parties p
  JOIN hz_cust_accounts a ON a.party_id = p.party_id
 WHERE p.party_name = 'Acme Retail LLC';
