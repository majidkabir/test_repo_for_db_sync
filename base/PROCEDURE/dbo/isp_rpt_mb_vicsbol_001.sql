SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: isp_RPT_MB_VICSBOL_001                                           */
/* Creation Date: 18-Jun-2024                                           */
/* Copyright: Maersk                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: UWP-20706 - Granite | MWMS | BOL Report                     */
/*        :                                                             */
/* Called By: RPT_MB_VICSBOL_001                                        */
/*          :                                                           */
/* Github Version: 1.1                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 18-Jun-2024 WLChooi  1.0   DevOps Combine Script                     */
/* 25-Nov-2024 WLChooi  1.1   FCR-1459 Use current Datetime (WL01)      */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_RPT_MB_VICSBOL_001]
(@c_Mbolkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue  INT = 1
         , @n_StartTCnt INT = @@TRANCOUNT

   SELECT DISTINCT MBOL.MbolKey
                 , ORDERS.ConsigneeKey
                 , DepartureDate = [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, MBOL.Facility, GETDATE())   --WL01
   FROM MBOL WITH (NOLOCK)
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
   JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERS.OrderKey)
   WHERE MBOL.MbolKey = @c_Mbolkey 
   AND ORDERS.[Status] >= '5'
END -- procedure

GO