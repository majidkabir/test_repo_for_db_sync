SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_RPT_CB_VICSCBOL_001                                          */
/* Creation Date: 06-Sep-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: UWP-24135 & FCR-798 - NAM|Maersk Logi Report|LVSUSA| Migrate*/
/*          VICS CBOL report to Maersk WMS V2 for Granite Project       */
/*        :                                                             */
/* Called By: RPT_CB_VICSCBOL_001                                       */
/*          :                                                           */
/* Github Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 06-Sep-2024 WLChooi  1.0   DevOps Combine Script                     */
/* 25-Nov-2024 WLChooi  1.1   FCR-1459 Use current Datetime (WL01)      */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_CB_VICSCBOL_001]
(
   @n_Cbolkey  BIGINT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT

   SELECT DISTINCT CBOL.CbolKey
                 , DepartureDate = [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, MBOL.Facility, GETDATE())   --WL01
   FROM CBOL WITH (NOLOCK)
   JOIN MBOL  WITH (NOLOCK) ON (CBOL.Cbolkey = MBOL.Cbolkey)
   JOIN MBOLDETAIL WITH (NOLOCK) ON ( MBOL.MbolKey = MBOLDETAIL.MbolKey )
   JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
   WHERE CBOL.CbolKey = @n_Cbolkey 
   AND ORDERS.[Status] >= '5'
END -- procedure

GO