SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_OTM_Table_Mapping] AS
SELECT 'ASNADDOTM ' AS TableName, 'RECEIPT' AS PhysicalTableName, 'ReceiptKey' AS Key1, 
       'DocType' AS Key2, 'StorerKey' AS Key3, 'OTM-ASN' AS ParmType   
UNION SELECT 'CANCASNOTM', 'RECEIPT', 'ReceiptKey', 'DocType', 'StorerKey', 'OTM-ASN'
UNION SELECT 'RCPTOTM',    'RECEIPT', 'ReceiptKey', 'DocType', 'StorerKey', 'OTM-ASN'
UNION SELECT 'ASNRCMOTM',  'RECEIPT', 'ReceiptKey', 'DocType', 'StorerKey', 'OTM-ASN'
UNION SELECT 'CANCSOOTM',  'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'DELSOOTM',   'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'SOADDOTM',   'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'SOCARGOOTM', 'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'SOCFMOTM',   'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'SOPNPOTM',   'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'SORCMOTM',   'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'SOSHPOTM',   'ORDERS',  'OrderKey', 'Status', 'StorerKey', 'OTM-ORD'
UNION SELECT 'DSTADDOTM',  'DOCStatusTrack', 'RowRef', 'Status', 'StorerKey','OTM-DST'
UNION SELECT 'LOADFNZOTM', 'LOADPLAN', 'LoadKey', 'Status', 'StorerKey', 'OTM-LP'
UNION SELECT 'LPCARGOOTM', 'LOADPLAN', 'LoadKey', 'Status', 'StorerKey', 'OTM-LP'
UNION SELECT 'MBCARGOOTM', 'MBOL', 'MbolKey', '', 'StorerKey', 'OTM-MBL'
UNION SELECT 'MBOLSHPOTM', 'MBOL', 'MbolKey', '', 'StorerKey', 'OTM-MBL'

GO