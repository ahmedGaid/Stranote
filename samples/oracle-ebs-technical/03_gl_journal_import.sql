-- Sample work file (fictional): monthly accrual journal through GL_INTERFACE
DECLARE
  l_ccid NUMBER;
BEGIN
  l_ccid := fnd_flex_ext.get_ccid(application_short_name => 'SQLGL', key_flex_code => 'GL#',
                                  structure_number => 101, validation_date => TO_CHAR(SYSDATE, 'YYYY/MM/DD'),
                                  concatenated_segments => '01-000-2210-0000-000');
  IF l_ccid = 0 THEN
    dbms_output.put_line(fnd_flex_ext.get_message);
  END IF;

  INSERT INTO gl_interface
    (status, ledger_id, accounting_date, currency_code, date_created, created_by, actual_flag,
     user_je_category_name, user_je_source_name, code_combination_id, entered_dr, entered_cr, reference10)
  VALUES
    ('NEW', 1, LAST_DAY(SYSDATE), 'USD', SYSDATE, fnd_global.user_id, 'A',
     'Accrual', 'Spreadsheet', l_ccid, 2500, NULL, 'Acme utilities accrual');
  COMMIT;
END;
/

SELECT ledger_id, name, currency_code, period_set_name FROM gl_ledgers WHERE ledger_id = 1;

SELECT code_combination_id, segment1, segment3, enabled_flag
  FROM gl_code_combinations
 WHERE code_combination_id = :ccid;

SELECT period_name, closing_status
  FROM gl_period_statuses
 WHERE ledger_id = 1 AND application_id = 101 AND period_name = 'OCT-26';

UPDATE gl_interface SET status = 'NEW' WHERE status LIKE 'E%' AND reference10 = 'Acme utilities accrual';
