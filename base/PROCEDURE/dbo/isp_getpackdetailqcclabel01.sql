SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetPackDetailQCCLabel01                        */
/* Creation Date: 2014-05-06                            		            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                       			   */
/*                                                                      */
/* Purpose:  print QCC Label in ASN for timberland HK (Footwear)		   */
/*                                                                      */
/* Input Parameters:  @c_labelno - pickdetail.labelno  					   */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_receipt_qcc_label04_rdt     			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from ASN                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2014-06-05   CSCHONG   1.0   modify style,color field value (CS01)   */
/* 2014-06-18   CSCHONG   2.0   link the lottable01 to pickdetail (CS02)*/
/* 2014-08-14   CSCHONG   3.0   Change the logic of the field (CS03)    */
/* 2014-08-29   CSCHONG   4.0   Get the TOP 1 (CS04)                    */
/* 2016-08-17   CSCHONG   4.1   WMS-237 - Change mapping (CS05)         */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPackDetailQCCLabel01] (
        @c_labelno    NVARCHAR(20),
        @c_SKU        NVARCHAR(20),
        @c_Lottable01 NVARCHAR(18),
        @c_qty        NVARCHAR(5),
        @b_Debug      CHAR(1)=0   ) 
AS
BEGIN
	SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @n_continue	 int,
		      @c_errmsg	 NVARCHAR(255),
		      @b_success	 int,
		      @n_err		 int,
		      @n_rowid     int,
		      @n_cnt       int
		   
  DECLARE @c_style           NVARCHAR(30),
          @c_busr7           NVARCHAR(30),
          @c_color           NVARCHAR(10),
          @c_susr1           NVARCHAR(30),
          @c_susr2           NVARCHAR(30),
          @c_ivas            NVARCHAR(30),
          @c_susr5           NVARCHAR(30),
          @c_countryorigin   NVARCHAR(50),
          @n_cost            NVARCHAR(30),
          @c_cocompany       NVARCHAR(45),
          @c_coaddress1      NVARCHAR(45),
          @c_grade           NVARCHAR(50),
          @c_company         NVARCHAR(45),
          @c_address1        NVARCHAR(45),
          @c_address2        NVARCHAR(45),
          @c_model           NVARCHAR(50),
          @n_count           int,
         -- @c_sku           NVARCHAR(20),
          @c_busr4           NVARCHAR(30),
          @c_busr8           NVARCHAR(30),  
          @c_phone1          NVARCHAR(18), 
          @c_note1           NVARCHAR(215), 
          @c_itemclass       NVARCHAR(10), 
          @c_extendedfield12 NVARCHAR(30),
          @c_extendedfield03 NVARCHAR(30),
          @c_company1        NVARCHAR(215),
          @n_TTLQty          INT,
          @n_qty             INT,
          @c_EANCode         NVARCHAR(15)             --(CS05)

   DECLARE @nfrom       INT				
         , @nlen        INT				
         , @i           INT
         , @nRowNo      INT
         , @cfieldvalue NVARCHAR(45)
         , @c_storerkey NVARCHAR(15)
           

  SELECT @n_continue = 1, @n_err = 0, @b_success = 1, @c_errmsg = '',@n_TTLQty=0,@n_count=1
  SELECT @n_qty = CONVERT(INT,@c_qty)
  
  IF ISNULL(@n_qty,0) = 0
  BEGIN
     SELECT @n_qty = 0
  END

  CREATE TABLE #TMP_LABEL (
          rowid           int identity(1,1),
          style           NVARCHAR(30) NULL,  --skuinfo.extendedfield11 -- ?? 
          busr7           NVARCHAR(30) NULL,  --skuinfo.extendedfield06 -- ??
          color           NVARCHAR(10) NULL, --??
          susr1           NVARCHAR(30) NULL,
          susr2           NVARCHAR(30) NULL,
          ivas            NVARCHAR(30) NULL,  --skuinfo.extendedfield09 --???????
          susr5           NVARCHAR(30) NULL,  --skuinfo.extendedfield03 --???
          countryorigin   NVARCHAR(50) NULL,--??line1
          cost            NVARCHAR(30) NULL,   --?????
          cocompany       NVARCHAR(45) NULL, --??line2
          coaddress1      NVARCHAR(45) NULL,--??line3
          grade           NVARCHAR(50) NULL, --ExtendedField15 --??????
          company         NVARCHAR(45) NULL, --???line1
          address1        NVARCHAR(45) NULL,--???line2
          address2        NVARCHAR(45) NULL,--???line3
          model           NVARCHAR(50) NULL,  --skuinfo.extendedfield14 --??
          busr4           NVARCHAR(30) NULL,  --skuinfo.extendedfield05
          busr8           NVARCHAR(30) NULL,  
          phone1          NVARCHAR(18) NULL, --???line4
          note1           NVARCHAR(215) NULL, --??
          itemclass       NVARCHAR(10) NULL, 
          extendedfield12 NVARCHAR(30) NULL,
          extendedfield03 NVARCHAR(30) NULL,
          company1        NVARCHAR(215) NULL, --???line1
          storerkey       NVARCHAR(15) NULL, --????
          EANCode         NVARCHAR(15) NULL)   --(CS05)

  IF @n_continue = 1 OR @n_continue = 2
  BEGIN
     SELECT TOP 1 IDENTITY(int,1,1) AS rowid,                                  --(CS04)
            (ISNULL(SIF.ExtendedField11,'')) AS Style, -- + '-' +                       --(CS05)
          -- CASE WHEN ISNULL(SKU.color,'') <> '' THEN SKU.color ELSE '' END) AS style, --(CS01) --(CS05)
            ISNULL(SIF.ExtendedField06,'') AS busr7,  
            ISNULL(SIF.ExtendedField06,'') AS Color,--+ 
            --CASE WHEN ISNULL(SKU.color,'') <> '' THEN SKU.color ELSE '' END) AS Color, 
            '' as susr1,'' as susr2,--SKU.susr1, SKU.susr2, 
            ISNULL(SIF.ExtendedField09,'') AS ivas,  
            ISNULL(SIF.ExtendedField03,'') AS susr5,  
            --CASE WHEN ISNUMERIC(SIF.ExtendedField08)=1 THEN convert(Float,SIF.ExtendedField08) ELSE 0.00 END AS cost, 
            ISNULL(SIF.ExtendedField07,'') AS Cost,--(RTRIM(ORDDET1.Userdefine04) + space(3) + ORDDET1.Userdefine02 ) AS Cost,
            CASE WHEN LOTB.Lottable01 not in ('CN','CNAP') THEN CLC.UDF01                                              --(CS05)
             --    WHEN LOTB.Lottable01 in ('CN','CNAP') THEN (COOSTORER.Country+ " " + RTRIM(COOSTORER.State)+ RTRIM(COOSTORER.City)) END
            ELSE SIF.ExtendedField04 END AS CountryOrigin, CASE WHEN LOTB.Lottable01 in ('CN','CNAP') THEN COOSTORER.Company ELSE '' END AS COCompany, 
            CASE WHEN LOTB.Lottable01 in ('CN','CNAP') THEN COOSTORER.Address1 ELSE '' END AS COAddress1,
            CASE WHEN ISNULL(SIF.ExtendedField15,'') <> '' THEN SIF.ExtendedField15 ELSE CLQ.Long END AS Grade,  
            -- '' as Company,'' as Address1,'' as Address2,--'' as model,
            STORER.Company, STORER.Address1, STORER.Address2, --0 as qty,
            (SIF.ExtendedField14 + SPACE(1)+  RTRIM(SKU.Size) ) AS Model ,                               --(CS03)
           --  '(' + CASE WHEN ISNULL(sku.measurement,'') = '' then SKU.Size  ELSE 
            -- (RTRIM(SKU.Size) + '/' + RTRIM(sku.measurement)) END + ')') AS Model,                 --(CS01)                                   
