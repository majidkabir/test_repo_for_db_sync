SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* View: V_GetMinReqCube                                                   */
/* Creation Date: 2020-09-11                                               */
/* Copyright: LF Logistics                                                 */
/* Written by: Wan                                                         */
/*                                                                         */
/* Purpose: WMS-13409-SG - Logitech - Back to Back Declaration for Form DE */
/*                                                                         */
/* Called By: d_dw_populate_btb_wave_grid &  d_dw_populate_btb_wave_query  */
/*          :                                                              */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Ver   Purposes                                     */
/***************************************************************************/
CREATE VIEW [dbo].[V_GetMinReqCube]
AS 
SELECT  ORDERS.Orderkey
      , MinReqCube = ISNULL(CODELKUP.Notes,'')
      , CubeFactor = CONVERT( DECIMAL(12,6),CASE WHEN ISNUMERIC(CODELKUP.UDF01) = 0 THEN '1.000000' ELSE CODELKUP.UDF01 END )
FROM ORDERS WITH (NOLOCK) 
JOIN STORER WITH (NOLOCK) ON STORER.Storerkey = ORDERS.Consigneekey
LEFT OUTER JOIN CODELKUP  WITH (NOLOCK) ON CODELKUP.ListName = 'LOGICUSREQ'
                                       AND CODELKUP.Code = STORER.SUSR5
                                       AND CODELKUP.Storerkey = ORDERS.Storerkey
WHERE CODELKUP.LISTNAME IS NOT NULL

GO