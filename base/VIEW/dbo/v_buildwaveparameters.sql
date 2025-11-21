SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 

CREATE VIEW [dbo].[V_BuildWaveParameters] AS    
SELECT 'CONDITION' as CondType,     
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName     
FROM INFORMATION_SCHEMA.COLUMNS Col     
WHERE Col.TABLE_NAME IN ('ORDERS')    
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')     
UNION ALL   
SELECT 'CONDITION' as CondType,     
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName     
FROM INFORMATION_SCHEMA.COLUMNS Col     
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')    
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL   
SELECT 'CONDITION' as CondType,     
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName     
FROM INFORMATION_SCHEMA.COLUMNS Col     
WHERE Col.TABLE_NAME IN ('ORDERINFO')    
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')      
UNION ALL     
SELECT 'RESTRICT' as CondType,     
       'Max_Orders_Per_Wave' AS ColumnName    
UNION ALL     
SELECT 'RESTRICT' as CondType,     
       'Max_Qty_Per_Wave' AS ColumnName  
UNION ALL     
SELECT 'SORT' as CondType,     
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName     
FROM INFORMATION_SCHEMA.COLUMNS Col     
WHERE Col.TABLE_NAME IN ('ORDERS')    
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')     
UNION ALL   
SELECT 'SORT' as CondType,     
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName     
FROM INFORMATION_SCHEMA.COLUMNS Col     
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')    
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT 'SORT' as CondType,     
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName     
FROM INFORMATION_SCHEMA.COLUMNS Col     
WHERE Col.TABLE_NAME IN ('ORDERINFO')    
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')   
UNION ALL
SELECT 'SORT' as CondType,     
       'Sku_Total_OpenQty' AS ColumnName     


GO