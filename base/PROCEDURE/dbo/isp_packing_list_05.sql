SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store Procedure: isp_Packing_List_05                                         */
/* Copyright: IDS                                                               */
/*                                                                              */
/* Purpose: Generate Packing List                                               */
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
/* 10-09-2009  1.0  James    SOS147256 - Created                                */
/********************************************************************************/

CREATE PROCEDURE [dbo].[isp_Packing_List_05] (
@cStorerKey_Start NVARCHAR(15),
@cStorerKey_End   NVARCHAR(15),
@cWaveKey_Start NVARCHAR(10),
@cWaveKey_End   NVARCHAR(10),
@cLoadKey_Start NVARCHAR(10),
@cLoadKey_End   NVARCHAR(10),
@cExternOrderKey_Start NVARCHAR(30),
@cExternOrderKey_End   NVARCHAR(30),
@cOrderKey_Start NVARCHAR(10),
@cOrderKey_End   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @bDebug int

   SELECT @bDebug = 0

   DECLARE @c_arcdbname      NVARCHAR(30),
           @sql              nvarchar(4000),
           @c_FromArchive    NVARCHAR(1),
           @c_ExecStatements nvarchar(4000),
           @c_ExecArguments  nvarchar(4000)  

   SELECT @c_FromArchive = 'N'

   DECLARE
      @cExternPOKey          NVARCHAR(20),
      @cOrderKey             NVARCHAR(10),
      @cC_Company            NVARCHAR(45),
      @dDeliveryDate         datetime,
      @cAddress              NVARCHAR(90),
      @cContact1             NVARCHAR(30),
      @cC_Phone1             NVARCHAR(18),
      @cExternOrderKey       NVARCHAR(30),
      @cPrevExternOrderKey   NVARCHAR(30),
      @cPrevOrderKey         NVARCHAR(10),
      @cPrevC_Company        NVARCHAR(45),
      @cPrevAddress          NVARCHAR(90),
      @cPrevC_Phone1         NVARCHAR(18),
      @cPrevcSkuDescr        NVARCHAR(60),
      @cSkuDescr             NVARCHAR(60),
      @cMaterialNo           NVARCHAR(18),
      @cUCCNo                NVARCHAR(20),
      @cPrevUCCNo            NVARCHAR(20),
      @cOrdertype            NVARCHAR(10),
      @cStorerKey            NVARCHAR(15),
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
      @cSkuSize11            NVARCHAR(5),
      @cSkuSize12            NVARCHAR(5),
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
      @nQty11                int,
      @nQty12                int,
      @nCnt                  int,
      @bSuccess              int,
      @nErr                  int,
      @cErrMsg               NVARCHAR(255),
      @nFetchStatus          int,
      @nCartonCnt            int,
      @cBuyerPo              NVARCHAR(20), 
      @cPrevBuyerPo          NVARCHAR(20),  
      @dPrevDeliveryDate     datetime,
      @ntblCnt               INT,
      @cType                 NVARCHAR(10),
      @cPrevType             NVARCHAR(10)
      
   IF OBJECT_ID('tempdb..#TempPackList') IS NOT NULL
      DROP TABLE #TempPackList

   CREATE TABLE #TempPackList (
   ExternOrderKey NVARCHAR(30) NULL,
   C_Company      NVARCHAR(45) NULL,
   C_Address      NVARCHAR(90) NULL,
   C_Phone1       NVARCHAR(18) NULL,
   ExternPOKey    NVARCHAR(20) NULL,
   UCCNO          NVARCHAR(20) NULL,
   OrderKey       NVARCHAR(10) NULL,
   DeliveryDate   datetime NULL,
   CartonCnt      int NULL,
   SizeLine       int NULL,
   MaterialNo     NVARCHAR(18) NULL,
   SKUDescr       NVARCHAR(60) NULL,
--   SKUPrice       float   NULL,
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
   SkuSize11      NVARCHAR(5) NULL,
   SkuSize12      NVARCHAR(5) NULL,
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
   Qty11          int NULL,
   Qty12          int NULL,
   Type           NVARCHAR(10) NULL
   )

   CREATE TABLE #TMPCNT (cartoncnt int)

   SELECT
      O.ExternOrderKey,
      O.C_Company,
      ISNULL(RTRIM(O.C_Address1),'') + ' ' + ISNULL(RTRIM(O.C_Address2),'') AS Address,
      O.C_Phone1,
      OD.ExternPOKey,
      OD.UserDefine02 AS UCC,
      REPLACE(LEFT(OD.SKU, 12), '-', '') AS MaterialNo,
      REPLACE(RIGHT(OD.SKU, 5), '-', '') AS [Size],
      SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS Qty,
      MAX(ISNULL(SKU.DESCR, '')) AS SKUDescr,
      O.OrderKey,
      O.DeliveryDate,
      O.Type 
   INTO #TEMP_CUR
   FROM ORDERS O WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey
   JOIN SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU)
   WHERE O.StorerKey BETWEEN @cStorerKey_Start AND @cStorerKey_End
      AND O.UserDefine09 BETWEEN @cWaveKey_Start AND @cWaveKey_End
      AND O.LoadKey BETWEEN @cLoadKey_Start AND @cLoadKey_End
      AND O.ExternOrderKey BETWEEN @cExternOrderKey_Start AND @cExternOrderKey_End
      AND O.OrderKey BETWEEN @cOrderKey_Start AND @cOrderKey_End
      AND (LEFT(O.TYPE, 7) = 'EC-MAIN' OR O.TYPE = 'XDOCK')
   GROUP BY
      O.ExternOrderKey,
      O.C_Company,
      O.C_Address1,
      O.C_Address2,
      O.C_Phone1,
      OD.ExternPOKey,
      OD.UserDefine02,
      REPLACE(LEFT(OD.SKU, 12), '-', ''),
      REPLACE(RIGHT(OD.SKU, 5), '-', ''),
      O.OrderKey,
      O.DeliveryDate,
      O.Type 
   ORDER BY O.ExternOrderKey, OD.UserDefine02, REPLACE(LEFT(OD.SKU, 12), '-', '')

   IF @@ROWCOUNT = 0
   BEGIN
 	   SELECT @c_arcdbname = NSQLValue FROM NSQLCONFIG (NOLOCK)
      WHERE ConfigKey='ArchiveDBName'

      --temp use only !!!
      set @c_arcdbname = 't08_archive'
