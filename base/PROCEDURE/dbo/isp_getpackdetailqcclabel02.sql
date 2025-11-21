SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Store Procedure:  isp_GetPackDetailQCCLabel02                        */  
/* Creation Date: 2014-05-15                                            */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:  prINT QCC Label in ASN for timberland HK (Non Footwear)    */  
/*                                                                      */  
/* Input Parameters:  @c_labelNo - packdetail.labelno                   */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_receipt_qcclabel02                 */  
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
/* 2014-06-05   CSCHONG   1.0   modify style,color field value (CS01)   */
/* 2014-06-18   CSCHONG   2.0   link the lottable01 to pickdetail (CS02)*/
/* 2014-07-10   CSCHONG   3.0   Add new field (CS03)                    */
/* 2014-08-14   CSCHONG   4.0   Add new field (CS04)                    */
/* 2014-08-29   CSCHONG   5.0   Get the TOP 1 (CS05)                    */
/* 2015-07-09   CSCHONG   6.0   Add new field (CS06)                    */
/* 2016-08-17   CSCHONG   6.1   WMS-237 -Change mapping (CS07)          */
/* 2017-03-01   JHTAN     6.2   IN00279947 wrong ExtendedField10 match  */
/*                              to ovas (JH01)                          */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetPackDetailQCCLabel02] (
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
  
 DECLARE @n_continue INT,  
        @c_errmsg    NVARCHAR(255),  
        @b_success   INT,  
        @n_err       INT,  
        @n_rowid     INT,  
        @n_cnt       INT  
       
  DECLARE @c_style           NVARCHAR(30), --skuinfo.extendedfield11  
          @c_busr7           NVARCHAR(30), --skuinfo.extendedfield06  
          @c_color           NVARCHAR(10),  
          @c_ovas            NVARCHAR(30),  
          @c_busr8           NVARCHAR(100),  
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
          @n_count           INT,  
          --@c_sku             NVARCHAR(20),  
          @c_susr1           NVARCHAR(30),  
          @c_itemclass       NVARCHAR(10),   
          @c_busr4           NVARCHAR(30),  
          @c_phone1          NVARCHAR(18),  
          @c_model           NVARCHAR(50),   
          @c_icon1           NVARCHAR(10),  
          @c_icon2           NVARCHAR(10),  
          @c_icon3           NVARCHAR(10),   
          @c_icon4           NVARCHAR(10),  
          @c_icon5           NVARCHAR(10), 
          @c_icon6           NVARCHAR(10),  
          @c_icon7           NVARCHAR(10), 
          @c_icon8           NVARCHAR(10),   
          @c_note1           NVARCHAR(215), 
          @c_note2           NVARCHAR(215), 
          @c_busr10          NVARCHAR(30),   
          @c_extendedfield12 NVARCHAR(30),   
          @c_extendedfield01 NVARCHAR(30), 
          @c_extendedfield02 NVARCHAR(30),
          @c_company1        NVARCHAR(215) ,
          @c_storerkey       NVARCHAR(30),
          @nRowNo            INT,
          @n_TTLQty          INT,
          @n_qty             INT,
          @c_extendedfield08 NVARCHAR(30),          --(CS03)
          @c_extendedfield16 NVARCHAR(30),          --(CS04)
          @c_extendedfield17 NVARCHAR(30),          --(CS04)
          @c_extendedfield18 NVARCHAR(30),          --(CS04)
          @c_extendedfield19 NVARCHAR(30),          --(CS04)
          @c_extendedfield20 NVARCHAR(30),          --(CS04)
          @c_extendedfield13 NVARCHAR(30),          --(CS04)
          @c_EANCode         NVARCHAR(15)          --(CS07)

  DECLARE @nfrom INT				
        , @nlen  INT				
        , @i     INT
        , @cfieldvalue NVARCHAR(45)
        
  
  SELECT @n_continue = 1, @n_err = 0, @b_success = 1, @c_errmsg = '',@n_TTLQty=0,@n_count=1
  SELECT @n_qty = CONVERT(INT,@c_qty)
  
  IF ISNULL(@n_qty,0) = 0
  BEGIN
     SELECT @n_qty = 0
  END  
    
  CREATE TABLE #TMP_LABEL (  
          rowid         INT identity(1,1),  
          style           NVARCHAR(30) NULL,  
          busr7           NVARCHAR(30) NULL,  
          color           NVARCHAR(10) NULL,  
          ovas            NVARCHAR(30) NULL,  
          busr8           NVARCHAR(100) NULL,  
          ivas            NVARCHAR(30) NULL,  
          susr5           NVARCHAR(30) NULL,  
          countryorigin   NVARCHAR(50) NULL,  
          cost            NVARCHAR(30) NULL,  
          cocompany       NVARCHAR(45) NULL,  
          coaddress1      NVARCHAR(45) NULL,  
          grade           NVARCHAR(50) NULL,  
          company         NVARCHAR(45) NULL,  
          address1        NVARCHAR(45) NULL,  
          address2        NVARCHAR(45) NULL,  
          susr1           NVARCHAR(30) NULL,  
          itemclass       NVARCHAR(10) NULL,  
          busr4           NVARCHAR(30) NULL,   
          phone1          NVARCHAR(18) NULL,  
          model           NVARCHAR(50) NULL,   
          icon1           NVARCHAR(10) NULL,  
          icon2           NVARCHAR(10) NULL,   
          icon3           NVARCHAR(10) NULL, 
          icon4           NVARCHAR(10) NULL, 
          icon5           NVARCHAR(10) NULL,
          icon6           NVARCHAR(10) NULL, 
          icon7           NVARCHAR(10) NULL, 
          icon8           NVARCHAR(10) NULL, 
          note1           NVARCHAR(215) NULL, 
          note2           NVARCHAR(215) NULL, 
          extendedfield12 NVARCHAR(30) NULL,
          company1        NVARCHAR(215) NULL,
          Storerkey       NVARCHAR(30) NULL,
          extendedfield08 NVARCHAR(30) NULL,        --(CS03)
          extendedfield16 NVARCHAR(30) NULL,        --(CS04)
          extendedfield17 NVARCHAR(30) NULL,        --(CS04)
          extendedfield18 NVARCHAR(30) NULL,        --(CS04)
          extendedfield19 NVARCHAR(30) NULL,        --(CS04)
          extendedfield20 NVARCHAR(30) NULL,        --(CS04)
          extendedfield13 NVARCHAR(30) NULL,        --(CS04)
          extendedfield02 NVARCHAR(30) NULL,         --(CS06)
          EANCode         NVARCHAR(15) NULL         --(CS07)
)  
     
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN  --1
    SELECT TOP 1 IDENTITY(INT,1,1) AS rowid,   
           ISNULL(SIF.ExtendedField11,'') AS style, --+ '-' +
           --CASE WHEN ISNULL(SKU.color,'') <> '' THEN SKU.color ELSE '' END) AS style,    --(CS01) --(CS07)
           ISNULL(SIF.ExtendedField06,'') AS busr7, 
           SKU.color,   
           ISNULL(SIF.ExtendedField01,'') AS ovas, --(JH01) old one is ISNULL(SIF.ExtendedField10,'') AS ovas,
           ISNULL(SIF.ExtendedField01,'') AS susr1,   
           ISNULL(SIF.ExtendedField09,'') AS ivas,  
           SKU.susr5,   
            --CASE WHEN ISNUMERIC(SIF.ExtendedField08)=1 THEN CAST(SIF.ExtendedField08 AS Float) ELSE 0.00 END AS cost,  
            ISNULL(SIF.ExtendedField07,'') AS Cost,--(RTRIM(ORDDET1.Userdefine04) + space(1) + ORDDET1.Userdefine02 ) AS Cost,
            CASE WHEN LOTB.Lottable01 not in ('CN','CNAP') THEN CLC.UDF01 
           --      WHEN LOTB.Lottable01 in ('CN','CNAP') THEN (COOSTORER.Country + RTRIM(COOSTORER.State)+ RTRIM(COOSTORER.City)) END
            ELSE SIF.ExtendedField04 END AS CountryOrigin, CASE WHEN LOTB.Lottable01 in ('CN','CNAP') THEN COOSTORER.Company ELSE '' END AS COCompany, 
            CASE WHEN LOTB.Lottable01 in ('CN','CNAP') THEN COOSTORER.Address1 ELSE '' END AS COAddress1, 
            CASE WHEN ISNULL(SIF.ExtendedField15,'') <> '' THEN SIF.ExtendedField15 ELSE CLQ.Long END AS Grade,  
            STORER.Company, STORER.Address1, STORER.Address2, 0 as qty,
            --'' as Company,  '' as Address1, '' as Address2, 0 as qty,