--            CASE WHEN RD.FinalizeFlag = 'Y' THEN
--                 RD.QtyReceived
--            ELSE
--                 RD.BeforeReceivedQty
--            END AS Qty,
            SKU.Sku , 
            ISNULL(SIF.ExtendedField05,'') AS busr4, --+ 
            --CASE WHEN ISNULL(SKU.color,'') <> '' THEN SKU.color ELSE '' END) AS busr4, 
            '' as busr8,-- SKU.busr8, 
            STORER.Phone1, 
            --CONVERT(NVARCHAR(215),SIF.ExtendedField21) AS Note1, 
            SIF.ExtendedField21 AS Note1, 
            SIF.ExtendedField02 AS Itemclass, 
            ISNULL(SIF.ExtendedField12,'') AS ExtendedField12,
            ISNULL(SIF.ExtendedField03,'') AS ExtendedField03,
            STORER.Notes1 as Company1,
            STORER.Storerkey,
            [dbo].[fnc_CalcCheckDigit_M10] (SIF.ExtendedField13,1)    AS EANCode                                    --(CS05) 
     INTO #TMP_REC
     FROM PACKHEADER PH WITH (NOLOCK)
     JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.Pickslipno = PH.Pickslipno)
     JOIN SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku)
     LEFT JOIN ORDERS ORD WITH (NOLOCK) ON Ord.Orderkey=PH.Orderkey
     CROSS APPLY
     (SELECT TOP 1 OrdDet.userdefine04,OrdDet.userdefine02 
      FROM Orderdetail OrdDet WITH (NOLOCK) 
      WHERE OrdDet.Orderkey = ORD.Orderkey AND OrdDet.sku=PD.SKU
     Order by sku ) ORDDET1
     LEFT JOIN SKUINFO SIF WITH (NOLOCK) ON (PD.Storerkey = SIF.Storerkey AND PD.Sku = SIF.Sku)
     LEFT JOIN PICKDETAIL  PICKDET WITH (NOLOCK) ON PICKDET.Orderkey = PH.Orderkey AND PICKDET.SKU = PD.SKU   --CS02
     LEFT JOIN LOTATTRIBUTE LOTB WITH (NOLOCK) ON (PICKDET.Lot = LOTB.Lot AND PICKDET.Sku = LOTB.Sku)         --CS02
     LEFT JOIN CODELKUP CLC WITH (NOLOCK) ON (CLC.ListName = 'VFCOO' 
                                         AND CLC.code = LOTB.lottable01)
     LEFT JOIN Storer COOSTORER WITH (NOLOCK) ON ( COOSTORER.Storerkey=SIF.ExtendedField04 AND COOSTORER.consigneefor = ORD.Storerkey)
     LEFT JOIN CODELKUP CLQ WITH (NOLOCK) ON (CLQ.ListName = 'TBLQual' and substring(SKU.Sku,12,1) = CLQ.Code)
     JOIN STORER WITH (NOLOCK) ON (ORD.Storerkey = STORER.Storerkey) 
     LEFT JOIN STORER CNTRORG WITH (NOLOCK) ON (SIF.ExtendedField04 = CNTRORG.Storerkey AND ORD.Storerkey = CNTRORG.consigneeFor)
     --WHERE SKU.ItemClass IN('F','Z') 
     --WHERE SKU.ItemClass IN('F') 
     WHERE SIF.ExtendedField02 IN('FT','PC') 
     AND PD.labelno = @c_labelno 
     AND PD.SKU = CASE WHEN ISNULL(RTRIM(@c_SKU),'') <> '' THEN @c_SKU ELSE PD.SKU END 
     AND LOTB.lottable01 = CASE WHEN ISNULL(RTRIM(@c_lottable01),'') <> '' THEN @c_lottable01 ELSE LOTB.lottable01 END         
