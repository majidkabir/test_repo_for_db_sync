SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************************/
/* Stored Procedure: isp_CheckListByStore                                 */
/* Creation Date:                                                         */
/* Copyright: IDS                                                         */
/* Written by:                                                            */
/*                                                                        */
/* Purpose:  										                                */
/*                                                                        */
/* Input Parameters:                                                      */
/*                                                                        */
/* Output Parameters:                                                     */
/*                                                                        */
/* Return Status:                                                         */
/*                                                                        */
/* Usage:                                                                 */
/*                                                                        */
/* Local Variables:                                                       */
/*                                                                        */
/* Called By: Report Module                                               */
/*                                                                        */
/* PVCS Version: 1.2                                                      */
/*                                                                        */
/* Version: 5.4                                                           */
/*                                                                        */
/* Data Modifications:                                                    */
/*                                                                        */
/* Updates:                                                               */
/* Date         Author    Ver.  Purposes                                  */
/* 28-Jan-2005	YTWan	           Not Able to Update/Insert Pickslip # to   */
/*			                       Table Pickheader, pickdetail, refkeylookup*/
/*			                       But able to print out PickslipNo          */
/* 11-Mar-2005  YTWan		  	  so#32746:To Print Check List for C4 Xdock */
/*							           and FT After Allocated from Report Module */
/* 29-Mar-2005  YTWan           so#32746:Fix bug - Sort by OD.Externpokey */
/* 08-Apr-2005  MaryVong        Added Drop object and Grant Execution     */
/* 25-May-2009  NJOW01    1.1   Add BUSR3 column. (sensitive              */
/*                              & non sensitive SKU flag)                 */
/**************************************************************************/
CREATE PROC [dbo].[isp_CheckListByStore] (
	@c_storerkey NVARCHAR(20), 
	@c_supplierstart NVARCHAR(45),
	@c_supplierend NVARCHAR(45),
	@c_receiptkeystart NVARCHAR(10),
	@c_receiptkeyend NVARCHAR(10)
) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	SELECT PICKDETAIL.OrderKey, 
          PICKDETAIL.OrderLineNumber, 
			 PICKDETAIL.StorerKey, 
			 PICKDETAIL.Sku,
			 ISNULL(SKU.DESCR,'') SKUDESCR, 
			 PICKDETAIL.Qty, 
			 PICKDETAIL.Lot, 
			 PICKDETAIL.Loc, 
			 PICKDETAIL.ID, 
			 PICKDETAIL.Packkey,
          OD.EXTERNPOKEY, 
			 OH.CONSIGNEEKEY, 
          OH.C_COMPANY, 
			 OH.Priority, 
          OH.DeliveryDate, 
			 OH.NOTES, 
			 STORERSODEFAULT.XDockLane,  
			 STORERSODEFAULT.XDockRoute, 
			 ISNULL(PACK.Casecnt, 0) CASECNT, 
			 ISNULL(PACK.Innerpack, 0) Innerpack, 
			 RD.Receiptkey,
			 RD.Recvby,
			 PO.SellerName,
			 STORER.Company,
			 SKU.Busr3  --NJOW01
	  FROM PICKDETAIL (NOLOCK)
     INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OD.ORDERKEY = PICKDETAIL.ORDERKEY) AND
			                                       (OD.ORDERLINENUMBER = PICKDETAIL.ORDERLINENUMBER)
	  INNER JOIN SKU WITH (NOLOCK)       	   ON (PICKDETAIL.STORERKEY = SKU.STORERKEY) AND
												            (PICKDETAIL.SKU = SKU.SKU) 
	  INNER JOIN PACK WITH (NOLOCK)           ON (SKU.PACKKEY = PACK.PACKKEY)
	  INNER JOIN ORDERS OH WITH (NOLOCK)     	ON (OH.ORDERKEY = OD.ORDERKEY)
	  INNER JOIN STORER ST (NOLOCK) 			   ON (OH.Consigneekey = ST.Storerkey)
	  LEFT OUTER JOIN STORERSODEFAULT         ON (ST.STORERKEY = STORERSODEFAULT.STORERKEY)
	  INNER JOIN PO (NOLOCK)                  ON (PO.ExternPOKey = OD.ExternPOKey)
     INNER JOIN (SELECT ExternPOKey, RECEIPTKEY, MAX(EditWho) Recvby FROM  ReceiptDetail RD(NOLOCK) 
                 GROUP BY ExternPOKey, RECEIPTKEY)  RD ON ( RD.ExternPOKey = OD.ExternPOKey)	  
	  INNEr JOIN STORER WITH (NOLOCK)         ON (STORER.STORERKEY = PO.SellerName)
	WHERE PO.Sellername BETWEEN @c_supplierstart   AND @c_supplierend
	AND   RD.ReceiptKey BETWEEN @c_receiptkeystart AND @c_receiptkeyend
	AND   PICKDETAIL.Status < '5'
	ORDER BY OD.EXTERNPOKEY, OH.CONSIGNEEKEY, STORERSODEFAULT.XDockRoute,  --29-Mar-2005 YTWan sos32746: Sort by OD.Externpokey 
	         SKU.Busr3, SKU.Sku --NJOW01
END

GO