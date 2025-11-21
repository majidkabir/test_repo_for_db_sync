SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE   VIEW [dbo].[V_ExtendedValidationColumn] AS
SELECT 'MBOLExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','MBOLDETAIL','LOADPLAN','LOADPLANDETAIL', 'ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT 'ASNExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('RECEIPT','RECEIPTDETAIL','SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop')
--WMS-14433 START
UNION ALL
SELECT 'ASNCloseExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('RECEIPT','RECEIPTDETAIL','SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop')
--WMS-14433 END
--WMS-17048 START
UNION ALL
SELECT 'ChannelTRFExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ChannelTransfer','ChannelTransferDetail','SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop')
--WMS-17048 END
UNION ALL
SELECT 'TRFExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('TRANSFER','TRANSFERDETAIL','SKU')
UNION ALL
SELECT 'PODExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('POD')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT 'ADJExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ADJUSTMENT','ADJUSTMENTDETAIL','SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'BKOExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('BOOKING_OUT','LOADPLAN','MBOL')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'REPLExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOTxLOCxID','LOT','LOC','ID', 'LOTATTRIBUTE', 'SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'IQCExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('INVENTORYQC','INVENTORYQCDETAIL','SKU', 'LOT','LOC','ID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'MoveExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOTxLOCxID','SKUxLOC','LOTATTRIBUTE', 'SKU', 'LOT','LOC','ID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'JOBExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WORKORDERJOBDETAIL','WORKORDERJOB','WORKORDERJOBOPERATION', 'STORER', 'SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'AllocateExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERDETAIL','SKU','PACK','LOADPLAN','WAVE','PICKDETAIL','LOTATTRIBUTE','LOT','LOC','ID','SKUxLOC','LOTxLOCxID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'LoadExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN','LOADPLANDETAIL','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'CFMPackConsoExtValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('PACKHEADER','PACKDETAIL','ORDERS','ORDERDETAIL','SKU','LOADPLAN','LOADPLANDETAIL')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'CFMPackDiscreteExtValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('PACKHEADER','PACKDETAIL','ORDERS','ORDERDETAIL','SKU','LOADPLAN','LOADPLANDETAIL')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'PrePackConsoExtValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('PICKHEADER','ORDERS','ORDERDETAIL','SKU','LOADPLAN','LOADPLANDETAIL','PICKDETAIL')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'PrePackDiscreteExtValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('PICKHEADER','ORDERS','ORDERDETAIL','SKU','LOADPLAN','LOADPLANDETAIL','PICKDETAIL')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'KitExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('KIT','KITDETAIL','LOTATTRIBUTE','SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'FacInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('FACILITY')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL --WMS-17231
SELECT 'InvHoldInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('INVENTORYHOLD','STORER','SKU','LOT','LOC','ID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'LocInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOC','FACILITY','PUTAWAYZONE')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'StorerInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('STORER')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'SkuInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL               --LFWM-3669                                    
SELECT 'SkuxLocInputValidation' AS ValidationType,                      
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('SKUxLOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'POInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('PO')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'PODetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('PODETAIL', 'SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'RcptInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('RECEIPT')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')

UNION ALL
SELECT 'RcptDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('RECEIPTDETAIL', 'SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'ORDInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'OrderDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL', 'SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'PickDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('PICKDETAIL', 'SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'TrfInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('TRANSFER')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'TrfDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('TRANSFERDETAIL', 'SKU', 'LOT', 'LOC', 'ID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'AdjInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ADJUSTMENT')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'AdjDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ADJUSTMENTDETAIL', 'SKU', 'LOT', 'LOC', 'ID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'WaveInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WAVE', 'WAVEDETAIL','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'WaveDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WAVEDETAIL','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'LoadInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN','LOADPLANDETAIL','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'LoadDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLANDETAIL','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'MBOLInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','MBOLDETAIL','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'MBOLDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOLDETAIL','LOADPLAN','LOADPLANDETAIL', 'ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'KITInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('KIT')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'KITDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('KITDETAIL','SKU', 'LOT', 'LOC', 'ID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'LOADPopulateValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'MBOLPopulateValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','ORDERS','LOADPLAN')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'WORKORDERInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WORKORDER')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL
SELECT 'WORKORDERDetInputValidation' AS ValidationType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WORKORDERDETAIL','SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')
UNION ALL --WMS-21757
SELECT 'UnAllocateExtendedValidation' as ValidateType,
       UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME) AS ColumnName
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERDETAIL','SKU','PACK','PICKDETAIL','LOTATTRIBUTE','LOT','LOC','ID','SKUxLOC','LOTxLOCxID')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'AddDate', 'ArchiveCop', 'TrafficCop','TimeStamp')


GO