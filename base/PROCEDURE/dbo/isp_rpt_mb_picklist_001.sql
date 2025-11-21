SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_MB_PICKLIST_001                            */
/* Creation Date: 26-OCT-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WZPang                                                   */
/*                                                                      */
/* Purpose: WMS-20954 - FRR - Truck Picking List Report(SG)		        */
/*                                                                      */
/* Called By: RPT_MB_PICKLIST_001                                       */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_MB_PICKLIST_001](
            @c_Mbolkey		NVARCHAR(10)
			)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT	MBOL.MbolKey
		,	MBOL.DRIVERName
		,	MBOL.AddDate
		,	ORDERS.C_Company
	FROM MBOL (NOLOCK)
	JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOLDETAIL.MbolKey = MBOL.MbolKey)
	JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.OrderKey)
	WHERE MBOL.MbolKey = @c_Mbolkey
	GROUP BY MBOL.MbolKey
		,	MBOL.DRIVERName
		,	MBOL.AddDate
		,	ORDERS.C_Company

	

END -- procedure

GO