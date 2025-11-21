SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Purpose: CN logireport Add View to BI Schema -lululemon          */
/* https://jiralfl.atlassian.net/browse/WMS-22713                         */
/* Creation Date: 30-May-2023                                              */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author		 Ver.  Purposes                                 */
/* 30-May-2023  JarekLim     1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_WorkOrder] 
AS
SELECT * FROM DBO.WorkOrder WITH (NOLOCK)

GO