<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:g="urn:language:sql:grammar"
    xmlns:c="urn:language:sql:comment" xmlns:t="urn:language:sql:token"
    xmlns:l="urn:language:sql:lineage" xmlns:fn="urn:language:sql:functions"
    xmlns:m="urn:git:metadata" xmlns="urn:language:sql:lineage" exclude-result-prefixes="xs fn"
    version="3.0">
    <!-- processing -->
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- params -->
    <xsl:param name="table-index-uri"/>
    <!-- imports -->
    <!-- variables -->
    <xsl:variable name="table-defs" select="doc($table-index-uri)//l:tables"/>
    <!--
        Match procedure
      -->
    <xsl:template match="g:create_procedure_body">
        <xsl:variable name="procedure-name" select="g:regular_id//t:*"/>
        <procedure name="{lower-case($procedure-name)}" file-path="{/g:sql/@path}">
            <xsl:apply-templates select="/g:sql/m:*" mode="include-meta"/>
            <steps>
                <xsl:apply-templates select="g:body | c:MULTI_LINE_COMMENT"/>
            </steps>
        </procedure>
    </xsl:template>
    <!--
        Match procedure
      -->
    <xsl:template match="g:create_procedure_body[g:delimited_id]">
        <xsl:variable name="procedure-name" select="replace(g:delimited_id//t:*, '&quot;', '')"/>
        <procedure name="{lower-case($procedure-name)}" file-path="{/g:sql/@path}">
            <xsl:apply-templates select="g:body"/>
        </procedure>
    </xsl:template>
    
    <xsl:template match="g:execute_immediate">
        <execute_immediate>
            <xsl:apply-templates mode="plain-text"/>
        </execute_immediate>
    </xsl:template>
    <xsl:template match="c:WS" mode="plain-text">
        <xsl:value-of select="replace(replace(.,'n','&#10;'),'_',' ')"/>
    </xsl:template>
    <xsl:template match="element()" mode="plain-text">
        <xsl:apply-templates mode="plain-text"/>
    </xsl:template>
    <xsl:template match="text()" mode="plain-text">
        <xsl:value-of select="."/>
    </xsl:template>
    
    
    <!--
        Match insert
      -->
    <xsl:template match="g:insert_statement">
        <xsl:variable name="into-clause" select="g:single_table_insert/g:insert_into_clause"/>
        <xsl:variable name="target-table" select="lower-case($into-clause/g:regular_id//t:*)"/>
        <xsl:variable name="target-table-def"
            select="$table-defs/l:table[@name = $target-table]/l:*"/>
        <xsl:variable name="top-level-select" select="g:single_table_insert//g:query_block[1]"/>
        <xsl:variable name="source">
            <xsl:apply-templates select="$top-level-select/g:*" mode="gather-lineage"/>
        </xsl:variable>
        <xsl:variable name="col-list" as="node()*">
            <xsl:apply-templates select="$into-clause//g:column_list" mode="gather-lineage"/>
        </xsl:variable>
        <xsl:variable name="used-col-def">
            <xsl:choose>
                <xsl:when test="$col-list">
                    <columns defined="explicit">
                        <xsl:for-each select="$col-list/l:column_name">
                            <column name="{.}"/>
                        </xsl:for-each>
                    </columns>
                </xsl:when>
                <xsl:otherwise>
                    <columns defined="implicit">
                        <xsl:for-each select="$target-table-def/l:column">
                            <column name="{@name}"/>
                        </xsl:for-each>
                    </columns>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- output lineage, target and source-->
        <insert target-table="{$target-table}">
            <xsl:variable name="s" select="$used-col-def/l:columns/l:column" as="node()*"/>
            <xsl:variable name="t" select="$source/l:expressions/l:*" as="node()*"/>
            <lineage num-cols-source="{count($s)}" num-cols-target="{count($t)}">
                <xsl:sequence select="for-each-pair($s, $t, fn:pair-source-target#2)"/>
            </lineage>
            <target>
                <xsl:sequence select="$used-col-def"/>
                <defined-in-ddl-as>
                    <xsl:sequence select="$target-table-def"/>
                </defined-in-ddl-as>
            </target>
            <source>
                <xsl:sequence select="$source"/>
            </source>
        </insert>
    </xsl:template>
    
    
    <xsl:function name="fn:pair-source-target">
        <xsl:param name="source"/>
        <xsl:param name="target"/>
        <column-lineage target-column="{$source/@name}">
            <xsl:apply-templates select="$target" mode="strip-non-general-element"/>
        </column-lineage>
    </xsl:function>
    <xsl:template match="element()|@*" mode="strip-non-general-element">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <xsl:template match="text()" mode="strip-non-general-element"/>
    <xsl:template match="l:general_element_part" mode="strip-non-general-element">
        <source-column>
            <xsl:copy-of select="l:* except l:t"/>
        </source-column>
    </xsl:template>
    <xsl:template match="l:column_name[not(ancestor::l:general_element_part)]" mode="strip-non-general-element">
        <source-column>
            <xsl:value-of select="."/>
        </source-column>
    </xsl:template>
    
    <!--
        Match update
      -->
    <xsl:template match="g:update_statement">
        <xsl:variable name="target-table"
            select="
                (
                g:general_table_ref/g:regular_id[1]//t:*,
                g:regular_id//t:*
                )[1]"/>
        <update target-table="{lower-case($target-table)}">
            <xsl:apply-templates select="g:update_set_clause" mode="gather-lineage"/>
        </update>
    </xsl:template>
    <!--
        Match merge
      -->
    <xsl:template match="g:merge_statement">
        <xsl:variable name="target-table"
            select="
                (
                g:merge_target/g:query_block/g:from_clause//g:regular_id[1]/t:*,
                g:merge_target/g:regular_id[1]//t:*,
                g:regular_id[1]//t:*
                )[1]"/>
        <xsl:variable name="target-table-def"
            select="$table-defs/l:table[@name = $target-table]/l:*"/>
        <merge target-table="{lower-case($target-table)}">
            <target>
                <xsl:apply-templates select="g:merge_target" mode="gather-lineage"/>
                <defined-in-ddl-as>
                    <xsl:copy-of select="$target-table-def"/>
                </defined-in-ddl-as>
            </target>
            <source>
                <xsl:apply-templates select="g:merge_update_clause" mode="gather-lineage"/>
                <xsl:apply-templates select="g:merge_insert_clause" mode="gather-lineage"/>
            </source>
        </merge>
    </xsl:template>
    <!--
        Match delete
      -->
    <xsl:template match="g:delete_statement">
        <xsl:variable name="target-table"
            select="
                (
                g:regular_id[1]//t:*,
                g:general_table_ref//g:regular_id[1]/t:*
                )[1]"/>
        <delete target-table="{lower-case($target-table)}">
            <xsl:apply-templates select="." mode="gather-lineage"/>
        </delete>
    </xsl:template>

    <!-- mode = gather-lineage -->
    <xsl:template match="g:*" mode="gather-lineage">
        <xsl:element name="{local-name(.)}">
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="@* | node()" mode="gather-lineage">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="g:regular_id[@object-type = 'table_alias_ref']" mode="gather-lineage" priority="10">
        <xsl:variable name="alias" select="lower-case(t:*)"/>
        <xsl:variable name="ultimate" select="fn:find-table-name-from-alias(.,$alias)"/>
        <xsl:choose>
            <xsl:when test="$ultimate">
                <table_name table_alias_ref="{$alias}">
                    <xsl:value-of select="$ultimate"/>
                </table_name>
            </xsl:when>
            <xsl:otherwise>
                <table_name>
                    <xsl:value-of select="$alias"/>
                </table_name>
            </xsl:otherwise>
        </xsl:choose>

    </xsl:template>
    <xsl:function name="fn:find-table-name-from-alias" as="xs:string">
        <xsl:param name="current-node"/>
        <xsl:param name="alias"/>
        <xsl:variable name="table-defintion" select="$current-node/ancestor::g:*/g:from_clause//g:table_ref_aux[g:regular_id[@object-type = 'table_alias' and string(t:*) = $alias]][1]"/>
        <xsl:value-of select="$table-defintion/g:regular_id[@object-type='tableview_name']/t:*"/>
    </xsl:function>
    <xsl:template match="g:regular_id[@object-type]" mode="gather-lineage">
        <xsl:variable name="object-type"
            select="
                if (string-length(@object-type) gt 0) then
                    @object-type
                else
                    'unknown'"/>
        <xsl:element name="{@object-type}">
            <xsl:value-of select="lower-case(t:*)"/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="c:*" mode="gather-lineage"/>
    <xsl:template match="t:*[not(parent::g:regular_id)]" mode="gather-lineage">
        <t>
            <xsl:value-of select="."/>
        </t>
    </xsl:template>
    <xsl:template match="g:order_by_clause" mode="gather-lineage"/>
    <xsl:template match="g:where_clause" mode="gather-lineage"/>
    <xsl:template match="g:group_by_clause" mode="gather-lineage"/>
    <xsl:template match="g:join_on_part" mode="gather-lineage"/>
    <xsl:template match="g:outer_join_type" mode="gather-lineage"/>
    <xsl:template match="g:selector" mode="gather-lineage">
        <selector>
            <xsl:value-of select="."/>
        </selector>
    </xsl:template>
    <!-- remove comma's -->
    <xsl:template match="g:expressions/t:COMMA" mode="gather-lineage" priority="1"/>

    <xsl:template match="@rule-path" mode="gather-lineage"/>
    <xsl:template match="g:*[count(element()) = 1 and local-name(.) eq lower-case(t:*)]"
        mode="gather-lineage">
        <t>
            <xsl:value-of select="t:*"/>
        </t>
    </xsl:template>
    <xsl:template match="g:logical_expression" mode="gather-lineage">
        <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:template>


    <!--
        Match Calls
      -->
<!--     <xsl:template match="g:routine_name">
        <xsl:variable name="package" select="lower-case(g:regular_id[1]//t:*)"/>
        <xsl:if
            test="not($package = ('utilities', 'utils', 'schema_maint', 'dbms_output', 'dbms_sql'))">
            <xsl:variable name="procedure-name" select="string-join(g:regular_id//t:*, '.')"/>
            <function_call name="{lower-case(g:regular_id[2]//t:*)}" package="{$package}"/>
        </xsl:if>
    </xsl:template> -->
    <xsl:template match="g:function_call[not(g:routine_name)]">
        <xsl:variable name="procedure-name" select="g:regular_id"/>
        <function_call name="{lower-case($procedure-name)}"/>
    </xsl:template>
    <!--
        By default throw away text
      -->
    <xsl:template match="c:*"/>
    <xsl:template match="text()"/>
</xsl:stylesheet>
