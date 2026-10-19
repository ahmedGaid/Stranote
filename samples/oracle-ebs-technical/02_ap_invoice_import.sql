-- Sample work file (fictional): load a supplier invoice into the AP open interface, then run Payables Open Interface Import
INSERT INTO ap_invoices_interface
  (invoice_id, invoice_num, vendor_id, vendor_site_id, invoice_amount, invoice_currency_code,
   invoice_date, source, org_id, gl_date)
SELECT ap_invoices_interface_s.NEXTVAL, 'ACME-INV-1001', sup.vendor_id, sit.vendor_site_id, 1500, 'USD',
       SYSDATE, 'MANUAL INVOICE ENTRY', 204, SYSDATE
  FROM ap_suppliers sup
  JOIN ap_supplier_sites_all sit ON sit.vendor_id = sup.vendor_id
 WHERE sup.segment1 = '1001'
   AND sit.org_id = 204;

INSERT INTO ap_invoice_lines_interface
  (invoice_id, invoice_line_id, line_number, line_type_lookup_code, amount, dist_code_combination_id)
VALUES
  (ap_invoices_interface_s.CURRVAL, ap_invoice_lines_interface_s.NEXTVAL, 1, 'ITEM', 1500, 13185);
COMMIT;

-- after the import: rejected rows
SELECT r.parent_table, r.reject_lookup_code
  FROM ap_interface_rejections r
  JOIN ap_invoices_interface i ON i.invoice_id = r.parent_id
 WHERE i.invoice_num = 'ACME-INV-1001';

-- imported invoice
SELECT invoice_id, invoice_num, approval_status, wfapproval_status
  FROM ap_invoices_all
 WHERE invoice_num = 'ACME-INV-1001';

BEGIN
  mo_global.set_policy_context('S', 204);
  dbms_output.put_line(ap_invoices_pkg.get_approval_status(p_invoice_id => :invoice_id,
                                                          p_invoice_amount => 1500,
                                                          p_payment_status_flag => 'N',
                                                          p_invoice_type_lookup_code => 'STANDARD'));
END;
/
