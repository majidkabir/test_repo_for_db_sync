SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Purpose: [PH] - LogiReport_Add_View in PRD Catalog_18July2022          */
/* https://jiralfl.atlassian.net/browse/WMS-20268                          */
/* Creation Date: 21-JUL-2021                                              */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author		 Ver.  Purposes                                 */
/* 21-JUL-2022  JarekLim     1.0   Created                                  */
/***************************************************************************/
CREATE VIEW [BI].[V_BookingVehicle] 
AS
SELECT * FROM DBO.BookingVehicle WITH (NOLOCK)

GO