SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure:isp_RPT_LP_LOADSHEET_010                             */
/* Creation Date: 12-Jun-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-22728                                                    */
/*                                                                       */
/* Called By: RPT_LP_LOADSHEET_010                                       */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 12-Jun-2023 WLChooi 1.0   DevOps Combine Script                       */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_LP_LOADSHEET_010]
(@c_Loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT OH.TrackingNo
        , OH.C_Company
        , OH.ConsigneeKey
        , OH.C_Address1
        , OH.C_City
        , LPD.LoadKey
        , OH.Facility
        , OH.StorerKey
        , MAX(OH.DeliveryDate) DeliveryDate
        , ISNULL(LOADPLAN.CarrierKey, '') AS carrierkey
        , ISNULL(LOADPLAN.Truck_Type, '') Truck_Type
        , ISNULL(CONVERT(NVARCHAR(35), OH.Notes), '') AS Notes
        , SUM(PD.Qty) AS PQty
        , CASE WHEN PAC.CaseCnt > 0 THEN FLOOR(SUM(PD.Qty) / PAC.CaseCnt)
               ELSE 0 END AS PQtyInCS
        , PD.Sku
        , SKU.DESCR
        , PAC.Pallet
        , PAC.CaseCnt
        , LOTT.Lottable02
        , LOTT.Lottable04
   FROM LoadPlanDetail LPD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (LPD.OrderKey = OH.OrderKey)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.OrderKey = OD.OrderKey)
   JOIN PICKDETAIL AS PD ON (PD.OrderKey = OD.OrderKey AND PD.Sku = OD.Sku AND PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.Storerkey AND SKU.Sku = PD.Sku)
   JOIN PACK PAC WITH (NOLOCK) ON (SKU.PACKKey = PAC.PackKey)
   JOIN LoadPlan LOADPLAN WITH (NOLOCK) ON (LOADPLAN.LoadKey = LPD.LoadKey)
   JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.Lot = PD.Lot)
   WHERE LPD.LoadKey = @c_Loadkey
   GROUP BY LPD.LoadKey
          , OH.Facility
          , OH.StorerKey
          , OH.TrackingNo
          , ISNULL(LOADPLAN.CarrierKey, '')
          , ISNULL(LOADPLAN.Truck_Type, '')
          , ISNULL(CONVERT(NVARCHAR(35), OH.Notes), '')
          , PD.Sku
          , SKU.DESCR
          , PAC.Pallet
          , PAC.CaseCnt
          , LOADPLAN.UserDefine01
          , ISNULL(PD.DropID, '')
          , LOTT.Lottable02
          , LOTT.Lottable04
          , OH.C_Company
          , OH.ConsigneeKey
          , OH.C_Address1
          , OH.C_City
   ORDER BY PD.Sku

   QUIT_SP:
END

GO