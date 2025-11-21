SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Purpose: [CN] WMS_Add_View_To_BI_Schema_For_JReport - PackdetailInfo    */
/* https://jiralfl.atlassian.net/browse/WMS-18642                          */
/* Creation Date: 20-Dec-2021                                              */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author		 Ver.  Purposes                                 */
/* 24-Dec-2021  gywong      1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_PackDetailInfo] AS
SELECT *
FROM dbo.PackDetailInfo WITH (NOLOCK)


GO