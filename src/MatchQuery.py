import json
import sys
import os

from LineageExtractor import dfs_field, dfs_field_value
from util.util import print_lineage, print_lineage_in_json, merge_json

# global variables

# result lineage info
lineage_source = {}


def main(argv):
    path = '../source/jsonAst/query'
    for file in os.listdir(path):
        if 'json' in file:
            print('\nProcessing ' + str(file))
            with open(os.path.join(path, file)) as f:
                ast = json.load(f)
                match_query(ast)
    # with open(os.path.join(path, 'plsql_alias_table1.json')) as f:
    #     ast = json.load(f)
    #     match_query(ast)


def match_query(ast):
    # match query
    ast_query = {}
    dfs_field(ast, 'query_block', ast_query)
    # ast_query = { 'query_block': [...] }

    # match source lineage
    src_tbl, src_col = extract_source_single_table(ast_query['query_block'])

    # match target lineage
    # nothing

    if src_tbl and len(src_tbl) > 0:
        print_lineage(src_tbl, src_col, None, None)
    else:
        print_lineage_in_json(lineage_source, None)


def save_table_aliases(ast):
    table_aliases = {}
    _aliases = {}
    if type(ast) == list:
        for item in ast:
            if 'table_ref_aux' in item:
                table_aliases = get_table_alias_from_json_part(item['table_ref_aux'], table_aliases)
            elif 'join_clause' in item:
                _aliases = save_table_aliases(item['join_clause'])

    table_aliases = merge_json(table_aliases, _aliases)
    return table_aliases


def get_table_alias_from_json_part(ast, table_aliases):
    table_alias = ''
    table_name = ''
    if type(ast) == list:
        for item in ast:
            if 'object-type' in item:
                value = item['regular_id'][0]['value']
                if item['object-type'] == 'tableview_name':
                    table_name = value
                elif item['object-type'] == 'table_alias':
                    table_alias = value
    table_aliases[table_alias] = table_name
    return table_aliases


def get_src_tbl(ast):
    # ast = { 'source': {...} }
    ast_tbl = ast['source']
    if len(ast_tbl) > 1 and 'table_ref' in ast_tbl:
        # record table
        table_aliases = save_table_aliases(ast_tbl['table_ref'])
        return table_aliases, ''
    return {}, ast_tbl['regular_id'][0]['value']


def get_src_col(ast, col):
    # match {"object-type" : "column_name"}
    if type(ast) == list:
        for item in ast:
            get_src_col(item, col)
    elif type(ast) == dict:
        if 'object-type' in ast and ast['object-type'] == 'column_name':
            col.append(ast['regular_id'][0]['value'])
        else:
            for key in ast.keys():
                get_src_col(ast[key], col)


def get_src_col_check_alias(ast, col, table_aliases):
    has_alias = False

    if type(ast) == list:
        for item in ast:
            if 'select_list_elements' in item:
                has_alias = True
                get_src_col_alias(item['select_list_elements'], table_aliases)

    if not has_alias:
        get_src_col(ast, col)


def get_src_col_alias(ast, table_aliases):
    src_tbl = ''
    src_col = []
    if type(ast) == list:
        for item in ast:
            if 'object-type' in item:
                val = item['regular_id'][0]['value']
                if item['object-type'] == 'table_alias_ref':
                    src_tbl = table_aliases[val]
                elif item['object-type'] == 'column_name':
                    src_col.append(val)

    if src_tbl in lineage_source:
        for col in src_col:
            # maybe change it to a set?
            if col not in lineage_source[src_tbl]:
                lineage_source[src_tbl].append(col)
    else:
        lineage_source[src_tbl] = src_col


def extract_source_single_table(ast):
    # match source table
    raw_src_tbl = {}
    dfs_field_value(ast, 'rule-path', 'table_ref_list', raw_src_tbl, 'source')
    table_aliases, src_tbl = get_src_tbl(raw_src_tbl)

    # match source columns
    src_col = []
    for item in ast:
        if 'selected_element' in item:
            get_src_col_check_alias(item['selected_element'], src_col, table_aliases)

    return src_tbl, src_col


if __name__ == "__main__":
    main(sys.argv[1:])
