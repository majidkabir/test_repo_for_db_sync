SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetReceiptQCCLabel01                        	  */
/* Creation Date: 2009-09-28                            		            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                         				    */
/*                                                                      */
/* Purpose:  print QCC Label in ASN for timberland China (Footwear)			*/
/*                                                                      */
/* Input Parameters:  @c_receiptkey - receiptkey        								*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_receipt_qcclabel01          				*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from ASN                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-DEC-2009  ChewKP01  1.1   SOS#147298 Rework (ChewKP01)            */
/* 27-JAN-2010	NJOW01    1.2   147298 - QCC label enhancements         */
/* 31-OCT-2012  NJOW02    1.3   SOS#260364 - Remove product care        */
/* 13-AUG-2013	NJOW03    1.4   286576-QCC Label change mapping to      */
/*                              skuinfo.                                */
/************************************************************************/

CREATE PROC [dbo].[isp_GetReceiptQCCLabel01] (@c_receiptkey NVARCHAR(10)) 
AS
BEGIN
	 SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @n_continue	 int,
		      @c_errmsg	   NVARCHAR(255),
		      @b_success	 int,
		      @n_err			 int,
		      @n_rowid     int,
		      @n_cnt       int
		   
  DECLARE @c_style     NVARCHAR(30),
          @c_busr7     NVARCHAR(30),
          @c_color     NVARCHAR(10),
          @c_susr1     NVARCHAR(30),
          @c_susr2     NVARCHAR(30),
          @c_ivas      NVARCHAR(30),
          @c_susr5     NVARCHAR(30),
          @c_countryorigin NVARCHAR(50),
          @n_cost      float,
          @c_cocompany NVARCHAR(45),
          @c_coaddress1 NVARCHAR(45),
          @c_grade     NVARCHAR(50),
          @c_company   NVARCHAR(45),
          @c_address1  NVARCHAR(45),
          @c_address2  NVARCHAR(45),
          @c_model     NVARCHAR(50),
          @n_qty       int,
          @c_sku       NVARCHAR(20),
          @c_busr4     NVARCHAR(30), --(ChewKP01)
          @c_busr8     NVARCHAR(30),  --(ChewKP01)
          @c_phone1    NVARCHAR(18), --NJOW01
          @c_note1     NVARCHAR(215), --NJOW01
          @c_itemclass NVARCHAR(10), --NJOW01
          @c_extendedfield12 NVARCHAR(30) --NJOW03

  SELECT @n_continue = 1, @n_err = 0, @b_success = 1, @c_errmsg = ''
  
  CREATE TABLE #TMP_LABEL (
          rowid     int identity(1,1),
          style     NVARCHAR(30) NULL,  --skuinfo.extendedfield11
          busr7     NVARCHAR(30) NULL,  --skuinfo.extendedfield06
          color     NVARCHAR(10) NULL,
          susr1     NVARCHAR(30) NULL,
          susr2     NVARCHAR(30) NULL,
          ivas      NVARCHAR(30) NULL,  --skuinfo.extendedfield09
          susr5     NVARCHAR(30) NULL,  --skuinfo.extendedfield03
          countryorigin NVARCHAR(50) NULL,
          cost      float NULL,  --skuinfo.extendedfield08
          cocompany NVARCHAR(45) NULL,
          coaddress1 NVARCHAR(45) NULL,
          grade     NVARCHAR(50) NULL,
          company   NVARCHAR(45) NULL,
          address1  NVARCHAR(45) NULL,
          address2  NVARCHAR(45) NULL,
          model     NVARCHAR(50) NULL,
          busr4     NVARCHAR(30) NULL, --(ChewKP01)    --skuinfo.extendedfield05
          busr8     NVARCHAR(30) NULL,  --(ChewKP01)
          phone1    NVARCHAR(18) NULL, --NJOW01
          note1     NVARCHAR(215) NULL, --NJOW01  --skuinfo.extendedfield021
          itemclass NVARCHAR(10) NULL, --NJOW01
          extendedfield12 NVARCHAR(30) NULL) --NJOW03

  IF @n_continue = 1 OR @n_continue = 2
  BEGIN
     SELECT IDENTITY(int,1,1) AS rowid, 
            ISNULL(SIF.ExtendedField11,'') AS style, --NJOW03
            ISNULL(SIF.ExtendedField06,'') AS busr7,  --NJOW03
            SKU.color, SKU.susr1, SKU.susr2, 
            ISNULL(SIF.ExtendedField09,'') AS ivas,  --NJOW03
            ISNULL(SIF.ExtendedField03,'') AS susr5,  --NJOW03
            CASE WHEN ISNUMERIC(SIF.ExtendedField08)=1 THEN CAST(SIF.ExtendedField08 AS Float) ELSE 0.00 END AS cost, --NJOW03
            CLC.Long AS CountryOrigin, CNTRORG.Company AS COCompany, CNTRORG.Address1 AS COAddress1,
            CLQ.Long AS Grade, STORER.Company, STORER.Address1, STORER.Address2,
            CASE WHEN substring(SKU.BUSR3,5,2) = 'FT' THEN
                 (SELECT CL.long 
                 FROM CODELKUP CL (NOLOCK) 
                 WHERE CL.listname = 'TBLSize' and
                 SKU.SkuGroup = CL.UDF01 and 
                 SKU.Size = CL.UDF02)
            ELSE
               replace(substring(SKU.sku,17,4),'-','')
            END AS Model,                                   
            CASE WHEN RD.FinalizeFlag = 'Y' THEN
                 RD.QtyReceived
            ELSE
                 RD.BeforeReceivedQty
            END AS Qty,
            SKU.Sku , 
            ISNULL(SIF.ExtendedField05,'') AS busr4, --NJOW03
            SKU.busr8, --(ChewKP01)
            STORER.Phone1, 
            CONVERT(NVARCHAR(215),SIF.ExtendedField21) AS Note1, --NJOW03
            substring(SKU.BUSR3,5,2) AS Itemclass, --NJOW03
            ISNULL(SIF.ExtendedField12,'') AS ExtendedField12 --NJOW03
     INTO #TMP_REC
     FROM RECEIPTDETAIL RD (NOLOCK)
     JOIN SKU (NOLOCK) ON (RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku)
     LEFT JOIN SKUINFO SIF (NOLOCK) ON (RD.Storerkey = SIF.Storerkey AND RD.Sku = SIF.Sku) --NJOW03 
     LEFT JOIN CODELKUP CLC (NOLOCK) ON (CLC.ListName = 'TBLCountry' 
                                         AND CLC.Short = case when charindex('-',SIF.ExtendedField04) > 0 
                                             THEN substring(ISNULL(SIF.ExtendedField04,''),1,charindex('-',ISNULL(SIF.ExtendedField04,''))-1) 
                                             ELSE ISNULL(SIF.ExtendedField04,'') END)
     LEFT JOIN STORER CNTRORG (NOLOCK) ON (SIF.ExtendedField04 = CNTRORG.Storerkey AND CNTRORG.Consigneefor = 'TBL')
     LEFT JOIN CODELKUP CLQ (NOLOCK) ON (CLQ.ListName = 'TBLQual' and substring(SKU.Sku,12,1) = CLQ.Code)
     JOIN STORER (NOLOCK) ON (RD.Storerkey = STORER.Storerkey) 
     --WHERE SKU.ItemClass IN('F','Z') 
     --WHERE SKU.ItemClass IN('F') --NJOW02
     WHERE substring(SKU.BUSR3,5,2) = 'FT' --NJOW03
     AND RD.Receiptkey = @c_receiptkey AND
     CASE WHEN RD.FinalizeFlag = 'Y' THEN  
                 RD.QtyReceived  
            ELSE  
                 RD.BeforeReceivedQty  
            END  > 0 
     ORDER BY RD.Userdefine01, RD.Sku 
  END
  
  IF @n_continue = 1 OR @n_continue = 2
  BEGIN
  	 SELECT @n_rowid = 0
  	 WHILE 1=1
  	 BEGIN
  	 	  SET ROWCOUNT 1
  	 	  SELECT @n_rowid = rowid, @c_style = style, @c_busr7 = busr7, @c_color = color, @c_susr1 = susr1, @c_susr2 = susr2, 
  	 	         @c_ivas = ivas, @c_susr5 = susr5, @n_cost = cost, @c_countryorigin = countryorigin, @c_cocompany = cocompany,
  	 	         @c_coaddress1 = coaddress1, @c_grade = grade, @c_company = company, @c_address1 = address1, @c_address2 = address2,
  	 	         @c_model = model, @n_qty = qty, @c_sku = sku, @c_busr4 = busr4, @c_busr8 = busr8, --(ChewKP01)
  	 	         @c_phone1 = phone1, @c_note1 = note1, @c_itemclass = itemclass, --NJOW01
  	 	         @c_extendedfield12 = extendedfield12 --NJOW03
  	 	  FROM #TMP_REC
  	 	  WHERE rowid > @n_rowid
  	 	  ORDER BY rowid
  	 	  SELECT @n_cnt = @@ROWCOUNT  	 	  
  	 	  SET ROWCOUNT 0
  	 	  
  	 	  IF @n_cnt = 0
  	 	     BREAK
  	 	  
  	 	  IF @n_Qty > 0
  	 	  BEGIN
        	 	  IF ISNULL(@c_style,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61380
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Style(ExtendedField11) cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_busr7,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61381
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField06 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END  
         	 	  IF ISNULL(@c_busr4,'') = '' AND @c_itemclass = 'FT' --NJOW01 --(ChewKP01)
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61382
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Color(ExtendedField05) cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  /*IF ISNULL(@c_busr8,'') = '' --(ChewKP01)
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61383
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Busr8 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END */
        	 	  /*IF ISNULL(@c_susr2,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61384
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Susr2 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END*/ 
        	 	  IF ISNULL(@c_model,'') = '' AND @c_itemclass = 'FT' --NJOW01
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61385
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Model cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_ivas,'') = '' AND @c_itemclass = 'FT' --NJOW01
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61386
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField09 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_grade,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61387
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Grade cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_company,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61388
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Company cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_susr5,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61389
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField03 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF @n_cost = 0
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61390
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Cost(ExtendedField08) cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_countryorigin,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61391
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Country Of Origin cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END
        	 	  IF ISNULL(@c_note1,'') = '' --NJOW03
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61392
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField21 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END
  	 	  END -- @n_Qty > 0  	 	     
  	 	  
  	 	  WHILE @n_qty > 0
  	 	  BEGIN
  	 	     INSERT #TMP_LABEL (style, busr7, color, susr1, susr2, ivas, susr5, countryorigin, cost,
  	 	                        cocompany, coaddress1, grade, company, address1, address2, model, busr4 ,busr8, phone1, note1, itemclass, --(ChewKP01)
  	 	                        extendedfield12)
  	 	                VALUES (@c_style, @c_busr7, @c_color, @c_susr1, @c_susr2, @c_ivas, @c_susr5, @c_countryorigin, @n_cost,
  	 	                        @c_cocompany, @c_coaddress1, @c_grade, @c_company, @c_address1, @c_address2, @c_model, @c_busr4 , @c_busr8, @c_phone1, @c_note1, @c_itemclass, --(ChewKP01)
  	 	                        @c_extendedfield12)
  	 	     
  	 	     SELECT @n_qty = @n_qty - 1
  	 	  END
  	 END
  END

  IF @n_continue=3
  BEGIN
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetReceiptQCCLabel01'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     SELECT style, busr7, color, susr1, susr2, ivas, susr5, countryorigin, cost,
  	        cocompany, coaddress1, grade, company, address1, address2, model,busr4 ,busr8, phone1, note1, itemclass, --(ChewKP01)
  	        extendedfield12
  	 FROM #TMP_LABEL 
  	 WHERE 1=2
     RETURN
  END
  ELSE
     SELECT style, busr7, color, susr1, susr2, ivas, susr5, countryorigin, cost,
  	        cocompany, coaddress1, grade, company, address1, address2, model,busr4 ,busr8, phone1, note1, itemclass, --(ChewKP01)
  	        extendedfield12 
  	 FROM #TMP_LABEL ORDER BY rowid
END         

GO