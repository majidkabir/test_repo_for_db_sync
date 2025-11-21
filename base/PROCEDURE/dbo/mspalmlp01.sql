SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: mspALMLP01                                            */
/* Creation Date: 2024-03-14                                               */
/* Copyright: Maersk                                                       */
/* Written by:Wan                                                          */
/*                                                                         */
/* Purpose:                                                                */
/*          (Work with SkipPreAllocation)                                  */
/*                                                                         */
/* Called By: nspOrderProcessing                                           */
/*                                                                         */
/* PVCS Version: 1.4                                                       */
/*                                                                         */
/* Version: V2                                                             */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author   Rev  Purposes                                      */
/* 2024-04-24  Wan01    1.1  UWP-15060 Fixed Get Multiple lot not filter by*/
/*                           Qty                                           */
/* 2024-04-24 SSA91301  1.2  UWP-18454 allow skip lottable filtering       */
/* 2024-06-25  Wan02    1.3  UWP-21046 shelf-life by % for consignee       */
/* 2024-07-09  Wan03    1.4  UWP-21046 shelf-life by % for consignee       */ 
/*                           % need to be as float for calculation         */
/* 2024-10-16  Wan04    1.5  UWP-24391 [FCR-837] Unilever Replenishment for*/
/*                           Flowrack locations                            */
/***************************************************************************/
CREATE   PROC [dbo].[mspALMLP01]
   @c_DocumentNo        NVARCHAR(10)
