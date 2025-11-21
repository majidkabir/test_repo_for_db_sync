SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
CREATE VIEW [dbo].[V_ORDERS]           
AS           
SELECT *        
      ,ltrim(rtrim(BillToKey)) + ltrim(rtrim(ConsigneeKey)) AS ShipToCode        
FROM [dbo].[ORDERS] WITH (NOLOCK)      

GO