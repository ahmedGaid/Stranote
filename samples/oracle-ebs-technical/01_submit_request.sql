-- Sample work file (fictional): submit the "Acme Daily Sales" concurrent program from PL/SQL and wait for it
DECLARE
  l_user_id   NUMBER;
  l_resp_id   NUMBER;
  l_appl_id   NUMBER;
  l_request_id NUMBER;
  l_phase     VARCHAR2(80);
  l_status    VARCHAR2(80);
  l_dev_phase VARCHAR2(30);
  l_dev_status VARCHAR2(30);
  l_message   VARCHAR2(2000);
  l_ok        BOOLEAN;
BEGIN
  SELECT user_id INTO l_user_id FROM fnd_user WHERE user_name = 'SYSADMIN';
  SELECT responsibility_id, application_id
    INTO l_resp_id, l_appl_id
    FROM fnd_responsibility_vl
   WHERE responsibility_name = 'Order Management Super User';

  fnd_global.apps_initialize(user_id => l_user_id, resp_id => l_resp_id, resp_appl_id => l_appl_id);
  mo_global.set_policy_context('S', 204);

  l_request_id := fnd_request.submit_request(application => 'ONT', program => 'ACME_DAILY_SALES',
                                             description => NULL, start_time => NULL, sub_request => FALSE,
                                             argument1 => TO_CHAR(SYSDATE, 'YYYY/MM/DD'));
  COMMIT;

  l_ok := fnd_concurrent.wait_for_request(request_id => l_request_id, interval => 10, max_wait => 600,
                                          phase => l_phase, status => l_status, dev_phase => l_dev_phase,
                                          dev_status => l_dev_status, message => l_message);
  dbms_output.put_line('Request ' || l_request_id || ' ended ' || l_dev_phase || '/' || l_dev_status);
END;
/

SELECT request_id, phase_code, status_code, actual_start_date, actual_completion_date
  FROM fnd_concurrent_requests
 WHERE request_id = :request_id;
