SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [dbo].[V_BuildLoadLog]
AS  
SELECT * 
FROM   [dbo].[BuildLoadLog]  WITH (NOLOCK)


GO