,  @c_Facility          NVARCHAR(5)
,  @c_StorerKey         NVARCHAR(15)
,  @c_SKU               NVARCHAR(20)
,  @c_Lottable01        NVARCHAR(18)
,  @c_Lottable02        NVARCHAR(18)
,  @c_Lottable03        NVARCHAR(18)
,  @d_Lottable04        DATETIME
,  @d_Lottable05        DATETIME
,  @c_Lottable06        NVARCHAR(30)
,  @c_Lottable07        NVARCHAR(30)
,  @c_Lottable08        NVARCHAR(30)
,  @c_Lottable09        NVARCHAR(30)
,  @c_Lottable10        NVARCHAR(30)
,  @c_Lottable11        NVARCHAR(30)
,  @c_Lottable12        NVARCHAR(30)
,  @d_Lottable13        DATETIME
,  @d_Lottable14        DATETIME
,  @d_Lottable15        DATETIME
,  @c_UOM               NVARCHAR(10)
,  @c_HostWHCode        NVARCHAR(10)
,  @n_UOMBase           INT
,  @n_QtyLeftToFulfill  INT
,  @c_OtherParms        NVARCHAR(200)=''
AS
BEGIN
   DECLARE @n_StorerSkuMinShelfLife          INT            = 0   
         , @n_ConsigneeSkuMinShelfLife       INT            = 0
         , @n_SkuOutGoingMinShelfLife        INT            = 0
         , @n_OrderMinShelfLife              INT            = 0
         , @n_ConsigneeSkuGroupMinShelfLife  INT            = 0
         , @c_ContinueChkShelfLife           NCHAR(1)       = 0
         , @c_Condition                      NVARCHAR(MAX)  =''
         , @c_SQL                            NVARCHAR(MAX)  =''
         , @c_SQLParms                       NVARCHAR(MAX)  =''     
         , @C_SortBy                         NVARCHAR(2000) =''
         , @c_Orderkey                       NVARCHAR(10)   =''
         , @c_OrderLineNumber                NVARCHAR(5)    =''
         , @c_OverAllocateFlag               NCHAR(1)       =''
         , @c_FullPalletByLocFlag            NCHAR(1)       ='Y'
         , @c_ShelfLifeFlag                  NCHAR(1)       ='' 
         , @n_LotQtyAvailable                INT            =0
         , @n_QtyAvailable                   INT            =''
         , @n_QtyToTake                      INT            =''
         , @n_NoOfLot                        INT            =''
         , @c_LOT                            NVARCHAR(10)   =''
         , @c_LOC                            NVARCHAR(10)   =''
         , @c_ID                             NVARCHAR(18)   =''
         , @c_OtherValue                     NVARCHAR(20)   =''
         , @c_Wavekey                        NVARCHAR(10)   =''
         , @c_Loadkey                        NVARCHAR(10)   =''
         , @c_key3                           NVARCHAR(10)   =''
         , @c_LocationCategory               NVARCHAR(10)   ='VNA'
         , @c_SkipLottableFilter             NVARCHAR(60)                           --SSA91301
         , @c_CLKCondition                   NVARCHAR(MAX)                          --SSA91301
         , @c_CLKConditionFlag               NCHAR(1)                               --SSA91301
         , @c_AllocateStrategyKey            NVARCHAR(10)                           --SSA91301
         , @n_Cnt                            INT                                    --SSA91301
         , @c_ConsigneeSkuGroupPCTG          NVARCHAR(10)   = ''                    --(Wan02)
         , @c_ShelfLifeSQL                   NVARCHAR(100)  = ''                    --(Wan02)
         , @c_ShelfLifeStrategyCode          NVARCHAR(20)   = ''                    --(Wan02)

         , @c_UDF01                          NVARCHAR(30)   = ''                    --(Wan04)
         , @c_UDF02                          NVARCHAR(30)   = ''                    --(Wan04)  
         , @c_UDF03                          NVARCHAR(30)   = ''                    --(Wan04) 
         , @c_UDF04                          NVARCHAR(30)   = ''                    --(Wan04)
         , @c_UDF05                          NVARCHAR(30)   = ''                    --(Wan04)
         , @c_LocTypeSort                    NVARCHAR(2000) = ''                    --(Wan04)
         , @c_SortingFlag                    NCHAR(1)       = 'N'                   --(Wan04)
         , @c_Sortfields                     NVARCHAR(2000) = ''                    --(Wan04)   
         , @c_SortMode                       NVARCHAR(10)   = ''                    --(Wan04)
         , @c_FromPickLocFlag                NCHAR(1)       = 'N'                   --(Wan04)

   SET @c_Condition = ''
   SET @n_SkuOutGoingMinShelfLife = 0
   SET @n_OrderMinShelfLife = 0
   SET @n_StorerSkuMinShelfLife = 0
   SET @n_ConsigneeSkuMinShelfLife = 0
   SET @n_ConsigneeSkuGroupMinShelfLife = 0
   SET @c_ContinueChkShelfLife = 'N'
   SET @c_CLKCondition = ''     --SSA91301
   SET @c_SkipLottableFilter = ''     --SSA91301

   EXEC isp_Init_Allocate_Candidates          

   IF LEN(@c_OtherParms) > 0
   BEGIN
      SET @c_OrderLineNumber = SUBSTRING(@c_OtherParms, 11, 5)
      SET @c_Key3 = SUBSTRING(@c_OtherParms, 16, 1)

      IF ISNULL(@c_OrderLineNumber,'') <> ''
      BEGIN
         SET @c_Orderkey = LEFT(@c_OtherParms, 10)  --discrete by order

         SELECT @c_ID = ID,
                @n_OrderMinShelfLife = MinShelfLife
         FROM ORDERDETAIL(NOLOCK)
         WHERE Orderkey = @c_Orderkey
         AND OrderLineNumber = @c_OrderLineNumber

         SELECT @c_Loadkey = Loadkey
         FROM LOADPLANDETAIL(NOLOCK)
         WHERE Orderkey = @c_Orderkey
         
         SELECT @c_Wavekey = Wavekey
         FROM WAVEDETAIL(NOLOCK)
         WHERE Orderkey = @c_Orderkey
      END
      
      IF ISNULL(@c_OrderLineNumber,'')='' AND ISNULL(@c_key3,'')=''       
      BEGIN
         SET @c_Loadkey = LEFT(@c_OtherParms, 10)  --Load conso
         
         SELECT @c_Wavekey = MAX(WD.Wavekey)
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN WAVEDETAIL WD (NOLOCK) ON LPD.Orderkey = WD.Orderkey
         AND LPD.Loadkey = @c_Loadkey
         HAVING COUNT(DISTINCT WD.Wavekey) = 1
      END
      
      IF ISNULL(@c_OrderLineNumber,'')='' AND ISNULL(@c_key3,'')='W'       
      BEGIN
         SET @c_Wavekey = LEFT(@c_OtherParms, 10) --Wave conso
      END   
   END

   CREATE TABLE #TMP_LOT (LOT NVARCHAR(10) NULL,
                          QtyAvailable INT NULL DEFAULT(0))                                     
   
   ----------SkipLottablefilter logic start(SSA91301)-------------

   DECLARE  @TMP_CODELKUP TABLE (
       [LISTNAME] [nvarchar](10) NULL,
       [Code] [nvarchar](30) NULL,
       [Description] [nvarchar](250) NULL,
       [Short] [nvarchar](10) NULL,
       [Long] [nvarchar](250) NULL,
       [Notes] [nvarchar](4000) NULL,
       [Notes2] [nvarchar](4000) NULL,
       [Storerkey] [nvarchar](50) NULL,
       [UDF01] [nvarchar](60) NULL,
       [UDF02] [nvarchar](60) NULL,
       [UDF03] [nvarchar](60) NULL,
       [UDF04] [nvarchar](60) NULL,
       [UDF05] [nvarchar](60) NULL,
       [code2] [nvarchar](30) NULL
       )

  --Get strategy from sku
   SELECT @c_AllocateStrategykey = STRATEGY.AllocateStrategykey
      FROM SKU (NOLOCK)
      JOIN STRATEGY (NOLOCK) ON SKU.Strategykey = STRATEGY.Strategykey
      WHERE SKU.Storerkey = @c_Storerkey
      AND SKU.Sku = @c_Sku

   IF EXISTS(  SELECT 1 FROM ALLOCATESTRATEGYDETAIL (NOLOCK)                        --(Wan04) - START
               WHERE LocationTypeOverride IN ('PICK','CASE')  
               AND AllocateStrategyKey = @c_AllocateStrategykey
            ) 
   BEGIN
      SET @c_OverAllocateFlag = 'Y'   
   END                                                                              --(Wan04) - END

   INSERT INTO @TMP_CODELKUP (Listname, Code, Description, Short, Long, Notes, Notes2, Storerkey, UDF01, UDF02, UDF03, UDF04, UDF05, Code2)
   SELECT CODELKUP.Listname,
          CODELKUP.Code,
          CODELKUP.Description,
          CODELKUP.Short,
          CODELKUP.Long,
          CODELKUP.Notes,
          CODELKUP.Notes2,
          CODELKUP.Storerkey,
          CODELKUP.UDF01,
          CODELKUP.UDF02,
          CODELKUP.UDF03,
          CODELKUP.UDF04,
          CODELKUP.UDF05,
          CODELKUP.Code2
   FROM CODELKUP (NOLOCK)
   WHERE CODELKUP.Listname = 'mspALMLP01'
   AND CODELKUP.Storerkey = CASE WHEN CODELKUP.Short = @c_AllocateStrategykey AND CODELKUP.Storerkey = '' THEN CODELKUP.Storerkey ELSE @c_Storerkey END --if setup short and no setup storer ignore storer otherwise by storer.
   AND CODELKUP.Short IN ( CASE WHEN CODELKUP.Short NOT IN (NULL,'') THEN @c_AllocateStrategykey ELSE CODELKUP.Short END ) --if short setup must match Allocate strategykey
   AND Code2 IN (@c_UOM,'')

   --Get Shelflife
   SELECT TOP 1 @c_ShelfLifeFlag   = UDF01                                          --(Wan02) - START                                            --(Wan02)-START
         ,@c_ShelfLifeStrategyCode = UDF02  
   FROM @TMP_CODELKUP
   WHERE Code = 'SHELFLIFE'  
   AND Code2 IN (@c_UOM,'')   
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END --consider matched uom first --(Wan02)-END
           ,CASE WHEN UDF02 = '' THEN 9 ELSE 1 END

   --Retrieve codelkup condition
   SELECT TOP 1 @c_CLKCondition = Notes
   FROM @TMP_CODELKUP
   WHERE Code = 'CONDITION'  --retrieve addition conditions
   AND Code2 IN (@c_UOM,'')--if defined uom in code2 only apply for the specific strategy uom
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END --consider matched uom first

   SET @n_Cnt = @@ROWCOUNT

   IF @n_Cnt > 0
   BEGIN
      IF ISNULL(@c_CLKCondition,'') <> ''
      BEGIN
         SET @c_CLKConditionFlag = 'Y'
      END
   END

   SELECT TOP 1 @c_FromPickLocFlag = ISNULL(UDF01,'')                               --(Wan04) - START 
   FROM @TMP_CODELKUP  
   WHERE Code = 'FROMPICKLOC' --allocation from pick location only. default is all location type.  
   AND Code2 IN (@c_UOM,'') 
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   SELECT TOP 1 @c_SortFields = ISNULL(Notes,''), @c_SortMode = ISNULL(UDF01,'')      
   FROM @TMP_CODELKUP  
   WHERE Code = 'SORTING' --user can define sorting fields. default is FIFO.  
   AND Code2 IN (@c_UOM,'') 
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END                              --(Wan04) - END

   SELECT TOP 1 @c_SkipLottableFilter = ISNULL(UDF01,'')
   FROM @TMP_CODELKUP
   WHERE Code = 'SKIPLOTTABLEFILTER' --Skip lottable filtering.
   AND Code2 IN (@c_UOM,'')
   ORDER BY CASE WHEN Code2 = @c_UOM THEN 0 ELSE 1 END

   IF ISNULL(@c_SortFields,'') <> ''                                                --(Wan04) - START                                                              
   BEGIN  
      SET @c_SortingFlag = 'Y'  
   END                                                                              --(Wan04) - END

   IF (ISNULL(@c_Lottable01,'') <> '' AND CHARINDEX('01',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTTABLE01 = RTRIM(@c_Lottable01)'
   END

   IF (ISNULL(@c_Lottable02,'') <> '' AND CHARINDEX('02',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTTABLE02 = RTRIM(@c_Lottable02)'
   END

   IF (ISNULL(@c_Lottable03,'') <> '' AND CHARINDEX('03',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTTABLE03 = RTRIM(@c_Lottable03)'
   END

   IF (CONVERT(char(10), @d_Lottable04, 103) <> '01/01/1900' AND @d_Lottable04 IS NOT NULL AND CHARINDEX('04',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTTABLE04 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable04, 106))'
   END

   IF (CONVERT(char(10), @d_Lottable05, 103) <> '01/01/1900' AND @d_Lottable05 IS NOT NULL AND CHARINDEX('05',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND LOTTABLE05 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable05, 106))'
   END

   IF (ISNULL(@c_Lottable06,'') <> '' AND CHARINDEX('06',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'')+ ' AND Lottable06 = RTRIM(@c_Lottable06) '
   END

   IF (ISNULL(@c_Lottable07,'') <> '' AND CHARINDEX('07',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable07 = RTRIM(@c_Lottable07) '
   END

   IF (ISNULL(@c_Lottable08,'') <> '' AND CHARINDEX('08',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable08 = RTRIM(@c_Lottable08) '
   END

   IF (ISNULL(@c_Lottable09,'') <> '' AND CHARINDEX('09',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable09 = RTRIM(@c_Lottable09) '
   END

   IF (ISNULL(@c_Lottable10,'') <> '' AND CHARINDEX('10',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable10 = RTRIM(@c_Lottable10) '
   END

   IF (ISNULL(@c_Lottable11,'') <> '' AND CHARINDEX('11',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable11 = RTRIM(@c_Lottable11) '
   END

   IF (ISNULL(@c_Lottable12,'') <> '' AND CHARINDEX('12',@c_SkipLottableFilter,1) = 0)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable12 = RTRIM(@c_Lottable12) '
   END

   IF (CONVERT(char(10), @d_Lottable13, 103) <> '01/01/1900' AND @d_Lottable13 IS NOT NULL AND CHARINDEX('13',@c_SkipLottableFilter,1) = 0)         --(Wan01) --(SSA91301)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable13 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable13, 106)) '  
   END                                                                                                                            
                                                                                                                                  
   IF (CONVERT(char(10), @d_Lottable14, 103) <> '01/01/1900' AND @d_Lottable14 IS NOT NULL AND CHARINDEX('14',@c_SkipLottableFilter,1) = 0)         --(Wan01) --(SSA91301)
   BEGIN                                                                                                                          
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable14 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable14, 106)) '  
   END                                                                                                                            
                                                                                                                                  
   IF (CONVERT(char(10), @d_Lottable15, 103) <> '01/01/1900' AND @d_Lottable15 IS NOT NULL AND CHARINDEX('15',@c_SkipLottableFilter,1) = 0)         --(Wan01) --(SSA91301)
   BEGIN                                                                                                                          
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND Lottable15 = RTRIM(CONVERT( NVARCHAR(20), @d_Lottable15, 106)) '  
   END

   IF @c_CLKConditionFlag = 'Y'
   BEGIN
       IF LEFT(LTRIM(@c_CLKCondition),3) <> 'AND'
          SET @c_CLKCondition = ' AND ' + RTRIM(LTRIM(@c_CLKCondition))
   END

   ----------SkipLottablefilter logic end(SSA91301)-------------
   IF  @c_ShelfLifeFlag IN ('E','M') SET @c_ContinueChkShelfLife = 'Y'              --(Wan02)

   ------Order shelflife (orderdetail.Minshelflife)
   IF ISNULL(@n_OrderMinShelfLife,0) > 0 AND ISNULL(@c_OrderKey,'') <> '' AND @c_ContinueChkShelfLife = 'Y'
      AND @c_ShelfLifeStrategyCode IN ('', 'ORDERS')                                --(Wan02)
   BEGIN
      IF @c_ShelfLifeFlag = 'E'
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_OrderMinShelfLife '     
                             + 'OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'') '                              
      END
      ELSE IF @c_ShelfLifeFlag = 'M'
      BEGIN
         SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_OrderMinShelfLife '   
                             + 'OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'') '                       
      END

      SET @c_ContinueChkShelfLife = 'N'
   END

   IF ISNULL(@c_OrderKey,'') <> '' AND @c_ContinueChkShelfLife = 'Y'
   BEGIN
      ------Consignee+Sku shelflife (Storer.MinShelflife * Sku.Shelflife)
      IF @c_ShelfLifeStrategyCode IN ('', 'ConsigneeSku')                           --(Wan02)
      BEGIN                                                                         --(Wan02)
         SELECT @n_ConsigneeSkuMinShelfLife = (Sku.Shelflife * Storer.MinShelflife/100)
         FROM ORDERS O (NOLOCK)
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN STORER (NOLOCK) ON O.Consigneekey = STORER.Storerkey
         WHERE O.Orderkey = @c_Orderkey
         AND OD.OrderLineNumber = @c_OrderLineNumber

         IF ISNULL(@n_ConsigneeSkuMinShelfLife,0) > 0                                
         BEGIN 
             IF @c_ShelfLifeFlag = 'E'
            BEGIN
               SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_ConsigneeSkuMinShelfLife'
                                + ' OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'')'
            END
            ELSE IF @c_ShelfLifeFlag = 'M'
            BEGIN
               SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_ConsigneeSkuMinShelfLife'
                                + ' OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'')'
            END

            SET @c_ContinueChkShelfLife = 'N'
         END
      END
      ------Consigneegroup + skugroup shelflife (Doclkup.consigneegroup + Doclkup.skugroup)
      IF @c_ContinueChkShelfLife = 'Y' 
         AND @c_ShelfLifeStrategyCode IN ('', 'ConsigneeSkuGroup')                  --(Wan02)
      BEGIN
         SELECT @n_ConsigneeSkuGroupMinShelfLife = DOCLKUP.Shelflife
               ,@c_ConsigneeSkuGroupPCTG         = ISNULL(DOCLKUP.UserDefine01,'')  --(Wan02)           
         FROM ORDERS O (NOLOCK)
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         JOIN STORER (NOLOCK) ON O.Consigneekey = STORER.Storerkey
         JOIN DOCLKUP (NOLOCK) ON STORER.Secondary = DOCLKUP.ConsigneeGroup AND SKU.Skugroup = DOCLKUP.Skugroup
         WHERE O.Orderkey = @c_Orderkey
         AND OD.OrderLineNumber = @c_OrderLineNumber

         IF ISNULL(@n_ConsigneeSkuGroupMinShelfLife,0) > 0
         BEGIN
            SET @c_ShelfLifeSQL = '@n_ConsigneeSkuGroupMinShelfLife'                --(Wan02) - START 
            IF @c_ConsigneeSkuGroupPCTG = 'PERCENTAGE'
            BEGIN
               SET @c_ShelfLifeSQL = 'DATEDIFF(Day, Lottable13, Lottable04)*(@n_ConsigneeSkuGroupMinShelfLife/100.00)'--(Wan03) 
            END

            IF @c_ShelfLifeFlag = 'E'
            BEGIN
               SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= ' --@n_ConsigneeSkuGroupMinShelfLife'
                                + @c_ShelfLifeSQL                                                                    --(Wan02)    
                                + ' OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'')'                                        
            END
            ELSE IF @c_ShelfLifeFlag = 'M'
            BEGIN
               SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= ' --@n_ConsigneeSkuGroupMinShelfLife'  
                                + @c_ShelfLifeSQL                                                                    --(Wan02)    
                                + ' OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'')'                                        
            END                                                                     --(Wan02) - END 

            SET @c_ContinueChkShelfLife = 'N'
         END
      END
   END

   ------Sku outgoing shelflife (Sku.SUSR2)
   IF @c_ContinueChkShelfLife = 'Y' 
      AND @c_ShelfLifeStrategyCode IN ('', 'SkuOutGo')                              --(Wan02)
   BEGIN
      SELECT @n_SkuOutGoingMinShelfLife = CASE WHEN ISNUMERIC(SUSR2) = 1 THEN CAST(SUSR2 AS INT)
                                          ELSE 0 END
      FROM  SKU (NOLOCK)
      WHERE SKU = @c_SKU
      AND   STORERKEY = @c_StorerKey

      IF ISNULL(@n_SkuOutGoingMinShelfLife,0) > 0
      BEGIN
        IF @c_ShelfLifeFlag = 'E'
          BEGIN
             SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_SkuOutGoingMinShelfLife'  
                              + ' OR Lottable04 IS NULL OR CONVERT(char(10), Lottable04, 103) = ''01/01/1900'')'                                
         END
         ELSE IF @c_ShelfLifeFlag = 'M'
         BEGIN
             SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_SkuOutGoingMinShelfLife'  
                                 + ' OR Lottable04 IS NULL OR CONVERT(char(10), Lottable04, 103) = ''01/01/1900'')'                                
         END

         SET @c_ContinueChkShelfLife = 'N'
      END
   END

   ------Storer+Sku shelflife (Storer.MinShelflife * Sku.Shelflife)
   IF @c_ContinueChkShelfLife = 'Y'
      AND @c_ShelfLifeStrategyCode IN ('', 'StorerSku')                             --(Wan02)
   BEGIN
      SELECT @n_StorerSkuMinShelfLife = (Sku.Shelflife * Storer.MinShelflife/100)
      FROM Sku (nolock)
      JOIN Storer (nolock) ON Sku.Storerkey = Storer.Storerkey
      WHERE Sku.Sku = @c_sku
      AND Sku.Storerkey = @c_storerkey

      IF ISNULL(@n_StorerSkuMinShelfLife,0) > 0
      BEGIN
        IF @c_ShelfLifeFlag = 'E'
        BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, GETDATE(), LOTTABLE04) >= @n_StorerSkuMinShelfLife'   
                             + ' OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'')'
         END
         ELSE IF @c_ShelfLifeFlag = 'M'
         BEGIN
            SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') + ' AND ( DATEDIFF(day, LOTTABLE04, GETDATE()) <= @n_StorerSkuMinShelfLife'   
                             + ' OR Lottable04 IS NULL OR CONVERT(CHAR(10), LOTTABLE04, 103) = ''01/01/1900'')'
         END

         SET @c_ContinueChkShelfLife = 'N'
      END
   END

   IF @c_UOM = '1'
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                       + ' AND SKUXLOC.LocationType NOT IN (''PICK'',''CASE'')'
                       + ' AND LOC.LocationCategory = @c_LocationCategory'
   END
   ELSE IF @c_FromPickLocFlag = 'Y'                                                 --(Wan04)
   BEGIN
      SET @c_Condition = ISNULL(RTRIM(@c_Condition),'') 
                       + ' AND SKUXLOC.LocationType IN (''PICK'',''CASE'')'
   END

   IF @c_SortingFlag = 'Y'                                                          --(Wan04) - START 
   BEGIN  
      IF @c_SortMode = 'DYNAMICSQL'    
      BEGIN  
        SELECT @c_SQL = @c_SortFields  
        SET @c_SortFields = ''  
          
        SET @c_SQLParms = N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU  NVARCHAR(20), @c_UOM NVARCHAR(10), @c_HostWHCode NVARCHAR(10)'  
             +', @n_UOMBase INT, @n_QtyLeftToFulfill INT, @c_Orderkey NVARCHAR(10), @c_OrderLineNumber NVARCHAR(5), @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'  
             +',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'  
             +',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'  
             +',@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'  
             +',@n_OrderMinShelfLife INT, @n_ConsigneeSkuMinShelfLife INT,@n_ConsigneeSkuGroupMinShelfLife INT'  
             +',@n_SkuOutGoingMinShelfLife INT, @n_StorerSkuMinShelfLife INT'  
             +',@c_ID NVARCHAR(18)'  
             +',@c_UDF01 NVARCHAR(30), @c_UDF02 NVARCHAR(30), @c_UDF03 NVARCHAR(30), @c_UDF04 NVARCHAR(30), @c_UDF05 NVARCHAR(30)'  
             +',@c_SortFields NVARCHAR(2000) OUTPUT'               
           
         EXEC sp_executesql @c_SQL, @c_SQLParms,     
            @c_Facility     
           ,@c_StorerKey    
           ,@c_SKU          
           ,@c_UOM          
           ,@c_HostWHCode   
           ,@n_UOMBase      
           ,@n_QtyLeftToFulfill   
           ,@c_Orderkey
           ,@c_OrderLineNumber  
           ,@c_Loadkey   
           ,@c_Wavekey    
           ,@c_Lottable01                                     
           ,@c_Lottable02                                     
           ,@c_Lottable03                                     
           ,@d_Lottable04                                     
           ,@d_Lottable05                                     
           ,@c_Lottable06                                     
           ,@c_Lottable07                                     
           ,@c_Lottable08                                     
           ,@c_Lottable09                                     
           ,@c_Lottable10                                     
           ,@c_Lottable11                                     
           ,@c_Lottable12                                     
           ,@d_Lottable13                                     
           ,@d_Lottable14                                     
           ,@d_Lottable15                                     
           ,@n_OrderMinShelfLife                              
           ,@n_ConsigneeSkuMinShelfLife                       
           ,@n_ConsigneeSkuGroupMinShelfLife                  
           ,@n_SkuOutGoingMinShelfLife                        
           ,@n_StorerSkuMinShelfLife                          
           ,@c_ID                                             
           ,@c_UDF01                                          
           ,@c_UDF02                                          
           ,@c_UDF03                                          
           ,@c_UDF04                                          
           ,@c_UDF05          
           ,@c_SortFields OUTPUT  
             
         IF @c_SortFields = 'FIFO'  
            SET @c_SortBy = ' ORDER BY ' + RTRIM(@c_LocTypeSort) + ' Lotattribute.Lottable05, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc'  
         ELSE IF @c_SortFields =  'FEFO'  
            SET @c_SortBy = ' ORDER BY ' + RTRIM(@c_LocTypeSort) + ' Lotattribute.Lottable04, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc'  
         ELSE IF ISNULL(@c_SortFields,'') = ''  
            SET @c_SortBy = ' ORDER BY ' + RTRIM(@c_LocTypeSort) + ' Lotattribute.Lottable05, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc'  
         ELSE     
            SET @c_SortBy = ' ORDER BY ' + RTRIM(@c_LocTypeSort) + RTRIM(@c_SortFields) + " "                                                           
      END  
      ELSE  
      BEGIN  
         IF @c_SortFields = 'FIFO'  
            SET @c_SortBy = ' ORDER BY ' + RTRIM(@c_LocTypeSort) + ' Lotattribute.Lottable05, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc' 
         ELSE IF @c_SortFields =  'FEFO'  
            SET @c_SortBy = ' ORDER BY ' + RTRIM(@c_LocTypeSort) + ' Lotattribute.Lottable04, Lotattribute.Lot, Loc.LogicalLocation, Loc.Loc'  
         ELSE  
            SET @c_SortBy = ' ORDER BY ' + RTRIM(@c_LocTypeSort) + RTRIM(@c_SortFields) + ' '  
      END  
   END  
   ELSE 
   BEGIN
      SET @c_SortBy = ' ORDER BY Lotattribute.Lottable04, Lotattribute.Lottable05,'
                    + CASE WHEN @c_UOM = 1 THEN 'LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN DESC'
                                           ELSE '1' END
                    + ',Lotattribute.Lot, LotxLocxID.ID'
   END                                                                              --(Wan04) - END

   IF (@c_FullPalletByLocFlag = 'Y' AND @c_UOM = '1') OR (@c_OverAllocateFlag = 'Y')--(Wan04)          
   BEGIN
      SET @c_SQL = N'DECLARE CURSOR_AVAILABLECFG CURSOR FAST_FORWARD READ_ONLY FOR'  
                 + ' SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC,LOTxLOCxID.ID'
                 + ' ,QTYAVAILABLE = LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN' 
                 + ' FROM LOTxLOCxID (NOLOCK)'
                 + ' JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot'
                 + ' JOIN LOT (NOLOCK) ON LOTxLOCxID.Lot = LOT.Lot'
                 + ' JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC'
                 + ' JOIN ID (NOLOCK) ON LOTxLOCxID.Id = ID.ID'
                 + ' JOIN SKUXLOC (NOLOCK) ON LOTxLOCxID.Storerkey = SKUXLOC.Storerkey'
                 +                      ' AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc = SKUXLOC.Loc'
                 + ' JOIN SKU (NOLOCK) ON LOTxLOCxID.Storerkey = SKU.Storerkey AND SKU.Sku = SKUXLOC.Sku'
                 + ' JOIN STORER (NOLOCK) ON LOTxLOCxID.Storerkey = STORER.Storerkey'
                 + ' JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey'
                 + ' WHERE LOTxLOCxID.Storerkey = @c_Storerkey'
                 + ' AND LOTxLOCxID.Sku = @c_Sku'
                 + ' AND LOC.Facility = @c_Facility'
                 + ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) > 0'
                 + ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'''
                 + ' AND LOC.LocationFlag NOT IN (''HOLD'',''DAMAGE'')'
                 + ' ' +  ISNULL(RTRIM(@c_Condition),'')
                 + ' ' + ISNULL(RTRIM(@c_CLKCondition),'')   --SSA91301
                 + ' ' + @c_SortBy

      SET @c_SQLParms = N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU  NVARCHAR(20), @c_UOM NVARCHAR(10), @c_HostWHCode NVARCHAR(10)'
          +', @n_UOMBase INT, @n_QtyLeftToFulfill INT, @c_Orderkey NVARCHAR(10), @c_OrderLineNumber NVARCHAR(5), @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
          +',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
          +',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
          +',@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'
          +',@n_OrderMinShelfLife INT, @n_ConsigneeSkuMinShelfLife INT,@n_ConsigneeSkuGroupMinShelfLife INT'
          +',@n_SkuOutGoingMinShelfLife INT, @n_StorerSkuMinShelfLife INT'
          +',@c_ID NVARCHAR(18), @c_LocationCategory NVARCHAR(10)'

      EXEC sp_executesql @c_SQL
                        ,@c_SQLParms 
                        ,@c_Facility    
                        ,@c_StorerKey   
                        ,@c_SKU         
                        ,@c_UOM         
                        ,@c_HostWHCode  
                        ,@n_UOMBase     
                        ,@n_QtyLeftToFulfill 
                        ,@c_Orderkey 
                        ,@c_OrderLineNumber 
                        ,@c_Loadkey   
                        ,@c_Wavekey   
                        ,@c_Lottable01                                   
                        ,@c_Lottable02                                   
                        ,@c_Lottable03                                   
                        ,@d_Lottable04                                   
                        ,@d_Lottable05                                   
                        ,@c_Lottable06                                   
                        ,@c_Lottable07                                   
                        ,@c_Lottable08                                   
                        ,@c_Lottable09                                   
                        ,@c_Lottable10                                   
                        ,@c_Lottable11                                   
                        ,@c_Lottable12                                   
                        ,@d_Lottable13                                   
                        ,@d_Lottable14                                   
                        ,@d_Lottable15                                   
                        ,@n_OrderMinShelfLife                            
                        ,@n_ConsigneeSkuMinShelfLife                     
                        ,@n_ConsigneeSkuGroupMinShelfLife                
                        ,@n_SkuOutGoingMinShelfLife                      
                        ,@n_StorerSkuMinShelfLife                        
                        ,@c_ID                                           
                        ,@c_LocationCategory                                      

      OPEN CURSOR_AVAILABLECFG

      FETCH NEXT FROM CURSOR_AVAILABLECFG INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable

      WHILE (@@FETCH_STATUS <> -1) AND (@n_QtyLeftToFulfill > 0)
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM #TMP_LOT WHERE Lot = @c_Lot)
         BEGIN
           -- Checking available lot for normal and overallocate
           INSERT INTO #TMP_LOT (Lot, QtyAvailable)
           SELECT LOTXLOCXID.Lot
               , SUM(LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated 
                   - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen)  
           FROM LOTXLOCXID (NOLOCK)
           JOIN LOT (NOLOCK) ON (LOTxLOCxID.Lot = LOT.Lot)
           JOIN LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.LOC)
           JOIN ID (NOLOCK) ON (LOTxLOCxID.Id = ID.ID)
           WHERE LOTXLOCXID.Lot = @c_Lot
           AND   LOT.Status = 'OK'
           AND   ID.Status = 'OK'
           AND   LOC.Status = 'OK'
           AND   LOC.LocationFlag NOT IN ('HOLD','DAMAGE')
           AND   LOC.Facility = @c_Facility
           --AND   LOTXLOCXID.Qty - LOTXLOCXID.QtyAllocated                         --(Wan04) --(Wan01)
           --    - LOTXLOCXID.QtyPicked - LOTXLOCXID.QtyReplen > 0                  --(Wan04) --(Wan01)
           GROUP BY LOTXLOCXID.Lot      
         END
         
         SET @n_LotQtyAvailable = 0

         SELECT @n_LotQtyAvailable = QtyAvailable
         FROM #TMP_LOT
         WHERE Lot = @c_Lot

         IF @n_LotQtyAvailable < @n_QtyAvailable
         BEGIN
            IF @c_UOM = '1'
               SET @n_QtyAvailable = 0
            ELSE
               SET @n_QtyAvailable = @n_LotQtyAvailable
         END

         IF @c_UOM = '1' AND @c_FullPalletByLocFlag = 'Y' --Pallet
         BEGIN
            SET @n_NoOfLot = 0

            SELECT @n_NoOfLot = COUNT(DISTINCT LLI.Lot)
            FROM LOTXLOCXID LLI (NOLOCK)
            WHERE LLI.Loc = @c_LOC
            AND LLI.ID = @c_ID
            AND LLI.Storerkey = @c_Storerkey
            AND LLI.Sku = @c_Sku
            AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0      --(Wan01)

            IF @n_QtyLeftToFulfill >= @n_QtyAvailable
               AND @n_NoOfLot = 1 -- if multi lot per sku/loc/id then proceed to next strategy allocation by carton
            BEGIN
               SET @n_QtyToTake = @n_QtyAvailable
            END
            ELSE
            BEGIN
               SET @n_QtyToTake = 0
            END
         END
         ELSE
         BEGIN
            IF @n_UOMBase > 0        
            BEGIN
               IF @n_QtyLeftToFulfill >= @n_QtyAvailable
               BEGIN
                  SET @n_QtyToTake = Floor(@n_QtyAvailable / @n_UOMBase) * @n_UOMBase
               END
               ELSE
               BEGIN
                  SET @n_QtyToTake = Floor(@n_QtyLeftToFulfill / @n_UOMBase) * @n_UOMBase
               END
            END                     
         END

         IF @n_QtyToTake > 0
         BEGIN
            UPDATE #TMP_LOT
            SET QtyAvailable = QtyAvailable - @n_QtyToTake
            WHERE Lot = @c_Lot

            IF @n_QtyToTake = @n_QtyAvailable AND @c_UOM = '1' AND @c_FullPalletByLocFlag = 'Y'
               SET @c_OtherValue = '@c_FULLPALLET=Y'
            ELSE
               SET @c_OtherValue = '1'

            SET @c_Lot       = RTRIM(@c_Lot)
            SET @c_Loc       = RTRIM(@c_Loc)
            SET @c_ID        = RTRIM(@c_ID)

            EXEC isp_Insert_Allocate_Candidates
               @c_Lot = @c_Lot
            ,  @c_Loc = @c_Loc
            ,  @c_ID  = @c_ID
            ,  @n_QtyAvailable = @n_QtyToTake
            ,  @c_OtherValue = @c_OtherValue

            SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToTake
         END

         FETCH NEXT FROM CURSOR_AVAILABLECFG INTO @c_LOT, @c_LOC, @c_ID, @n_QtyAvailable
      END
      CLOSE CURSOR_AVAILABLECFG
      DEALLOCATE CURSOR_AVAILABLECFG

      EXEC isp_Cursor_Allocate_Candidates @n_SkipPreAllocationFlag = 1    
   END
   ELSE
   BEGIN
      SET @c_SQL = N'DECLARE CURSOR_CANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR'
                 + ' SELECT LOTxLOCxID.LOT, LOTxLOCxID.LOC,LOTxLOCxID.ID'
                 + ' ,QTYAVAILABLE = LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN'
                 + ' ,''1'''
                 + ' FROM LOTxLOCxID (NOLOCK)'
                 + ' JOIN LOTATTRIBUTE (NOLOCK) ON LOTxLOCxID.Lot = LOTATTRIBUTE.Lot'
                 + ' JOIN LOT (NOLOCK) ON LOTxLOCxID.Lot = LOT.Lot'
                 + ' JOIN LOC (NOLOCK) ON LOTxLOCxID.Loc = LOC.LOC'
                 + ' JOIN ID (NOLOCK) ON LOTxLOCxID.Id = ID.ID'
                 + ' JOIN SKUXLOC (NOLOCK) ON LOTxLOCxID.Storerkey =  SKUXLOC.Storerkey'
                 +                      ' AND LOTxLOCxID.Sku = SKUXLOC.Sku AND LOTxLOCxID.Loc =  SKUXLOC.Loc'
                 + ' JOIN SKU (NOLOCK) ON LOTxLOCxID.Storerkey = SKU.Storerkey AND SKU.Sku =  SKUXLOC.Sku'
                 + ' JOIN STORER (NOLOCK) ON LOTxLOCxID.Storerkey = STORER.Storerkey'
                 + ' JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey'
                 + ' WHERE LOTxLOCxID.Storerkey = @c_Storerkey'   
                 + ' AND LOTxLOCxID.Sku = @c_Sku'
                 + ' AND LOC.Facility = @c_Facility'
                 + ' AND (LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED - LOTxLOCxID.QTYREPLEN) > 0'
                 + ' AND LOT.STATUS = ''OK'' AND LOC.STATUS = ''OK'' AND ID.STATUS = ''OK'''
                 + ' AND LOC.LocationFlag NOT IN (''HOLD'',''DAMAGE'')'
                 + ' ' + ISNULL(RTRIM(@c_Condition),'')
                 + ' ' + ISNULL(RTRIM(@c_CLKCondition),'')   --SSA91301
                 + ' ' + @c_SortBy

      SET @c_SQLParms = N'@c_Facility NVARCHAR(5), @c_StorerKey NVARCHAR(15), @c_SKU  NVARCHAR(20), @c_UOM NVARCHAR(10), @c_HostWHCode NVARCHAR(10)'
          +', @n_UOMBase INT, @n_QtyLeftToFulfill INT, @c_Orderkey NVARCHAR(10), @c_OrderLineNumber NVARCHAR(5), @c_Loadkey NVARCHAR(10), @c_Wavekey NVARCHAR(10)'
          +',@c_Lottable01 NVARCHAR(18), @c_Lottable02 NVARCHAR(18), @c_Lottable03 NVARCHAR(18), @d_Lottable04 DATETIME, @d_Lottable05 DATETIME'
          +',@c_Lottable06 NVARCHAR(30), @c_Lottable07 NVARCHAR(30), @c_Lottable08 NVARCHAR(30), @c_Lottable09 NVARCHAR(30), @c_Lottable10 NVARCHAR(30)'
          +',@c_Lottable11 NVARCHAR(30), @c_Lottable12 NVARCHAR(30), @d_Lottable13 DATETIME, @d_Lottable14 DATETIME, @d_Lottable15 DATETIME'
          +',@n_OrderMinShelfLife INT, @n_ConsigneeSkuMinShelfLife INT,@n_ConsigneeSkuGroupMinShelfLife INT'
          +',@n_SkuOutGoingMinShelfLife INT, @n_StorerSkuMinShelfLife INT'
          +',@c_ID NVARCHAR(18), @c_LocationCategory NVARCHAR(10)'
          --+',@c_UDF01 NVARCHAR(30), @c_UDF02 NVARCHAR(30), @c_UDF03 NVARCHAR(30), @c_UDF04 NVARCHAR(30), @c_UDF05 NVARCHAR(30)'

      EXEC sp_executesql @c_SQL 
                        ,@c_SQLParms   
                        ,@c_Facility   
                        ,@c_StorerKey  
                        ,@c_SKU        
                        ,@c_UOM        
                        ,@c_HostWHCode 
                        ,@n_UOMBase    
                        ,@n_QtyLeftToFulfill 
                        ,@c_Orderkey 
                        ,@c_OrderLineNumber 
                        ,@c_Loadkey  
                        ,@c_Wavekey  
                        ,@c_Lottable01                                   
                        ,@c_Lottable02                                   
                        ,@c_Lottable03                                   
                        ,@d_Lottable04                                   
                        ,@d_Lottable05                                   
                        ,@c_Lottable06                                   
                        ,@c_Lottable07                                   
                        ,@c_Lottable08                                   
                        ,@c_Lottable09                                   
                        ,@c_Lottable10                                   
                        ,@c_Lottable11                                   
                        ,@c_Lottable12                                   
                        ,@d_Lottable13                                   
                        ,@d_Lottable14                                   
                        ,@d_Lottable15                                   
                        ,@n_OrderMinShelfLife                            
                        ,@n_ConsigneeSkuMinShelfLife                     
                        ,@n_ConsigneeSkuGroupMinShelfLife                
                        ,@n_SkuOutGoingMinShelfLife                      
                        ,@n_StorerSkuMinShelfLife                        
                        ,@c_ID                                           
                        ,@c_LocationCategory                                       
   END
 
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_AVAILABLECFG') in (0 , 1)
   BEGIN
      CLOSE CURSOR_AVAILABLECFG
      DEALLOCATE CURSOR_AVAILABLECFG
   END
END

GO