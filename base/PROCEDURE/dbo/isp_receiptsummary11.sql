SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_receiptsummary11                                */
/* Creation Date: 16-Jun-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: Return Summary                                              */
/*                                                                      */
/* Called By: r_dw_receipt_summary11                                    */
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

CREATE PROC [dbo].[isp_receiptsummary11] (@c_receiptkey NVARCHAR(10)) 
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

	CREATE TABLE #TEMRECSUMM11 (
			ReceiptKey		      NVARCHAR(10) NULL,
			StorerKey		      NVARCHAR(15) NULL,
			SellerCompany        NVARCHAR(45) NULL,
			CarrierReference  	NVARCHAR(18) NULL, 
			UserDefine03  		   NVARCHAR(30) NULL,  
			RECDATE  		      DATETIME NULL,  
			UserDefine04  		   NVARCHAR(30) NULL,   
			UserDefine05  		   NVARCHAR(30) NULL, 
			ExtReceiptKey 		   NVARCHAR(20) NULL,  
			UserDefine01  		   NVARCHAR(30) NULL,
			SKU   		 		   NVARCHAR(20) NULL,  
			SNC		 		      NVARCHAR(20) NULL,  
			RECQty          	   INT NULL,  
			PST   		         NVARCHAR(20) NULL,		
			SLength				   FLOAT NULL,		
			Swidth			      FLOAT NULL,		
			SHeight              FLOAT NULL,		
			TTLCube	            FLOAT NULL,		
			TTLGWGT              FLOAT NULL)
		
	   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 

	INSERT INTO #TEMRECSUMM11
   SELECT REC.ReceiptKey,REC.StorerKey,REC.SellerCompany,REC.CarrierReference,
	       REC.UserDefine03,rec.ReceiptDate,REC.UserDefine04,REC.UserDefine05,RD.ExternReceiptKey,
	       REC.UserDefine01,RD.Sku,CASE WHEN S.SerialNoCapture='1' THEN 'FG' ELSE 'S&A' END AS SNC,
			 SUM(RD.QtyReceived) AS RECQty,
			 CASE WHEN L.LocationRoom='Y' THEN N'破损' ELSE N'完好' END AS PST,
			 S.Length,s.Width,s.Height,SUM(s.STDCUBE*RD.QtyReceived) AS TTLCube,
			 SUM(s.STDGROSSWGT*RD.QtyReceived) AS GWGT 
	FROM RECEIPT REC WITH (NOLOCK)
	JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.ReceiptKey=REC.ReceiptKey
	JOIN SKU S WITH (NOLOCK) ON S.sku = RD.Sku AND s.StorerKey=RD.StorerKey
	JOIN LOC L WITH (NOLOCK) ON L.Loc=RD.ToLoc
	WHERE REC.ReceiptKey = @c_receiptkey
	GROUP BY REC.ReceiptKey,REC.StorerKey,REC.SellerCompany,REC.CarrierReference,
	REC.UserDefine03,rec.ReceiptDate,REC.UserDefine04,REC.UserDefine05,RD.ExternReceiptKey,
	REC.UserDefine01,RD.Sku,CASE WHEN S.SerialNoCapture='1' THEN 'FG' ELSE 'S&A' END,
	 CASE WHEN L.LocationRoom='Y' THEN N'破损' ELSE N'完好' END,
	 S.Length,s.Width,s.Height
	ORDER BY REC.ReceiptKey desc

	

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
	  SELECT *
	  FROM #TEMRECSUMM11
   END -- @n_continue = 1 OR @n_continue = 2

	DROP Table #TEMRECSUMM11 

   IF @n_continue=3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_receiptsummary11'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END

GO