--     CASE WHEN RD.FinalizeFlag = 'Y' THEN  
--                 RD.QtyReceived  
--            ELSE  
--                 RD.BeforeReceivedQty  
--            END  > 0 
--     ORDER BY RD.Userdefine01, PD.Sku 
  END
 -- select 'get table '
  --select * from #TMP_REC

  DECLARE C_Initial_Record CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
  SELECT rowid,Storerkey 
  FROM #TMP_REC
  ORDER BY rowid
  
  OPEN C_Initial_Record             
  FETCH NEXT FROM C_Initial_Record INTO @nRowNo   
                                      , @c_Storerkey  

     WHILE @@FETCH_STATUS=0              
     BEGIN 
 
      SET @cfieldvalue = ''
      				
      SET @nfrom = 1 
      SET @nlen = 0 
      SET @i = 1	
			
      WHILE @i <= 4			
      BEGIN	
         		
         SELECT @nlen = patindex('%'+char(13)+char(10)+'%',substring(notes1,@nfrom,1000)) - 1 
         FROM STORER WITH (NOLOCK) 
         WHERE storerkey  = @c_storerkey				

         SELECT @nlen = CASE WHEN @nlen > 0 THEN @nlen ELSE 1000 END
			
         SELECT @cfieldvalue = substring(notes1,@nfrom,@nlen) 
         FROM STORER WITH (NOLOCK) 
         WHERE storerkey  = @c_storerkey		
         
         --select @nfrom = @nfrom + @nlen + 2 , @i = @i+1		
         
      -- select @cfieldvalue
      --select convert(nvarchar(5),LEN(@cfieldvalue))

      IF @i = 1 
      BEGIN
         UPDATE #TMP_REC
         SET company = @cfieldvalue
         WHERE rowid = @nRowNo
      END

      ELSE IF @i = 2 
      BEGIN
         UPDATE #TMP_REC
         SET address1 = @cfieldvalue
         WHERE rowid = @nRowNo
      END
      ELSE IF @i = 3 
      BEGIN
         UPDATE #TMP_REC
         SET address2 = @cfieldvalue
         WHERE rowid = @nRowNo
      END
      ELSE IF @i = 4
      BEGIN
         UPDATE #TMP_REC
         SET phone1 = @cfieldvalue
         WHERE rowid = @nRowNo
      END

      --select * from #tempfield				
         SET @nfrom = @nfrom + @nlen + 2 
         SET @i = @i+1				
      END
  
   FETCH NEXT FROM C_Initial_Record INTO @nRowNo 
                                        ,@c_Storerkey 

     END                 
     CLOSE C_Initial_Record            
     DEALLOCATE C_Initial_Record

  IF @n_qty <> 0
  BEGIN
    WHILE (@n_count <@n_qty)
      BEGIN
       INSERT INTO #TMP_REC (style, susr1, susr2,busr7, color,ivas, susr5,cost,countryorigin,cocompany,
  	 	                       coaddress1, grade, company, address1,address2, model, sku, busr4, busr8, 
  	 	                       phone1, note1, itemclass,extendedfield12,extendedfield03,company1,storerkey,EANCode)       --(CS05)
       SELECT TOP 1 style, susr1, susr2,busr7, color,ivas, susr5,cost,countryorigin,cocompany,
  	 	              coaddress1, grade, company, address1,address2, model, sku, busr4, busr8, 
  	 	              phone1, note1, itemclass,extendedfield12,extendedfield03,company1,storerkey,EANCode                 --(CS05)
       FROM #TMP_REC
       ORDER BY rowid
      
       SELECT @n_count = @n_count + 1
      END
  END

  IF @n_continue = 1 OR @n_continue = 2
  BEGIN
  	 SELECT @n_rowid = 0
  	 WHILE 1=1
  	 BEGIN
  	 	  SET ROWCOUNT 1
  	 	  SELECT @n_rowid = rowid, @c_style = style, @c_susr1 = susr1, @c_susr2 = susr2,@c_busr7 = busr7, @c_color = color, --@c_susr1 = susr1, @c_susr2 = susr2, 
  	 	         @c_ivas = ivas, @c_susr5 = susr5, @n_cost = cost, @c_countryorigin = countryorigin, @c_cocompany = cocompany,
  	 	         @c_coaddress1 = coaddress1, @c_grade = grade, @c_company = company, @c_address1 = address1, @c_address2 = address2,
  	 	         @c_model = model,@c_sku = sku, @c_busr4 = busr4, @c_busr8 = busr8, 
  	 	         @c_phone1 = phone1, @c_note1 = note1, @c_itemclass = itemclass, 
  	 	         @c_extendedfield12 = extendedfield12,@c_extendedfield03 = extendedfield03,@c_company1 = company1,@c_EANCode=EANCode                 --(CS05)
  	 	         
  	 	  FROM #TMP_REC
  	 	  WHERE rowid > @n_rowid
  	 	  ORDER BY rowid
  	 	  SELECT @n_cnt = @@ROWCOUNT  	 	  
  	 	  SET ROWCOUNT 0
  	 	  
  	 	  IF @n_cnt = 0
  	 	     BREAK
  	 	  