--            CASE WHEN RD.FinalizeFlag = 'Y' THEN  
--                 RD.QtyReceived  
--            ELSE  
--                 RD.BeforeReceivedQty  
--            END AS Qty,  
            SKU.Sku,  
            --SKU.Susr1,  
            SIF.ExtendedField02 AS Itemclass,
            CASE WHEN ISNULL(SIF.ExtendedField02,'') ='AP' THEN ISNULL(SUBSTRING(LTRIM(SIF.ExtendedField05),1,3),'') ELSE ISNULL(SIF.ExtendedField05,'') END AS busr4,  --(CS01)   --(CS07)
--            (ISNULL(SIF.ExtendedField05,'') + 
--            CASE WHEN ISNULL(SKU.color,'') <> '' THEN SKU.color ELSE '' END) AS busr4,   --(CS01)
            SKU.busr8,  
            STORER.Phone1, 
             (SIF.ExtendedField14 + SPACE(1)+
             CASE WHEN ISNULL(sku.measurement,'') = '' then SKU.Size  ELSE 
             '(' + (RTRIM(SKU.Size) + '/' + RTRIM(sku.measurement)) END) +')' AS Model,               
            ISNULL(SIF.ExtendedField07,'') AS Busr10,   
            CAST(SIF.ExtendedField21 AS NCHAR(215)) AS Note1, 
            --left(SIF.ExtendedField21 + replicate(' ', 215), 215) AS Note1,
            ISNULL(SIF.ExtendedField12,'') AS ExtendedField12, 
            ISNULL(SIF.ExtendedField01,'') AS ExtendedField01,
            ISNULL(SIF.ExtendedField02,'') AS ExtendedField02,
            STORER.Notes1 as Company1,'' as note2, Storer.Storerkey,
            SIF.ExtendedField08,SIF.ExtendedField16,SIF.ExtendedField17,          --(CS03)   --(CS04)
            SIF.ExtendedField18,SIF.ExtendedField19,SIF.ExtendedField20,          --(CS04)
            SIF.ExtendedField13,                                                   --(CS04)             
            [dbo].[fnc_CalcCheckDigit_M10] (SIF.ExtendedField13,1)    AS EANCode            --(CS07) 
     INTO #TMP_REC  
     FROM PACKHEADER PH WITH (NOLOCK)
     JOIN PACKDETAIL PD WITH (NOLOCK) ON (PD.Pickslipno = PH.Pickslipno)
     JOIN SKU (NOLOCK) ON (PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku)  
     LEFT JOIN ORDERS ORD WITH (NOLOCK) ON Ord.Orderkey=PH.Orderkey
     CROSS APPLY
     (SELECT TOP 1 OrdDet.userdefine04 , OrdDet.userdefine02 
      FROM Orderdetail OrdDet WITH (NOLOCK) 
      WHERE OrdDet.Orderkey = ORD.Orderkey AND OrdDet.sku=PD.SKU
     Order by sku ) ORDDET1
     LEFT JOIN SKUINFO SIF (NOLOCK) ON (PD.Storerkey = SIF.Storerkey AND PD.Sku = SIF.Sku)    
     LEFT JOIN PICKDETAIL  PICKDET WITH (NOLOCK) ON PICKDET.Orderkey = PH.Orderkey AND PICKDET.SKU = PD.SKU   --CS02
     LEFT JOIN LOTATTRIBUTE LOTB WITH (NOLOCK) ON (PICKDET.Lot = LOTB.Lot AND PICKDET.Sku = LOTB.Sku)         --CS02
     LEFT JOIN CODELKUP CLC (NOLOCK) ON (CLC.ListName = 'VFCOO'   
                                   AND CLC.code = LOTB.lottable01)   
     LEFT JOIN STORER CNTRORG (NOLOCK) ON (SIF.ExtendedField04 = CNTRORG.Storerkey AND CNTRORG.Consigneefor = ORD.Storerkey)  
     LEFT JOIN Storer COOSTORER WITH (NOLOCK) ON ( COOSTORER.Storerkey=SIF.ExtendedField04 AND COOSTORER.consigneefor = ORD.Storerkey)
     LEFT JOIN CODELKUP CLQ (NOLOCK) ON (CLQ.ListName = 'TBLQual' and substring(SKU.Sku,12,1) = CLQ.Code)  
