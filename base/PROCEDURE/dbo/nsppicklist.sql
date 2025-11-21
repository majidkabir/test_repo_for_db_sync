SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspPickList                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspPickList](
@c_InvoiceNoStart     NVARCHAR(10),
@c_InvoiceNoEnd       NVARCHAR(10),
@c_StorerStart	      NVARCHAR(15),
@c_StorerEnd	      NVARCHAR(15),
@c_ConsigneeKeyStart  NVARCHAR(15),
@c_ConsigneeKeyEnd    NVARCHAR(15)
)
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_RowCount int
   -- If you have a problems in this statement like 2 diff. PC printed same orders
   -- Please un-comment this
   -- Set the flag to Print in progress
   /*
   UPDATE ORDERS
   SET PrintFlag = "P",
   TrafficCop = NULL
   WHERE  ( ORDERS.invoiceno >= @c_InvoiceNoStart) AND
   ( ORDERS.invoiceno <= @c_InvoiceNoEnd )  and
   ( ORDERS.storerkey >= @c_StorerStart ) and
   ( ORDERS.storerkey <= @c_StorerEnd ) and
   ( ORDERS.billtokey >= @c_ConsigneeKeyStart ) and
   ( ORDERS.billtokey <= @c_ConsigneeKeyEnd ) and
   ( ( ORDERS.PrintFlag = "N" OR ORDERS.PrintFlag = NULL ) )
   IF @@ERROR = 0
   BEGIN
   SELECT @n_RowCount = @@ROWCOUNT
   COMMIT TRAN
   END
   ELSE
   BEGIN
   ROLLBACK TRAN
   SELECT @n_RowCount = 0
   END
   */
   SELECT LOC.PutawayZone,
   PICKDETAIL.Lot,
   PICKDETAIL.Loc,
   PickQty = PICKDETAIL.Qty,
   PICKDETAIL.UOM,
   PICKDETAIL.CaseID,
   SKU.DESCR,
   SKU.Sku,
   SKU.STDNETWGT,
   SKU.STDCUBE,
   SKU.STDGROSSWGT  ,
   LOTATTRIBUTE.Lottable02,
   LOTATTRIBUTE.Lottable03,
   LOTATTRIBUTE.Lottable04 ,
   ORDERS.InvoiceNo ,   ORDERS.OrderKey,
   ORDERS.StorerKey,
   ORDERS.ConsigneeKey,
   STORER.Company,
   ORDERS.DeliveryDate,
   ORDERS.BuyerPO,
   ORDERS.ExternOrderKey,
   ORDERS.Route,
   ORDERS.Stop,
   ORDERS.Door,
   ORDERS.C_CONTACT1,
   ORDERS.BilltoKey,
   ORDERS.Notes,
   PACK.CaseCnt ,
   PACK.PackUOM1 ,
   PACK.PackUOM2 ,
   PACK.InnerPack ,
   PACK.PackUOM3 ,
   PACK.Qty ,
   PACK.PackUOM4 ,
   PACK.Pallet ,
   PACK.PackUOM5 ,
   PACK.Cube ,
   PACK.PackUOM6 ,
   PACK.GrossWgt ,
   PACK.PackUOM7 ,
   PACK.NetWgt ,
   PACK.PackUOM8 ,
   PACK.OtherUnit1 ,
   PACK.PackUOM9 ,
   PACK.OtherUnit2 ,
   ORDERS.B_company,
   ORDERS.B_address1,
   ORDERS.B_address2,
   ORDERS.B_address3,
   ORDERS.B_address4,
   ORDERS.C_company,
   ORDERS.C_address1,
   ORDERS.C_address2,
   ORDERS.C_address3,
   ORDERS.C_address4
   FROM LOC (NOLOCK),
   PICKDETAIL (NOLOCK),   ORDERS  (NOLOCK),      storer (NOLOCK),
   SKU  (NOLOCK),         lotattribute (NOLOCK), pack (NOLOCK)
   WHERE ( LOC.Loc = PICKDETAIL.Loc ) and
   ( SKU.StorerKey = PICKDETAIL.Storerkey ) and
   ( SKU.Sku = PICKDETAIL.Sku ) and
   ( pickdetail.lot = lotattribute.lot) and
   ( ORDERS.orderkey = pickdetail.orderkey) and
   ( ORDERS.storerkey = storer.storerkey) and
   ( ORDERS.invoiceno >= @c_InvoiceNoStart) AND
   ( ORDERS.invoiceno <= @c_InvoiceNoEnd )  and
   ( ORDERS.storerkey >= @c_StorerStart ) and
   ( ORDERS.storerkey <= @c_StorerEnd ) and
   ( ORDERS.billtokey >= @c_ConsigneeKeyStart ) and
   ( ORDERS.billtokey <= @c_ConsigneeKeyEnd ) and
   ( pack.packkey = pickdetail.packkey) AND
   ( ORDERS.PrintFlag <> 'Y' )
   -- ( ORDERS.PrintFlag = "P" )
   SELECT @n_RowCount = @@ROWCOUNT
   IF @n_RowCount > 0
   BEGIN
      BEGIN TRAN
         UPDATE ORDERS
         SET PrintFlag = "Y",
         TrafficCop = NULL
         WHERE  ( ORDERS.invoiceno >= @c_InvoiceNoStart) AND
         ( ORDERS.invoiceno <= @c_InvoiceNoEnd )  and
         ( ORDERS.storerkey >= @c_StorerStart ) and
         ( ORDERS.storerkey <= @c_StorerEnd ) and
         ( ORDERS.billtokey >= @c_ConsigneeKeyStart ) and
         ( ORDERS.billtokey <= @c_ConsigneeKeyEnd ) and
         ( ORDERS.PrintFlag <> "Y" )
         -- ( ORDERS.PrintFlag = "P" ) Only update which = print in progress
         IF @@ERROR = 0
         BEGIN
            SELECT @n_RowCount = @@ROWCOUNT
            COMMIT TRAN
         END
      ELSE
         BEGIN
            ROLLBACK TRAN
            SELECT @n_RowCount = 0
         END
      END
   END /* main procedure */

GO