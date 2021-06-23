import json
import sys

from LineageExtractor import dfs_field, dfs_field_value
from util.util import print_lineage


def main(argv):
    for file in argv:
        # Open JSON ast
        with open(file) as f:
            ast = json.load(f)

        print('\nparsing: ' + str(file) + '\n')

        # match insert
        ast_insert = {}
        dfs_field(ast, 'insert_statement', ast_insert)

        # match target lineage
        ast_target = {}
        dfs_field(ast_insert, 'insert_into_clause', ast_target)
        tgt_tbl, tgt_col = extract_target(ast_target)

        # match source lineage
        ast_source = {}
        dfs_field_value(ast_insert, 'rule-path', 'select_statement', ast_source, 'source')
        src_tbl, src_col = extract_source(ast_source)

        # TODO: wrap lineage info into a nice table
        print_lineage(src_tbl, src_col, tgt_tbl, tgt_col)


# extract target lineage
def extract_target(ast):
    # get (single) target table
    lineage_target_tbl = {}
    tbl_field_val = 'general_table_ref'
    dfs_field_value(ast, 'rule-path', tbl_field_val, lineage_target_tbl, 'source')
    tgt_tbl = lineage_target_tbl['source']['regular_id'][0]['value']

    # get target columns
    raw_target_col = {}
    col_field_name = 'column_list'
    dfs_field(ast, col_field_name, raw_target_col)

    lineage_target_col = []
    if col_field_name in raw_target_col:
        for item in raw_target_col[col_field_name]:
            if 'regular_id' in item:
                lineage_target_col.append(item['regular_id'][0]['value'])

    return tgt_tbl, lineage_target_col


# extract source lineage
def extract_source(ast):
    # get source tables
    raw_source_tbl = {}
    dfs_field(ast, 'from_clause', raw_source_tbl)
    src_tbl = get_source_tbl(raw_source_tbl['from_clause'])

    # get source columns
    raw_source_col = {}
    dfs_field_value(ast, 'rule-path', 'selected_element', raw_source_col, 'source')
    src_col = get_source_col(raw_source_col['source'])
    return src_tbl, src_col


def get_source_tbl(ast):
    src_tbl = []
    if type(ast) == list:
        for item in ast:
            # multi tables
            if 'table_ref_list' in item:
                for tbl in item['table_ref_list']:
                    if 'table_ref_aux' in tbl:
                        src_tbl.append(tbl['table_ref_aux'][0]['regular_id'][0]['value'])
            # single table
            elif 'rule-path' in item and 'table_ref_list' in item['rule-path']:
                src_tbl.append(item['regular_id'][0]['value'])
    return src_tbl


def get_source_col(ast):
    src_col = []
    if 'expressions' in ast and type(ast['expressions']) == list:
        for item in ast['expressions']:
            if 'object-type' in item and 'column_name' == item['object-type']:
                src_col.append(item['regular_id'][0]['value'])
    return src_col


if __name__ == "__main__":
    main(sys.argv[1:])
