SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nsp_receiptsummary06                                */
/* Creation Date: 30-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose: Return Summary                                              */
/*                                                                      */
/* Called By: r_dw_receipt_summary06                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[nsp_receiptsummary06] (@c_receiptkey NVARCHAR(10)) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_continue		int,
			  @c_errmsg		 NVARCHAR(255),
			  @b_success		int,
			  @n_err				int,
			  @n_starttcnt		int

	CREATE TABLE #TEMPHEADER (
			ReceiptKey		 NVARCHAR(10) NULL,
			StorerKey		 NVARCHAR(15) NULL,
			Company		     NVARCHAR(45) NULL, 
			BCompany			 NVARCHAR(45) NULL,  
			Address1 		 NVARCHAR(45) NULL,  
			Address2 		 NVARCHAR(45) NULL,  
			Address3 		 NVARCHAR(45) NULL,  
			Address4 		 NVARCHAR(45) NULL,  
			Phone1	 		 NVARCHAR(18) NULL,  
			Fax1		 		 NVARCHAR(18) NULL,  
			Zip		 		 NVARCHAR(18) NULL,  
			ConsigneeKey	 NVARCHAR(15) NULL,  
			C_Company		 NVARCHAR(45) NULL,		
			EditDate				DATETIME NULL,		
			ReceiptDate			DATETIME NULL,		
			ExternReceiptKey NVARCHAR(20) NULL,		
			ORDERSFacility	 NVARCHAR(5) NULL,		
			RECEIPTFacility NVARCHAR(5) NULL,		
			BillToKey		 NVARCHAR(15) NULL)
		
	CREATE TABLE #TEMPSUMMARY (
			ReceiptKey		 NVARCHAR(10) NULL,
			SKU				 NVARCHAR(20) NULL,
			DESCR			     NVARCHAR(60) NULL, 
			UOM				 NVARCHAR(10) NULL,  
			Lottable02		 NVARCHAR(18) NULL,  
			Lottable04			DATETIME NULL,  
			HOSTWHCODE		 NVARCHAR(10) NULL,		
			QTY					INT, 
			LOWERQTY				INT, 
			ReceiptType       NVARCHAR(2) NULL)
	   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 

	INSERT INTO #TEMPHEADER
   SELECT RECEIPT.ReceiptKey,
			RECEIPT.StorerKey,
         STORER.Company, 
			BSTORER.Company AS BCompany, 
         ISNULL(RTRIM(STORER.Address1), '') AS Address1,
         ISNULL(RTRIM(STORER.Address2), '') AS Address2,
         ISNULL(RTRIM(STORER.Address3), '') AS Address3,
         ISNULL(RTRIM(STORER.Address4), '') AS Address4,
         STORER.Phone1,
         STORER.Fax1,
         STORER.Zip,
			ORDERS.ConsigneeKey,
			ORDERS.C_Company,
			MBOL.EditDate,
			RECEIPT.ReceiptDate,
			RECEIPT.ExternReceiptKey,
			ORDERS.Facility AS ORDERSFacility,
			RECEIPT.Facility AS RECEIPTFacility,
			ORDERS.BillToKey
    FROM RECEIPT (NOLOCK),   
			STORER (NOLOCK),   
         ORDERS (NOLOCK),
			MBOL (NOLOCK),  
			STORER BSTORER (NOLOCK)
   WHERE ( RECEIPT.ExternReceiptKey = ORDERS.ExternOrderKey ) and  
         ( ORDERS.MbolKey = MBOL.MbolKey ) and  
         ( ORDERS.Billtokey = BSTORER.StorerKey ) and  
         ( RECEIPT.StorerKey = STORER.StorerKey ) and   
         ( ORDERS.Type = '6' ) and   
			( RECEIPT.Receiptkey = @c_receiptkey ) 
	GROUP BY RECEIPT.ReceiptKey,
			RECEIPT.StorerKey, 
         STORER.Company, 
			BSTORER.Company, 
         ISNULL(RTRIM(STORER.Address1), ''),
         ISNULL(RTRIM(STORER.Address2), ''),
         ISNULL(RTRIM(STORER.Address3), ''),
         ISNULL(RTRIM(STORER.Address4), ''),
         STORER.Phone1,
         STORER.Fax1,
         STORER.Zip,
			ORDERS.ConsigneeKey,
			ORDERS.C_Company,
			MBOL.EditDate,
			RECEIPT.ReceiptDate,
			RECEIPT.ExternReceiptKey,
			ORDERS.Facility,
			RECEIPT.Facility,
			ORDERS.BillToKey

	SELECT @n_err = @@ERROR
	IF @n_err <> 0 
	BEGIN
		SELECT @n_continue = 3
		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63300  
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into #TEMPHEADER Failed. (nsp_receiptsummary06)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
	END -- @n_err = 0 


   INSERT INTO #TEMPSUMMARY 
	SELECT RECEIPTDETAIL.ReceiptKey,
			RECEIPTDETAIL.Sku AS Sku,
			SKU.DESCR AS DESCR,
			RECEIPTDETAIL.UOM AS UOM,
			RECEIPTDETAIL.Lottable02 AS Lottable02,
			RECEIPTDETAIL.Lottable04 AS Lottable04,
			ISNULL(RDLOC.HOSTWHCODE, '') AS HOSTWHCODE,
			-SUM(CASE RECEIPTDETAIL.FinalizeFlag WHEN 'N' 
						 THEN (CASE WHEN RECEIPTDETAIL.UOM = PACK.PackUOM1 THEN RECEIPTDETAIL.BeforeReceivedQty/PACK.CaseCnt 
										WHEN RECEIPTDETAIL.UOM = PACK.PackUOM2 THEN RECEIPTDETAIL.BeforeReceivedQty/PACK.InnerPack   
										WHEN RECEIPTDETAIL.UOM = PACK.PackUOM4 THEN RECEIPTDETAIL.BeforeReceivedQty/PACK.Pallet  
								 ELSE RECEIPTDETAIL.BeforeReceivedQty END)  
				  ELSE (CASE WHEN RECEIPTDETAIL.UOM = PACK.PackUOM1 THEN RECEIPTDETAIL.QtyReceived/PACK.CaseCnt 
								 WHEN RECEIPTDETAIL.UOM = PACK.PackUOM2 THEN RECEIPTDETAIL.QtyReceived/PACK.InnerPack   
								 WHEN RECEIPTDETAIL.UOM = PACK.PackUOM4 THEN RECEIPTDETAIL.QtyReceived/PACK.Pallet  
						  ELSE RECEIPTDETAIL.QtyReceived END) 
				  END) AS QTY,
			-SUM(CASE RECEIPTDETAIL.FinalizeFlag WHEN 'N' 
						 THEN RECEIPTDETAIL.BeforeReceivedQty
				  ELSE RECEIPTDETAIL.QtyReceived 
				  END) AS LowerQTY,
			'EI' AS ReceiptType
    FROM RECEIPTDETAIL (NOLOCK)
	 JOIN	SKU (NOLOCK)		 ON ( SKU.StorerKey = RECEIPTDETAIL.StorerKey 
									  AND SKU.Sku = RECEIPTDETAIL.Sku )
	 JOIN	PACK (NOLOCK)		 ON ( PACK.PackKey = SKU.PackKey ) 
	 JOIN	LOC RDLOC (NOLOCK) ON ( RECEIPTDETAIL.ToLoc = RDLOC.Loc )
   WHERE ( RECEIPTDETAIL.Receiptkey = @c_receiptkey ) 
	GROUP BY RECEIPTDETAIL.ReceiptKey,
			RECEIPTDETAIL.Sku,
			SKU.DESCR,
			RECEIPTDETAIL.UOM,
			RECEIPTDETAIL.Lottable02,
			RECEIPTDETAIL.Lottable04,
			ISNULL(RDLOC.HOSTWHCODE, '')
	UNION ALL
   SELECT RECEIPT.Receiptkey,
			PICKDETAIL.Sku AS Sku,
			SKU.DESCR AS DESCR,
			ORDERDETAIL.UOM AS UOM,
			LOTATTRIBUTE.Lottable02 AS Lottable02,
			LOTATTRIBUTE.Lottable04 AS Lottable04,
			ISNULL(PDLOC.HOSTWHCODE, '') AS HOSTWHCODE,
			SUM(CASE WHEN ORDERDETAIL.UOM = PACK.PackUOM1 THEN PICKDETAIL.QTY/PACK.CaseCnt 
						WHEN ORDERDETAIL.UOM = PACK.PackUOM2 THEN PICKDETAIL.QTY/PACK.InnerPack   
						WHEN ORDERDETAIL.UOM = PACK.PackUOM4 THEN PICKDETAIL.QTY/PACK.Pallet  
				  ELSE PICKDETAIL.QTY
				  END) AS QTY,
			SUM(PICKDETAIL.QTY) AS LowerQTY,
			'EO' AS ReceiptType
    FROM RECEIPT (NOLOCK)   
	 JOIN	ORDERS (NOLOCK)			ON ( RECEIPT.Storerkey = ORDERS.Storerkey
										    AND RECEIPT.ExternReceiptKey = ORDERS.ExternOrderKey )
	 JOIN	ORDERDETAIL (NOLOCK)		ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
	 JOIN	PICKDETAIL (NOLOCK)		ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey 
											 AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )
	 JOIN	MBOL (NOLOCK)				ON ( ORDERS.MbolKey = MBOL.MbolKey )
	 JOIN	SKU (NOLOCK)				ON ( SKU.Storerkey = PICKDETAIL.Storerkey 
											 AND SKU.Sku = PICKDETAIL.Sku )
	 JOIN	PACK (NOLOCK)		 ON ( PACK.PackKey = SKU.PackKey ) 
	 JOIN	LOTATTRIBUTE (NOLOCK)	ON ( PICKDETAIL.Lot = LOTATTRIBUTE.Lot )
	 JOIN	LOC PDLOC (NOLOCK)		ON ( PICKDETAIL.Loc = PDLOC.Loc ) 
	 JOIN	STORER BSTORER (NOLOCK) ON ( ORDERS.Billtokey = BSTORER.StorerKey )
   WHERE ( ORDERS.Type = '6' ) and   
			( RECEIPT.Receiptkey = @c_receiptkey ) 
	GROUP BY RECEIPT.Receiptkey,
			PICKDETAIL.Sku,
			SKU.DESCR,
			ORDERDETAIL.UOM,
			LOTATTRIBUTE.Lottable02,
			LOTATTRIBUTE.Lottable04,
			ISNULL(PDLOC.HOSTWHCODE, '')

	SELECT @n_err = @@ERROR
	IF @n_err <> 0 
	BEGIN
		SELECT @n_continue = 3
		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63301  
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into #TEMPSUMMARY Failed. (nsp_receiptsummary06)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
	END -- @n_err = 0 


   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
	  SELECT *
	  FROM #TEMPHEADER, #TEMPSUMMARY 
	  WHERE #TEMPHEADER.ReceiptKey = #TEMPSUMMARY.ReceiptKey
   END -- @n_continue = 1 OR @n_continue = 2

	DROP Table #TEMPSUMMARY 

   IF @n_continue=3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_receiptsummary06'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END


GO