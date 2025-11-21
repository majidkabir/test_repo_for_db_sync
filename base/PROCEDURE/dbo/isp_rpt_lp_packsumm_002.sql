SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_LP_PACKSUMM_002                               */
/* Creation Date:  08-SEP-2023                                             */
/* Copyright: MAERSK                                                       */
/* Written by: Aftab                                                       */
/*                                                                         */
/* Purpose: WMS-23626 - Migrate WMS report to Logi Report                  */
/*                                                                         */
/* Called By:RPT_LP_PACKSUMM_002                                           */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 08-Sep-2023  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/

CREATE   PROC [dbo].[isp_RPT_LP_PACKSUMM_002]
(@c_Loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1
   
   SELECT DISTINCT LPD.Orderkey
   FROM LOADPLANDETAIL LPD (NOLOCK)
   WHERE LPD.Loadkey = @c_Loadkey
   ORDER BY LPD.OrderKey

END

GO