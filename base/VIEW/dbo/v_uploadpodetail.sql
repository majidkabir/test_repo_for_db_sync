SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_UploadPODetail] 
AS 
SELECT [POkey]
, [PoLineNumber]
, [Storerkey]
, [ExternPOkey]
, [POGroup]
, [ExternLinenumber]
, [SKU]
, [QtyOrdered]
, [UOM]
, [MODE]
, [STATUS]
, [REMARKS]
, [adddate]
, [Best_bf_Date]
, [ExpiryDate]
, [SerialLot]
FROM [UploadPODetail] (NOLOCK) 

GO