SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
CREATE VIEW [dbo].[V_StockTakeSheetParameters]   
AS   
SELECT *  
FROM dbo.[StockTakeSheetParameters] (NOLOCK)   

GO