SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_ids_ec_scgdsrn] 
AS 
SELECT [externreceiptkey]
, [pokey]
, [sku]
, [goodqty]
, [badqty]
FROM [ids_ec_scgdsrn] (NOLOCK) 

GO