--      SET @sql = 'SELECT 1 FROM ' + RTRIM(@c_arcdbname) + '.sys.objects WHERE object_id in '
--         + '(OBJECT_ID(N''[dbo].[sku]''), OBJECT_ID(N''[dbo].[orders]''), OBJECT_ID(N''[dbo].[orderdetail]'')) '
--         + 'AND type in (N''U'') '
--      EXEC(@sql)

      SET @c_ExecStatements = N'SELECT COUNT(1) = @ntblCnt '
                              + 'FROM ' + ISNULL(RTRIM(@c_arcdbname),'') + '.sys.objects WITH (NOLOCK) WHERE object_id in ' 
                              + '(OBJECT_ID(N''[dbo].[sku]''), OBJECT_ID(N''[dbo].[orders]''), OBJECT_ID(N''[dbo].[orderdetail]'')) '
                              + 'AND type in (N''U'') '
									 
      SET @c_ExecArguments = N'@c_arcdbname NVARCHAR(30), ' + 
										'@ntblCnt     INT OUTPUT ' 

      IF @ntblCnt = 3 --all 3 tables in archive db exists only then we proceed to retrieve from archive db
      BEGIN
         SELECT @c_FromArchive = 'Y'
         SET @sql = 'INSERT INTO #TEMP_CUR '
            + 'SELECT '
            + 'O.ExternOrderKey, '
            + 'O.C_Company, '
            + 'ISNULL(RTrim(O.C_Address1),'''') + '' '' + ISNULL(RTrim(O.C_Address2),'''') AS Address, '
            + 'O.C_Phone1, '
            + 'OD.ExternPOKey, '
            + 'OD.UserDefine02 AS UCC, '
            + 'REPLACE(LEFT(OD.SKU, 12), ''-'', '''') AS MaterialNo, '
            + 'REPLACE(RIGHT(OD.SKU, 5), ''-'', '''') AS [Size], '
            + 'SUM(OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) AS Qty, '
            + 'MAX(ISNULL(SKU.DESCR, '''')) AS SKUDescr, '
            + 'O.OrderKey, '
            + 'O.DeliveryDate, '
            + 'O.Type '
            + 'FROM ' + RTRIM(@c_arcdbname) + '..ORDERS O WITH (NOLOCK) '
            + 'JOIN ' + RTRIM(@c_arcdbname) + '..ORDERDETAIL OD WITH (NOLOCK) ON O.OrderKey = OD.OrderKey '
            + 'JOIN ' + RTRIM(@c_arcdbname) + '..SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU) '
            + 'WHERE O.StorerKey BETWEEN N''' + @cStorerKey_Start + ''' AND N''' + @cStorerKey_End + ''' '
            + '   AND O.UserDefine09 BETWEEN N''' + @cWaveKey_Start + ''' AND N''' + @cWaveKey_End + ''' '
            + '   AND O.LoadKey BETWEEN N''' + @cLoadKey_Start + ''' AND N''' + @cLoadKey_End + ''' '
            + '   AND O.ExternOrderKey BETWEEN N''' + @cExternOrderKey_Start + ''' AND N''' + @cExternOrderKey_End + ''' '
            + '   AND O.OrderKey BETWEEN N''' + @cOrderKey_Start + ''' AND N''' + @cOrderKey_End + ''' '
            + 'AND (LEFT(O.TYPE, 7) = ''EC-MAIN'' OR O.TYPE = ''XDOCK'') '
            + 'GROUP BY '
            + 'O.ExternOrderKey, '
            + 'O.C_Company, '
            + 'O.C_Address1, '
            + 'O.C_Address2, '
            + 'O.C_Phone1, '
            + 'OD.ExternPOKey, '
            + 'OD.UserDefine02, '
            + 'REPLACE(LEFT(OD.SKU, 12), ''-'', ''''), '
            + 'REPLACE(RIGHT(OD.SKU, 5), ''-'', ''''), '
            + 'O.OrderKey, '
            + 'O.DeliveryDate, '
            + 'O.Type '
            + 'ORDER BY O.ExternOrderKey, OD.UserDefine02, REPLACE(LEFT(OD.SKU, 12), ''-'', '''') '
         EXEC(@sql)
      END
   END

   DECLARE CUR_GetOrderLine CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT * FROM #TEMP_CUR

   OPEN CUR_GetOrderLine

   FETCH NEXT FROM CUR_GetOrderLine INTO
         @cExternOrderKey,
         @cC_Company,
         @cAddress,
         @cC_Phone1,
         @cExternPOKey,
         @cUCCNo,
         @cMaterialNo,
         @cSKUSize,
         @nQty,
         @cSkuDescr,
         @cOrderKey,
         @dDeliveryDate,
         @cType
         
   SET @nFetchStatus = @@FETCH_STATUS
   SET @cPrevExternOrderKey = @cExternOrderKey
   SET @cPrevMaterialNo     = @cMaterialNo
   SET @cPrevcSkuDescr      = @cSkuDescr
   SET @cPrevUCCNo          = @cUCCNo
   SET @cPrevOrderKey       = @cOrderKey
   SET @cPrevC_Company      = @cC_Company
   SET @cPrevAddress        = @cAddress
   SET @cPrevC_Phone1       = @cC_Phone1
   SET @dPrevDeliveryDate   = @dDeliveryDate
   SET @cPrevType           = @cType
   
   --initialise counter
   SELECT @cSkuSize1  = '',  @cSkuSize2  = ''
   SELECT @cSkuSize3  = '',  @cSkuSize4  = ''
   SELECT @cSkuSize5  = '',  @cSkuSize6  = ''
   SELECT @cSkuSize7  = '',  @cSkuSize8  = ''
   SELECT @cSkuSize9  = '',  @cSkuSize10 = ''
   SELECT @cSkuSize11 = '',  @cSkuSize12 = ''

   SELECT @nQty1  = 0, @nQty2  = 0
   SELECT @nQty3  = 0, @nQty4  = 0
   SELECT @nQty5  = 0, @nQty6  = 0
   SELECT @nQty7  = 0, @nQty8  = 0
   SELECT @nQty9  = 0, @nQty10 = 0
   SELECT @nQty11 = 0, @nQty12 = 0

   SET @nCnt = 0

   WHILE @nFetchStatus = 0
   BEGIN
      IF  @cPrevExternOrderKey <> @cExternOrderKey OR
          @cPrevMaterialNo     <> @cMaterialNo OR
          @cPrevcSkuDescr      <> @cSkuDescr OR
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
               + 'FROM ' + RTRIM(@c_arcdbname) + '..ORDERDETAIL O (NOLOCK) '
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
                ExternOrderKey ,C_Company   ,C_Address ,C_Phone1       
               ,ExternPOKey    ,UCCNO       ,OrderKey  ,CartonCnt    
               ,SizeLine       ,MaterialNo  ,SKUDescr  ,DeliveryDate 
               ,SkuSize1       ,SkuSize2    ,SkuSize3  ,SkuSize4     
               ,SkuSize5       ,SkuSize6    ,SkuSize7  ,SkuSize8     
               ,SkuSize9       ,SkuSize10   ,SkuSize11 ,SkuSize12
               ,Qty1           ,Qty2        ,Qty3      ,Qty4
               ,Qty5           ,Qty6        ,Qty7      ,Qty8
               ,Qty9           ,Qty10       ,Qty11     ,Qty12, Type)
         VALUES (
                @cPrevExternOrderKey ,@cPrevC_Company  ,@cPrevaddress   ,@cPrevC_Phone1       
               ,@cExternPOKey        ,@cPrevUCCNo      ,@cPrevOrderKey  ,@nCartonCnt        
               ,0                    ,@cPrevMaterialNo ,@cPrevcSkuDescr ,@dPrevDeliveryDate 
               ,@cSkuSize1           ,@cSkuSize2       ,@cSkuSize3      ,@cSkuSize4         
               ,@cSkuSize5           ,@cSkuSize6       ,@cSkuSize7      ,@cSkuSize8         
               ,@cSkuSize9           ,@cSkuSize10      ,@cSkuSize11     ,@cSkuSize12 
               ,@nQty1               ,@nQty2           ,@nQty3          ,@nQty4               
               ,@nQty5               ,@nQty6           ,@nQty7          ,@nQty8        
               ,@nQty9               ,@nQty10          ,@nQty11         ,@nQty12, @cPrevType)

         --initialise counter
         SELECT @cSkuSize1 = @cSKUSize, @cSkuSize2='', @cSkuSize3='',  @cSkuSize4=''   
         SELECT @cSkuSize5='',  @cSkuSize6='',  @cSkuSize7='',  @cSkuSize8=''
         SELECT @cSkuSize9='',  @cSkuSize10='', @cSkuSize11='', @cSkuSize12=''

         SELECT @nQty1 = @nQty, @nQty2=0, @nQty3=0, @nQty4=0
         SELECT @nQty5=0, @nQty6=0, @nQty7=0, @nQty8=0
         SELECT @nQty9=0, @nQty10=0, @nQty11=0, @nQty12=0

         SET @nCnt = 1

         IF @cPrevExternOrderKey  <> @cExternOrderKey
         BEGIN
            SET @cPrevExternOrderKey = @cExternOrderKey
            SET @cPrevOrderKey       = @cOrderKey
            SET @cPrevC_Company      = @cC_Company
            SET @cPrevAddress        = @cAddress
            SET @cPrevC_Phone1       = @cC_Phone1
            SET @dPrevDeliveryDate   = @dDeliveryDate
            SET @cPrevType           = @cType
         END

         IF @cPrevMaterialNo  <> @cMaterialNo
            SET @cPrevMaterialNo = @cMaterialNo

         IF @cPrevcSkuDescr <> @cSkuDescr 
            SET @cPrevcSkuDescr  = @cSkuDescr     

         IF @cPrevUCCNo  <> @cUCCNo
         BEGIN
            SET @cPrevUCCNo = @cUCCNo
         END
      END
      ELSE
      BEGIN
         SET @nCnt = @nCnt + 1
      END

      IF  @nCnt = 1  select @cSkuSize1  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 2  select @cSkuSize2  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 3  select @cSkuSize3  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 4  select @cSkuSize4  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 5  select @cSkuSize5  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 6  select @cSkuSize6  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 7  select @cSkuSize7  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 8  select @cSkuSize8  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 9  select @cSkuSize9  = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 10 select @cSkuSize10 = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 11 select @cSkuSize11 = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')
      IF  @nCnt = 12 select @cSkuSize12 = ISNULL(LTRIM(RTRIM(@cSKUSize)),'')


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
      IF  @nCnt = 11 select @nQty11 = @nQty
      IF  @nCnt = 12 select @nQty12 = @nQty

      FETCH NEXT FROM CUR_GetOrderLine INTO
           @cExternOrderKey,
           @cC_Company,
           @cAddress,
           @cC_Phone1,
           @cExternPOKey,
           @cUCCNo,
           @cMaterialNo,
           @cSKUSize,
           @nQty,
           @cSkuDescr,
           @cOrderKey,
           @dDeliveryDate,
           @cType
           
      SET @nFetchStatus = @@FETCH_STATUS
   END   --CUR_GetOrderLine

   IF @c_FromArchive = 'Y'
   BEGIN
      DELETE FROM #TMPCNT
      SET @SQL = 'INSERT INTO #TMPCNT SELECT COUNT(DISTINCT O.USERDEFINE02) '
      + 'FROM ORDERDETAIL O (NOLOCK) '
      + 'WHERE O.ExternOrderKey =N''' + @cPrevExternOrderKey + ''''
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
          ExternOrderKey ,C_Company  ,C_Address ,C_Phone1    
          ,ExternPOKey   ,UCCNO      ,OrderKey  ,CartonCnt      
          ,SizeLine      ,MaterialNo ,SKUDescr  ,DeliveryDate       
          ,SkuSize1      ,SkuSize2   ,SkuSize3  ,SkuSize4       
          ,SkuSize5      ,SkuSize6   ,SkuSize7  ,SkuSize8       
          ,SkuSize9      ,SkuSize10  ,SkuSize11 ,SkuSize12         
          ,Qty1          ,Qty2       ,Qty3      ,Qty4         
          ,Qty5          ,Qty6       ,Qty7      ,Qty8
          ,Qty9          ,Qty10      ,Qty11     ,Qty12, Type)
   VALUES (
           @cPrevExternOrderKey ,@cPrevC_Company  ,@cPrevaddress   ,@cPrevC_Phone1 
          ,@cExternPOKey        ,@cPrevUCCNo      ,@cPrevOrderKey  ,@nCartonCnt 
          ,0                    ,@cPrevMaterialNo ,@cPrevcSkuDescr ,@dPrevDeliveryDate 
          ,@cSkuSize1           ,@cSkuSize2       ,@cSkuSize3      ,@cSkuSize4 
          ,@cSkuSize5           ,@cSkuSize6       ,@cSkuSize7      ,@cSkuSize8 
          ,@cSkuSize9           ,@cSkuSize10      ,@cSkuSize11     ,@cSkuSize12 
          ,@nQty1               ,@nQty2           ,@nQty3          ,@nQty4 
          ,@nQty5               ,@nQty6           ,@nQty7          ,@nQty8 
          ,@nQty9               ,@nQty10          ,@nQty11         ,@nQty12, @cPrevType) 


   CLOSE CUR_GetOrderLine
   DEALLOCATE CUR_GetOrderLine

   SELECT * FROM #TempPackList (NOLOCK) WHERE Orderkey is not null--GROUP BY MaterialNo

   DROP TABLE #TempPackList
   DROP TABLE #TEMP_CUR
   DROP TABLE #TMPCNT
END

GO