--     LEFT JOIN CODELKUP CL2 (NOLOCK) ON (CL2.ListName = 'TBLCAT' and CL2.Code = SIF.ExtendedField01)  
--     LEFT JOIN CODELKUP CL3 (NOLOCK) ON (CL3.ListName = 'TBLACC' and CL3.Code = SIF.ExtendedField13 AND CL3.Short IN ('2','3')) -- 2-Accessory(Socks,Headwear,Scarves), 3-Accessory(Gloves,Packs,SLG,Belts,Laces)  
--     LEFT JOIN CODELKUP CL4 (NOLOCK) ON (CL4.ListName = 'TBLSize_B' and CL4.UDF01 = SIF.ExtendedField14 AND CL4.UDF02 = SKU.Size)   
--     LEFT JOIN CODELKUP CL5 (NOLOCK) ON (CL5.ListName = 'TBLSize_C' and CL5.Code = CASE WHEN ISNUMERIC(SKU.Size) = 1 THEN  
--                                                                                        CAST(CAST(SKU.Size AS INT) / 10 AS NVARCHAR(3))  
--                                                                                   ELSE  
--                                                                                        REPLACE(LTRIM(REPLACE(RTRIM(SKU.Size),'0',' ')),' ','0')  
--                                                                                   END)       
      JOIN STORER (NOLOCK) ON (ORD.Storerkey = STORER.Storerkey)   
     --WHERE SKU.ItemClass <> 'F'   
     --WHERE SKU.ItemClass IN('A','C')   
      WHERE SIF.ExtendedField02 IN('AP','AC')   
      AND PD.labelno = @c_labelno 
      AND PD.SKU = CASE WHEN ISNULL(RTRIM(@c_SKU),'') <> '' THEN @c_SKU ELSE PD.SKU END 
      AND LOTB.lottable01 = CASE WHEN ISNULL(RTRIM(@c_lottable01),'') <> '' THEN @c_lottable01 ELSE LOTB.lottable01 END    
