SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_UPLOADPOHeader] 
AS 
SELECT [POkey]
, [ExternPOKey]
, [POGROUP]
, [Storerkey]
, [POType]
, [SellerName]
, [MODE]
, [STATUS]
, [REMARKS]
, [LoadingDate]
, [adddate]
FROM [UPLOADPOHeader] (NOLOCK) 

GO