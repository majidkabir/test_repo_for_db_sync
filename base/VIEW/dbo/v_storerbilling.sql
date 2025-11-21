SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_STORERBILLING] 
AS 
SELECT [StorerKey]
, [RSMinimumInvoiceCharge]
, [RSMinimumInvoiceTaxGroup]
, [RSMinimumInvoiceGLDist]
, [ISMinimumInvoiceCharge]
, [ISMinimumInvoiceTaxGroup]
, [ISMinimumInvoiceGLDist]
, [HIMinimumInvoiceCharge]
, [HIMinimumInvoiceTaxGroup]
, [HIMinimumInvoiceGLDist]
, [HOMinimumShipmentCharge]
, [HOMinimumShipmentTaxGroup]
, [HOMinimumShipmentGLDist]
, [ISMinimumReceiptCharge]
, [ISMinimumReceiptTaxGroup]
, [ISMinimumReceiptGLDist]
, [HIMinimumReceiptCharge]
, [HIMinimumReceiptTaxGroup]
, [HIMinimumReceiptGLDist]
, [InvoiceNumberStrategy]
, [BillingGroup]
, [LockBatch]
, [LockWho]
, [AddDate]
, [AddWho]
, [EditDate]
, [EditWho]
, [TrafficCop]
, [ArchiveCop]
FROM [STORERBILLING] (NOLOCK) 

GO