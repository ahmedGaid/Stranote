-- comment line mentioning fnd_ignored.call_me should be skipped
declare
  l_rowid varchar2(30);
begin
  fnd_flex_value_rules_pkg.insert_row(x_rowid => l_rowid,
     x_flex_value_rule_id => 1);
  fnd_flex_value_rule_lines_pkg.insert_row(x_rowid => l_rowid);
  fnd_flex_value_rule_usages_pkg.insert_row(x_rowid => l_rowid);
  fnd_program.add_to_group('XXCUST_GL_RULE_UPL', 'XXCUST', 'GL Requests', 'SQLGL');
  fnd_program.executable('XXCUST_GL_RULE_UPL', 'XXCUST');
  fnd_program.register('XXCUST_GL_RULE_UPL', 'XXCUST');
  fnd_program.delete_program('OLD', 'XXCUST');
  xxcust_gl_rule_pkg.load_rules;
  insert into xxcust_gl_rule_stg (id) values (1);
  for r in (select * from fnd_flex_value_sets where flex_value_set_name = 'X') loop null; end loop;
  update fnd_flex_value_rules set description = 'x' where 1 = 2;
  delete from gl_code_combinations_tmp where 1 = 2;
  select count(*) into l_n from gl_ledgers gl join fnd_id_flex_structures s on 1 = 1;
  fnd_file.put_line(fnd_file.log, 'done');
end;
/