SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


CREATE VIEW [dbo].[V_BuildLoadDetailLog]
AS  
SELECT * 
FROM   [dbo].[BuildLoadDetailLog]  WITH (NOLOCK)


GO