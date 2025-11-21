SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/        
/* Store Procedure: nsp_GetECCOPackingList                                      */        
/* Creation Date:   04th Aug 2006                                               */        
/* Copyright: IDS                                                               */        
/* Written by:      Shong                                                       */        
/*                                                                              */        
/* Purpose: Generate ECCO Packing List FBR55603                                 */        
/*                                                                              */        
/* Called By:                                                                   */        
/*                                                                              */        
/* PVCS Version: 1.1                                                            */        
/*                                                                              */        
/* Version: 5.4                                                                 */        
/*                                                                              */        
/* Data Modifications:                                                          */        
/*                                                                              */        
/* Date        Rev  Author   Purposes                                           */        
/* 27-Feb-2007 1.0  jwong    bug fix                                            */        
/* 13-Jan-2009 1.1  Leong    SOS#126667 - bug fix                               */         
/* 16-Feb-2009 1.2  Audrey   SOS#129172 - Change original qty to qtyallocated   */                               
/* 03-Feb-2009 1.3  NJOW01   SOS#129562 - ECCO Packing List - Add orders.       */        
/*                                        Buyerpo on Report Header              */        
/* 06-Mar-2009 1.4  Audrey   SOS#130771 - Bug fix -Add in the @cPrevcSkuDescr   */    
/* 16-Mar-2009 1.5  Audrey   SOS#130771 - Add in the qtyallocate + qtypicked +  */    
/*                                        shippedqty                            */      
/* 01-Apr-2009 1.6  NJOW02   SOS#132434 - ECCO Packing List able to extract     */
/*                                        records from archive database if not  */
/*                                        found in live database                */
/* 28-Jan-2019 1.7 TLTING_ext          enlarge externorderkey field length      */
/********************************************************************************/        
        
