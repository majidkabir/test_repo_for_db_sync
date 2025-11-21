SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--KR - Add view to BI schema for LogiReport https://jiralfl.atlassian.net/browse/WMS-21163
/* Date         Author      Ver.  Purposes                                 */
/* 11-Nov-2022  JarekLIM    1.0   Created                                  */
/***************************************************************************/

CREATE    VIEW [BI].[V_PackDetail_DELLOG]  AS  
SELECT *
FROM dbo.PackDetail_DELLOG WITH (NOLOCK)

GO