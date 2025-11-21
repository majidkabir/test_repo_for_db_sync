SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_SKULog] 
AS 
SELECT [Person]
, [ActionTime]
, [ActionDescr]
FROM [SKULog] (NOLOCK) 

GO