--     CASE WHEN RD.FinalizeFlag = 'Y' THEN    
--                 RD.QtyReceived    
--            ELSE    
--                 RD.BeforeReceivedQty    
--            END  > 0                                           
--     ORDER BY RD.Userdefine01, RD.Sku   
  END --1 
    
 -- SELECT TOP 1 @c_storerkey = Storerkey
 --  FROM #TMP_REC
 IF @b_debug='1'
 BEGIN
  Select * from #TMP_REC 
 END
  --select @c_storerkey 
  
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
         FROM storer (nolock) 
         WHERE storerkey  = @c_storerkey				

         SELECT @nlen = CASE WHEN @nlen > 0 THEN @nlen ELSE 1000 END
			
         SELECT @cfieldvalue = substring(notes1,@nfrom,@nlen) 
         FROM STORER WITH (NOLOCK) 
         WHERE storerkey  = @c_storerkey				
         
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
       INSERT INTO #TMP_REC (style, susr1, busr7, color,ovas,ivas, susr5,cost,countryorigin,cocompany,
  	 	                       coaddress1, grade, company, address1,address2,qty, model, sku, busr4, busr8, 
  	 	                       phone1, note1,note2,busr10, itemclass,ExtendedField01,ExtendedField02,extendedfield12
                             ,company1,storerkey,ExtendedField08,ExtendedField16,ExtendedField17,ExtendedField18  --(CS03) --(CS04
                             ,ExtendedField19,ExtendedField20,ExtendedField13,EANCode)                            --(CS04) --(CS07)
       SELECT TOP 1 style, susr1, busr7, color,ovas,ivas, susr5,cost,countryorigin,cocompany,
  	 	              coaddress1, grade, company, address1,address2,qty, model, sku, busr4, busr8, 
  	 	              phone1, note1,note2,busr10, itemclass,ExtendedField01,ExtendedField02,extendedfield12,company1,
                    storerkey,ExtendedField08 ,ExtendedField16,ExtendedField17,ExtendedField18,ExtendedField19,  --(CS03) --(CS04)
                    ExtendedField20,ExtendedField13 ,EANCode                                                     --(CS04) --(CS07)
       FROM #TMP_REC
       ORDER BY rowid
      
       SELECT @n_count = @n_count + 1
      END
  END
	
  --select '1'
  IF @n_continue = 1 OR @n_continue = 2  
  BEGIN  --2
    SELECT @n_rowid = 0  
    WHILE 1=1  
    BEGIN  --3
       SET ROWCOUNT 1  
       SELECT @n_rowid = rowid, @c_style = style, @c_busr7 = busr7, @c_color = color, @c_ovas = ovas, @c_busr8 = busr8,   
              @c_ivas = ivas, @c_susr5 = susr5, @n_cost = cost, @c_countryorigin = countryorigin, @c_cocompany = cocompany,  
              @c_coaddress1 = coaddress1, @c_grade = grade, @c_company = company, @c_address1 = address1, @c_address2 = address2,  
              @n_qty = qty, @c_sku = sku, @c_susr1 = susr1, @c_itemclass = itemclass ,@c_busr4 = busr4,   
              @c_phone1 = phone1, @c_model = model, @c_note1 = note1, @c_note2 = note2, @c_busr10 = busr10,  
              @c_extendedfield12 = extendedfield12, @c_extendedfield01 = extendedfield01, @c_extendedfield02 = extendedfield02,@c_company1 = company1,
              @c_extendedfield08 = extendedfield08,@c_extendedfield16 = extendedfield16 ,@c_extendedfield17 = extendedfield17,                                      --(CS03) --(CS04)
              @c_extendedfield18 = extendedfield18,@c_extendedfield19 = extendedfield19,@c_extendedfield20 = extendedfield20,@c_extendedfield13 = extendedfield13,   --(CS04) 
              @c_EANCode = EANCode                                                                                            --(CS07)
       FROM #TMP_REC  
       WHERE rowid > @n_rowid  
       ORDER BY rowid  
       SELECT @n_cnt = @@ROWCOUNT         
       SET ROWCOUNT 0  
         
       IF @n_cnt = 0  
          BREAK                
         
      /* IF @n_Qty > 0  
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
             IF ISNULL(@c_busr4,'') = ''   
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
             IF ISNULL(@c_susr1,'') = ''  
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
             IF ISNULL(@c_note1,'') = ''  
             BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 61391  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField21 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '  
               BREAK  
             END  
             IF ISNULL(@c_note2,'') = '' AND @c_itemclass = 'AC3' 
             BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 61392  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField22 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '  
               BREAK  
             END  
             IF ISNULL(@c_busr10,'') = '' AND @c_itemclass IN ('AP','AC2')
             BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 61393  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField07 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '  
               BREAK  
             END  
             IF ISNULL(@c_extendedfield01,'') = ''  
             BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 61394  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField01 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '  
               BREAK  
             END  
             IF ISNULL(@c_extendedfield02,'') = '' AND @c_itemclass = 'AP' 
             BEGIN  
               SELECT @n_continue = 3  
               SELECT @n_err = 61395  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': ExtendedField02 cannot be empty for SKU '+ rtrim(@c_sku)+ '. (isp_GetReceiptQCCLabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '  
               BREAK  
             END  */
  
               
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
             BEGIN  --4
                SELECT @c_note2 = ''  
               /*IF RTRIM(@c_icon1) <> ''  
                  SELECT @c_icon1 = RTRIM(@c_icon1) + '.BMP'  
               IF RTRIM(@c_icon2) <> ''  
                  SELECT @c_icon2 = RTRIM(@c_icon2) + '.BMP'  
               IF RTRIM(@c_icon3) <> ''  
                  SELECT @c_icon3 = RTRIM(@c_icon3) + '.BMP'  
               IF RTRIM(@c_icon4) <> ''  
                  SELECT @c_icon4 = RTRIM(@c_icon4) + '.BMP'  
               IF RTRIM(@c_icon5) <> ''  
                  SELECT @c_icon5 = RTRIM(@c_icon5) + '.BMP'  
               IF RTRIM(@c_icon6) <> ''  
                  SELECT @c_icon6 = RTRIM(@c_icon6) + '.BMP'  
               IF RTRIM(@c_icon7) <> ''  
                  SELECT @c_icon7 = RTRIM(@c_icon7) + '.BMP'  
               IF RTRIM(@c_icon8) <> ''  
                 SELECT @c_icon8 = RTRIM(@c_icon8) + '.BMP' */
               IF RTRIM(@c_icon1) <> ''  
                  SELECT @c_icon1 = short 
                  FROM CODELKUP (NOLOCK)
                  WHERE code= @c_icon1
               IF RTRIM(@c_icon2) <> ''  
                  SELECT @c_icon2 = short 
                  FROM CODELKUP (NOLOCK)
                  WHERE code= @c_icon2 
               IF RTRIM(@c_icon3) <> ''  
                  SELECT @c_icon3 = short 
                  FROM CODELKUP (NOLOCK)
                  WHERE code= @c_icon3  
               IF RTRIM(@c_icon4) <> ''  
                  SELECT @c_icon4 = short 
                  FROM CODELKUP (NOLOCK)
                  WHERE code= @c_icon4  
               IF RTRIM(@c_icon5) <> ''  
                  SELECT @c_icon5 = short 
                  FROM CODELKUP (NOLOCK)
                  WHERE code= @c_icon5 
               IF RTRIM(@c_icon6) <> ''  
                  SELECT @c_icon6 = short 
                  FROM CODELKUP (NOLOCK)
                  WHERE code= @c_icon6 
               IF RTRIM(@c_icon7) <> ''  
                  SELECT @c_icon7 = short 
                  FROM CODELKUP (NOLOCK)
                  WHERE code= @c_icon7 
               IF RTRIM(@c_icon8) <> ''  
                 SELECT @c_icon8 = short 
                 FROM CODELKUP (NOLOCK)
                 WHERE code= @c_icon8  
             END  --4
      -- END -- @n_Qty > 0  
                   
    --   WHILE @n_qty > 0  
  --     BEGIN  
          INSERT #TMP_LABEL (style, busr7, color, ovas, busr8, ivas, susr5, countryorigin, cost,  
                             cocompany, coaddress1, grade, company, address1, address2, susr1, itemclass, busr4, 
                             phone1, model, icon1, icon2, icon3, icon4, icon5, icon6, icon7, icon8, note1, note2, extendedfield12,company1,extendedfield08,    --(CS03)  --(CS04)
                             extendedfield16,extendedfield17,extendedfield18,extendedfield19,extendedfield20,extendedfield13,extendedfield02,EANCode)          --(CS04)  --(CS06) --(CS07)
          VALUES (@c_style, @c_busr7, @c_color, @c_ovas, @c_busr8, @c_ivas, @c_susr5, @c_countryorigin, @n_cost,  
                  @c_cocompany, @c_coaddress1, @c_grade, @c_company, @c_address1, @c_address2, @c_susr1, @c_itemclass, @c_busr4, 
                  @c_phone1, @c_model, @c_icon1, @c_icon2, @c_icon3, @c_icon4, @c_icon5, @c_icon6, @c_icon7, @c_icon8, @c_note1, @c_note2, @c_extendedfield12,@c_company1,@c_extendedfield08,  --(CS03)  
                  @c_extendedfield16,@c_extendedfield17,@c_extendedfield18,@c_extendedfield19,@c_extendedfield20,@c_extendedfield13,@c_extendedfield02,@c_EANCode)                       --(CS04)  --(CS06) --(CS07)
            
    --      SELECT @n_qty = @n_qty - 1  
   --    END  
   END --3  
  END  --2
  
  IF @n_continue=3  
  BEGIN  
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetReceiptQCCLabel02'  
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
     SELECT style, busr7, color, ovas, busr8, ivas, susr5, countryorigin, cost,  
           cocompany, coaddress1, grade, company, address1, address2, susr1, itemclass, busr4,   
           phone1, model, icon1, icon2, icon3, icon4, icon5, icon6, icon7, icon8, note2, note1, extendedfield12,company1,extendedfield08,   --(CS03)
           extendedfield16,extendedfield17,extendedfield18,extendedfield19,extendedfield20,extendedfield13,extendedfield02,EANCode          --(CS04)  --(CS06)  --(CS07)
    FROM #TMP_LABEL  
    WHERE 1=2  
     RETURN  
  END  
  ELSE 
 -- BEGIN 
     SELECT style, busr7, color, ovas, busr8, ivas, susr5, countryorigin, cost,  
           cocompany, coaddress1, grade, company, address1, address2, susr1, itemclass, busr4,   
           phone1, model, icon1, icon2, icon3, icon4, icon5, icon6, icon7, icon8, note2, note1, extendedfield12,company1,extendedfield08,  --(CS03)
           extendedfield16,extendedfield17,extendedfield18,extendedfield19,extendedfield20,extendedfield13,extendedfield02,EANCode             --(CS04)  --(CS06) --(CS07)
    FROM #TMP_LABEL ORDER BY rowid  
END 


GO