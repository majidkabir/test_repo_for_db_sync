SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/****************************************************************************/
/* Stored Procedure: isp_RPT_MB_MANDET_006                                  */
/* Creation Date: 14-MAY-2023                                               */
/* Copyright: LFL                                                           */
/* Written by: CSCHONG                                                      */
/*                                                                          */
/* Purpose:WMS-22485 RG migrate despatch report to logi & field modification*/
/*                                                                          */
/* Called By: RPT_MB_MANDET_006                                             */
/*                                                                          */
/* GitLab Version: 1.1                                                      */
/*                                                                          */
/* Version: 1.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author  Ver   Purposes                                      */
/* 14-MAY-2023  CSCHONG 1.0   DevOps Combine Script                         */
/* 31-Oct-2023  WLChooi 1.1   UWP-10213 - Global Timezone (GTZ01)          */
/****************************************************************************/

CREATE   PROC [dbo].[isp_RPT_MB_MANDET_006] @c_MBOLKey NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_TTLQTY      INT
         , @n_ttlcapacity FLOAT

   SELECT @n_TTLQTY = SUM(ORDERDETAIL.ShippedQty)
        , @n_ttlcapacity = SUM(ORDERS.Capacity)
   FROM MBOL (NOLOCK)
   JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
   JOIN ORDERDETAIL (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey)
   JOIN ORDERS (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   WHERE (MBOL.MbolKey = @c_MBOLKey)

   SELECT MBOL.AddWho
        , MBOL.MbolKey
        , MBOL.BookingReference
        , MBOL.OtherReference
        , MBOL.PlaceOfLoading
        , MBOL.PlaceOfDischarge
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, MBOL.EffectiveDate) AS EffectiveDate   --GTZ01
        , MBOL.CarrierKey
        , MBOL.Vessel
        , MBOL.VoyageNumber
        , MBOL.Equipment AS Equipment
        , ORDERDETAIL.Lottable03 AS externpokey
        , ORDERS.ExternOrderKey
        --ORDERDETAIL.Sku,
        --ORDERDETAIL.OrderLineNumber,
        --SKU.DESCR,
        , Qty = CASE WHEN ORDERDETAIL.QtyPicked > 0 THEN ORDERDETAIL.QtyPicked
                     ELSE ORDERDETAIL.ShippedQty END
        -- SKU.PACKKey,
        , STORER.Company
        , MBOL.PlaceOfLoadingQualifier --10
        , [dbo].[fnc_ConvSFTimeZone](ORDERS.StorerKey, ORDERS.Facility, MBOL.ArrivalDateFinalDestination) AS ArrivalDateFinalDestination --datetime   --GTZ01
        , MBOL.ContainerNo
        , SUBSTRING(ORDERS.Notes, 0, 3) AS SpecialHandling
        , ORDERS.BuyerPO AS MarkforKey
        , ORDERS.Capacity
        , @n_TTLQTY AS TTLQTY
        , @n_ttlcapacity AS TTLCAPACITY
   FROM MBOL (NOLOCK)
   JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MbolKey = MBOLDETAIL.MbolKey)
   JOIN ORDERDETAIL (NOLOCK) ON (MBOLDETAIL.OrderKey = ORDERDETAIL.OrderKey)
   JOIN ORDERS (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   LEFT OUTER JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
   WHERE (MBOL.MbolKey = @c_MBOLKey)

END

GO