--  	 	  IF @n_Qty > 0
--  	 	  BEGIN
--        	 	  IF ISNULL(@c_style,'') = ''
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61380
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Style(ExtendedField11) cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  IF ISNULL(@c_busr7,'') = ''
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61381
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField06 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END  
--         	 	  IF ISNULL(@c_busr4,'') = '' AND @c_itemclass = 'FT' 
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61382
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Color(ExtendedField05) cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  /*IF ISNULL(@c_busr8,'') = '' --(ChewKP01)
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61383
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Busr8 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END */
--        	 	  /*IF ISNULL(@c_susr2,'') = ''
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61384
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Susr2 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END*/ 
--        	 	  IF ISNULL(@c_model,'') = '' AND @c_itemclass = 'FT' 
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61385
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Model cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  IF ISNULL(@c_ivas,'') = '' AND @c_itemclass = 'FT' 
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61386
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField09 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  IF ISNULL(@c_grade,'') = ''
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61387
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Grade cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  IF ISNULL(@c_company,'') = ''
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61388
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Storer Company cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  IF ISNULL(@c_susr5,'') = ''
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61389
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField03 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  IF @n_cost = 0
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61390
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Cost(ExtendedField08) cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END 
--        	 	  IF ISNULL(@c_countryorigin,'') = ''
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61391
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Country Of Origin cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END
--        	 	  IF ISNULL(@c_note1,'') = '' 
--        	 	  BEGIN
--        	 	  	 SELECT @n_continue = 3
--        	 	  	 SELECT @n_err = 61392
--        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField21 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
--        	 	  	 BREAK
--        	 	  END
--  	 	  END -- @n_Qty > 0  	 	     
  	 	  
