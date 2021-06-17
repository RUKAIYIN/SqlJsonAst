import json
import sys
import os

from LineageExtractor import dfs_field, dfs_field_value
from util.LineagePrinter import print_lineage


def main(argv):
    path = '../source/jsonAst/query'
    for file in os.listdir(path):
        if 'json' in file:
            print('\nProcessing ' + str(file))
            with open(os.path.join(path, file)) as f:
                ast = json.load(f)
                match_query(ast)


def match_query(ast):
    # match query
    ast_query = {}
    dfs_field(ast, 'query_block', ast_query)
    # ast_query = { 'query_block': [...] }

    # match source lineage
    src_tbl, src_col = extract_source_single_table(ast_query['query_block'])

    # match target lineage
    # nothing

    print_lineage(src_tbl, src_col, None, None)


def get_src_tbl(ast):
    # ast = { 'source': {...} }
    return ast['source']['regular_id'][0]['value']


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


def extract_source_single_table(ast):
    # match source table
    raw_src_tbl = {}
    dfs_field_value(ast, 'rule-path', 'table_ref_list', raw_src_tbl, 'source')
    src_tbl = get_src_tbl(raw_src_tbl)

    # match source columns
    src_col = []
    for item in ast:
        if 'selected_element' in item:
            get_src_col(item, src_col)

    return src_tbl, src_col


if __name__ == "__main__":
    main(sys.argv[1:])
