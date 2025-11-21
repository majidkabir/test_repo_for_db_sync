SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_shipment_order_summary07                        */
/* Creation Date: 27-Jun-2016                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:[TW] Add LCT Delivery Notes on Exceed View Report(SOS371950) */
/*                                                                      */
/* Input Parameters: @c_StorerKey - StorerKey,                          */
/*                   @c_loadkeyStart - loadkey,                         */
/*                   @c_loadkeyEnd - loadkey,                           */
/*                   @c_OrderKeyStart - OrderKey,                       */
/*                   @c_OrderKeyEnd - OrderKey                          */
/*                                                                      */
/*                                                                      */
/* Usage: Call by dw = r_shipment_order_summary07                       */
/*                                                                      */
/* PVCS Version: 1.1 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver.  Purposes                                 */
/* 31-JUL-2017  CSCHONG  1.0   WMS-2411-revise field mapping (CS01)     */
/* 27-SEP-2019  WLChooi  1.1   WMS-10689 - Change to Orders.DeliveryDate*/
/*                             (WL01)                                   */
/************************************************************************/

CREATE PROC [dbo].[isp_shipment_order_summary07] ( 
   @c_StorerKey      NVARCHAR( 15),
   @c_LoadKeyStart   NVARCHAR( 10), 
   @c_LoadKeyEnd     NVARCHAR( 10),
   @c_OrderKeyStart  NVARCHAR( 10),
   @c_OrderKeyEnd    NVARCHAR( 10) )
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @b_debug int

   DECLARE 
      @nFromCartonNo         int,
      @nToCartonNo           int,
      @cUCC_LabelNo          NVARCHAR( 20)
     


   DECLARE @n_Address1Mapping INT
         , @n_C_CityMapping   INT
   
   SET @b_debug = 0




   SELECT DISTINCT Row_Number() OVER (PARTITION BY ORDERS.Orderkey ORDER BY ORDDET.SKU Asc) AS RowID,
          --ORDERS.type AS OrdType,  --10           --CS01
          ISNULL(OI.Platform,'') AS Ordtype,
          ORDERS.ExternOrderKey AS ExternOrderKey,
          --CONVERT(NVARCHAR(10),LPD.DeliveryDate,121) AS DeliveryDate,    --WL01
          CONVERT(NVARCHAR(10),ORDERS.DeliveryDate,121) AS DeliveryDate,   --WL01
          ORDERS.C_Company AS C_Company, 
          ISNULL(RTRIM(ORDERS.C_Address1),'') AS C_Address1,
          ORDERS.ConsigneeKey AS ConsigneeKey,
          ORDDET.SKU AS SKU,
          SKU.Descr AS SDescr,
          RTRIM(ORDERS.c_Phone1) AS c_phone1,
          ORDERS.Orderkey AS Orderkey,
          (ORDDET.QtyAllocated+ORDDET.QtyPicked+ORDDET.ShippedQty) AS ORDQty,
          ORDERS.Notes AS ORDNotes,
          IDS.Company AS Company,ISNULL(ph.pickheaderkey,'') AS Pickslipno   
  FROM ORDERS ORDERS (NOLOCK) 
  JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = ORDERS.Orderkey
  JOIN LoadplanDetail LPD (NOLOCK) ON LPD.loadkey = ORDERS.loadkey AND  LPD.Orderkey=ORDERS.Orderkey
  JOIN SKU SKU (NOLOCK) ON (ORDDET.Sku = SKU.Sku AND ORDDET.StorerKey = SKU.StorerKey)
  JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey) 
  LEFT OUTER JOIN STORER IDS (NOLOCK) ON (IDS.Storerkey = 'LCTOFFICE')
  LEFT JOIN OrderInfo OI WITH (NOLOCK) ON OI.orderkey = ORDERS.OrderKey
  LEFT JOIN pickheader ph (NOLOCK) ON ph.OrderKey=orders.OrderKey             --CS01
  WHERE ORDERS.StorerKey = @c_StorerKey 
    AND ORDERS.Loadkey>= CASE WHEN ISNULL(@c_LoadKeyStart,'') <> '' THEN @c_LoadKeyStart ELSE ORDERS.Loadkey END 
    AND ORDERS.Loadkey<= CASE WHEN ISNULL(@c_LoadKeyEnd,'') <> '' THEN @c_LoadKeyEnd ELSE ORDERS.Loadkey END 
    AND ORDERS.Orderkey >= CASE WHEN ISNULL(@c_OrderKeyStart,'') <> '' THEN @c_OrderKeyStart ELSE ORDERS.OrderKey END 
    AND ORDERS.Orderkey <= CASE WHEN ISNULL(@c_OrderKeyEnd,'') <> '' THEN @c_OrderKeyEnd ELSE ORDERS.OrderKey END 
    AND ORDERS.Status >= '3'
  ORDER BY ORDERS.Orderkey,ORDDET.SKU

END

GO