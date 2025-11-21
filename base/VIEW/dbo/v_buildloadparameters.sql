SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_BuildLoadParameters] AS
SELECT 'CONDITION' as CondType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT 'CONDITION' as CondType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('StorerKey', 'SKU')
UNION ALL
SELECT 'RESTRICT' as CondType,
       'Max_Orders_Per_Load' AS ColumnName
UNION ALL
SELECT 'RESTRICT' as CondType,
       'Max_Qty_Per_Load' AS ColumnName
UNION ALL
SELECT 'RESTRICT' as CondType,
       'No_Of_SKU_In_Order' AS ColumnName
UNION ALL
SELECT 'STRATEGY' as CondType,
       'STRG CODE' AS ColumnName
UNION ALL
SELECT 'SORT' as CondType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT 'SORT' as CondType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('SKU')
UNION ALL
SELECT 'GROUP' as CondType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')


GO