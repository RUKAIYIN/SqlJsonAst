# SqlJsonAst
SqlJsonAst is a project to parse the Abstract Syntax Tree (AST) of SQL statement in the JSON format
into raw Data Lineage information.

So far, it can parse Insert and Query statements. It can recognise difficult situations
such as concatenation, column alias and table alias.

## File Structure
In `/src` you will find the source code for the parser.

In `/resource/jsonAst` you will find the JSON ASTs used as inputs.

All jupyter Notebook files `*.ipynb` contain the preliminary experiments.

## Run
You can run the Python script separately to see how it works for different SQL statement.

- run `/src/MatchInsert.py` to parse all ASTs for Insert SQL
- run `/src/MatchQuery.py` to parse all ASTs for Query SQL