CREATE PROCEDURE [dbo].[nsp_GetECCOPackingList] (        
@cReceiptKey NVARCHAR(10)        
)        
AS        
BEGIN        
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF       
   DECLARE @bDebug int        
        
   SELECT @bDebug = 0        

  --NJOW02
  DECLARE @c_arcdbname NVARCHAR(30),
          @sql nvarchar(4000),
          @c_FromArchive NVARCHAR(1)
  SELECT @c_FromArchive = 'N'          
           
   DECLARE         
      @cExternPOKey          NVARCHAR(20),        
      @cOrderKey             NVARCHAR(10),        
      @cC_Company            NVARCHAR(45),        
      @dReceiptDate          datetime,        
      @cAddress              NVARCHAR(90),        
      @cContact1             NVARCHAR(30),        
      @cC_Phone1             NVARCHAR(18),        
      @cPOKey                NVARCHAR(10),        
      @cExternOrderKey       NVARCHAR(50),         --tlting_ext
      @cPrevExternOrderKey   NVARCHAR(50),        
      @cPrevOrderKey       NVARCHAR(10),        
      @cPrevC_Company        NVARCHAR(45),          
      @cPrevAddress          NVARCHAR(90),         
      @cPrevC_Phone1         NVARCHAR(18),        
      @cPrevcSkuDescr        NVARCHAR(60), -- SOS#130771      
      @cSkuDescr             NVARCHAR(60),        
      @cMaterialNo           NVARCHAR(18),        
      @cUCCNo                NVARCHAR(20),        
      @cPrevUCCNo            NVARCHAR(20),        
      @cOrdertype            NVARCHAR(10),        
      @cStorerKey            NVARCHAR(10),        
      @cPrevMaterialNo       NVARCHAR(18),        
      @nQty                  int,        
      @nPrice                float,         
      @cSKUSize              NVARCHAR(5),         
      @cSkuSize1             NVARCHAR(5),        
      @cSkuSize2             NVARCHAR(5),        
      @cSkuSize3             NVARCHAR(5),        
      @cSkuSize4             NVARCHAR(5),        
      @cSkuSize5             NVARCHAR(5),        
      @cSkuSize6             NVARCHAR(5),        
      @cSkuSize7             NVARCHAR(5),        
      @cSkuSize8             NVARCHAR(5),        
      @cSkuSize9             NVARCHAR(5),        
      @cSkuSize10            NVARCHAR(5),        
      @nQty1                 int,        
      @nQty2                 int,        
      @nQty3                 int,        
      @nQty4                 int,        
      @nQty5                 int,        
      @nQty6                 int,        
      @nQty7                 int,        
      @nQty8                 int,        
      @nQty9                 int,        
      @nQty10                int,        
      @nCnt                  int,        
      @bSuccess              int,        
      @nErr                  int,         
      @cErrMsg               NVARCHAR(255),        
      @nFetchStatus          int,         
      @nCartonCnt            int,        
      @cBuyerPo              NVARCHAR(20), --NJOW01        
      @cPrevBuyerPo          NVARCHAR(20)  --NJOW01        
        
   IF OBJECT_ID('tempdb..#TempPackList') IS NOT NULL        
      DROP TABLE #TempPackList         
        
   CREATE TABLE #TempPackList (        
   ReceiptDate    datetime NULL,        
   ExternOrderKey NVARCHAR(50) NULL,          --tlting_ext
   C_Company      NVARCHAR(45) NULL,        
   C_Address      NVARCHAR(90) NULL,        
   C_Phone1 NVARCHAR(18) NULL,        
   ExternPOKey    NVARCHAR(20) NULL,        
   POKey          NVARCHAR(10) NULL,        
   UCCNO          NVARCHAR(20) NULL,           
   OrderKey       NVARCHAR(10) NULL,        
   CartonCnt      int NULL,        
   SizeLine       int NULL,         
   MaterialNo     NVARCHAR(18) NULL,        
   SKUDescr       NVARCHAR(60) NULL,        
   SKUPrice       float   NULL,        
   SkuSize1       NVARCHAR(5) NULL,        
   SkuSize2       NVARCHAR(5) NULL,        
   SkuSize3       NVARCHAR(5) NULL,        
   SkuSize4       NVARCHAR(5) NULL,        
   SkuSize5       NVARCHAR(5) NULL,        
   SkuSize6       NVARCHAR(5) NULL,        
   SkuSize7       NVARCHAR(5) NULL,        
   SkuSize8       NVARCHAR(5) NULL,        
   SkuSize9       NVARCHAR(5) NULL,        
   SkuSize10      NVARCHAR(5) NULL,        
   Qty1           int  NULL,        
   Qty2           int NULL,        
   Qty3           int NULL,        
   Qty4           int NULL,        
   Qty5           int NULL,        
   Qty6           int NULL,        
   Qty7           int NULL,        
   Qty8           int NULL,        
   Qty9           int NULL,        
   Qty10          int NULL,        
   BuyerPO        NVARCHAR(20) NULL --NJOW01         
   )        
           
  CREATE TABLE #TMPCNT (cartoncnt int) --NJOW02

  --DECLARE CUR_GetOrderLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
      SELECT R.ReceiptDate,        
             O.ExternOrderKey,         
             O.C_Company,           
             ISNULL(RTRIM(O.C_Address1),'') + ' ' + ISNULL(RTRIM(O.C_Address2),'') AS Address,         
             O.C_Phone1,        
             OD.ExternPOKey,        
             RD.POKey,        
             OD.UserDefine02 AS UCC,        
             REPLACE(LEFT(OD.SKU, 12), '-', '') AS MaterialNo,         
             REPLACE(RIGHT(OD.SKU, 5), '-', '') AS [Size],         
             /*SUM(OD.OriginalQty) AS OriginalQty,    SOS#129172*/            
             /* SUM(OD.Qtyallocated) AS Qtyallocated, SOS#129172*/      
             SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS Qty, --SOS#130771      
             MAX(ISNULL(SKU.Price,0)) AS Price,         
             MAX(ISNULL(SKU.DESCR, '')) AS SKUDescr,         
             O.OrderKey,        
             O.BuyerPO   --NJOW01 
      INTO #TEMP_CUR
      FROM RECEIPT R (NOLOCK)          
      JOIN ORDERDETAIL OD (NOLOCK) ON (OD.ExternPOKey = R.ExternReceiptKey)         
      JOIN ORDERS O (NOLOCK) ON O.OrderKey = OD.OrderKey         
      JOIN SKU (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU)         
      JOIN (SELECT ReceiptDetail.ReceiptKey, MAX(ReceiptDetail.POKEY) as POKey FROM ReceiptDetail (NOLOCK)         
            WHERE ReceiptDetail.ReceiptKey = @cReceiptKey         
            GROUP BY ReceiptDetail.ReceiptKey)        
           AS RD ON RD.ReceiptKey = R.ReceiptKey        
      WHERE R.ReceiptKey = @cReceiptKey
      AND ISNULL(RTRIM(R.ExternReceiptKey),'') <> ''        
      GROUP BY R.ReceiptDate,        
             O.ExternOrderKey,         
             O.C_Company,           
             O.C_Address1,        
      O.C_Address2,         
             O.C_Phone1,        
             OD.ExternPOKey,        
             RD.POKey,        
             OD.UserDefine02,        
             REPLACE(LEFT(OD.SKU, 12), '-', ''),         
             REPLACE(RIGHT(OD.SKU, 5), '-', ''),         
             O.OrderKey,        
             O.BuyerPO  --NJOW01          
      ORDER BY O.ExternOrderKey, OD.UserDefine02, REPLACE(LEFT(OD.SKU, 12), '-', '')         
        
   --OPEN CUR_GetOrderLine        
           
   /*FETCH NEXT FROM CUR_GetOrderLine INTO         
        @dReceiptDate,        
        @cExternOrderKey,         
        @cC_Company,           
        @cAddress,         
        @cC_Phone1,        
        @cExternPOKey,        
        @cPOKey,        
        @cUCCNo,        
        @cMaterialNo,         
        @cSKUSize,         
        @nQty,        
        @nPrice,         
        @cSkuDescr,        
        @cOrderKey,        
        @cBuyerPO --NJOW01*/          
    
   --NJOW02 ----Start    
   IF @@ROWCOUNT = 0--OFETCH_STATUS <> 0
   BEGIN
 	   SELECT @c_arcdbname = NSQLValue FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='ArchiveDBName'
      
      --IF (SELECT COUNT(*) FROM sys.master_files s_mf
      --    WHERE s_mf.state = 0 and has_dbaccess(db_name(s_mf.database_id)) = 1
      --    AND db_name(s_mf.database_id) = @c_arcdbname) > 0
      IF 1=1
      BEGIN
        --CLOSE CUR_GetOrderLine
        --DEALLOCATE CUR_GetOrderLine
      	SELECT @c_FromArchive = 'Y'
        SET @sql = '/*DECLARE CUR_GetOrderLine CURSOR FAST_FORWARD READ_ONLY FOR*/          '
                 + '      INSERT INTO #TEMP_CUR         '
                 + '      SELECT R.ReceiptDate,         '
                 + '             O.ExternOrderKey,          '
                 + '             O.C_Company,            ' 
                 + '             ISNULL(RTrim(O.C_Address1),'''') + '' '' + ISNULL(RTrim(O.C_Address2),'''') AS Address,          ' 
                 + '             O.C_Phone1,         ' 
                 + '             OD.ExternPOKey,         ' 
                 + '             RD.POKey,         ' 
                 + '             OD.UserDefine02 AS UCC,         ' 
                 + '             REPLACE(LEFT(OD.SKU, 12), ''-'', '''') AS MaterialNo,          ' 
                 + '             REPLACE(RIGHT(OD.SKU, 5), ''-'', '''') AS [Size],          ' 
                 + '             /*SUM(OD.OriginalQty) AS OriginalQty,    SOS#129172*/             ' 
                 + '             /* SUM(OD.Qtyallocated) AS Qtyallocated, SOS#129172*/       ' 
                 + '             SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS Qty, /*SOS#130771*/       ' 
                 + '             MAX(ISNULL(SKU.Price,0)) AS Price,          '
                 + '             MAX(ISNULL(SKU.DESCR, '''')) AS SKUDescr,          ' 
                 + '             O.OrderKey,         ' 
                 + '             O.BuyerPO   /*NJOW01*/           ' 
                 + '      FROM '+RTRIM(@c_arcdbname)+'..RECEIPT R (NOLOCK)           ' 
                 + '      JOIN ORDERDETAIL OD (NOLOCK) ON (OD.ExternPOKey = R.ExternReceiptKey)          ' 
                 + '      JOIN ORDERS O (NOLOCK) ON O.OrderKey = OD.OrderKey          ' 
                 + '      JOIN SKU (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU)          ' 
                 + '      JOIN (SELECT RD1.ReceiptKey, MAX(RD1.POKEY) as POKey FROM '+RTRIM(@c_arcdbname)+'..ReceiptDetail RD1 (NOLOCK)          ' 
                 + '            WHERE RD1.ReceiptKey = N'''+ @cReceiptKey +''' ' 
                 + '            GROUP BY RD1.ReceiptKey)         ' 
                 + '           AS RD ON RD.ReceiptKey = R.ReceiptKey         ' 
                 + '      WHERE R.ReceiptKey = N'''+@cReceiptKey +''' '
                 + '      AND ISNULL(RTRIM(R.ExternReceiptKey),'''') <> '''' ' 
                 + '      GROUP BY R.ReceiptDate,         ' 
                 + '             O.ExternOrderKey,          ' 
                 + '             O.C_Company,            ' 
                 + '             O.C_Address1,         ' 
                 + '      O.C_Address2,          ' 
                 + '             O.C_Phone1,         ' 
                 + '             OD.ExternPOKey,         ' 
                 + '             RD.POKey,         ' 
                 + '             OD.UserDefine02,         ' 
                 + '             REPLACE(LEFT(OD.SKU, 12), ''-'', ''''),          ' 
                 + '             REPLACE(RIGHT(OD.SKU, 5), ''-'', ''''),          ' 
                 + '             O.OrderKey,         ' 
                 + '             O.BuyerPO  /*NJOW01*/           ' 
                 + '      ORDER BY O.ExternOrderKey, OD.UserDefine02, REPLACE(LEFT(OD.SKU, 12), ''-'', '''') '
        EXEC(@sql)
        
        IF @@ROWCOUNT = 0 --Get orders from archive
        BEGIN
		        SET @sql = '/*DECLARE CUR_GetOrderLine CURSOR FAST_FORWARD READ_ONLY FOR*/          '
		                 + '      INSERT INTO #TEMP_CUR         '
		                 + '      SELECT R.ReceiptDate,         '
		                 + '             O.ExternOrderKey,          '
		                 + '             O.C_Company,            ' 
		                 + '             ISNULL(RTrim(O.C_Address1),'''') + '' '' + ISNULL(RTrim(O.C_Address2),'''') AS Address,          ' 
		                 + '             O.C_Phone1,         ' 
		                 + '             OD.ExternPOKey,         ' 
		                 + '             RD.POKey,         ' 
		                 + '             OD.UserDefine02 AS UCC,         ' 
		                 + '             REPLACE(LEFT(OD.SKU, 12), ''-'', '''') AS MaterialNo,          ' 
		                 + '             REPLACE(RIGHT(OD.SKU, 5), ''-'', '''') AS [Size],          ' 
		                 + '             /*SUM(OD.OriginalQty) AS OriginalQty,    SOS#129172*/             ' 
		                 + '             /* SUM(OD.Qtyallocated) AS Qtyallocated, SOS#129172*/       ' 
		                 + '             SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS Qty, /*SOS#130771*/       ' 
		                 + '             MAX(ISNULL(SKU.Price,0)) AS Price,          '
		                 + '             MAX(ISNULL(SKU.DESCR, '''')) AS SKUDescr,          ' 
		                 + '             O.OrderKey,         ' 
		                 + '             O.BuyerPO   /*NJOW01*/           ' 
		                 + '      FROM '+RTRIM(@c_arcdbname)+'..RECEIPT R (NOLOCK)           ' 
		                 + '      JOIN '+RTRIM(@c_arcdbname)+'..ORDERDETAIL OD (NOLOCK) ON (OD.ExternPOKey = R.ExternReceiptKey)          ' 
		                 + '      JOIN '+RTRIM(@c_arcdbname)+'..ORDERS O (NOLOCK) ON O.OrderKey = OD.OrderKey          ' 
		                 + '      JOIN SKU (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU)          ' 
		                 + '      JOIN (SELECT RD1.ReceiptKey, MAX(RD1.POKEY) as POKey FROM '+RTRIM(@c_arcdbname)+'..ReceiptDetail RD1 (NOLOCK)          ' 
		                 + '            WHERE RD1.ReceiptKey = N'''+ @cReceiptKey +''' ' 
		                 + '            GROUP BY RD1.ReceiptKey)         ' 
		                 + '           AS RD ON RD.ReceiptKey = R.ReceiptKey         ' 
		                 + '      WHERE R.ReceiptKey = N'''+@cReceiptKey +''' '
		                 + '      AND ISNULL(RTRIM(R.ExternReceiptKey),'''') <> '''' ' 
		                 + '      GROUP BY R.ReceiptDate,         ' 
		                 + '             O.ExternOrderKey,          ' 
		                 + '             O.C_Company,            ' 
		                 + '             O.C_Address1,         ' 
		                 + '      O.C_Address2,          ' 
		                 + '             O.C_Phone1,         ' 
		                 + '             OD.ExternPOKey,         ' 
		                 + '             RD.POKey,         ' 
		                 + '             OD.UserDefine02,         ' 
		                 + '             REPLACE(LEFT(OD.SKU, 12), ''-'', ''''),          ' 
		                 + '             REPLACE(RIGHT(OD.SKU, 5), ''-'', ''''),          ' 
		                 + '             O.OrderKey,         ' 
		                 + '             O.BuyerPO  /*NJOW01*/           ' 
		                 + '      ORDER BY O.ExternOrderKey, OD.UserDefine02, REPLACE(LEFT(OD.SKU, 12), ''-'', '''') '
		        EXEC(@sql)
      	END
      END      
   END
   
   DECLARE CUR_GetOrderLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT * FROM #TEMP_CUR
        
   OPEN CUR_GetOrderLine        
           
   FETCH NEXT FROM CUR_GetOrderLine INTO         
         @dReceiptDate,        
         @cExternOrderKey,         
         @cC_Company,           
         @cAddress,         
         @cC_Phone1,        
         @cExternPOKey,        
         @cPOKey,        
         @cUCCNo,        
         @cMaterialNo,         
         @cSKUSize,         
         @nQty,        
         @nPrice,         
         @cSkuDescr,        
         @cOrderKey,        
         @cBuyerPO --NJOW01          	

   --NJOW02 -----End
          
   SET @nFetchStatus = @@FETCH_STATUS           
   SET @cPrevExternOrderKey = @cExternOrderKey        
   SET @cPrevMaterialNo     = @cMaterialNo       
   SET @cPrevcSkuDescr      = @cSkuDescr --SOS#130771      
   SET @cPrevUCCNo          = @cUCCNo        
   SET @cPrevOrderKey       = @cOrderKey        
   SET @cPrevC_Company      = @cC_Company        
   SET @cPrevAddress        = @cAddress        
   SET @cPrevC_Phone1       = @cC_Phone1        
   SET @cPrevBuyerPO        = @cBuyerPO --NJOW01        
           
   SELECT @cSkuSize1='',  @cSkuSize2='',  @cSkuSize3='',  @cSkuSize4=''   --initialise counter        
   SELECT @cSkuSize5='',  @cSkuSize6='',  @cSkuSize7='',  @cSkuSize8=''        
   SELECT @cSkuSize9='',  @cSkuSize10=''        
        
   SELECT @nQty1=0, @nQty2=0, @nQty3=0, @nQty4=0, @nQty5=0, @nQty6=0, @nQty7=0  ---- initialise counter        
   SELECT @nQty8=0, @nQty9=0, @nQty10=0        
        
   SET @nCnt = 0         
        
   WHILE @nFetchStatus = 0        
   BEGIN        
      IF  @cPrevExternOrderKey <> @cExternOrderKey OR         
          @cPrevMaterialNo     <> @cMaterialNo OR         
          @cPrevcSkuDescr      <> @cSkuDescr OR --SOS#130771        
          @cPrevUCCNo          <> @cUCCNo         
      BEGIN        
      	 IF @c_FromArchive = 'Y'
      	 BEGIN
      	 	  DELETE FROM #TMPCNT
      	 	  SET @SQL = 'INSERT INTO #TMPCNT SELECT COUNT(DISTINCT O.USERDEFINE02) '
								+ 'FROM ORDERDETAIL O (NOLOCK) '
								+ 'WHERE O.ExternOrderKey =N'''+ @cPrevExternOrderKey +''''
            EXEC(@SQL)
            
            IF @@ROWCOUNT = 0 
            BEGIN
	      	 	  SET @SQL = 'INSERT INTO #TMPCNT SELECT COUNT(DISTINCT O.USERDEFINE02) '
									+ 'FROM '+RTRIM(@c_arcdbname)+'..ORDERDETAIL O (NOLOCK) '
									+ 'WHERE O.ExternOrderKey =N'''+ @cPrevExternOrderKey +''''
      	      EXEC(@SQL)
            END
					  
				  SELECT @nCartonCnt = cartoncnt
				  FROM #TMPCNT
      	 END
      	 ELSE
      	 BEGIN
         		SELECT @nCartonCnt = COUNT(DISTINCT USERDEFINE02)         
         		FROM   ORDERDETAIL (NOLOCK)        
		        WHERE  ExternOrderKey = @cPrevExternOrderKey         
         END
        
                 
         INSERT INTO #TempPackList (        
                ReceiptDate ,ExternOrderKey ,C_Company ,C_Address         
               ,C_Phone1    ,ExternPOKey    ,POKey     ,UCCNO         
               ,OrderKey    ,CartonCnt      ,SizeLine  ,MaterialNo         
               ,SKUDescr    ,SKUPrice       ,SkuSize1  ,SkuSize2         
               ,SkuSize3    ,SkuSize4       ,SkuSize5  ,SkuSize6         
               ,SkuSize7    ,SkuSize8       ,SkuSize9  ,SkuSize10         
               ,Qty1        ,Qty2           ,Qty3      ,Qty4         
               ,Qty5        ,Qty6           ,Qty7      ,Qty8         
               ,Qty9        ,Qty10          ,BuyerPO)        
         VALUES (        
                @dReceiptDate ,@cPrevExternOrderKey ,@cPrevC_Company ,@cPrevaddress         
               ,@cPrevC_Phone1    ,@cExternPOKey        ,@cPOKey     ,@cPrevUCCNo ,@cPrevOrderKey         
               ,@nCartonCnt   ,0 ,@cPrevMaterialNo  , @cPrevcSkuDescr/*@cSkuDescr  SOS#130771*/  ,@nPrice     ,@cSkuSize1         
               ,@cSkuSize2    ,@cSkuSize3           ,@cSkuSize4  ,@cSkuSize5  ,@cSkuSize6         
               ,@cSkuSize7    ,@cSkuSize8           ,@cSkuSize9  ,@cSkuSize10 ,@nQty1     ,@nQty2         
        ,@nQty3        ,@nQty4               ,@nQty5      ,@nQty6      ,@nQty7            
               ,@nQty8        ,@nQty9               ,@nQty10     ,@cPrevBuyerPO        
               ) --NJOW01        
        
         SELECT @cSkuSize1 = @cSKUSize,          
                @cSkuSize2='',  @cSkuSize3='',  @cSkuSize4=''   --initialise counter        
         SELECT @cSkuSize5='',  @cSkuSize6='',  @cSkuSize7='',  @cSkuSize8=''        
         SELECT @cSkuSize9='',  @cSkuSize10=''        
            
         SELECT @nQty1 = @nQty,         
                @nQty2=0, @nQty3=0, @nQty4=0, @nQty5=0,         
                @nQty6=0, @nQty7=0          
         SELECT @nQty8=0, @nQty9=0, @nQty10=0        
        
         SET @nCnt = 1        
        
         IF @cPrevExternOrderKey  <> @cExternOrderKey         
         BEGIN        
            SET @cPrevExternOrderKey = @cExternOrderKey        
            SET @cPrevOrderKey   = @cOrderKey        
            SET @cPrevC_Company      = @cC_Company        
            SET @cPrevAddress        = @cAddress        
            SET @cPrevC_Phone1       = @cC_Phone1        
            SET @cPrevBuyerPO        = @cBuyerPO --NJOW01        
         END         
        
         IF @cPrevMaterialNo  <> @cMaterialNo                  
            SET @cPrevMaterialNo    = @cMaterialNo        
               
        IF @cPrevcSkuDescr <> @cSkuDescr /*SOS#130771 start*/      
            SET @cPrevcSkuDescr  =   @cSkuDescr     /*SOS#130771 end*/      
        
         IF @cPrevUCCNo  <> @cUCCNo         
         BEGIN        
            SET @cPrevUCCNo          = @cUCCNo        
         END         
        
      END         
      ELSE        
      BEGIN        
         SET @nCnt = @nCnt + 1         
      END         
        
      IF  @nCnt = 1  select @cSkuSize1  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 2  select @cSkuSize2  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 3  select @cSkuSize3  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 4  select @cSkuSize4  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 5  select @cSkuSize5  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 6  select @cSkuSize6  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 7  select @cSkuSize7  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 8  select @cSkuSize8  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 9  select @cSkuSize9  = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
      IF  @nCnt = 10 select @cSkuSize10 = ISNULL(dbo.fnc_LTrim(dbo.fnc_RTrim(@cSKUSize)),'')        
              
              
      IF  @nCnt = 1 select @nQty1 = @nQty        
      IF  @nCnt = 2 select @nQty2 = @nQty        
      IF  @nCnt = 3 select @nQty3 = @nQty        
      IF  @nCnt = 4 select @nQty4 = @nQty        
      IF  @nCnt = 5 select @nQty5 = @nQty        
      IF  @nCnt = 6 select @nQty6 = @nQty        
      IF  @nCnt = 7 select @nQty7 = @nQty        
      IF  @nCnt = 8 select @nQty8 = @nQty        
      IF  @nCnt = 9 select @nQty9 = @nQty        
      IF  @nCnt = 10 select @nQty10 = @nQty        
          
      FETCH NEXT FROM CUR_GetOrderLine INTO         
           @dReceiptDate,        
           @cExternOrderKey,         
           @cC_Company,           
           @cAddress,         
           @cC_Phone1,        
           @cExternPOKey,        
           @cPOKey,        
           @cUCCNo,        
           @cMaterialNo,         
           @cSKUSize,         
           @nQty,        
           @nPrice,         
           @cSkuDescr,         
           @cOrderKey,        
           @cBuyerPO  --NJOW01          
        
      SET @nFetchStatus = @@FETCH_STATUS        
        
  END   --CUR_GetOrderLine        
  
   IF @c_FromArchive = 'Y'
   BEGIN
        DELETE FROM #TMPCNT
        SET @SQL = 'INSERT INTO #TMPCNT SELECT COUNT(DISTINCT O.USERDEFINE02) '
						+ 'FROM ORDERDETAIL O (NOLOCK) '
						+ 'WHERE O.ExternOrderKey =N'''+ @cPrevExternOrderKey +''''
        EXEC(@SQL)
        
        IF @@ROWCOUNT = 0
        BEGIN
	        SET @SQL = 'INSERT INTO #TMPCNT SELECT COUNT(DISTINCT O.USERDEFINE02) '
							+ 'FROM '+RTRIM(@c_arcdbname)+'..ORDERDETAIL O (NOLOCK) '
							+ 'WHERE O.ExternOrderKey =N'''+ @cPrevExternOrderKey +''''
	        EXEC(@SQL)
        END
					  					  
		  SELECT @nCartonCnt = cartoncnt
		  FROM #TMPCNT
   END
   ELSE
   BEGIN
      SELECT @nCartonCnt = COUNT(DISTINCT USERDEFINE02)         
      FROM   ORDERDETAIL (NOLOCK)        
      WHERE  ExternOrderKey = @cPrevExternOrderKey         
   END

        
   -- IF @cPrevUCCNo  <> @cUCCNo -- SOS#126667         
        
         INSERT INTO #TempPackList (        
                ReceiptDate ,ExternOrderKey ,C_Company ,C_Address         
               ,C_Phone1    ,ExternPOKey    ,POKey     ,UCCNO         
               ,OrderKey    ,CartonCnt      ,SizeLine  ,MaterialNo         
               ,SKUDescr    ,SKUPrice       ,SkuSize1  ,SkuSize2         
               ,SkuSize3    ,SkuSize4       ,SkuSize5  ,SkuSize6         
               ,SkuSize7    ,SkuSize8       ,SkuSize9  ,SkuSize10         
               ,Qty1        ,Qty2           ,Qty3      ,Qty4         
               ,Qty5        ,Qty6           ,Qty7      ,Qty8         
               ,Qty9        ,Qty10          ,BuyerPO)        
         VALUES (        
                @dReceiptDate ,@cPrevExternOrderKey ,@cPrevC_Company ,@cPrevaddress         
               ,@cPrevC_Phone1 ,@cExternPOKey ,@cPOKey ,@cPrevUCCNo ,@cPrevOrderKey         
               ,@nCartonCnt ,0 ,@cPrevMaterialNo ,@cPrevcSkuDescr /*@cSkuDescr SOS#130771*/    ,@nPrice ,@cSkuSize1         
               ,@cSkuSize2 ,@cSkuSize3 ,@cSkuSize4 ,@cSkuSize5  ,@cSkuSize6         
               ,@cSkuSize7 ,@cSkuSize8 ,@cSkuSize9 ,@cSkuSize10 ,@nQty1 ,@nQty2         
               ,@nQty3 ,@nQty4 ,@nQty5 ,@nQty6 ,@nQty7 ,@nQty8 ,@nQty9 ,@nQty10,@cPrevBuyerPO        
               ) --NJOW01        
        
        
   CLOSE CUR_GetOrderLine        
   DEALLOCATE CUR_GetOrderLine        
        
   SELECT * FROM #TempPackList (NOLOCK)--GROUP BY MaterialNo        
        
   DROP TABLE #TempPackList
   DROP TABLE #TEMP_CUR
   DROP TABLE #TMPCNT        
END

GO