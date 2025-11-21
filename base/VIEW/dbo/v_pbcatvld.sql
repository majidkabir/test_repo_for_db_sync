SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbcatvld] 
AS 
SELECT [pbv_name]
, [pbv_vald]
, [pbv_type]
, [pbv_cntr]
, [pbv_msg]
FROM [pbcatvld] (NOLOCK) 

GO