import json


def print_lineage(src_tbl, src_col, tgt_tbl, tgt_col):
    print('Source table: ' + str(src_tbl))
    print('Source columns: ' + str(src_col))
    print('Target table: ' + str(tgt_tbl))
    print('Target columns: ' + str(tgt_col))


def print_lineage_in_json(source_json, source_target):
    print('Source:')
    print(json.dumps(source_json, indent=4, sort_keys=True))
    print('\nTarget:')
    print(json.dumps(source_target, indent=4, sort_keys=True))


def merge_json(json1, json2):
    """
    merge json1 and json2 into json1,
    provided no same keys between them
    :param json1:
    :param json2:
    :return:
    """
    if json2:
        for key in json2.keys():
            json1[key] = json2[key]

    return json1
