SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_GetReceiptQCCLabel02                        	*/
/* Creation Date: 2009-09-28                            		            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                         				*/
/*                                                                      */
/* Purpose:  print QCC Label in ASN for timberland China (Non Footwear) */
/*                                                                      */
/* Input Parameters:  @c_receiptkey - receiptkey        					   */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_receipt_qcclabel02          			*/
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
/* 27-JAN-2010	 NJOW01    1.2   147298 - QCC label enhancements         */
/* 27-DEC-2011  NJOW02    1.3   233216 - Change formula to include      */
/*                              codelkup udf01                          */
/* 13-Aug-2013  NJOW03    1.4   286578-QCC Label change mapping to      */
/*                              skuinfo.                                */
/* 10-Aug-2013  CSCHONG   1.5   SOS349616 (CS01)                        */
/************************************************************************/

CREATE PROC [dbo].[isp_GetReceiptQCCLabel02] (@c_receiptkey NVARCHAR(10)) 
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
		   
  DECLARE @c_style     NVARCHAR(30), --skuinfo.extendedfield11
          @c_busr7     NVARCHAR(30), --skuinfo.extendedfield06
          @c_color     NVARCHAR(10),
          @c_ovas      NVARCHAR(30),
          @c_busr8     NVARCHAR(100),
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
          @n_qty       int,
          @c_sku       NVARCHAR(20),
          @c_susr1     NVARCHAR(30),
          @c_itemclass NVARCHAR(10), 
          @c_busr4     NVARCHAR(30), --(ChewKP01) --skuinfo.extendedfield05
          @c_phone1    NVARCHAR(18), --NJOW01
          @c_model     NVARCHAR(50), --NJOW01
          @c_icon1     NVARCHAR(10), --NJOW01
          @c_icon2     NVARCHAR(10), --NJOW01
          @c_icon3     NVARCHAR(10), --NJOW01
          @c_icon4     NVARCHAR(10), --NJOW01
          @c_icon5     NVARCHAR(10), --NJOW01
          @c_icon6     NVARCHAR(10), --NJOW01
          @c_icon7     NVARCHAR(10), --NJOW01
          @c_icon8     NVARCHAR(10), --NJOW01
          @c_note1     NVARCHAR(215), --NJOW01
          @c_note2     NVARCHAR(215), --NJOW01
          @c_busr10    NVARCHAR(30), --NJOW01 --skuinfo.extendedfield07
          @c_extendedfield12 NVARCHAR(30), --NJOW03
          @c_extendedfield01 NVARCHAR(30), --NJOW03
          @c_extendedfield02 NVARCHAR(30) --NJOW03

  SELECT @n_continue = 1, @n_err = 0, @b_success = 1, @c_errmsg = ''
  
  CREATE TABLE #TMP_LABEL (
          rowid     int identity(1,1),
          style     NVARCHAR(30) NULL,
          busr7     NVARCHAR(30) NULL,
          color     NVARCHAR(10) NULL,
          ovas      NVARCHAR(30) NULL,
          busr8     NVARCHAR(100) NULL,
          ivas      NVARCHAR(30) NULL,
          susr5     NVARCHAR(30) NULL,
          countryorigin NVARCHAR(50) NULL,
          cost      float NULL,
          cocompany NVARCHAR(45) NULL,
          coaddress1 NVARCHAR(45) NULL,
          grade     NVARCHAR(50) NULL,
          company   NVARCHAR(45) NULL,
          address1  NVARCHAR(45) NULL,
          address2  NVARCHAR(45) NULL,
          susr1     NVARCHAR(30) NULL,
          itemclass NVARCHAR(10) NULL,
          busr4     NVARCHAR(30) NULL, --(ChewKP01)
          phone1    NVARCHAR(18) NULL, --NJOW01
          model     NVARCHAR(50) NULL, --NJOW01
          icon1     NVARCHAR(10) NULL, --NJOW01
          icon2     NVARCHAR(10) NULL, --NJOW01
          icon3     NVARCHAR(10) NULL, --NJOW01
          icon4     NVARCHAR(10) NULL, --NJOW01
          icon5     NVARCHAR(10) NULL, --NJOW01
          icon6     NVARCHAR(10) NULL, --NJOW01
          icon7     NVARCHAR(10) NULL, --NJOW01
          icon8     NVARCHAR(10) NULL, --NJOW01
          note1     NVARCHAR(215) NULL, --NJOW01
          note2     NVARCHAR(215) NULL, --NJOW01
          extendedfield12 NVARCHAR(30) NULL --NJOW03 
)
   
  IF @n_continue = 1 OR @n_continue = 2
  BEGIN
  	 SELECT IDENTITY(int,1,1) AS rowid, 
  	        ISNULL(SIF.ExtendedField11,'') AS style, --NJOW03
  	        ISNULL(SIF.ExtendedField06,'') AS busr7, --NJOW03
  	        SKU.color, 
  	        ISNULL(SIF.ExtendedField10,'') AS ovas, --NJOW03
  	        CL2.Long AS susr1, 
  	        ISNULL(SIF.ExtendedField09,'') AS ivas, --NJOW03 
  	        SKU.susr5, 
            CASE WHEN ISNUMERIC(SIF.ExtendedField08)=1 THEN CAST(SIF.ExtendedField08 AS Float) ELSE 0.00 END AS cost, --NJOW03
            CASE WHEN ISNULL(CL3.Short,'') = '3' THEN
                    RTRIM(ISNULL(CLC.Long,'')) + ' ' + LTRIM(RTRIM(ISNULL(CNTRORG.State,''))) + LTRIM(RTRIM(ISNULL(CNTRORG.City,'')))
               ELSE CLC.Long 
            END AS CountryOrigin, 
            CNTRORG.Company AS COCompany, CNTRORG.Address1 AS COAddress1,
            CASE WHEN ISNULL(SIF.ExtendedField15,'') <> '' THEN SIF.ExtendedField15 ELSE CLQ.Long END AS Grade, --NJOW03
            STORER.Company, STORER.Address1, STORER.Address2,
            CASE WHEN RD.FinalizeFlag = 'Y' THEN
                 RD.QtyReceived
            ELSE
                 RD.BeforeReceivedQty
            END AS Qty,
            SKU.Sku,
            --SKU.Susr1,
            CASE WHEN substring(SKU.BUSR3,5,2) = 'AP' THEN 
                   'AP'
                 WHEN substring(SKU.BUSR3,5,2) IN ('AC','EQ') AND ISNULL(CL3.Code,'') <> ''  THEN
                   'AC'+LTRIM(ISNULL(CL3.Short,''))
                 ELSE ''
            END AS Itemclass, --NJOW03 
            ISNULL(SIF.ExtendedField05,'') AS busr4, --NJOW03
            SKU.busr8,  --(ChewKP01)
            STORER.Phone1, --NJOW01
            CASE WHEN substring(SKU.BUSR3,5,2) = 'AP' THEN  --NJOW03
                    (SELECT CASE WHEN CL.UDF01 = '1' THEN
                                 RTRIM(CL.Long) + '(' +RTRIM(CL.Short) + '/' + replace(ltrim(replace(Rtrim(SKU.Measurement),'0',' ')),' ','0') + ')'  
                               ELSE
                                 CL.long 
                            END 
                    FROM CODELKUP CL (NOLOCK) 
                    WHERE CL.listname = 'TBLSize_A' 
                    AND SIF.ExtendedField02 = SUBSTRING(CL.code,1,CHARINDEX('_',CL.code) - 1) 
                    AND Sku.Size = CL.UDF03)                    
                 WHEN substring(SKU.BUSR3,5,2) IN ('AC','EQ') AND ISNULL(CL3.Code,'') <> '' THEN  --NJOW01
                    CASE WHEN ISNULL(CL4.Long,'') <> '' THEN
                         RTRIM(CL4.Long) + '(' +CASE WHEN ISNULL(CL5.Code,'') <> '' THEN                        
                                                    CL5.Short                                                   
                                                ELSE                                                            
                                                    CASE WHEN ISNUMERIC(SKU.Size) = 1 THEN                      
                                                				CAST(CAST(SKU.Size AS int) / 10 AS NVARCHAR(3))          
                                                	  ELSE                                                          
                                                				REPLACE(LTRIM(REPLACE(RTRIM(SKU.Size),'0',' ')),' ','0') 
                                                	  END                                                           
                                                END + ')'                                                       
                    ELSE                   
                       CASE WHEN ISNULL(SIF.ExtendedField14,'') <> '' THEN
                           RTRIM(SIF.ExtendedField14) + '(' +CASE WHEN ISNULL(CL5.Code,'') <> '' THEN                           
                                                                 CL5.Short                                                      
                                                             ELSE                                                               
                                                               CASE WHEN ISNUMERIC(SKU.Size) = 1 THEN                         
                                                             				CAST(CAST(SKU.Size AS int) / 10 AS NVARCHAR(3))           
                                                             	 ELSE                                                           
                                                             				REPLACE(LTRIM(REPLACE(RTRIM(SKU.Size),'0',' ')),' ','0')  
                                                             	 END                                                            
                                                             END + ')'
                       ELSE                                                      
                           CASE WHEN ISNULL(CL5.Code,'') <> '' THEN
                               CL5.Short
                           ELSE
                               CASE WHEN ISNUMERIC(SKU.Size) = 1 THEN                      
   																	CAST(CAST(SKU.Size AS int) / 10 AS NVARCHAR(3))          
															 ELSE                                                        
  																	REPLACE(LTRIM(REPLACE(RTRIM(SKU.Size),'0',' ')),' ','0')  
															 END                                                   
                           END 
                           --replace(ltrim(replace(Rtrim(SKU.Size),'0',' ')),' ','0')
                       END                       
                    END
                 ELSE ''
            END AS Model,             
            ISNULL(SIF.ExtendedField07,'') AS Busr10, --NJOW03 
            CONVERT(NVARCHAR(215),SIF.ExtendedField21) AS Note1, --NJOW03
            CONVERT(NVARCHAR(215),SIF.ExtendedField22) AS Note2,  --NJOW03
            ISNULL(SIF.ExtendedField12,'') AS ExtendedField12, --NJOW03
            ISNULL(SIF.ExtendedField01,'') AS ExtendedField01, --NJOW03
            ISNULL(SIF.ExtendedField02,'') AS ExtendedField02 --NJOW03
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
     LEFT JOIN CODELKUP CL2 (NOLOCK) ON (CL2.ListName = 'TBLCAT' and CL2.Code = SIF.ExtendedField01)
     LEFT JOIN CODELKUP CL3 (NOLOCK) ON (CL3.ListName = 'TBLACC' and CL3.Code = SIF.ExtendedField13 AND CL3.Short IN ('2','3')) --NJOW03 2-Accessory(Socks,Headwear,Scarves), 3-Accessory(Gloves,Packs,SLG,Belts,Laces)
     LEFT JOIN CODELKUP CL4 (NOLOCK) ON (CL4.ListName = 'TBLSize_B' and CL4.UDF01 = SIF.ExtendedField14 AND CL4.UDF02 = SKU.Size) --NJOW03
     LEFT JOIN CODELKUP CL5 (NOLOCK) ON (CL5.ListName = 'TBLSize_C' and CL5.Code = CASE WHEN ISNUMERIC(SKU.Size) = 1 THEN
                                                                                        CAST(CAST(SKU.Size AS int) / 10 AS NVARCHAR(3))
                                                                                   ELSE
                                                                                        REPLACE(LTRIM(REPLACE(RTRIM(SKU.Size),'0',' ')),' ','0')
                                                                                   END) --NJOW03     
     JOIN STORER (NOLOCK) ON (RD.Storerkey = STORER.Storerkey) 
     --WHERE SKU.ItemClass <> 'F' 
     --WHERE SKU.ItemClass IN('A','C')  --NJOW01
     WHERE (substring(SKU.BUSR3,5,2) = 'AP' OR (substring(SKU.BUSR3,5,2) IN ('AC','EQ') AND ISNULL(CL3.Code,'') <> '')) --NJOW03
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
  	 	  SELECT @n_rowid = rowid, @c_style = style, @c_busr7 = busr7, @c_color = color, @c_ovas = ovas, @c_busr8 = busr8, 
  	 	         @c_ivas = ivas, @c_susr5 = susr5, @n_cost = cost, @c_countryorigin = countryorigin, @c_cocompany = cocompany,
  	 	         @c_coaddress1 = coaddress1, @c_grade = grade, @c_company = company, @c_address1 = address1, @c_address2 = address2,
  	 	         @n_qty = qty, @c_sku = sku, @c_susr1 = susr1, @c_itemclass = itemclass ,@c_busr4 = busr4, --(ChewKP01)
  	 	         @c_phone1 = phone1, @c_model = model, @c_note1 = note1, @c_note2 = note2, @c_busr10 = busr10, --NJOW01
  	 	         @c_extendedfield12 = extendedfield12, @c_extendedfield01 = extendedfield01, @c_extendedfield02 = extendedfield02 --NJOW03
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
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Style(ExtendedField11) cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_busr7,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61381
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ExtendedField06 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_busr4,'') = '' --(ChewKP01)
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61382
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ExtendedField05 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_ovas,'') = '' 
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61383
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ExtendedField10 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_susr1,'') = '' --(ChewKP01)
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61384
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Susr1 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_ivas,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61385
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': ExtendedField09 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_grade,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61386
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Grade cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_company,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61387
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Company cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  /*IF ISNULL(@c_susr5,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61388
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Susr5 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END */
        	 	  IF @n_cost = 0
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61389
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cost cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END 
        	 	  IF ISNULL(@c_countryorigin,'') = ''
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61390
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Country Of Origin cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END
        	 	  IF ISNULL(@c_note1,'') = '' AND @c_itemclass NOT IN ('AP')--CS01
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61391
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField21 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END
        	 	  IF ISNULL(@c_note2,'') = '' AND @c_itemclass = 'AC3' --NJOW03 Accessory (Gloves,Packs,SLG,Belts,Laces) 
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61392
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField22 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END
        	 	  IF ISNULL(@c_busr10,'') = '' AND @c_itemclass IN ('AC2') --NJOW03  --(CS01)
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61393
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField07 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END
        	 	  IF ISNULL(@c_extendedfield01,'') = ''  --NJOW03
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61394
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField01 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END
        	 	  IF ISNULL(@c_extendedfield02,'') = '' AND @c_itemclass = 'AP' --NJOW03
        	 	  BEGIN
        	 	  	 SELECT @n_continue = 3
        	 	  	 SELECT @n_err = 61395
        	 	  	 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField02 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
        	 	  	 BREAK
        	 	  END

        	 	  
        	 	  --NJOW01
        	 	  SELECT @c_busr10 = REPLACE(@c_busr10,'000','   ')
        	 	  SELECT @c_icon1 = SUBSTRING(@c_busr10,1,3)
        	 	  SELECT @c_icon2 = SUBSTRING(@c_busr10,4,3)
        	 	  SELECT @c_icon3 = SUBSTRING(@c_busr10,7,3)
        	 	  SELECT @c_icon4 = SUBSTRING(@c_busr10,10,3)
        	 	  SELECT @c_icon5 = SUBSTRING(@c_busr10,13,3)
        	 	  SELECT @c_icon6 = SUBSTRING(@c_busr10,16,3)
        	 	  SELECT @c_icon7 = SUBSTRING(@c_busr10,19,3)
        	 	  SELECT @c_icon8 = SUBSTRING(@c_busr10,22,3)        	 	  
        	 	  IF RTRIM(@c_busr10) <> ''
        	 	  BEGIN
              /*CS01 start*/
        	 	     SELECT @c_note2 = ''
        	 	  	 IF RTRIM(@c_icon1) <> ''
        	 	  	    SELECT @c_icon1 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon1) + '.BMP' ELSE '' END  
        	 	  	 IF RTRIM(@c_icon2) <> ''
        	 	  	    SELECT @c_icon2 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon2) + '.BMP' ELSE '' END  
        	 	  	 IF RTRIM(@c_icon3) <> ''
        	 	  	    SELECT @c_icon3 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon3) + '.BMP' ELSE '' END  
        	 	  	 IF RTRIM(@c_icon4) <> ''
        	 	  	    SELECT @c_icon4 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon4) + '.BMP' ELSE '' END  
        	 	  	 IF RTRIM(@c_icon5) <> '' 
        	 	  	    SELECT @c_icon5 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon5) + '.BMP' ELSE '' END  
        	 	  	 IF RTRIM(@c_icon6) <> ''
        	 	  	    SELECT @c_icon6 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon6) + '.BMP' ELSE '' END  
        	 	  	 IF RTRIM(@c_icon7) <> ''
        	 	  	    SELECT @c_icon7 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon7) + '.BMP' ELSE '' END  
        	 	  	 IF RTRIM(@c_icon8) <> ''
        	 	  	    SELECT @c_icon8 = CASE WHEN @c_itemclass <> 'AP' THEN RTRIM(@c_icon8) + '.BMP' ELSE '' END  
        	 	  END
  	 	  END -- @n_Qty > 0
  	 	    	 	     
  	 	  WHILE @n_qty > 0
  	 	  BEGIN
  	 	     INSERT #TMP_LABEL (style, busr7, color, ovas, busr8, ivas, susr5, countryorigin, cost,
  	 	                        cocompany, coaddress1, grade, company, address1, address2, susr1, itemclass, busr4, --(ChewKP01)
  	 	                        phone1, model, icon1, icon2, icon3, icon4, icon5, icon6, icon7, icon8, note1, note2, extendedfield12) --NJOW01
  	 	                VALUES (@c_style, @c_busr7, @c_color, @c_ovas, @c_busr8, @c_ivas, @c_susr5, @c_countryorigin, @n_cost,
  	 	                        @c_cocompany, @c_coaddress1, @c_grade, @c_company, @c_address1, @c_address2, @c_susr1, @c_itemclass, @c_busr4, --(ChewKP01)
  	 	                         @c_phone1, @c_model, @c_icon1, @c_icon2, @c_icon3, @c_icon4, @c_icon5, @c_icon6, @c_icon7, @c_icon8, @c_note1, @c_note2, @c_extendedfield12) --NJOW01
  	 	     
  	 	     SELECT @n_qty = @n_qty - 1
  	 	  END
  	 END
  END

  IF @n_continue=3
  BEGIN
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetReceiptQCCLabel02'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     SELECT style, busr7, color, ovas, busr8, ivas, susr5, countryorigin, cost,
  	 	      cocompany, coaddress1, grade, company, address1, address2, susr1, itemclass, busr4, --(ChewKP01)
  	 	      phone1, model, icon1, icon2, icon3, icon4, icon5, icon6, icon7, icon8, note2, note1, extendedfield12  --NJOW01
  	 FROM #TMP_LABEL
  	 WHERE 1=2
     RETURN
  END
  ELSE
     SELECT style, busr7, color, ovas, busr8, ivas, susr5, countryorigin, cost,
  	 	      cocompany, coaddress1, grade, company, address1, address2, susr1, itemclass, busr4,  --(ChewKP01)
  	 	      phone1, model, icon1, icon2, icon3, icon4, icon5, icon6, icon7, icon8, note2, note1, extendedfield12  --NJOW01
  	 FROM #TMP_LABEL ORDER BY rowid
END

GO