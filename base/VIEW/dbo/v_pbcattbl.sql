SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_pbcattbl] 
AS 
SELECT [pbt_tnam]
, [pbt_tid]
, [pbt_ownr]
, [pbd_fhgt]
, [pbd_fwgt]
, [pbd_fitl]
, [pbd_funl]
, [pbd_fchr]
, [pbd_fptc]
, [pbd_ffce]
, [pbh_fhgt]
, [pbh_fwgt]
, [pbh_fitl]
, [pbh_funl]
, [pbh_fchr]
, [pbh_fptc]
, [pbh_ffce]
, [pbl_fhgt]
, [pbl_fwgt]
, [pbl_fitl]
, [pbl_funl]
, [pbl_fchr]
, [pbl_fptc]
, [pbl_ffce]
, [pbt_cmnt]
FROM [pbcattbl] (NOLOCK) 

GO