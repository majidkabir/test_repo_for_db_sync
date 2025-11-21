SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE VIEW [dbo].[V_StorerConfig] 
AS 
SELECT *
FROM dbo.[StorerConfig] (NOLOCK) 


GO