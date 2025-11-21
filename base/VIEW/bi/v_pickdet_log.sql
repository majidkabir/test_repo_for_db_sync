SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
--[IN] HM Add New BI View - PICKDET_LOG on JReport https://jiralfl.atlassian.net/browse/WMS-15677
/* Date         Author      Ver.  Purposes                                 */
/* 10-Nov-2020  KHLim       1.1   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_PICKDET_LOG]  AS
SELECT *
FROM dbo.PICKDET_LOG WITH (NOLOCK)

GO