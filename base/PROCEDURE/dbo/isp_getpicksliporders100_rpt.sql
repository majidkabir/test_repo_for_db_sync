SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders100_rpt                        */
/* Creation Date: 30-SEP-2019                                           */
/* Copyright: LFL                                                       */
/* Written by: Chooi                                                    */
/*                                                                      */
/* Purpose:  WMS-10742 - CN IKEA Pickslip REPORT                        */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_pickorder100_rpt             */
/*                                                                      */
/* Called By: View Report                                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders100_rpt]
      (@c_Loadkey NVARCHAR(10), @c_Sorting NVARCHAR(10) = '' )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue INT = 1, @n_MaxLine INT = 20

   CREATE TABLE #Temp_PSOrder100(
      Pickslipno         NVARCHAR(10),
   --   Orderkey           NVARCHAR(10),
      UserDefine10       NVARCHAR(10),
      DeliveryDate       DATETIME,
      SKU                NVARCHAR(20),
      LOC                NVARCHAR(10),
      Lottable02         NVARCHAR(18),
      Notes              NVARCHAR(255),
      OriginalQty        INT,
      PDQTY              INT,
      LogicalLoc         NVARCHAR(18),
      Loadkey            NVARCHAR(10) )

   IF(@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      INSERT INTO #Temp_PSOrder100
      SELECT   PH.Pickheaderkey
           --  , PD.Orderkey
             , ISNULL(OH.UserDefine10,'')
             --, SUBSTRING(ISNULL(OH.UserDefine10,''),1,CHARINDEX('-',ISNULL(OH.UserDefine10,'')) - 1)
             , OH.DeliveryDate
             , PD.SKU
             , PD.LOC
             , CASE WHEN LOC.LocationType = 'OTHER' THEN LOTT.LOTTABLE02 ELSE '' END
             , ISNULL(SC.Notes,'') AS Notes
             , OD.OriginalQty
             , SUM(PD.Qty) AS PDQTY
             , LOC.LogicalLocation
             , LPD.LoadKey
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON OH.ORDERKEY = OD.ORDERKEY
      JOIN PICKDETAIL PD (NOLOCK) ON PD.ORDERKEY = OD.ORDERKEY AND OD.ORDERLINENUMBER = PD.ORDERLINENUMBER AND OD.SKU = PD.SKU
      JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
      JOIN LoadPlanDetail LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderkey = LPD.Loadkey
      LEFT JOIN SKUConfig SC (NOLOCK) ON SC.STORERKEY = OH.STORERKEY AND SC.SKU = PD.SKU
      LEFT JOIN LOTATTRIBUTE LOTT (NOLOCK) ON LOTT.LOT = PD.LOT
      WHERE LPD.LoadKey = @c_Loadkey 
      GROUP BY PH.Pickheaderkey
         --    , PD.Orderkey
             , ISNULL(OH.UserDefine10,'')
             , OH.DeliveryDate
             , PD.SKU
             , PD.LOC
             , CASE WHEN LOC.LocationType = 'OTHER' THEN LOTT.LOTTABLE02 ELSE '' END
             , ISNULL(SC.Notes,'')
             , OD.OriginalQty
             , LOC.LogicalLocation
             , LPD.LoadKey
      END

      SELECT *, (Row_Number() OVER (PARTITION BY Loadkey Order By CASE WHEN @c_Sorting = 1 THEN SKU WHEN @c_Sorting = 2 THEN Loc END Asc) - 1 ) / @n_MaxLine
      FROM #Temp_PSOrder100
      ORDER BY CASE WHEN @c_Sorting = 1 THEN SKU
                    WHEN @c_Sorting = 2 THEN Loc END
END


GO