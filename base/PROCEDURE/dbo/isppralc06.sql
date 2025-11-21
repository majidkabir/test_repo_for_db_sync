SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPRALC06                                              */
/* Creation Date: 2021-07-07                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-17271 - RG - Adidas Allocation Strategy                 */
/*        : Call By Storerconfig 'PreAllocationSP'                      */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-07-07  Wan      1.0   Created.                                  */
/* 2021-10-06  Wan      1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[ispPRALC06]
   @c_OrderKey        NVARCHAR(10)    
,  @c_LoadKey         NVARCHAR(10)      
,  @c_WaveKey         NVARCHAR(10)        
,  @b_Success         INT            = 1   OUTPUT
,  @n_Err             INT            = 0   OUTPUT
,  @c_ErrMsg          NVARCHAR(255)  = ''  OUTPUT
,  @b_debug           INT = 0   
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_StartTCnt             INT = @@TRANCOUNT
         , @n_Continue              INT = 1
      
         , @n_RowID_FilterORDSQL    INT   = 0
         , @n_RowID_AllocateBy      INT   = 0
         
         , @c_Storerkey             NVARCHAR(15) = ''
         , @c_Facility              NVARCHAR(5)  = ''
         
         , @c_PreAllocSP_Opt5       NVARCHAR(4000) = ''
         
         , @c_FilterORDSQL          NVARCHAR(MAX)  = ''         
         , @c_AllocateBy            NVARCHAR(250)  = ''
         , @c_AllocateSource        NVARCHAR(15)   = ''
         
         , @c_SQL                   NVARCHAR(MAX)  = ''
         , @c_SQLParms              NVARCHAR(MAX)  = ''
         , @c_SQL2                  NVARCHAR(MAX)  = ''
         , @c_SQLParms2             NVARCHAR(MAX)  = ''
         
         , @c_sWavekey              NVARCHAR(10)   = ''          
         , @c_sLoadkey              NVARCHAR(10)   = ''
         , @c_sOrderkey             NVARCHAR(10)   = ''                        
         , @c_sOrderLineNumber      NVARCHAR(5)    = ''               
         , @c_Sku                   NVARCHAR(20)   = ''
         , @c_PACKKey               NVARCHAR(10)   = ''
         , @c_UOM                   NVARCHAR(10)   = ''
         , @c_Lottable01            NVARCHAR(18)   = ''
         , @c_Lottable02            NVARCHAR(18)   = ''
         , @c_Lottable03            NVARCHAR(18)   = ''
         , @dt_Lottable04           DATETIME
         , @dt_Lottable05           DATETIME
         , @c_Lottable06            NVARCHAR(30)   = ''
         , @c_Lottable07            NVARCHAR(30)   = ''
         , @c_Lottable08            NVARCHAR(30)   = ''
         , @c_Lottable09            NVARCHAR(30)   = ''
         , @c_Lottable10            NVARCHAR(30)   = ''
         , @c_Lottable11            NVARCHAR(30)   = ''
         , @c_Lottable12            NVARCHAR(30)   = ''
         , @dt_Lottable13           DATETIME
         , @dt_Lottable14           DATETIME
         , @dt_Lottable15           DATETIME  
         , @c_HostWHCode            NVARCHAR(10)   = ''
         , @c_OtherParms            NVARCHAR(250)  = ''
         , @n_UOMBase               INT            = 1
         , @n_QtyLeftToFulfill      INT            = 0
         , @c_Channel               NVARCHAR(20)   = ''
         , @n_Channel_id            BIGINT         = 0   

         , @c_aAllocStrategyKey     NVARCHAR(10)   = ''
         , @c_aStrategyLine         NVARCHAR(5)    = ''
         , @c_PickCode              NVARCHAR(30)   = ''
         , @c_aUOM                  NVARCHAR(30)   = ''
         , @c_aOtherValue           NVARCHAR(250)  = ''
         
         , @c_aOrderkey             NVARCHAR(10)   = '' 
         , @c_aOrderLineNumber      NVARCHAR(5)    = ''                                                      
         , @n_aQty                  INT            = 0
         
         , @c_aLot_Prev             NVARCHAR(10)   = ''
         , @c_aLot                  NVARCHAR(10)   = ''               
         , @c_aLoc                  NVARCHAR(10)   = ''               
         , @c_aID                   NVARCHAR(18)   = ''
         , @n_aQtyAvailable         INT            = 0
      
         , @n_ChannelHoldQty        INT            = 0 
         , @n_Channel_QtyAvailable  INT            = 0   

         , @c_aUCCNo                NVARCHAR(20)   = '' 
         , @n_UOMQty                INT            = 0
         , @n_QtyToInsert           INT            = 0

         , @c_PickDetailkey         NVARCHAR(10)   = ''
         , @c_PickMethod            NVARCHAR       = ''   

         , @c_ChannelInventoryMgmt  NVARCHAR(30)   = '0'  
                     
         , @CUR_ALLOCORDSKU         CURSOR
         , @CUR_PICKCODE            CURSOR
         
   DECLARE @t_ALLOCSTRAT TABLE 
      (
         RowID             INT            IDENTITY(1,1) PRIMARY KEY
      ,  ListName          NVARCHAR(10)   DEFAULT('')
      ,  Code              NVARCHAR(30)   DEFAULT('')
      ,  AllocateBy        NVARCHAR(250)  DEFAULT('')      
      ,  FilterORDSQL      NVARCHAR(MAX)  DEFAULT('')
      ,  AllocStrategyKey  NVARCHAR(10)   DEFAULT('')
      )
   
   SET @b_Success = 1   
   SET @n_Err     = 0   
   SET @c_ErrMsg  = ''  

   IF OBJECT_ID('tempdb..#OPORDLINES','u') IS NOT NULL
   BEGIN
      DROP TABLE #OPORDLINES;
   END
   
   CREATE TABLE #OPORDLINES
      (  RowID             INT            IDENTITY(1,1)  PRIMARY KEY 
      ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Loadkey           NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  OrderKey          NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT('')
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Packkey           NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  UOM               NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Lottable01        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable03        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable04        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable05        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable06        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable07        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable08        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable09        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable10        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable11        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable12        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable13        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable14        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable15        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  QtyLeftToFullFill INT            NOT NULL DEFAULT(0)
      ,  Channel           NVARCHAR(20)   NOT NULL DEFAULT('')   
      )
   
   IF OBJECT_ID('tempdb..#FILTERORD','u') IS NOT NULL
   BEGIN
      DROP TABLE #FILTERORD;
   END
   
   CREATE TABLE #FILTERORD
      (  OrderKey          NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY )
   
   IF OBJECT_ID('tempdb..#ALLOCORDSKU','u') IS NOT NULL
   BEGIN
      DROP TABLE #ALLOCORDSKU;
   END
      
   CREATE TABLE #ALLOCORDSKU
      (  RowID             INT   IDENTITY(1,1)  PRIMARY KEY
      ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Loadkey           NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  OrderKey          NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT('')
      ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
      ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  Packkey           NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  UOM               NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Lottable01        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable03        NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Lottable04        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable05        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable06        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable07        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable08        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable09        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable10        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable11        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable12        NVARCHAR(30)   NOT NULL DEFAULT('')
      ,  Lottable13        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable14        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  Lottable15        DATETIME       NOT NULL DEFAULT('1900-01-01')
      ,  QtyLeftToFullFill INT            NOT NULL DEFAULT(0)
      ,  Channel           NVARCHAR(20)   NOT NULL DEFAULT('')         
      )
   
   IF OBJECT_ID('tempdb..#ALLOCATE_CANDIDATES','u') IS NOT NULL  
   BEGIN  
      DROP TABLE #ALLOCATE_CANDIDATES;  
   END  
  
   CREATE TABLE #ALLOCATE_CANDIDATES  
   (  RowID          INT            NOT NULL IDENTITY(1,1)   
   ,  Lot            NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  ID             NVARCHAR(18)   NOT NULL DEFAULT('')  
   ,  QtyAvailable   INT            NOT NULL DEFAULT(0)  
   ,  OtherValue     NVARCHAR(20)   NOT NULL DEFAULT('')     
   )  

      
   SET @b_Success = 1
   SET @n_Err     = 0
   SET @c_ErrMsg  = ''
         
   SELECT TOP 1 
         @c_Facility = o.Facility
      ,  @c_Storerkey = o.StorerKey
   FROM dbo.WAVE AS w WITH (NOLOCK)
   JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = w2.OrderKey
   WHERE w.WaveKey = @c_Wavekey
   
   EXEC nspGetRight    
      @c_Facility  = @c_Facility  
    , @c_StorerKey = @c_StorerKey    
    , @c_sku       = NULL    
    , @c_ConfigKey = 'PreAllocationSP'     
    , @b_Success   = @b_Success           OUTPUT   
    , @c_authority = ''       
    , @n_err       = @n_err               OUTPUT    
    , @c_errmsg    = @c_errmsg            OUTPUT 
    , @c_Option5   = @c_PreAllocSP_Opt5   OUTPUT  
     
   IF @b_Success <> 1
   BEGIN 
      SET @n_Continue= 3
      SET @c_ErrMsg  = RTRIM(@c_ErrMsg) + '. (ispPRALC06)'
      GOTO QUIT_SP
   END 
    
   SELECT @c_aAllocStrategyKey = dbo.fnc_GetParamValueFromString('@c_AllocateStrategyKey', @c_PreAllocSP_Opt5, @c_aAllocStrategyKey) 
   
   IF @c_aAllocStrategyKey = ''
   BEGIN 
      SET @n_Continue= 3
      SET @n_Err     = 60010
      SET @c_ErrMsg  = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Allocate Strategy Key Not Setup. (ispPRALC06)'
      GOTO QUIT_SP
   END
   
   EXEC nspGetRight2   
      @c_Facility  = @c_Facility  
    , @c_StorerKey = @c_StorerKey    
    , @c_sku       = NULL    
    , @c_ConfigKey = 'ChannelInventoryMgmt'     
    , @b_Success   = @b_Success              OUTPUT   
    , @c_authority = @c_ChannelInventoryMgmt OUTPUT      
    , @n_err       = @n_err                  OUTPUT    
    , @c_errmsg    = @c_errmsg               OUTPUT 

   IF @b_Success <> 1
   BEGIN 
      SET @n_Continue= 3
      SET @c_ErrMsg  = RTRIM(@c_ErrMsg) + '. (ispPRALC06)'
      GOTO QUIT_SP
   END           
    
   --Order Filtering
   INSERT INTO @t_ALLOCSTRAT (ListName, Code, AllocateBy, FilterORDSQL, AllocStrategyKey)
   SELECT c.LISTNAME
         ,c.Code
         ,AllocateBy= ISNULL(c.Long,'') 
         ,FilterSQL = ISNULL(c.Notes,'') 
         ,CASE WHEN c.UDF01 = '' THEN @c_aAllocStrategyKey ELSE c.UDF01 END
   FROM dbo.CODELKUP AS c WITH (NOLOCK) 
   WHERE c.listname  = 'ALCTypFSeq'
   AND   c.Storerkey = @c_Storerkey
   ORDER BY c.Short
         ,  c.Code
     
   IF @@ROWCOUNT = 0
   BEGIN
      INSERT INTO @t_ALLOCSTRAT (ListName, Code, AllocateBy, FilterORDSQL, AllocStrategyKey)
      VALUES ('ALCTypFSeq','1','','', @c_aAllocStrategyKey)
   END
   
   IF @b_debug = 2
   BEGIN 
      SELECT * FROM @t_ALLOCSTRAT
   END 
   
   SET @n_RowID_FilterORDSQL = 0
   WHILE 1 = 1
   BEGIN 
      SET @c_FilterORDSQL = ''
      SET @c_AllocateBy = ''
      SET @c_aAllocStrategyKey = ''
      
      SELECT TOP 1 
             @c_FilterORDSQL = ta.FilterORDSQL
            ,@c_AllocateBy = ta.AllocateBy
            ,@c_aAllocStrategyKey= ta.AllocStrategyKey
            ,@n_RowID_FilterORDSQL = ta.RowID
      FROM @t_ALLOCSTRAT AS ta
      WHERE ta.listname  = 'ALCTypFSeq'
      AND ta.RowID > @n_RowID_FilterORDSQL
      --GROUP BY ta.FilterORDSQL
      --ORDER BY MAX(ta.RowID)
      ORDER BY ta.RowID
      
      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END
      
      TRUNCATE TABLE #OPORDLINES;

      SET @c_SQL = N'SELECT'
                  + ' w.Wavekey'
                  + ',Loadkey = ISNULL(lpd.Loadkey,'''')'
                  + ',o.OrderKey'
                  + ',o.OrderLineNumber'
                  + ',o.Storerkey'
                  + ',o.Sku'
                  + ',s.PACKKey'
                  + ',o.UOM'
                  + ',o.Lottable01'  
                  + ',o.Lottable02' 
                  + ',o.Lottable03'  
                  + ',Lottable04 = CASE WHEN o.Lottable04 IS NULL THEN ''1900-01-01'' ELSE o.Lottable04 END'
                  + ',Lottable05 = CASE WHEN o.Lottable05 IS NULL THEN ''1900-01-01'' ELSE o.Lottable05 END'
                  + ',o.Lottable06'  
                  + ',o.Lottable07'  
                  + ',o.Lottable08' 
                  + ',o.Lottable09'  
                  + ',o.Lottable10'  
                  + ',o.Lottable11'  
                  + ',o.Lottable12' 
                  + ',Lottable13 = CASE WHEN o.Lottable13 IS NULL THEN ''1900-01-01'' ELSE o.Lottable13 END' 
                  + ',Lottable14 = CASE WHEN o.Lottable14 IS NULL THEN ''1900-01-01'' ELSE o.Lottable14 END'   
                  + ',Lottable15 = CASE WHEN o.Lottable15 IS NULL THEN ''1900-01-01'' ELSE o.Lottable15 END' 
                  + ',QtyLeftToFullFill = o.OpenQty - o.QtyAllocated - o.QtyPicked - o.ShippedQty' 
                  + ',Channel = ISNULL(o.Channel,'''')'                 
                  + ' FROM dbo.WAVE AS w WITH (NOLOCK)'
                  + ' JOIN dbo.WAVEDETAIL AS w2 WITH (NOLOCK) ON w2.WaveKey = w.WaveKey'
                  + ' JOIN dbo.ORDERDETAIL AS o WITH (NOLOCK) ON o.orderkey = w2.OrderKey'
                  + ' JOIN dbo.SKU AS s WITH (NOLOCK) ON s.StorerKey = o.StorerKey'
                  +                                 ' AND s.Sku = o.Sku'
                  + ' LEFT OUTER JOIN dbo.LOADPLANDETAIL AS lpd WITH (NOLOCK) ON lpd.orderkey = o.OrderKey'                                
                  + ' WHERE w.WaveKey = @c_Wavekey'
                  + ' AND o.OpenQty - o.QtyAllocated - o.QtyPicked - o.ShippedQty > 0' 
         
      IF @c_FilterORDSQL <> ''
      BEGIN
         TRUNCATE TABLE #FILTERORD
         
         SET @c_SQL2 = @c_FilterORDSQL
         SET @c_SQLParms2 = N'@c_Wavekey   NVARCHAR(10)' 
         
         IF @b_Debug = 1 
         BEGIN
            PRINT @c_SQL2
         END 
              
         INSERT INTO #FILTERORD
         EXEC sp_ExecuteSQL  
                  @c_SQL2
               , @c_SQLParms2
               , @c_Wavekey
         
         SET @c_SQL = @c_SQL + N' AND EXISTS (SELECT 1 FROM #FILTERORD as f WHERE f.Orderkey = o.Orderkey)'
      END
      
      SET @c_SQL = @c_SQL + N' ORDER BY ISNULL(lpd.Loadkey, ''''), o.Orderkey, o.OrderLineNumber'
      
      SET @c_SQLParms = N'@c_Wavekey   NVARCHAR(10)' 
  
      IF @b_Debug = 1 
      BEGIN
         PRINT @c_SQL
      END 
         
      INSERT INTO #OPORDLINES
         (  Wavekey
         ,  Loadkey
         ,  OrderKey          
         ,  OrderLineNumber   
         ,  Storerkey         
         ,  Sku               
         ,  Packkey  
         ,  UOM         
         ,  Lottable01        
         ,  Lottable02        
         ,  Lottable03        
         ,  Lottable04        
         ,  Lottable05        
         ,  Lottable06        
         ,  Lottable07        
         ,  Lottable08        
         ,  Lottable09        
         ,  Lottable10        
         ,  Lottable11        
         ,  Lottable12        
         ,  Lottable13        
         ,  Lottable14        
         ,  Lottable15        
         ,  QtyLeftToFullFill
         ,  Channel 
         )      
      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms
                        , @c_Wavekey
      
      IF @b_debug = 2
      BEGIN
         SELECT * FROM #OPORDLINES
      END
         
      --SET @n_RowID_AllocateBy = 0
            
      --WHILE 1 = 1
      --BEGIN
      --   --Allocation By
      --   SELECT TOP 1
      --          @c_AllocateBy = ta.AllocateBy
      --         ,@c_aAllocStrategyKey= ta.AllocStrategyKey
      --         ,@n_RowID_AllocateBy = ta.RowID
      --   FROM @t_ALLOCSTRAT AS ta
      --   WHERE ta.listname  = 'ALCTypFSeq'
      --   AND ta.FilterORDSQL= @c_FilterORDSQL
      --   AND ta.RowID > @n_RowID_AllocateBy
      --   --GROUP BY ta.AllocateBy
      --   --ORDER BY MAX(ta.RowID)
      --   ORDER BY ta.RowID

      --   IF @@ROWCOUNT = 0
      --   BEGIN
      --      BREAK
      --   END
         
         SET @c_AllocateSource = CASE WHEN @c_AllocateBy = '' THEN 'OrderLineNumber'
                                      WHEN @c_AllocateBy LIKE '%OrderlineNumber' THEN 'OrderLineNumber'
                                      WHEN @c_AllocateBy LIKE 'Wavekey%' THEN 'Wavekey'
                                      WHEN @c_AllocateBy LIKE 'Loadkey%' THEN 'Loadkey'
                                      ELSE 'Orderkey'
                                      END  
         IF @b_debug = 1
         BEGIN  
            
            PRINT  '@c_AllocateBy: ' + @c_AllocateBy
                + ',@c_AllocateSource: ' + @c_AllocateSource
                + CHAR(13)  
         END 
         
         SET @c_SQL = N'SELECT Orderkey = ' + CASE WHEN @c_AllocateSource IN ('Orderkey', 'OrderLineNumber') THEN 'o.Orderkey' ELSE '''''' END 
                    + ', Wavekey = ' + CASE WHEN @c_AllocateSource = 'Wavekey' THEN 'o.Wavekey' ELSE '''''' END 
                    + ', Loadkey = ' + CASE WHEN @c_AllocateSource = 'Loadkey' THEN 'o.Loadkey' ELSE '''''' END
                    + ', OrderlineNumber = ' + CASE WHEN @c_AllocateSource = 'OrderLineNumber' 
                                                   THEN 'o.OrderlineNumber'
                                                   ELSE '''''' END
                    + ', o.Storerkey'         
                    + ', o.Sku'              
                    + ', o.Packkey'  
                    + ', o.UOM'                             
                    + ', o.Lottable01'        
                    + ', o.Lottable02'        
                    + ', o.Lottable03'        
                    + ', o.Lottable04'        
                    + ', o.Lottable05'        
                    + ', o.Lottable06'        
                    + ', o.Lottable07'        
                    + ', o.Lottable08'        
                    + ', o.Lottable09'        
                    + ', o.Lottable10'        
                    + ', o.Lottable11'        
                    + ', o.Lottable12'        
                    + ', o.Lottable13'        
                    + ', o.Lottable14'        
                    + ', o.Lottable15'        
                    + ', QtyLeftToFullFill = SUM(o.QtyLeftToFullFill)'   
                    + CASE WHEN @c_ChannelInventoryMgmt = '0' THEN ',''''' ELSE ', o.Channel' END                                                    
                    + ' FROM #OPORDLINES AS o'
                    + ' WHERE o.Wavekey = @c_Wavekey'
                    + ' GROUP BY '
                    + CASE WHEN @c_AllocateSource = 'Orderkey'THEN 'o.Orderkey' ELSE '' END 
                    + CASE WHEN @c_AllocateSource = 'Wavekey' THEN 'o.Wavekey'  ELSE '' END 
                    + CASE WHEN @c_AllocateSource = 'Loadkey' THEN 'o.Loadkey' ELSE '' END
                    + CASE WHEN @c_AllocateSource = 'OrderLineNumber' THEN 'o.Orderkey, o.OrderLineNumber' ELSE '' END
                    +         ',o.Storerkey'         
                    +         ',o.Sku'              
                    +         ',o.Packkey' 
                    +         ',o.UOM'                            
                    +         ',o.Lottable01'        
                    +         ',o.Lottable02'        
                    +         ',o.Lottable03'        
                    +         ',o.Lottable04'        
                    +         ',o.Lottable05'        
                    +         ',o.Lottable06'        
                    +         ',o.Lottable07'        
                    +         ',o.Lottable08'        
                    +         ',o.Lottable09'        
                    +         ',o.Lottable10'        
                    +         ',o.Lottable11'        
                    +         ',o.Lottable12'        
                    +         ',o.Lottable13'        
                    +         ',o.Lottable14'        
                    +         ',o.Lottable15'
                    + CASE WHEN @c_ChannelInventoryMgmt = '0' THEN '' ELSE ', o.Channel' END     
                    + ' HAVING SUM(o.QtyLeftToFullFill) > 0'
                    + ' ORDER BY '
                    + CASE WHEN @c_AllocateSource = 'Orderkey'THEN 'o.Orderkey' ELSE '' END 
                    + CASE WHEN @c_AllocateSource = 'Wavekey' THEN 'o.Wavekey' ELSE '' END 
                    + CASE WHEN @c_AllocateSource = 'Loadkey' THEN 'o.Loadkey' ELSE '' END
                    + CASE WHEN @c_AllocateSource = 'OrderLineNumber' THEN 'o.orderkey ,o.OrderLineNumber' ELSE '' END
        
         SET @c_SQLParms = N'@c_Wavekey   NVARCHAR(10)' 
         
         IF @b_debug = 1
         BEGIN
            PRINT @c_SQL  
         END
         
         TRUNCATE TABLE #ALLOCORDSKU;
         
         INSERT INTO #ALLOCORDSKU
             (
                  OrderKey
             ,    Wavekey
             ,    Loadkey
             ,    OrderLineNumber
             ,    Storerkey        
             ,    Sku              
             ,    Packkey  
             ,    UOM        
             ,    Lottable01       
             ,    Lottable02       
             ,    Lottable03       
             ,    Lottable04       
             ,    Lottable05       
             ,    Lottable06       
             ,    Lottable07       
             ,    Lottable08       
             ,    Lottable09       
             ,    Lottable10       
             ,    Lottable11       
             ,    Lottable12       
             ,    Lottable13       
             ,    Lottable14       
             ,    Lottable15       
             ,    QtyLeftToFullFill
             ,    Channel
             )
         EXEC sp_ExecuteSQL  @c_SQL
                           , @c_SQLParms
                           , @c_Wavekey
                     
         IF @b_debug = 2
         BEGIN
            SELECT TOP 10 * FROM #ALLOCORDSKU   
         END
                     
         SET @CUR_ALLOCORDSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT a.Wavekey
               ,a.Loadkey
               ,a.OrderKey
               ,a.OrderLineNumber 
               ,a.Storerkey
               ,a.Sku
               ,a.PACKKey
               ,a.UOM
               ,a.Lottable01  
               ,a.Lottable02 
               ,a.Lottable03  
               ,a.Lottable04    
               ,a.Lottable05  
               ,a.Lottable06  
               ,a.Lottable07  
               ,a.Lottable08 
               ,a.Lottable09  
               ,a.Lottable10  
               ,a.Lottable11  
               ,a.Lottable12 
               ,a.Lottable13  
               ,a.Lottable14    
               ,a.Lottable15
               ,SUM(a.QtyLeftToFullFill)
               ,a.Channel 
         FROM #ALLOCORDSKU AS a 
         GROUP BY a.Wavekey
               ,  a.Loadkey
               ,  a.OrderKey
               ,  a.OrderLineNumber
               ,  a.Storerkey
               ,  a.Sku
               ,  a.PACKKey
               ,  a.UOM               
               ,  a.Lottable01  
               ,  a.Lottable02 
               ,  a.Lottable03  
               ,  a.Lottable04    
               ,  a.Lottable05  
               ,  a.Lottable06  
               ,  a.Lottable07  
               ,  a.Lottable08 
               ,  a.Lottable09  
               ,  a.Lottable10  
               ,  a.Lottable11  
               ,  a.Lottable12 
               ,  a.Lottable13  
               ,  a.Lottable14    
               ,  a.Lottable15
               ,  a.Channel 
         ORDER BY MIN(a.RowID)
         
         OPEN @CUR_ALLOCORDSKU
      
         FETCH NEXT FROM @CUR_ALLOCORDSKU INTO @c_sWavekey   
                                             , @c_sLoadkey  
                                             , @c_sOrderkey                                   
                                             , @c_sOrderLineNumber                  
                                             , @c_Storerkey
                                             , @c_Sku
                                             , @c_PACKKey
                                             , @c_UOM                                             
                                             , @c_Lottable01  
                                             , @c_Lottable02 
                                             , @c_Lottable03  
                                             , @dt_Lottable04    
                                             , @dt_Lottable05  
                                             , @c_Lottable06  
                                             , @c_Lottable07  
                                             , @c_Lottable08 
                                             , @c_Lottable09  
                                             , @c_Lottable10  
                                             , @c_Lottable11  
                                             , @c_Lottable12 
                                             , @dt_Lottable13  
                                             , @dt_Lottable14    
                                             , @dt_Lottable15  
                                             , @n_QtyLeftToFulfill
                                             , @c_Channel
                                          
         WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
         BEGIN 
            SET @c_OtherParms = RTRIM(@c_WaveKey) + '     ' 
                              + CASE WHEN @c_sWavekey <> '' THEN 'W'
                                       WHEN @c_sLoadkey <> '' THEN 'L'
                                       WHEN @c_sOrderlineNumber <> '' THEN 'D'
                                       WHEN @c_sOrderkey <> '' THEN 'O'
                                       ELSE 'W'
                                       END

            IF @b_debug = 1
            BEGIN
                
               PRINT  '@c_sWavekey: ' + @c_sWavekey             
                    +',@c_sLoadkey: ' + @c_sLoadkey             
                    +',@c_sOrderkey: '+ @c_sOrderkey          
                    +',@c_sOrderLineNumber: '+ @c_sOrderLineNumber   
                    +',@c_Storerkey: ' + @c_Storerkey           
                    +',@c_Sku: ' + @c_Sku                
                    +',@c_PACKKey: ' + @c_PACKKey        + CHAR(13)       
                    +',@c_Lottable01: ' + @c_Lottable01          
                    +',@c_Lottable02: ' + @c_Lottable02         
                    +',@c_Lottable03: ' + @c_Lottable03         
                    +',@dt_Lottable04: ' + CONVERT(NVARCHAR(20), @dt_Lottable04, 121)         
                    +',@dt_Lottable05: ' + CONVERT(NVARCHAR(20), @dt_Lottable05, 121)         
                    +',@c_Lottable06: ' + @c_Lottable06         
                    +',@c_Lottable07: ' + @c_Lottable07         
                    +',@c_Lottable08: ' + @c_Lottable08         
                    +',@c_Lottable09: ' + @c_Lottable09         
                    +',@c_Lottable10: ' + @c_Lottable10  + CHAR(13)        
                    +',@c_Lottable11: ' + @c_Lottable11         
                    +',@c_Lottable12: ' + @c_Lottable12         
                    +',@dt_Lottable13: ' + CONVERT(NVARCHAR(20), @dt_Lottable13, 121)        
                    +',@dt_Lottable14: ' + CONVERT(NVARCHAR(20), @dt_Lottable14, 121)        
                    +',@dt_Lottable15: ' + CONVERT(NVARCHAR(20), @dt_Lottable15, 121) + CHAR(13)       
                    +',@n_QtyLeftToFulfill: ' + CAST(@n_QtyLeftToFulfill AS NVARCHAR)
                    +',@c_OtherParms: ' + @c_OtherParms
                    + CHAR(13)  
            END
            
            SET @c_aStrategyLine = ''          
            WHILE @n_QtyLeftToFulfill > 0 AND @n_Continue = 1 
            BEGIN
               SELECT TOP 1 
                      @c_aStrategyLine = asd.AllocateStrategyLineNumber
                     ,@c_PickCode = asd.PickCode
                     ,@c_aUOM     = asd.UOM
               FROM dbo.AllocateStrategy AS ast WITH (NOLOCK)
               JOIN dbo.AllocateStrategyDetail AS asd WITH (NOLOCK) ON asd.AllocateStrategyKey = ast.AllocateStrategyKey
               WHERE asd.AllocateStrategyKey = @c_aAllocStrategyKey
               AND asd.AllocateStrategyLineNumber > @c_aStrategyLine
               ORDER BY asd.AllocateStrategyLineNumber ASC
               
               IF @@ROWCOUNT= 0
               BEGIN
                  BREAK
               END
               
               IF @b_Debug = 1
               BEGIN
                  PRINT  '@c_aAllocStrategyKey: ' + @c_aAllocStrategyKey + ', @c_aStrategyLine: ' +  @c_aStrategyLine 
                     + ', @c_PickCode: ' + @c_PickCode + ', @c_aUOM:' + @c_aUOM
                     + ', @n_QtyLeftToFulfill: ' + CAST(@n_QtyLeftToFulfill AS NVARCHAR)
                     
                  PRINT 'DECLARE_CURSOR_CANDIDATES'
               END

               DECLARE_CURSOR_CANDIDATES:
               --Execute PickCode
               TRUNCATE TABLE #ALLOCATE_CANDIDATES;
               
               IF @b_debug = 1
               BEGIN    
                  SET @c_SQL = 'EXEC '    + @c_PickCode 
                          + ' @c_Wavekey = '''  + @c_Wavekey   + ''''  
                          + ',@c_Facility = ''' + @c_Facility  + ''''        
                          + ',@c_StorerKey= ''' + @c_StorerKey + ''''       
                          + ',@c_SKU = '''      + @c_SKU+ '''' + CHAR(13)
                          + ',@c_Lottable01 = ''' + @c_Lottable01 + ''''      
                          + ',@c_Lottable02 = ''' + @c_Lottable02 + ''''      
                          + ',@c_Lottable03 = ''' + @c_Lottable03 + ''''      
                          + ',@dt_Lottable04= ''' + CONVERT(NVARCHAR(10), @dt_Lottable04, 112) + ''''     
                          + ',@dt_Lottable05= ''' + CONVERT(NVARCHAR(10), @dt_Lottable05, 112) + ''''  +  CHAR(13)  
                          + ',@c_Lottable06 = ''' + @c_Lottable06 + ''''       
                          + ',@c_Lottable07 = ''' + @c_Lottable07 + ''''       
                          + ',@c_Lottable08 = ''' + @c_Lottable08 + ''''       
                          + ',@c_Lottable09 = ''' + @c_Lottable09 + ''''       
                          + ',@c_Lottable10 = ''' + @c_Lottable10 + ''''  + CHAR(13)     
                          + ',@c_Lottable11 = ''' + @c_Lottable11 + ''''       
                          + ',@c_Lottable12 = ''' + @c_Lottable12 + ''''       
                          + ',@dt_Lottable13= ''' + CONVERT(NVARCHAR(10), @dt_Lottable13, 112) + ''''       
                          + ',@dt_Lottable14= ''' + CONVERT(NVARCHAR(10), @dt_Lottable14, 112) + ''''       
                          + ',@dt_Lottable15= ''' + CONVERT(NVARCHAR(10), @dt_Lottable15, 112) + ''''   + CHAR(13)    
                          + ',@c_UOM = ''' + @c_aUOM         + ''''       
                          + ',@c_HostWHCode = ''' + @c_HostWHCode   + ''''   
                          + ',@n_UOMBase = '      + CONVERT(NVARCHAR(10), @n_UOMBase)   
                          + ',@n_QtyLeftToFulfill = ' + CONVERT(NVARCHAR(10), @n_QtyLeftToFulfill)     
                          + ',@c_OtherParms = ''' + @c_OtherParms  + ''''
                   PRINT @c_SQL
               END
               
               SET @c_SQL = 'EXEC ' + @c_PickCode 
                          + ' @c_Wavekey     = @c_Wavekey'  
                          + ',@c_Facility    = @c_Facility'        
                          + ',@c_StorerKey   = @c_StorerKey'       
                          + ',@c_SKU         = @c_SKU'       
                          + ',@c_Lottable01  = @c_Lottable01'       
                          + ',@c_Lottable02  = @c_Lottable02'       
                          + ',@c_Lottable03  = @c_Lottable03'       
                          + ',@dt_Lottable04 = @dt_Lottable04'       
                          + ',@dt_Lottable05 = @dt_Lottable05'       
                          + ',@c_Lottable06  = @c_Lottable06'       
                          + ',@c_Lottable07  = @c_Lottable07'       
                          + ',@c_Lottable08  = @c_Lottable08'       
                          + ',@c_Lottable09  = @c_Lottable09'       
                          + ',@c_Lottable10  = @c_Lottable10'       
                          + ',@c_Lottable11  = @c_Lottable11'       
                          + ',@c_Lottable12  = @c_Lottable12'       
                          + ',@dt_Lottable13 = @dt_Lottable13'       
                          + ',@dt_Lottable14 = @dt_Lottable14'       
                          + ',@dt_Lottable15 = @dt_Lottable15'       
                          + ',@c_UOM         = @c_aUOM'       
                          + ',@c_HostWHCode  = @c_HostWHCode'    
                          + ',@n_UOMBase     = @n_UOMBase'   
                          + ',@n_QtyLeftToFulfill = @n_QtyLeftToFulfill'     
                          + ',@c_OtherParms   = @c_OtherParms'
               
               SET @c_SQLParms  = N'@c_Wavekey     NVARCHAR(10)'  
                                + ',@c_Facility    NVARCHAR(5)'     
                                + ',@c_StorerKey   NVARCHAR(15)'     
                                + ',@c_SKU         NVARCHAR(20)'    
                                + ',@c_Lottable01  NVARCHAR(18)'    
                                + ',@c_Lottable02  NVARCHAR(18)'    
                                + ',@c_Lottable03  NVARCHAR(18)'    
                                + ',@dt_Lottable04 DATETIME'
                                + ',@dt_Lottable05 DATETIME'    
                                + ',@c_Lottable06  NVARCHAR(30)'    
                                + ',@c_Lottable07  NVARCHAR(30)'    
                                + ',@c_Lottable08  NVARCHAR(30)'    
                                + ',@c_Lottable09  NVARCHAR(30)'    
                                + ',@c_Lottable10  NVARCHAR(30)'    
                                + ',@c_Lottable11  NVARCHAR(30)'    
                                + ',@c_Lottable12  NVARCHAR(30)'    
                                + ',@dt_Lottable13 DATETIME'    
                                + ',@dt_Lottable14 DATETIME'    
                                + ',@dt_Lottable15 DATETIME'    
                                + ',@c_aUOM        NVARCHAR(10)'    
                                + ',@c_HostWHCode  NVARCHAR(10)'    
                                + ',@n_UOMBase     INT'   
                                + ',@n_QtyLeftToFulfill INT'     
                                + ',@c_OtherParms   NVARCHAR(250)'
               
               EXEC sp_ExecuteSQL  @c_SQL
                                 , @c_SQLParms
                                 , @c_Wavekey          
                                 , @c_Facility          
                                 , @c_Storerkey        
                                 , @c_Sku              
                                 , @c_Lottable01       
                                 , @c_Lottable02       
                                 , @c_Lottable03       
                                 , @dt_Lottable04      
                                 , @dt_Lottable05      
                                 , @c_Lottable06       
                                 , @c_Lottable07       
                                 , @c_Lottable08       
                                 , @c_Lottable09       
                                 , @c_Lottable10       
                                 , @c_Lottable11       
                                 , @c_Lottable12       
                                 , @dt_Lottable13      
                                 , @dt_Lottable14 
                                 , @dt_Lottable15 
                                 , @c_aUOM         
                                 , @c_HostWHCode   
                                 , @n_UOMBase    
                                 , @n_QtyLeftToFulfill     
                                 , @c_OtherParms                        
                                 
               SET @n_Err = @@ERROR
               
               IF @b_debug = 1
               BEGIN 
                   PRINT '@n_Err1: '  + CAST (@n_Err AS NVARCHAR)
               END 
               
               IF @n_Err = 16915        
               BEGIN        
                  CLOSE CURSOR_CANDIDATES        
                  DEALLOCATE CURSOR_CANDIDATES        
                  GOTO DECLARE_CURSOR_CANDIDATES        
               END  
                     
               OPEN CURSOR_CANDIDATES 
                
               SET @n_Err = @@ERROR
               
               IF @b_debug = 1
               BEGIN 
                   PRINT  'CURSOR_CANDIDATES @n_Err2: '  + CAST (@n_Err AS NVARCHAR)
               END 
               
               IF @n_Err = 16905        
               BEGIN        
                  CLOSE CURSOR_CANDIDATES        
                  DEALLOCATE CURSOR_CANDIDATES        
                  GOTO DECLARE_CURSOR_CANDIDATES        
               END  
               
               IF @n_Err <> 0        
               BEGIN        
                  SET @n_Continue = 3        
                  SET @n_Err      = 60020
                  SET @c_ErrMsg   ='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Creation/Opening of Candidate Cursor Failed! (ispPRALC06)' 
               END  
               
               --SET @c_aLot = ''
               WHILE @n_Continue = 1 AND @n_QtyLeftToFulfill > 0
               BEGIN
                  IF @b_debug = 1
                  BEGIN 
                      PRINT 'FETCH NEXT: CURSOR_CANDIDATES '  
                  END 

                  SET @c_aLot_Prev = @c_aLot
                  FETCH NEXT FROM CURSOR_CANDIDATES INTO @c_aLOT, @c_aLOC, @c_aID, @n_aQtyAvailable, @c_aOtherValue 
            
                  IF @@FETCH_STATUS = -1 
                  BEGIN
                     BREAK
                  END  
   
                  IF @b_debug = 1
                  BEGIN 
                     PRINT '@@FETCH_STATUS: '  + CAST (@@FETCH_STATUS AS NVARCHAR)
                     PRINT '@c_aLOT:' + @c_aLOT + ', @c_aLOC: ' + @c_aLOC +', @c_aID: '+ @c_aID
                        +', @n_aQtyAvailable: ' + CAST(@n_aQtyAvailable AS NVARCHAR)
                        +', @c_aOtherValue: ' + @c_aOtherValue
                  END 
  
                  IF @c_ChannelInventoryMgmt = '1'               
                  BEGIN
                     IF @c_aLot <> @c_aLot_Prev
                     BEGIN
                        SET @n_Channel_ID = 0
                     END
 
                     IF @c_Channel <> '' AND @n_Channel_ID = 0        
                     BEGIN        
                        SET @n_Channel_ID = 0        
       
                        EXEC isp_ChannelGetID         
                            @c_StorerKey   = @c_StorerKey        
                           ,@c_Sku         = @c_SKU        
                           ,@c_Facility    = @c_Facility        
                           ,@c_Channel     = @c_Channel        
                           ,@c_LOT         = @c_aLOT        
                           ,@n_Channel_ID  = @n_Channel_ID  OUTPUT        
                           ,@b_Success     = @b_Success     OUTPUT        
                           ,@n_ErrNo       = @n_Err         OUTPUT        
                           ,@c_ErrMsg      = @c_ErrMsg      OUTPUT                         
                           ,@c_CreateIfNotExist = 'N'        

                        IF @b_Success = 0
                        BEGIN
                           SET @n_continue = 3 
                           SET @n_err = ERROR_NUMBER()        
                           SET @c_ErrMsg = ERROR_MESSAGE()        
                           SET @c_ErrMsg = RTRIM(@c_ErrMsg) + '. (ispPRALC06)'  
                           BREAK
                        END       
                     END     
                                       
                     IF @n_Channel_ID = 0
                     BEGIN
                        SET @n_aQtyAvailable = 0   
                     END
                     ELSE        
                     BEGIN        
                        SET @n_Channel_QtyAvailable = 0         
                        SET @n_ChannelHoldQty = 0  
                              
                        EXEC isp_ChannelAllocGetHoldQty_Wrapper          
                              @c_StorerKey   = @c_Storerkey       
                           ,  @c_Sku         = @c_SKU         
                           ,  @c_Facility    = @c_Facility                  
                           ,  @c_Lot         = @c_aLOT        
                           ,  @c_Channel     = @c_Channel        
                           ,  @n_Channel_ID  = @n_Channel_ID           
                           ,  @c_SourceKey   = @c_Wavekey        
                           ,  @c_SourceType  = 'ispPRALC06'         
                           ,  @n_ChannelHoldQty = @n_ChannelHoldQty  OUTPUT       
                           ,  @b_Success     = @b_Success            OUTPUT        
                           ,  @n_Err         = @n_Err                OUTPUT         
                           ,  @c_ErrMsg      = @c_ErrMsg             OUTPUT        
                                         
                        SELECT @n_Channel_QtyAvailable = ci.Qty - ci.QtyAllocated - ci.QtyOnHold - @n_ChannelHoldQty                                   
                        FROM ChannelInv AS ci WITH(NOLOCK)        
                        WHERE ci.Channel_ID = @n_Channel_ID        
                                         
                        IF @n_Channel_QtyAvailable < @n_aQtyAvailable        
                        BEGIN  
                           --IF Channel Available < UCC Qty
                           IF @c_aOtherValue NOT IN ('1', 'FULLPALET') AND LEFT(@c_aOtherValue,4) NOT IN ('uom=') AND @c_aOtherValue <> '' AND
                              @c_aUOM IN ('2','6') 
                           BEGIN  
                              CONTINUE
                           END     
                           SET @n_aQtyAvailable = @n_Channel_QtyAvailable           
                        END  
                     END                     
                  END 
                  
                  IF @n_aQtyAvailable = 0
                  BEGIN
                     CONTINUE
                  END              
                                
                  -- If Full UCC cannot partially assign to order(s) for UOM '2' & '6'
                  IF @c_aUOM IN ('2','6') AND @n_aQtyAvailable > @n_QtyLeftToFulfill
                  BEGIN
                     CONTINUE
                  END
                  
                  SET @c_aUCCNo = ''

                  IF @c_aOtherValue NOT IN ('1', 'FULLPALET') AND LEFT(@c_aOtherValue,4) NOT IN ('uom=') AND @c_aOtherValue <> ''
                  BEGIN
                     SET @c_aUCCNo = @c_aOtherValue
                     SELECT @n_UOMQty = SUM(u.Qty)
                       FROM dbo.UCC AS u (NOLOCK)
                     WHERE u.Storerkey = @c_Storerkey
                     AND u.UCCNo = @c_aUCCNo
                     GROUP BY u.UCCNo
                  END
                  
                  IF @c_aUOM IN ('2','6') 
                  BEGIN
                     SET @c_PickMethod = 'C'
                  END
                  
                  IF @c_aUOM IN ('7') AND @c_aUCCNo = ''
                  BEGIN
                     SET @c_PickMethod = '' 
                                         
                     SELECT @c_PickMethod = pz.UOM3PickMethod -- piece        
                     FROM dbo.LOC AS l  WITH (NOLOCK)  
                     JOIN dbo.PutawayZone AS pz WITH (NOLOCK) ON (l.Putawayzone = pz.Putawayzone)    
                     WHERE l.LOC = @c_aLoc 
                  END
                  
                  IF @b_debug = 2
                  BEGIN  
                     SELECT @c_AllocateBy '@c_AllocateBy', @c_sOrderkey '@c_sOrderkey'
                  END

                  --Invetory Assign to Orders
                  SET @c_SQL = N'DECLARE CUR_OPORDLINES CURSOR FAST_FORWARD READ_ONLY FOR'
                     + ' SELECT o2.OrderKey'
                     +      '  ,o2.OrderLineNumber'
                     +      '  ,QtyLeftToAllocate = o2.OpenQty - o2.QtyAllocated - o2.QtyPicked - o2.ShippedQty'
                     + ' FROM #OPORDLINES AS o'
                     + ' JOIN dbo.ORDERDETAIL AS o2 WITH (NOLOCK) ON o2.OrderKey = o.OrderKey'
                     +                                         ' AND o2.OrderLineNumber = o.OrderLineNumber'
                     + ' WHERE o.Storerkey= @c_Storerkey'
                     + ' AND o.Sku        = @c_Sku'
                     + ' AND o.PACKKey    = @c_PACKKey'
                     + ' AND o.UOM        = @c_UOM'                     
                     + ' AND o.Lottable01 = @c_Lottable01'  
                     + ' AND o.Lottable02 = @c_Lottable02' 
                     + ' AND o.Lottable03 = @c_Lottable03'  
                     + ' AND o.Lottable04 = @dt_Lottable04'    
                     + ' AND o.Lottable05 = @dt_Lottable05'  
                     + ' AND o.Lottable06 = @c_Lottable06'  
                     + ' AND o.Lottable07 = @c_Lottable07'  
                     + ' AND o.Lottable08 = @c_Lottable08' 
                     + ' AND o.Lottable09 = @c_Lottable09'  
                     + ' AND o.Lottable10 = @c_Lottable10'  
                     + ' AND o.Lottable11 = @c_Lottable11'  
                     + ' AND o.Lottable12 = @c_Lottable12' 
                     + ' AND o.Lottable13 = @dt_Lottable13'  
                     + ' AND o.Lottable14 = @dt_Lottable14'    
                     + ' AND o.Lottable15 = @dt_Lottable15'   
                     + ' AND o2.OpenQty - o2.QtyAllocated - o2.QtyPicked - o2.ShippedQty > 0'  
                     + CASE WHEN @c_ChannelInventoryMgmt ='0' THEN '' ELSE ' AND o.Channel = @c_Channel' END
                     + CASE WHEN @c_sWavekey = '' THEN '' ELSE ' AND o.Wavekey = @c_sWavekey' END
                     + CASE WHEN @c_sLoadkey = '' THEN '' ELSE ' AND o.Loadkey = @c_sLoadkey' END
                     + CASE WHEN @c_sOrderkey= '' THEN '' ELSE ' AND o.Orderkey= @c_sOrderkey' END
                     + CASE WHEN @c_sOrderLineNumber = '' THEN '' ELSE ' AND o.OrderLineNumber= @c_sOrderLineNumber' END                   
                     + ' ORDER BY o.OrderKey'
                     +          ',o.OrderLineNumber'
                      
                  IF @b_debug = 1
                  BEGIN
                     PRINT 'Allocate Order - @c_SQL: ' + @c_SQL 
                  END
                         
                  SET @c_SQLParms= N'@c_sWavekey         NVARCHAR(10)' 
                                 + ',@c_sLoadkey         NVARCHAR(10)'   
                                 + ',@c_sOrderKey        NVARCHAR(10)'   
                                 + ',@c_sOrderLineNumber NVARCHAR(5)'   
                                 + ',@c_Storerkey        NVARCHAR(15)'   
                                 + ',@c_Sku              NVARCHAR(20)'   
                                 + ',@c_Packkey          NVARCHAR(10)' 
                                 + ',@c_UOM              NVARCHAR(10)'                                    
                                 + ',@c_Lottable01       NVARCHAR(18)'   
                                 + ',@c_Lottable02       NVARCHAR(18)'   
                                 + ',@c_Lottable03       NVARCHAR(18)'   
                                 + ',@dt_Lottable04      DATETIME'   
                                 + ',@dt_Lottable05      DATETIME'   
                                 + ',@c_Lottable06       NVARCHAR(30)'   
                                 + ',@c_Lottable07       NVARCHAR(30)'   
                                 + ',@c_Lottable08       NVARCHAR(30)'   
                                 + ',@c_Lottable09       NVARCHAR(30)'   
                                 + ',@c_Lottable10       NVARCHAR(30)'   
                                 + ',@c_Lottable11       NVARCHAR(30)'   
                                 + ',@c_Lottable12       NVARCHAR(30)'   
                                 + ',@dt_Lottable13      DATETIME'   
                                 + ',@dt_Lottable14      DATETIME'   
                                 + ',@dt_Lottable15      DATETIME'  
                                 + ',@c_Channel          NVARCHAR(20)'                                  
                                  
                  EXEC sp_ExecuteSQL  @c_SQL
                                    , @c_SQLParms
                                    , @c_sWavekey          
                                    , @c_sLoadkey          
                                    , @c_sOrderKey         
                                    , @c_sOrderLineNumber  
                                    , @c_Storerkey        
                                    , @c_Sku              
                                    , @c_Packkey 
                                    , @c_UOM         
                                    , @c_Lottable01       
                                    , @c_Lottable02       
                                    , @c_Lottable03       
                                    , @dt_Lottable04      
                                    , @dt_Lottable05      
                                    , @c_Lottable06       
                                    , @c_Lottable07       
                                    , @c_Lottable08       
                                    , @c_Lottable09       
                                    , @c_Lottable10       
                                    , @c_Lottable11       
                                    , @c_Lottable12       
                                    , @dt_Lottable13      
                                    , @dt_Lottable14      
                                    , @dt_Lottable15 
                                    , @c_Channel     

                  OPEN CUR_OPORDLINES
            
                  FETCH NEXT FROM CUR_OPORDLINES INTO @c_aOrderkey  
                                                    , @c_aOrderlineNumber
                                                    , @n_aQty
                                                 
                  WHILE @@FETCH_STATUS <> -1 AND @n_aQtyAvailable > 0 AND @n_Continue = 1
                  BEGIN 
                     IF @b_debug = 1
                     BEGIN
                        PRINT 'Allocate Order - @c_sWavekey: ' + @c_sWavekey             
                             +',@c_sLoadkey: ' + @c_sLoadkey             
                             +',@c_sOrderkey: '+ @c_sOrderkey 
                             +',@c_aOrderkey: '+ @c_aOrderkey 
                     END
                    
                     IF @n_aQtyAvailable <= @n_aQty
                     BEGIN
                        SET @n_QtyToInsert = @n_aQtyAvailable
                     END
                     ELSE
                     BEGIN
                        SET @n_QtyToInsert = @n_aQty
                     END
                                   
                     IF @n_QtyToInsert > 0 
                     BEGIN
                        EXECUTE nspg_getkey        
                            @KeyName = 'PickDetailKey'        
                          , @fieldlength = 10       
                          , @keystring = @c_PickDetailKey OUTPUT        
                          , @b_Success = @b_Success       OUTPUT        
                          , @n_Err     = @n_Err           OUTPUT        
                          , @c_ErrMsg  = @c_ErrMsg        OUTPUT 
                          
                        IF @b_Success = 0
                        BEGIN 
                           SET @n_Continue = 3
                           SET @n_Err = 60030
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err) + ': Error getting PickDetailkey. (ispPRALC06)'
                        END
                          
                        IF @c_aUCCNo = ''
                        BEGIN 
                           SET @n_UOMQty = @n_QtyToInsert   
                        END
                        
                        --insert pickdetail
                        IF @b_Debug = 1
                        BEGIN
                           PRINT 'insert pickdetail: @c_Wavekey: ' + @c_Wavekey  
                                +',@c_PickDetailKey: ' + @c_PickDetailKey     
                                +',@c_Orderkey: '+ @c_aOrderkey          
                                +',@c_OrderLineNumber: '+ @c_aOrderLineNumber   
                                +',@c_Storerkey: ' + @c_Storerkey           
                                +',@c_Sku: ' + @c_Sku                
                                +',@c_PACKKey: ' + @c_PACKKey  
                                +',@c_UOM: ' + @c_aUOM           
                                +',@c_aLot: ' + @c_aLot          
                                +',@c_aLoc: ' + @c_aLoc 
                                +',@c_aUCCNo: ' + @c_aUCCNo                                   
                                +',@c_aID: ' + @c_aID 
                                +',@c_PickMethod: ' + @c_PickMethod                                              
                                +',@n_UOMQty: ' + CAST(@n_UOMQty AS NVARCHAR)                                      
                                +',@n_QtyToInsert: ' + CAST(@n_QtyToInsert AS NVARCHAR) 
                        END 
                        
                        IF @n_Continue = 1
                        BEGIN
                           INSERT INTO PICKDETAIL (  
                                 PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                                 Lot, StorerKey, Sku, UOM, UOMQty, Qty, DropID,
                                 Loc, Id, PackKey, CartonGroup, DoReplenish,  
                                 replenishzone, doCartonize, Trafficcop, PickMethod,
                                 Channel_ID, Wavekey
                                 ) 
                           VALUES (  
                                 @c_PickDetailKey, '', '', @c_aOrderKey, @c_aOrderLineNumber,  
                                 @c_aLot, @c_StorerKey, @c_SKU, @c_aUOM, @n_UOMQty, @n_QtyToInsert, @c_aUCCNo,
                                 @c_aLoc, @c_aID, @c_PackKey, '', 'N',  
                                 '', NULL, 'U', @c_PickMethod,
                                 @n_Channel_ID, @c_Wavekey
                                 )  
                              
                           IF @@ERROR <> 0
                           BEGIN
                              SET @n_Continue = 3
                              SET @n_Err = 60040
                              SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),@n_Err,0) + ': Insert PickDetail Failed. (ispPRALC06)'
                           END
                        END
                     END
                     
                     IF @c_aUCCNo <> '' AND @n_Continue = 1
                     BEGIN
                        ;  WITH upd_ucc (UCC_RowRef) AS
                        (  SELECT UCC_RowRef FROM dbo.UCC AS u WITH (NOLOCK)
                           WHERE u.Storerkey = @c_Storerkey
                           AND u.UCCNo = @c_aUCCNo
                           AND u.Lot   = @c_aLot
                           AND u.Loc   = @c_aLoc
                           AND u.ID    = @c_aID
                           AND u.[Status] < '3'
                        )
                        
                        UPDATE u WITH (ROWLOCK)
                           SET [Status] = '3'
                           ,   EditDate = GETDATE()
                           ,   EditWho = SUSER_SNAME()
                           ,   TrafficCop = NULL
                        FROM dbo.UCC u
                        JOIN upd_ucc upd ON u.UCC_RowRef = upd.UCC_RowRef

                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_Continue = 3
                           SET @n_Err = 60050
                           SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Error Update UCC table. (ispPRALC06)'
                        END
                     END 

                     IF @n_Continue = 1
                     BEGIN
                        UPDATE o
                           SET o.QtyLeftToFullFill = o.QtyLeftToFullFill - @n_QtyToInsert
                        FROM #OPORDLINES AS o
                        WHERE o.OrderKey = @c_aOrderkey
                        AND   o.OrderLineNumber = @c_aOrderlineNumber
                        AND  o.QtyLeftToFullFill > 0
                     END

                     SET @n_aQtyAvailable = @n_aQtyAvailable - @n_QtyToInsert
                     SET @n_QtyLeftToFulfill = @n_QtyLeftToFulfill - @n_QtyToInsert
                     
                     FETCH NEXT FROM CUR_OPORDLINES INTO @c_aOrderkey  
                                                       , @c_aOrderlineNumber
                                                       , @n_aQty
                  END
                  CLOSE CUR_OPORDLINES
                  DEALLOCATE CUR_OPORDLINES
               END  
            
               CLOSE CURSOR_CANDIDATES        
               DEALLOCATE CURSOR_CANDIDATES  
            END 
         
            FETCH NEXT FROM @CUR_ALLOCORDSKU INTO @c_sWavekey   
                                                , @c_sLoadkey  
                                                , @c_sOrderkey                                   
                                                , @c_sOrderLineNumber                  
                                                , @c_Storerkey
                                                , @c_Sku
                                                , @c_PACKKey
                                                , @c_UOM                                               
                                                , @c_Lottable01  
                                                , @c_Lottable02 
                                                , @c_Lottable03  
                                                , @dt_Lottable04    
                                                , @dt_Lottable05  
                                                , @c_Lottable06  
                                                , @c_Lottable07  
                                                , @c_Lottable08 
                                                , @c_Lottable09  
                                                , @c_Lottable10  
                                                , @c_Lottable11  
                                                , @c_Lottable12 
                                                , @dt_Lottable13  
                                                , @dt_Lottable14    
                                                , @dt_Lottable15  
                                                , @n_QtyLeftToFulfill
                                                , @c_Channel                                                                  
         END    
         CLOSE @CUR_ALLOCORDSKU
         DEALLOCATE @CUR_ALLOCORDSKU  
      --END 
   END 
          
   QUIT_SP: 
   IF CURSOR_STATUS('GLOBAL' , 'CURSOR_CANDIDATES') in (0 , 1)          
   BEGIN          
      CLOSE CURSOR_CANDIDATES          
      DEALLOCATE CURSOR_CANDIDATES          
   END  

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRALC06'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO