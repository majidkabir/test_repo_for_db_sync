SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbcatfmt] 
AS 
SELECT [pbf_name]
, [pbf_frmt]
, [pbf_type]
, [pbf_cntr]
FROM [pbcatfmt] (NOLOCK) 

GO