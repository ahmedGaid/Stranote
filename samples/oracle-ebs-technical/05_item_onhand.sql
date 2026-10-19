-- Sample work file (fictional): on-hand report for Acme finished goods, and an item update with EGO_ITEM_PUB
SELECT msi.segment1 item, msi.description, ood.organization_code, SUM(moq.transaction_quantity) onhand
  FROM mtl_system_items_b msi
  JOIN mtl_onhand_quantities_detail moq
    ON moq.inventory_item_id = msi.inventory_item_id AND moq.organization_id = msi.organization_id
  JOIN org_organization_definitions ood ON ood.organization_id = msi.organization_id
 WHERE msi.segment1 LIKE 'ACME-FG-%'
 GROUP BY msi.segment1, msi.description, ood.organization_code;

SELECT secondary_inventory_name, description
  FROM mtl_secondary_inventories
 WHERE organization_id = 207;

DECLARE
  l_items  ego_item_pub.item_tbl_type;
  l_out    ego_item_pub.item_tbl_type;
  l_status VARCHAR2(1);
  l_count  NUMBER;
BEGIN
  fnd_global.apps_initialize(1318, 20634, 401);
  l_items(1).transaction_type := 'UPDATE';
  l_items(1).segment1         := 'ACME-FG-100';
  l_items(1).organization_id  := 207;
  l_items(1).description      := 'Acme finished good 100 (new pack size)';
  ego_item_pub.process_items(p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_true,
                             p_item_tbl => l_items, x_item_tbl => l_out, x_return_status => l_status, x_msg_count => l_count);
  dbms_output.put_line('Status ' || l_status || ', messages ' || l_count);
END;
/
