SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_CCSkuReleaseGroupTableField]
AS
SELECT 'SKU' as CountType, 
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col 
WHERE Col.TABLE_NAME IN ('LOC','SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT 'Loc' as CountType, 
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName 
FROM INFORMATION_SCHEMA.COLUMNS Col 
WHERE Col.TABLE_NAME IN ('LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop') 


GO