--  	 	  WHILE @n_qty > 0
--  	 	  BEGIN
  	 	     INSERT #TMP_LABEL (style, busr7, color,susr1, susr2, ivas, susr5, countryorigin, cost,
  	 	                        cocompany, coaddress1, grade, company, address1, address2, model, busr4,busr8 , phone1, note1, itemclass, --(ChewKP01)
  	 	                        extendedfield12,extendedfield03,company1,EANCode)                --(CS05)
  	 	                VALUES (@c_style, @c_busr7, @c_color, @c_susr1, @c_susr2,@c_ivas, @c_susr5, @c_countryorigin, @n_cost,
  	 	                        @c_cocompany, @c_coaddress1, @c_grade, @c_company, @c_address1, @c_address2, @c_model, @c_busr4,@c_busr8 , @c_phone1, @c_note1, @c_itemclass, --(ChewKP01)
  	 	                        @c_extendedfield12,@c_extendedfield03,@c_company1,@c_EANCode)
  	 	     
  	 	     --SELECT @n_qty = @n_qty - 1
--  	 	  END
  	 END
  END

  IF @n_continue=3
  BEGIN
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetReceiptQCCLabel01'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     SELECT style, busr7, color, ivas, susr5, countryorigin, cost,
  	        cocompany, coaddress1, grade, company, address1, address2, model,busr4,busr8 ,phone1, note1, itemclass, 
  	        extendedfield12,extendedfield03,company1,EANCode                                  --(CS05)
  	 FROM #TMP_LABEL 
  	 WHERE 1=2
     RETURN
  END
  ELSE
     SELECT style, busr7, color, susr1, susr2,ivas, susr5, countryorigin, cost,
  	        cocompany, coaddress1, grade, company, address1, address2, model,busr4 ,busr8, phone1, note1, itemclass, --(ChewKP01)
  	        extendedfield12,extendedfield03,company1,rowid,EANCode            --(CS05)
  	 FROM #TMP_LABEL ORDER BY rowid
END         

GO