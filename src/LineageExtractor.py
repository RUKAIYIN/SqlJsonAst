def dfs_field(ast, field_name, result):
    """
    looking for a specific field_name in the input json
    :param ast:
    :param field_name:
    :param result:
    :return: json whose only field is field_name saved in 'result'
    """
    # base
    if field_name in result:
        return

    if type(ast) == dict:
        if field_name in ast:
            result[field_name] = ast[field_name]
            return
        else:
            for key in ast.keys():
                dfs_field(ast[key], field_name, result)
    elif type(ast) == list:
        for item in ast:
            dfs_field(item, field_name, result)


def dfs_field_value(ast, field_name, field_value, result, rst_field_name):
    """
    looking for a specific field_name whose value is field_value in the input json
    :param ast:
    :param field_name:
    :param field_value:
    :param result:
    :param rst_field_name:
    :return: json whole only field is rst_field_name saved in 'result'
    """
    # base
    if rst_field_name in result:
        return

    if type(ast) == dict:
        if field_name in ast and field_value in ast[field_name]:
            result[rst_field_name] = ast
            return
        else:
            for key in ast.keys():
                dfs_field_value(ast[key], field_name, field_value, result, rst_field_name)
    elif type(ast) == list:
        for item in ast:
            dfs_field_value(item, field_name, field_value, result, rst_field_name)
