SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
-- [CN] Logi Report to access CartonTrack_Pool table https://jiralfl.atlassian.net/browse/WMS-23014
/* Date         Author      Ver.  Purposes                                 */
/* 11-JUL-2023  JAREKLIM    1.0   Created                                  */
/***************************************************************************/
CREATE   VIEW [BI].[V_CartonTrack_Pool]
AS
SELECT *
FROM dbo.CartonTrack_Pool(NOLOCK)

GO