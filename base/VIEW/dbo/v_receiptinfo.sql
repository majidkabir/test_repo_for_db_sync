SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE   VIEW dbo.V_ReceiptInfo 
AS    
SELECT *  
FROM dbo.ReceiptInfo (nolock) 

GO