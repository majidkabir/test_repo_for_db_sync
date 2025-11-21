SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
       
CREATE VIEW [dbo].[V_RDTUser]      
AS      
SELECT * FROM  [RDT].[RDTUser] WITH (nolock)    

GO