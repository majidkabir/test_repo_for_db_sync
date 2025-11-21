SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_C4_Rec_Exp] 
AS 
SELECT [Messageh]
, [MessageDate]
, [Rev_Date]
, [PO_Number]
, [Buyer]
, [SupplyCode]
, [Head]
, [Line]
, [SKU]
, [Qty]
, [Best_Before_Date]
, [Status]
, [Documentkey]
, [Adddate]
, [EditDate]
FROM [C4_Rec_Exp] (NOLOCK) 

GO