SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbsrpt_category] 
AS 
SELECT [category_id]
, [category]
FROM [pbsrpt_category] (NOLOCK) 

GO