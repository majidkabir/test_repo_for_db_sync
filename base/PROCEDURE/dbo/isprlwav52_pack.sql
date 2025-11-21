SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV52_PACK                                         */
/* Creation Date: 2022-05-12                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-19633 - TH-Nike-Wave Release                            */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-05-12  Wan      1.0   Created.                                  */
/* 2022-05-12  Wan      1.0   DevOps Combine Script.                    */
/* 2022-08-04  Wan01    1.1   Fixed to get correct SourceType           */
/* 2022-08-29  Wan02    1.3   Fixed. Infinity Loop due to differen UOM  */
/* 2022-08-31  SPChin   1.4   JSM-92661 - Bug Fixed                     */
/* 2022-09-06  Wan03    1.4   WMS-20686 - TH-NIKE - customize Wave      */
/*                            Release V2022                             */
/************************************************************************/
CREATE PROC [dbo].[ispRLWAV52_PACK]
   @c_Wavekey     NVARCHAR(10)    
,  @b_Success     INT            = 1   OUTPUT
,  @n_Err         INT            = 0   OUTPUT
,  @c_ErrMsg      NVARCHAR(255)  = ''  OUTPUT
,  @b_debug       INT            = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT         = 0
         , @n_Continue           INT         = 1

         , @b_NewCarton          INT         = 0
         , @b_SplitPickdetail    INT         = 0

         , @n_RowRef             INT         = 0
         , @n_RowRef_Sku         INT         = 0
         , @n_RowRef_PD          INT         = 0
         , @n_Status             INT         = 0      --0:Original, 1:Split, 2:New
         , @b_InsSkuToPack       INT         = 0      

         , @c_Busr7_Prev         NVARCHAR(30)= ''
         , @c_LocLevel_Prev      NVARCHAR(10)= ''

         , @c_Loadkey            NVARCHAR(10)= ''
         , @c_Orderkey           NVARCHAR(10)= ''
         , @c_Busr7              NVARCHAR(30)= ''
         , @c_LocLevel           NVARCHAR(10)= ''
         , @c_Consigneekey       NVARCHAR(15)= ''
         , @c_Route              NVARCHAR(10)= ''
         , @c_ExternOrderkey     NVARCHAR(30)= ''

         , @n_TotalPickCube      FLOAT       = 0.00
         , @n_TotalPickWgt       FLOAT       = 0.00

         , @n_CartonSeqNo_Prev   INT         = 0
         , @n_CartonSeqNo        INT         = 0
         , @c_CartonGroup        NVARCHAR(10)= ''
         , @c_CartonType         NVARCHAR(10)= ''
         , @n_MaxCube            FLOAT       = 0.00
         , @n_MaxWeight          FLOAT       = 0.00

         , @n_AvailableCube      FLOAT       = 0.00
         , @n_AvailableWgt       FLOAT       = 0.00

         , @n_QtyNeedCube        FLOAT       = 0.00
         , @n_QtyNeedWgt         FLOAT       = 0.00
         , @n_PackedCube         FLOAT       = 0.00
         , @n_PackedWgt          FLOAT       = 0.00
         , @n_ItemClass_Cube     FLOAT       = 0.00      
         , @n_ItemClass_Wgt      FLOAT       = 0.00      
         
         , @n_QtyCubeExceed      INT         = 0         
         , @n_QtyWgtExceed       INT         = 0         
         , @n_QtyToReduce        INT         = 0         
         , @n_QtyToPack          INT         = 0
         , @n_Qty_Recalc         INT         = 0         
         , @n_Qty_PD             INT         = 0           
         , @n_QtyToPack_REM      INT         = 0         
         , @n_QtyToPack_TTL      INT         = 0         

         , @c_PickDetailKey      NVARCHAR(10)= ''
         , @c_Storerkey          NVARCHAR(15)= ''
         , @c_Sku                NVARCHAR(20)= ''
         , @c_UOM                NVARCHAR(10)= ''
         , @c_DropID             NVARCHAR(20)= ''     
         , @n_PickStdCube        FLOAT       = 0.00
         , @n_PickStdGrossWgt    FLOAT       = 0.00
         , @n_StdCube            FLOAT       = 0.00
         , @n_StdGrossWgt        FLOAT       = 0.00
         , @n_PackQtyIndicator   INT         = 0      
         , @n_QtyToPackBundle    INT         = 0      
         , @n_Qty                INT         = 0

         , @n_MaxLength          FLOAT       = 0.00
         , @n_MaxWidth           FLOAT       = 0.00
         , @n_MaxHeight          FLOAT       = 0.00
         , @n_MaxDimension       FLOAT       = 0.00

         , @c_LogicalLocation    NVARCHAR(10)= ''

         , @n_CartonNo           INT         = 0
         , @c_PickSlipNo         NVARCHAR(10)= ''
         , @c_LabelNo            NVARCHAR(20)= ''
         , @c_NewPickDetailKey   NVARCHAR(10)= '' 

         , @n_CartonItem         INT         = 0  
         , @c_Facility           NVARCHAR(5) = '' 
         , @c_NewCartonType      NVARCHAR(10)= '' 
         , @c_CartonOptimizeChk  NVARCHAR(30)= '' 
         
         , @n_AccessQty          INT         = 0  
         , @n_PickedQty          INT         = 0  
         , @c_ItemClass          NVARCHAR(10)= '' 
         , @c_Size               NVARCHAR(10)= '' 
         
         , @c_ReleaseWave_Authority    NVARCHAR(30)   = ''           --Wan03
         , @c_ReleaseWave_Opt5         NVARCHAR(1000) = ''           --Wan03
         , @c_UseCTNBreakByFloor       CHAR(1)     = 'N'             --Wan03
         
         , @CUR_ORD              CURSOR
         , @CUR_PD               CURSOR
         , @CUR_DELPCK           CURSOR
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP','U') IS NOT NULL
   BEGIN
      DROP TABLE  #PICKDETAIL_WIP
   END
   
   CREATE TABLE #PICKDETAIL_WIP  
   (  RowRef            INT         IDENTITY(1,1)     PRIMARY KEY
   ,  Wavekey           NVARCHAR(10) DEFAULT('') 
   ,  Loadkey           NVARCHAR(10) DEFAULT('')
   ,  Orderkey          NVARCHAR(10) DEFAULT('')
   ,  [Route]           NVARCHAR(10) DEFAULT('')
   ,  ExternOrderkey    NVARCHAR(50) DEFAULT('')
   ,  Pickdetailkey     NVARCHAR(10) DEFAULT('')   
   ,  Busr7             NVARCHAR(30) DEFAULT('')      -- Product engine
   ,  Storerkey         NVARCHAR(15) DEFAULT('')
   ,  Sku               NVARCHAR(20) DEFAULT('')
   ,  UOM               NVARCHAR(10) DEFAULT('')
   ,  UOMQty            INT          DEFAULT(0)
   ,  Qty               INT          DEFAULT(0)
   ,  Lot               NVARCHAR(10) DEFAULT('')
   ,  ToLoc             NVARCHAR(10) DEFAULT('')
   ,  PickStdCube       FLOAT        DEFAULT(0.00)
   ,  PickStdGrossWgt   FLOAT        DEFAULT(0.00)
   ,  StdCube           FLOAT        DEFAULT(0.00)
   ,  StdGrossWgt       FLOAT        DEFAULT(0.00)
   ,  SkuStdCube        FLOAT        DEFAULT(0.00)    
   ,  SkuStdGrossWgt    FLOAT        DEFAULT(0.00)      
   ,  CubeTolerance     FLOAT        DEFAULT(0.00)    
   ,  [Length]          FLOAT        DEFAULT(0.00)    
   ,  Width             FLOAT        DEFAULT(0.00)    
   ,  Height            FLOAT        DEFAULT(0.00)    
   ,  PackQtyIndicator  INT          DEFAULT(0)       
   ,  DropID            NVARCHAR(20) DEFAULT('')
   ,  LocLevel          NVARCHAR(10) DEFAULT('')
   ,  Logicallocation   NVARCHAR(10) DEFAULT('')
   ,  PickSlipNo        NVARCHAR(10) DEFAULT('')
   ,  CartonType        NVARCHAR(10) DEFAULT('')
   ,  CaseID            NVARCHAR(20) DEFAULT('')
   ,  CartonSeqNo       INT          DEFAULT(0)
   ,  CartonCube        FLOAT        DEFAULT(0.00)
   ,  [Status]          INT          DEFAULT(0)
   ,  ItemClass         NVARCHAR(10) DEFAULT('')      
   ,  Size              NVARCHAR(10) DEFAULT('')      
   )

   IF OBJECT_ID('tempdb..#NikeCTNGroup','U') IS NULL
   BEGIN
       CREATE TABLE #NikeCTNGroup
         (  RowRef               INT            IDENTITY(1,1) PRIMARY KEY
         ,  CartonizationGroup   NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  CartonType           NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  [Cube]               FLOAT          NOT NULL DEFAULT (0.00)
         ,  MaxWeight            FLOAT          NOT NULL DEFAULT (0.00)
         ,  CartonLength         FLOAT          NOT NULL DEFAULT (0.00) 
         ,  CartonWidth          FLOAT          NOT NULL DEFAULT (0.00) 
         ,  CartonHeight         FLOAT          NOT NULL DEFAULT (0.00) 
         )
   END
      
   IF OBJECT_ID('tempdb..#OptimizeItemToPack','U') IS NULL     
   BEGIN
      CREATE TABLE #OptimizeItemToPack 
         (
            ID          INT                     IDENTITY(1,1)
         ,  Storerkey   NVARCHAR(15)   NOT NULL DEFAULT('') 
         ,  SKU         NVARCHAR(20)   NOT NULL DEFAULT('')
         ,  Dim1        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
         ,  Dim2        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
         ,  Dim3        DECIMAL(10,6)  NOT NULL DEFAULT(0.00)
         ,  Quantity    INT            NOT NULL DEFAULT(0)
         ,  RowRef      INT            NOT NULL DEFAULT(0)
         ,  OriginalQty INT            NOT NULL DEFAULT(0)
         )
   END

   BEGIN TRAN

   SELECT TOP 1 @c_Storerkey = OH.Storerkey
            ,   @c_Facility  = OH.Facility 
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
   WHERE WD.Wavekey = @c_Wavekey
         
   EXEC nspGetRight
         @c_Facility   = @c_Facility  
      ,  @c_StorerKey  = @c_StorerKey 
      ,  @c_sku        = ''       
      ,  @c_ConfigKey  = 'CartonOptimizeCheck' 
      ,  @b_Success    = @b_Success             OUTPUT
      ,  @c_authority  = @c_CartonOptimizeChk   OUTPUT 
      ,  @n_err        = @n_err                 OUTPUT
      ,  @c_errmsg     = @c_errmsg              OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 83010  
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ispRLWAV52_PACK)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END

   --Wan03 - START
   SELECT @c_ReleaseWave_Authority = fgr.Authority
         ,@c_ReleaseWave_Opt5 = fgr.Option5
   FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') AS fgr 
   
   SET @c_UseCTNBreakByFloor = 'N' 
   SELECT @c_UseCTNBreakByFloor = dbo.fnc_GetParamValueFromString('@c_UseCTNBreakByFloor', @c_ReleaseWave_Opt5, @c_UseCTNBreakByFloor) 
   --Wan03 - END
   INSERT INTO #PICKDETAIL_WIP  
      (  
         Wavekey   
      ,  Loadkey           
      ,  Orderkey  
      ,  [Route]
      ,  ExternOrderkey        
      ,  Pickdetailkey     
      ,  Busr7             
      ,  Storerkey         
      ,  Sku               
      ,  UOM
      ,  UOMQty  
      ,  Qty  
      ,  Lot            
      ,  ToLoc  
      ,  PickStdCube        
      ,  PickStdGrossWgt               
      ,  StdCube        
      ,  StdGrossWgt 
      ,  SkuStdCube 
      ,  SkuStdGrossWgt                       
      ,  CubeTolerance  
      ,  [Length]   
      ,  [Width]  
      ,  [Height] 
      ,  PackQtyIndicator          
      ,  DropID 
      )
      SELECT  WD.Wavekey  
         , OH.Loadkey  
         , PD.Orderkey  
         , OH.[Route]  
         , OH.ExternOrderkey  
         , PickDetailKey = MIN (PD.PickDetailKey)  
         , SKU.Busr7  
         , PD.Storerkey  
         , PD.Sku  
         , PD.UOM  
         , PD.UOMQty  
         , Qty = SUM(PD.Qty) 
         , PD.Lot  
         , ToLoc = CASE WHEN TD.TaskDetailKey IS NULL THEN PD.Loc ELSE TD.LogicalToLoc END            
         , PickStdCube = SUM(PD.Qty * SKU.StdCube)   
         , PickStdWgt  = SUM(PD.Qty * SKU.StdGrossWgt)  
         , StdCube = SKU.StdCube 
         , StdWgt  = SKU.StdGrossWgt  
         , SkuStdCube = SKU.StdCube 
         , SkuStdGrossWgt = SKU.StdGrossWgt                          
         , CubeTolerance = CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END    
         , [Length]= ISNULL(SKU.[Length],0.00)  
         , Width   = ISNULL(SKU.Width,0.00)    
         , Height  = ISNULL(SKU.Height,0.00) 
         , PackQtyIndicator = ISNULL(SKU.PackQtyIndicator,1)   
         , PD.DropID
   FROM WAVEDETAIL WD WITH (NOLOCK)  
   JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey  
   JOIN ORDERS     OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey  
   JOIN SKU SKU WITH (NOLOCK) ON  PD.Storerkey = SKU.Storerkey  
                              AND PD.Sku = SKU.Sku  
   LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON  PD.DropID = TD.CaseID  
                                         AND TD.TaskType  = 'RPF'  
                                         --AND TD.Sourcetype IN ( 'ispRLWAV52-INLINE', 'ispRLWAV52-DTC', 'ispRLWAV52-REPLEN' )   --(Wan01) 
                                         AND TD.Sourcetype LIKE 'ispRLWAV52_RPF-%'                                               --(Wan01)
                                         AND PD.DropID <> ''                                                                     --(Wan01) 
   WHERE WD.Wavekey = @c_Wavekey
   AND   PD.UOM = '2'  
   AND   PD.Qty > 0                
   GROUP BY WD.Wavekey  
         , OH.Loadkey  
         , PD.Orderkey  
         , OH.[Route]  
         , OH.ExternOrderkey  
         , SKU.Busr7  
         , PD.Storerkey  
         , PD.Sku  
         , PD.UOM  
         , PD.UOMQty  
         , PD.Lot  
         , CASE WHEN TD.TaskDetailKey IS NULL THEN PD.Loc ELSE TD.LogicalToLoc END           
         , SKU.StdGrossWgt  
         , SKU.StdCube  
         , CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END   
         , ISNULL(SKU.[Length],0.00)  
         , ISNULL(SKU.Width,0.00)     
         , ISNULL(SKU.Height,0.00)
         , ISNULL(SKU.PackQtyIndicator,1)  
         , PD.DropID  
   ORDER BY PD.Orderkey
         ,  MIN(PD.PickDetailKey)  

   INSERT INTO #PICKDETAIL_WIP  
      (  
         Wavekey   
      ,  Loadkey           
      ,  Orderkey  
      ,  [Route]
      ,  ExternOrderkey        
      ,  Pickdetailkey     
      ,  Busr7             
      ,  Storerkey         
      ,  Sku               
      ,  UOM
      ,  UOMQty  
      ,  Qty  
      ,  Lot            
      ,  ToLoc  
      ,  PickStdCube        
      ,  PickStdGrossWgt               
      ,  StdCube        
      ,  StdGrossWgt 
      ,  SkuStdCube     
      ,  SkuStdGrossWgt     
      ,  CubeTolerance  
      ,  [Length] 
      ,  [Width]  
      ,  [Height] 
      ,  PackQtyIndicator 
      ,  DropID 
      ,  ItemClass        
      ,  Size             
      )
   SELECT  WD.Wavekey
         , OH.Loadkey
         , PD.Orderkey
         , OH.[Route]
         , OH.ExternOrderkey
         , PD.PickDetailKey
         , SKU.Busr7
         , PD.Storerkey
         , PD.Sku
         , PD.UOM
         , PD.UOMQty
         , PD.Qty
         , PD.Lot
         , ToLoc = CASE WHEN TD.TaskDetailKey IS NULL THEN PD.Loc ELSE TD.LogicalToLoc END            
         , PickStdCube = PD.Qty / (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)   
                        * (SKU.StdCube + (CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END / 100.00 * SKU.StdCube))           
         , PickStdWgt  = PD.Qty / (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)   
                       * SKU.StdGrossWgt
         , StdCube = SKU.StdCube    
         , StdWgt  = SKU.StdGrossWgt     
         , SkuStdCube = SKU.StdCube  
         , SkuStdGrossWgt = SKU.StdGrossWgt                
         , CubeTolerance = CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END  
         , [Length]= ISNULL(SKU.[Length],0.00)  
         , Width   = ISNULL(SKU.Width,0.00)    
         , Height  = ISNULL(SKU.Height,0.00)
 
         , PackQtyIndicator = ISNULL(SKU.PackQtyIndicator,1) 
         , PD.DropID
         , ItemClass = ISNULL(SKU.ItemClass,'')              
         , Size      = ISNULL(SKU.Size,'')                     
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
   JOIN ORDERS     OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN SKU SKU WITH (NOLOCK) ON  PD.Storerkey = SKU.Storerkey
                              AND PD.Sku = SKU.Sku
   LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON  PD.DropID = TD.CaseID
                                         AND TD.TaskType  = 'RPF'
                                         --AND TD.Sourcetype IN ( 'ispRLWAV52-INLINE', 'ispRLWAV52-DTC', 'ispRLWAV52-REPLEN' )   --(Wan01)
                                         AND TD.Sourcetype LIKE 'ispRLWAV52_RPF-%'                                               --(Wan01) 
                                         AND PD.DropID <> ''                                                                     --(Wan01)  
   WHERE WD.Wavekey = @c_WaveKey
   AND   PD.UOM IN ('6', '7')             
   AND   PD.Qty > 0                       
   ORDER BY PD.Orderkey
        
   UPDATE #PICKDETAIL_WIP
   SET LocLevel = CASE WHEN @c_UseCTNBreakByFloor = 'N' THEN L.LocLevel ELSE L.[Floor] END             --Wan03)
         ,Logicallocation = L.LogicalLocation
   FROM #PICKDETAIL_WIP W
   JOIN LOC L (NOLOCK) ON W.ToLoc = L.Loc

   SELECT TOP 1 @c_Storerkey = PD.Storerkey
   FROM #PICKDETAIL_WIP PD

   SELECT @c_CartonGroup = CartonGroup
   FROM STORER WITH (NOLOCK)
   WHERE Storerkey = @c_Storerkey

   INSERT INTO #NikeCTNGroup
      (  CartonizationGroup  
      ,  CartonType          
      ,  [Cube]              
      ,  MaxWeight  
      ,  CartonLength                              
      ,  CartonWidth                               
      ,  CartonHeight                                         
      )
   SELECT CartonizationGroup  
      ,  CartonType          
      ,  [Cube]              
      ,  MaxWeight 
      ,  CartonLength = ISNULL(CartonLength,0.00)  
      ,  CartonWidth  = ISNULL(CartonWidth,0.00)   
      ,  CartonHeight = ISNULL(CartonHeight,0.00)                  
   FROM CARTONIZATION CZ WITH (NOLOCK)
   WHERE CZ.CartonizationGroup = @c_CartonGroup
   ORDER BY [Cube]
           ,MaxWeight 
          
   SET @n_AccessQty = 0      
   SELECT @n_AccessQty = ISNULL(CL.Short,0)
   FROM CODELKUP CL WITH (NOLOCK) 
   WHERE CL.ListName = 'NIKPHCZCFG'  
   AND CL.Code = 'AccessValue' 

   SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  PD.Orderkey
         , PD.Loadkey
         , PD.[Route]
         , PD.ExternOrderkey
   FROM #PICKDETAIL_WIP PD   
   GROUP BY PD.Orderkey
         ,  PD.Loadkey
         ,  PD.[Route]
         ,  PD.ExternOrderkey
   ORDER BY PD.Orderkey
          
   OPEN @CUR_ORD
   
   FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey
                              ,  @c_Loadkey
                              ,  @c_Route
                              ,  @c_ExternOrderkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT '@c_Orderkey: ' + @c_Orderkey
      END

      SET @n_CartonSeqNo = 0                 
      
      --------------------------------------------
      -- UOM = '2' 
      --------------------------------------------
      SET @c_DropID = ''

      WHILE 1=1
      BEGIN
         SELECT TOP 1 @c_DropID = PD.DropID
                  ,  @n_PickStdCube = SUM(PD.PickStdCube)
                  ,  @n_PickStdGrossWgt = SUM(PD.PickStdGrossWgt)                 
         FROM #PICKDETAIL_WIP PD
         WHERE PD.Orderkey = @c_Orderkey
         AND   PD.UOM = '2'
         AND   PD.CartonType = ''
         GROUP BY PD.Busr7
               ,  PD.LocLevel
               ,  PD.LogicalLocation
               ,  PD.DropID            
         ORDER BY PD.Busr7
               ,  PD.LocLevel
               ,  PD.LogicalLocation
               ,  PD.DropID                                
        
         IF @c_DropID = '' OR @@ROWCOUNT = 0 
         BEGIN
            BREAK
         END
         
         SET @n_CartonSeqNo = @n_CartonSeqNo + 1
         
         SET @c_CartonType = ''
         SET @n_MaxCube = 0
         SET @n_MaxWeight = 0
         
         SELECT TOP 1 @c_CartonType = CG.CartonType
                     ,@n_MaxCube    = CG.[Cube]
                     ,@n_MaxWeight  = CG.MaxWeight
         FROM #NikeCTNGroup CG
         WHERE [Cube]  >= @n_PickStdCube
         AND MaxWeight >= @n_PickStdGrossWgt
         ORDER BY RowRef 

         IF @c_CartonType = ''
         BEGIN
            SELECT TOP 1 @c_CartonType = CG.CartonType
                        ,@n_MaxCube    = CG.[Cube]
                        ,@n_MaxWeight  = CG.MaxWeight
            FROM #NikeCTNGroup CG
            ORDER BY RowRef DESC
         END
         
         IF @b_debug = 1
         BEGIN
            PRINT '@c_CartonType: ' + @c_CartonType
               + ', @c_LocLevel: '+ @c_LocLevel
               + ', @n_CartonSeqNo: ' + CAST (@n_CartonSeqNo AS NVARCHAR) 
         END
                
         SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.RowRef
         FROM #PICKDETAIL_WIP PD
         WHERE PD.Orderkey = @c_Orderkey
         AND   PD.UOM = '2'
         AND   PD.DropID = @c_DropID
         AND   PD.CartonType = ''
         ORDER BY PD.RowRef
         
         OPEN @CUR_PD
   
         FETCH NEXT FROM @CUR_PD INTO @n_RowRef
                         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '@n_RowRef: ' + CAST(@n_RowRef AS NVARCHAR)
                     +', @c_UOM:' +  @c_UOM 
                     +', @c_Busr7:' +  @c_Busr7
                     +', @c_LocLevel: ' + @c_LocLevel
            END
           
            UPDATE #PICKDETAIL_WIP
            Set  CartonType = @c_CartonType
               , CartonSeqNo= @n_CartonSeqNo
               , CartonCube = @n_MaxCube
            WHERE RowRef    = @n_RowRef  

            FETCH NEXT FROM @CUR_PD INTO @n_RowRef
         END
         CLOSE @CUR_PD
         DEALLOCATE @CUR_PD
      END
      --------------------------------------------
      -- UOM = '2' 
      --------------------------------------------
 
      --------------------------------------------
      -- UOM IN ('6','7') 
      --------------------------------------------
      
      SET @b_NewCarton = 1

      SET @c_Busr7_Prev = ''
      SET @c_LocLevel_Prev = ''
      
      SET @n_PickedQty = CASE WHEN @n_AccessQty > 0 THEN @n_AccessQty ELSE 1 END

      WHILE 1=1
      BEGIN
         SET @n_RowRef = 0
         ;WITH PD ( RowRef, Storerkey, Sku, ItemClass, SIZE, Busr7, LocLevel, Sku_Qty) AS
         (  SELECT RowRef = MIN(PD.RowRef)  
                  ,  PD.Storerkey  
                  ,  PD.Sku  
                  ,  PD.ItemClass  
                  ,  PD.Size  
                  ,  PD.Busr7  
                  ,  PD.LocLevel 
                  ,  SKU_QTY = SUM(FLOOR(PD.Qty/PD.PackQtyIndicator))       
            FROM #PICKDETAIL_WIP PD  
            WHERE PD.Orderkey = @c_Orderkey  
            AND   PD.UOM IN ('6','7')  
            AND   PD.CartonType = ''  
            GROUP BY PD.Storerkey  
                  ,  PD.Sku  
                  ,  PD.ItemClass  
                  ,  PD.Size  
                  ,  PD.Busr7  
                  ,  PD.LocLevel 
         )           
         SELECT TOP 1   
                    @n_RowRef = MIN(PD.RowRef)  
                  , @c_ItemClass = PD.ItemClass  
                  , @c_Size = PD.Size  
                  , @c_Busr7 = PD.Busr7  
                  , @c_LocLevel = PD.LocLevel             
         FROM  PD  
         WHERE PD.Sku_Qty > @n_PickedQty                                                           
         GROUP BY PD.Busr7  
               ,  PD.LocLevel  
               ,  PD.ItemClass                                          
               ,  PD.Size   
                                                  
         ORDER BY PD.Busr7  
               ,  PD.LocLevel  
               ,  PD.ItemClass                                          
               ,  PD.Size  

         IF @n_RowRef = 0 OR @@ROWCOUNT = 0 
         BEGIN
            IF @n_PickedQty = 0
            BEGIN
               BREAK
            END   
            
            SET @n_PickedQty = 0 -- Floor (qty/packqtyindicator) may have 0 qty
            SET @b_NewCarton = 1 -- New Carton If Change Access Qty
            CONTINUE
         END
         
         IF @c_Busr7_Prev <> @c_Busr7 OR
            @c_LocLevel_Prev <> @c_LocLevel
         BEGIN
            SET @b_NewCarton = 1
         END
         
         SET @c_Busr7_Prev = @c_Busr7 
         SET @c_LocLevel_Prev = @c_LocLevel
         
         SET @b_SplitPickdetail = 0
       
         GET_PICK_REC:
         SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef_Sku = MIN(PD.RowRef)  
               ,PD.Storerkey  
               ,PD.Sku  
               ,PickStdCube     = SUM(PD.Qty) / (1.00 * PD.PackQtyIndicator)   
                                * (PD.SKUStdCube + (PD.CubeTolerance / 100.00 * PD.SKUStdCube)) 
               ,PickStdGrossWgt = SUM(PD.Qty) / (1.00 * PD.PackQtyIndicator)  
                                * PD.SKUStdGrossWgt   
               ,PD.StdCube  
               ,PD.StdGrossWgt  
               ,Qty = SUM(PD.Qty) 
               ,UOM = MAX(PD.UOM)               --JSM-92661 --(Wan02) Not to Group UOM, 6 and 7 may pack into same carton 
               ,PD.PackQtyIndicator                                 
         FROM #PICKDETAIL_WIP PD  
         WHERE PD.Orderkey = @c_Orderkey  
         AND   PD.UOM IN ('6','7')  
         AND   PD.CartonType = ''  
         AND   PD.ItemClass = @c_ItemClass                          
         AND   PD.Size = @c_Size                                    
         AND   PD.Busr7 = @c_Busr7    
         AND   PD.LocLevel = @c_LocLevel  
         GROUP BY PD.Storerkey                                      
               ,  PD.Sku  
               ,  PD.StdCube  
               ,  PD.StdGrossWgt  
               ,  PD.SkuStdCube  
               ,  PD.SkuStdGrossWgt 
               ,  PD.CubeTolerance                
               --,  PD.UOM                      --(Wan02)              
               ,  PD.PackQtyIndicator                                                                                                                
         HAVING SUM(FLOOR(PD.Qty/PD.PackQtyIndicator)) > @n_PickedQty  
         ORDER BY SUM(PD.Qty) DESC                                  
               ,  PD.Sku  

         OPEN @CUR_PD
   
         FETCH NEXT FROM @CUR_PD INTO @n_RowRef_Sku  
                                    , @c_Storerkey
                                    , @c_Sku
                                    , @n_PickStdCube
                                    , @n_PickStdGrossWgt
                                    , @n_StdCube
                                    , @n_StdGrossWgt
                                    , @n_Qty
                                    , @c_UOM
                                    , @n_PackQtyIndicator  
                          
         WHILE @@FETCH_STATUS <> -1 AND @b_SplitPickdetail = 0    
         BEGIN
            IF @n_Qty >= @n_PackQtyIndicator
            BEGIN
               SET @n_Qty = FLOOR(@n_Qty/@n_PackQtyIndicator) * @n_PackQtyIndicator       
            END
            
            IF @b_debug = 1
            BEGIN
               PRINT '@n_RowRef_Sku: ' + CAST(@n_RowRef_Sku AS NVARCHAR)
                     +', @c_UOM:' +  @c_UOM 
                     +', @c_Busr7:' +  @c_Busr7
                     +', @c_LocLevel: ' + @c_LocLevel
            END
            SET @n_Status = 0

            IF @b_debug = 1
            BEGIN
               PRINT '@c_Sku: ' + @c_Sku
                  + ', @n_StdCube: ' + CAST (@n_StdCube as NVARCHAR)
                  + ', @n_StdGrossWgt: '+ CAST (@n_StdGrossWgt as NVARCHAR)
                  + ', @n_Qty: ' + CAST (@n_Qty AS NVARCHAR) 
                  + ', @b_NewCarton: ' + CAST (@b_NewCarton AS NVARCHAR)    
                  + ', @n_PickedQty: ' + CAST (@n_PickedQty AS NVARCHAR)                       
            END
   
            IF @b_NewCarton = 0
            BEGIN
               IF @c_CartonOptimizeChk = '1'         
               BEGIN
                  SET @n_QtyToPack = @n_Qty
               END
               ELSE
               BEGIN
                  IF EXISTS ( SELECT 1  
                              FROM #PICKDETAIL_WIP p
                              WHERE p.CartonType = @c_CartonType
                              AND p.CartonSeqNo  = @n_CartonSeqNo
                              AND p.orderkey = @c_Orderkey 
                              AND p.ItemClass <> @c_ItemClass
                  )
                  BEGIN 
                     SET @n_ItemClass_Cube = 0.00
                     SET @n_ItemClass_Wgt  = 0.00
                     SELECT @n_ItemClass_Cube = SUM(p.PickStdCube)
                           ,@n_ItemClass_Wgt  = SUM(p.PickStdGrossWgt)
                     FROM #PICKDETAIL_WIP p
                     WHERE p.orderkey = @c_Orderkey 
                     AND   p.CartonType   = ''
                     AND   p.CartonSeqNo  = ''
                     AND   P.ItemClass = @c_ItemClass
                     AND   p.Busr7 = @c_Busr7            
                     AND   p.LocLevel = @c_LocLevel      
                     GROUP BY P.ItemClass
                  
                     IF @n_QtyNeedCube <> @n_ItemClass_Cube OR @n_QtyNeedWgt < @n_ItemClass_Wgt -- New Itemclass cannot fully fit into current box
                     BEGIN 
                        SET @b_NewCarton = 1  
                        GOTO NEW_CARTON
                     END 
                  END

                  SET @n_QtyNeedCube = FLOOR( @n_AvailableCube / @n_StdCube ) * @n_PackQtyIndicator         
                  SET @n_QtyNeedWgt  = FLOOR( @n_AvailableWgt / @n_StdGrossWgt ) * @n_PackQtyIndicator      

                  IF @b_debug = 1
                  BEGIN
                     PRINT '@c_Sku: ' + @c_Sku
                        + ', @n_AvailableCube: ' + CAST (@n_AvailableCube as NVARCHAR)
                        + ', @n_QtyNeedCube: '+ CAST (@n_QtyNeedCube as NVARCHAR)
                        + ', @n_AvailableWgt: ' + CAST (@n_AvailableWgt as NVARCHAR)
                        + ', @n_QtyNeedWgt: '+ CAST (@n_QtyNeedWgt as NVARCHAR)
                        + ', @c_CartonOptimizeChk: ' + @c_CartonOptimizeChk
                  END

                  SET @n_QtyToPack = 0
                  IF @n_QtyNeedCube > 0 AND @n_QtyNeedWgt > 0
                  BEGIN
                     IF @n_QtyNeedCube > @n_QtyNeedWgt
                     BEGIN
                        SET @n_QtyToPack = @n_QtyNeedWgt
                     END
                     ELSE
                     BEGIN
                        SET @n_QtyToPack = @n_QtyNeedCube
                     END

                     --2020-10-12
                     IF @n_QtyToPack > @n_Qty 
                     BEGIN
                        SET @n_QtyToPack = @n_Qty
                     END
                  END

                  IF @n_QtyToPack = 0
                  BEGIN
                     SET @b_NewCarton = 1
                     GOTO NEW_CARTON            
                  END 
               
                  IF @n_PickedQty > 0 AND @n_Qty > @n_QtyToPack AND                                                                    --2021-08-11
                   ((@n_Qty - @n_QtyToPack)/@n_PackQtyIndicator <= @n_PickedQty OR (@n_QtyToPack/@n_PackQtyIndicator) <= @n_PickedQty) --2021-08-11  
                  BEGIN 
                     SET @b_NewCarton = 1  
                     GOTO NEW_CARTON                         
                  END
               END   
            END
     
            NEW_CARTON:

            IF @b_NewCarton = 1
            BEGIN
               SET @n_PackedCube = 0.00
               SET @n_PackEdWgt = 0.00

               SET @n_TotalPickCube = 0.00
               SET @n_TotalPickWgt  = 0.00
               
               IF @n_PickedQty = 0           -- Floor (qty/packqtyindicator) may have 0 qty, hence pickedqty = 0 
               BEGIN                
                  SELECT @n_TotalPickCube = ISNULL(SUM(PD.PickStdCube),0.00)
                        ,@n_TotalPickWgt  = ISNULL(SUM(PD.PickStdGrossWgt),0.00)
                        ,@n_MaxLength  = ISNULL(MAX(PD.[Length]),0.00)
                        ,@n_MaxWidth   = ISNULL(MAX(PD.Width),0.00)
                        ,@n_MaxHeight  = ISNULL(MAX(PD.Height),0.00)
                  FROM #PICKDETAIL_WIP PD
                  WHERE PD.Orderkey = @c_Orderkey
                  AND   PD.Busr7    = @c_Busr7
                  AND   PD.LocLevel = @c_LocLevel
                  AND   PD.UOM IN ('6', '7')
                  AND   PD.CartonType = ''
               END
               ELSE 
               BEGIN
                  SELECT @n_TotalPickCube = ISNULL(SUM(PD.PickStdCube),0.00)
                        ,@n_TotalPickWgt  = ISNULL(SUM(PD.PickStdGrossWgt),0.00)
                        ,@n_MaxLength  = ISNULL(MAX(PD.[Length]),0.00)
                        ,@n_MaxWidth   = ISNULL(MAX(PD.Width),0.00)
                        ,@n_MaxHeight  = ISNULL(MAX(PD.Height),0.00)
                  FROM #PICKDETAIL_WIP PD
                  WHERE PD.Orderkey = @c_Orderkey
                  AND   PD.Busr7    = @c_Busr7
                  AND   PD.LocLevel = @c_LocLevel
                  AND   PD.ItemClass = @c_ItemClass         
                  AND   PD.UOM IN ('6', '7')
                  AND   PD.CartonType = ''
               END
                  
               SET @n_MaxDimension = @n_MaxLength

               IF @n_MaxLength < @n_MaxWidth
                  SET @n_MaxDimension = @n_MaxWidth
          
               IF @n_MaxDimension < @n_MaxHeight
                  SET @n_MaxDimension = @n_MaxHeight


               SET @c_CartonType = ''
               SELECT TOP 1 @c_CartonType = CG.CartonType
                           ,@n_MaxCube    = CG.[Cube]
                           ,@n_MaxWeight  = CG.MaxWeight
               FROM #NikeCTNGroup CG
               WHERE [Cube]  >= @n_TotalPickCube
               AND MaxWeight >= @n_TotalPickWgt
               AND (CartonLength >= @n_MaxDimension OR CartonWidth >= @n_MaxDimension OR CartonHeight >= @n_MaxDimension)--2020-08-07
               ORDER BY RowRef 

               IF @c_CartonType = ''
               BEGIN
                  SELECT TOP 1 @c_CartonType = CG.CartonType
                              ,@n_MaxCube    = CG.[Cube]
                              ,@n_MaxWeight  = CG.MaxWeight
                  FROM #NikeCTNGroup CG
                  ORDER BY RowRef DESC 

                  --if the pickdetail pickstdcube and/or @n_PickStdGrossWgt > Carton Maxcube and/or MaxWeight 
                  SET @n_QtyCubeExceed = 0
                  SET @n_QtyWgtExceed  = 0
 
                  IF @n_MaxCube   < @n_PickStdCube   
                     SET @n_QtyCubeExceed = CEILING((@n_PickStdCube - @n_MaxCube)/@n_StdCube) * @n_PackQtyIndicator 
 
                  IF @n_MaxWeight < @n_PickStdGrossWgt 
                     SET @n_QtyWgtExceed  = CEILING((@n_PickStdGrossWgt - @n_MaxWeight)/@n_StdGrossWgt) * @n_PackQtyIndicator 
 
                  
                  IF @n_QtyCubeExceed > @n_QtyWgtExceed 
                  BEGIN
                     SET @n_QtyToReduce = @n_QtyCubeExceed
                  END 
                  ELSE 
                  BEGIN
                     SET @n_QtyToReduce = @n_QtyWgtExceed
                  END 
               END

               IF @b_debug = 1
               BEGIN
                  PRINT '@c_CartonType: ' + @c_CartonType
                     + ', @n_TotalPickCube: ' + CAST (@n_TotalPickCube as NVARCHAR)
                     + ', @n_TotalPickWgt: ' + CAST (@n_TotalPickWgt as NVARCHAR)
                     + ', @n_PickStdCube: '+ CAST (@n_PickStdCube as NVARCHAR)
                     + ', @n_PickStdGrossWgt: '+ CAST (@n_PickStdGrossWgt as NVARCHAR)
                     + ', @n_MaxCube: ' + CAST (@n_MaxCube as NVARCHAR)
                     + ', @n_MaxWeight: '+ CAST (@n_MaxWeight as NVARCHAR)
                     + ', @n_QtyCubeExceed:' + + CAST (@n_QtyCubeExceed as NVARCHAR)
                     + ', @@n_QtyWgtExceed:' + + CAST (@n_QtyWgtExceed as NVARCHAR)
                     + ', @n_QtyToReduce:' + + CAST (@n_QtyToReduce as NVARCHAR)
                     + ', @n_Qty ' + CAST (@n_Qty AS NVARCHAR)      
               END

               SET @b_NewCarton = 0
               SET @n_AvailableCube = @n_MaxCube
               SET @n_AvailableWgt  = @n_MaxWeight
               SET @n_QtyToPack = @n_Qty

               IF @n_QtyToReduce > 0 AND @c_CartonOptimizeChk <> '1'
               BEGIN
                  SET @n_QtyToPack = @n_Qty - @n_QtyToReduce
                  SET @n_QtyToReduce = 0
               END 

               SET @n_CartonSeqNo = @n_CartonSeqNo + 1
            END
       
            IF @c_CartonOptimizeChk = '1' 
            BEGIN
               IF @n_QtyToPack = 0        --If New Carton and QtyToPack is 0, Pass Item Qty to Optimizer to check if can fit.
               BEGIN
                  SET @n_QtyToPack = @n_Qty
               END

               SET @n_CartonItem = 0
               
               TRUNCATE TABLE #OptimizeItemToPack;    

               INSERT INTO #OptimizeItemToPack        
               (  Storerkey, SKU, Dim1, Dim2, Dim3, Quantity  )
               SELECT 
                  p.Storerkey
               ,  p.Sku 
               , CONVERT(DECIMAL(10,6), p.[Length]) 
               , CONVERT(DECIMAL(10,6), p.Width) 
               , CONVERT(DECIMAL(10,6), p.Height)
               , Quantity = SUM(p.Qty) / p.PackQtyIndicator 
               FROM #PICKDETAIL_WIP p
               WHERE p.CartonType = @c_CartonType
               AND p.CartonSeqNo  = @n_CartonSeqNo
               AND p.orderkey = @c_Orderkey              
               GROUP BY p.Storerkey
                     ,  p.Sku
                     ,  p.[Length]
                     ,  p.Width 
                     ,  p.Height
                     ,  p.PackQtyIndicator 

               SELECT TOP 1 @n_CartonItem = oitp.ID
               FROM #OptimizeItemToPack AS oitp 
               ORDER BY oitp.ID DESC
               
               SET @b_InsSkuToPack = 1
               IF @n_CartonItem > 0 
               BEGIN
                  IF EXISTS ( SELECT 1  
                              FROM #PICKDETAIL_WIP p
                              WHERE p.CartonType = @c_CartonType
                              AND p.CartonSeqNo  = @n_CartonSeqNo
                              AND p.orderkey = @c_Orderkey 
                              AND p.ItemClass <> @c_ItemClass
                  )
                  BEGIN
                     INSERT INTO #OptimizeItemToPack            
                     (  Storerkey, SKU, Dim1, Dim2, Dim3, Quantity  )
                     SELECT 
                       p.Storerkey
                     , p.Sku 
                     , CONVERT(DECIMAL(10,6), p.Length) 
                     , CONVERT(DECIMAL(10,6), p.Width) 
                     , CONVERT(DECIMAL(10,6), p.Height)
                     , Quantity = @n_QtyToPack / p.PackQtyIndicator 
                     FROM #PICKDETAIL_WIP p
                     WHERE p.orderkey = @c_Orderkey 
                     AND   p.CartonType   = ''
                     AND   p.CartonSeqNo  = ''
                     AND   P.ItemClass = @c_ItemClass
                     AND   p.Busr7 = @c_Busr7             
                     AND   p.LocLevel = @c_LocLevel                           
                     ORDER BY p.RowRef
                     
                     EXEC isp_CartonOptimizeCheck
                       @c_CartonGroup  = @c_CartonGroup
                     , @c_CartonType   = @c_CartonType   
                     , @n_MaxCube      = @n_MaxCube         
                     , @n_MaxWeight    = @n_MaxWeight       
                     , @n_QtyToPack    = @n_QtyToPack       OUTPUT
                     , @b_CheckIfFix   = 1      
                     , @b_Success      = @b_Success         OUTPUT
                     , @n_Err          = @n_Err             OUTPUT
                     , @c_ErrMsg       = @c_ErrMsg          OUTPUT  
                     
                     IF @n_QtyToPack = 0 
                     BEGIN
                        SET @b_NewCarton = 1
                        GOTO NEW_CARTON   
                     END 
                     
                     DELETE FROM #OptimizeItemToPack
                     WHERE ID > @n_CartonItem
                     AND Sku <> @c_Sku
                     
                     SET @b_InsSkuToPack = 0
                  END
               END

               IF @b_InsSkuToPack = 1
               BEGIN
                  INSERT INTO #OptimizeItemToPack            
                     (  Storerkey, SKU, Dim1, Dim2, Dim3, Quantity  )
                  SELECT 
                     p.Storerkey
                  , p.Sku 
                  , CONVERT(DECIMAL(10,6), p.Length) 
                  , CONVERT(DECIMAL(10,6), p.Width) 
                  , CONVERT(DECIMAL(10,6), p.Height)
                  , Quantity = @n_QtyToPack / @n_PackQtyIndicator 
                  FROM #PICKDETAIL_WIP p
                  WHERE P.RowRef = @n_RowRef_Sku
               END 

               IF @b_debug = 1  
               BEGIN  
                  PRINT 'Before @n_QtyToPack: ' +  cast(@n_QtyToPack as nvarchar)  
                  + ', @n_Qty: ' + CAST (@n_Qty AS NVARCHAR)
                  + ', @n_MaxCube: ' + CAST(@n_MaxCube AS NVARCHAR)
                  + ', @n_MaxWeight: ' + CAST(@n_MaxWeight AS NVARCHAR)

                  SELECT * from #OptimizeItemToPack        
               END  

               SET @c_NewCartonType = @c_CartonType
               EXEC isp_CartonOptimizeCheck
                    @c_CartonGroup  = @c_CartonGroup
                  , @c_CartonType   = @c_NewCartonType   OUTPUT
                  , @n_MaxCube      = @n_MaxCube         OUTPUT
                  , @n_MaxWeight    = @n_MaxWeight       OUTPUT
                  , @n_QtyToPack    = @n_QtyToPack       OUTPUT
                  , @b_Success      = @b_Success         OUTPUT
                  , @n_Err          = @n_Err             OUTPUT
                  , @c_ErrMsg       = @c_ErrMsg          OUTPUT
          
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_err = 83020  
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_CartonOptimizeCheck. (ispRLWAV52_PACK)'   
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '   
                  GOTO QUIT_SP  
               END
               
               IF @b_debug = 1
               BEGIN
                   PRINT 'After @n_QtyToPack: ' +  cast(@n_QtyToPack as nvarchar)  
                    + ', @n_CartonItem: ' +  cast(@n_CartonItem as nvarchar) 
                    + ', @c_CartonType: ' + @c_CartonType 
                    + ', @c_NewCartonType: ' + @c_NewCartonType
                    + ', @n_MaxCube: ' + CAST(@n_MaxCube AS NVARCHAR)
                    + ', @n_MaxWeight: ' + CAST(@n_MaxWeight AS NVARCHAR)
               END
               
               IF @n_QtyToPack = 0 AND @n_CartonItem > 0 --1) Open a another new carton for current item if current item fit in. 
               BEGIN                                     --2) IF current item is put to new carton, remain putting to this new carton if cannot fit
                  SET @b_NewCarton = 1
                  GOTO NEW_CARTON
               END
               
               -- Pack to Current Carton, total qty = 12, pack qty = 8, remain qty = 4, pack 8 to current box
               -- Pack to Current Carton, total qty = 12, pack qty = 1, remain qty = 11, close current box and pack 12 to new box
               -- Pack to Current Carton, total qty = 12, pack qty = 11,remain qty = 1,  close current box and pack 12 to new box
               IF @n_CartonItem > 0 AND @n_PickedQty > 0 AND @n_Qty > @n_QtyToPack AND                                                                   --2021-08-11
                 ((@n_Qty - @n_QtyToPack)/@n_PackQtyIndicator <= @n_PickedQty OR (@n_QtyToPack/@n_PackQtyIndicator) <= @n_PickedQty)                     --2021-08-11
               BEGIN                                      
                  SET @b_NewCarton = 1  
                  GOTO NEW_CARTON  
               END  
               
               IF @c_CartonType <> @c_NewCartonType  -- Change to Biger Carton
               BEGIN
                  UPDATE #PICKDETAIL_WIP 
                     SET CartonType= @c_NewCartonType
                        ,CartonCube= @n_MaxCube          
                  WHERE CartonType = @c_CartonType
                  AND CartonSeqNo  = @n_CartonSeqNo

                  SET @c_CartonType = @c_NewCartonType   

                  IF @b_debug = 1                         
                  BEGIN 
                     SELECT CartonType, CartonCube, * from #PICKDETAIL_WIP
                     WHERE CartonSeqNo = @n_CartonSeqNo 
                  END  
               END
            END  
            
            IF @n_QtyToPack = 0     --If 0 qty can fit, at least put 1 even system calculate pick item cube < Large Carton Cube
            BEGIN
               SET @n_QtyToPack = 1 * @n_PackQtyIndicator
            END


            SET @n_RowRef_PD = 0
            SET @n_QtyToPack_REM = @n_QtyToPack
            SET @n_QtyToPack_TTL = @n_QtyToPack
            WHILE 1 = 1 AND @n_QtyToPack_REM > 0
            BEGIN
               SET @n_Status = 0  
               SET @b_SplitPickdetail = 0  
               
               SELECT TOP 1 @n_RowRef_PD = pw.RowRef
                     ,@n_Qty_PD = pw.Qty
               FROM #PICKDETAIL_WIP AS pw
               WHERE pw.RowRef <> @n_RowRef_PD
               AND pw.Storerkey = @c_Storerkey
               AND   pw.Sku = @c_Sku
               AND   pw.CartonType = ''
               AND   pw.LocLevel = @c_LocLevel      
               AND   pw.Orderkey = @c_Orderkey                    
               ORDER BY pw.Qty DESC
                      , pw.RowRef
               
               IF @@ROWCOUNT = 0 
               BEGIN
                  BREAK
               END
   
               IF @n_Qty_PD > @n_QtyToPack_REM AND @n_QtyToPack_REM > 0   
               BEGIN  
                  SET @n_QtyToPack = @n_QtyToPack_REM
                  
                  SET @b_SplitPickdetail = 1  
                 
                  INSERT INTO #PICKDETAIL_WIP      
                     (    
                        Wavekey  
                     ,  Loadkey  
                     ,  Orderkey  
                     ,  [Route]  
                     ,  ExternOrderkey  
                     ,  Busr7  
                     ,  PickDetailKey  
                     ,  Storerkey  
                     ,  Sku  
                     ,  UOM  
                     ,  UOMQty  
                     ,  Qty  
                     ,  PickStdCube  
                     ,  PickStdGrossWgt  
                     ,  StdCube  
                     ,  StdGrossWgt  
                     ,  SkuStdCube        
                     ,  SkuStdGrossWgt    
                     ,  [Length]          
                     ,  Width             
                     ,  Height            
                     ,  CubeTolerance     
                     ,  PackQtyIndicator               
                     ,  Lot  
                     ,  ToLoc  
                     ,  DropID  
                     ,  LocLevel  
                     ,  LogicalLocation  
                     ,  [Status]  
                     ,  ItemClass         
                     ,  Size              
                     )  
                  SELECT   
                        Wavekey = @c_Wavekey  
                     ,  PD.Loadkey  
                     ,  @c_Orderkey  
                     ,  PD.[Route]  
                     ,  PD.ExternOrderkey  
                     ,  Busr7 = @c_Busr7  
                     ,  PD.PickDetailkey  
                     ,  PD.Storerkey  
                     ,  PD.Sku  
                     ,  PD.UOM  
                     ,  UOMQty = CASE WHEN PD.DropID = '' THEN @n_QtyToPack ELSE PD.UOMQty END                    
                     ,  Qty    = @n_Qty_PD - @n_QtyToPack  
                     ,  PickStdCube    = ((@n_Qty_PD - @n_QtyToPack) / (1.00 * @n_PackQtyIndicator)) * @n_StdCube    
                     ,  PickStdGrosWgt = ((@n_Qty_PD - @n_QtyToPack) / (1.00 * @n_PackQtyIndicator)) * @n_StdGrossWgt
                     ,  StdCube     = @n_StdCube  
                     ,  StdGrossWgt = @n_StdGrossWgt  
                     ,  PD.SkuStdCube          
                     ,  PD.SkuStdGrossWgt                           
                     ,  PD.[Length]            
                     ,  PD.Width               
                     ,  PD.Height              
                     ,  PD.CubeTolerance       
                     ,  @n_PackQtyIndicator  --Bundle Sku should not be splitted, just keep a record for split sku                 
                     ,  PD.Lot  
                     ,  PD.ToLoc  
                     ,  PD.DropID  
                     ,  PD.LocLevel  
                     ,  PD.LogicalLocation  
                     ,  [Status]  = 2  
                     ,  PD.ItemClass              
                     ,  PD.Size                         
                  FROM #PICKDETAIL_WIP PD  
                  WHERE PD.RowRef = @n_RowRef_PD  
  
                  SET @n_Status = 1               
               END  
               ELSE  
               BEGIN 
                  SET @n_QtyToPack_Rem = @n_QtyToPack_Rem - @n_Qty_PD  
                  SET @n_QtyToPack = @n_Qty_PD   
               END  
  
               IF @b_debug = 1  
               BEGIN  
                  PRINT 'sku: ' + @c_Sku
                     + ', @n_RowRef_PD:' + CAST (@n_RowRef_PD as NVARCHAR)  
                     + ',@n_QtyToPack: ' + CAST (@n_QtyToPack as NVARCHAR)  
                     + ', @n_PackedCube: '+ CAST (@n_PackedCube as NVARCHAR)  
                     + ', @n_PackedWgt: '+ CAST (@n_PackedWgt as NVARCHAR)  
                     + ', @n_MaxCube: ' + CAST (@n_MaxCube as NVARCHAR)  
                     + ', @n_MaxWeight: '+ CAST (@n_MaxWeight as NVARCHAR)  

                  PRINT '@c_CartonType: ' + @c_CartonType  
                     + ', @c_LocLevel: '+ @c_LocLevel  
                     + ', @n_CartonSeqNo: ' + CAST (@n_CartonSeqNo AS NVARCHAR) 
               END  
              
               UPDATE #PICKDETAIL_WIP  
               Set  CartonType     = @c_CartonType  
                  , CartonSeqNo    = @n_CartonSeqNo  
                  , CartonCube     = @n_MaxCube  
                  , UOMQty         = CASE WHEN DropID = '' THEN @n_QtyToPack ELSE UOMQty END  
                  , Qty            = @n_QtyToPack  
                  , PickStdCube    = (@n_QtyToPack / (1.00 * @n_PackQtyIndicator)) * StdCube             
                  , PickStdGrossWgt= (@n_QtyToPack / (1.00 * @n_PackQtyIndicator)) * StdGrossWgt           
                  , [Status]       = CASE WHEN [Status] = 0 THEN @n_Status ELSE [Status] END  
               WHERE RowRef        = @n_RowRef_PD  
            
               IF @b_SplitPickdetail = 1 
               BEGIN 
                  BREAK
               END 
               SET @n_QtyToPack_TTL = @n_QtyToPack_TTL + @n_QtyToPack
            END
         
            SET @n_PackedCube= @n_PackedCube + (@n_StdCube * (@n_QtyToPack / (1.00 * @n_PackQtyIndicator)))            
            SET @n_PackedWgt = @n_PackedWgt  + (@n_StdGrossWgt * ( @n_QtyToPack / (1.00 * @n_PackQtyIndicator)))        
  
            SET @n_AvailableCube = @n_MaxCube - @n_PackedCube  
            SET @n_AvailableWgt  = @n_MaxWeight - @n_PackedWgt  

            NEXT_PD:

            FETCH NEXT FROM @CUR_PD INTO @n_RowRef_Sku  
                                       , @c_Storerkey
                                       , @c_Sku
                                       , @n_PickStdCube
                                       , @n_PickStdGrossWgt
                                       , @n_StdCube
                                       , @n_StdGrossWgt
                                       , @n_Qty
                                       , @c_UOM
                                       , @n_PackQtyIndicator  
 
         END
         CLOSE @CUR_PD
         DEALLOCATE @CUR_PD
      END
      -------------------------------------------
      -- ReCalulate CartonType - START
      --------------------------------------------
      SET @n_CartonSeqNo = 0
      IF @c_CartonOptimizeChk = '1'   
      BEGIN
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1
                   @n_TotalPickCube = ISNULL(SUM(PD.PickStdCube),0.00)  
                  ,@n_TotalPickWgt  = ISNULL(SUM(PD.PickStdGrossWgt),0.00)
                  ,@c_CartonType =  PD.CartonType
                  ,@n_CartonSeqNo= PD.CartonSeqNo
            FROM #PICKDETAIL_WIP PD  
            WHERE PD.Orderkey = @c_Orderkey  
            AND   PD.CartonType <> ''
            AND   PD.CartonSeqNo > @n_CartonSeqNo  
            AND   PD.UOM IN ('6', '7') 
            GROUP BY PD.CartonType
                     ,PD.CartonSeqNo
             ORDER BY PD.CartonSeqNo
        
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END    
               
            SET @c_NewCartonType = ''
            SELECT TOP 1 @c_NewCartonType = CG.CartonType  
                     ,@n_MaxCube    = CG.[Cube]  
                     ,@n_MaxWeight  = CG.MaxWeight  
            FROM #NikeCTNGroup CG  
            WHERE [Cube]  >= @n_TotalPickCube  
            AND MaxWeight >= @n_TotalPickWgt  
            ORDER BY RowRef
                  
            IF @c_NewCartonType = ''  
            BEGIN
               SET @c_NewCartonType = @c_CartonType
            END
                  
            IF @c_CartonType <> @c_NewCartonType
            BEGIN
               TRUNCATE TABLE #OptimizeItemToPack;              
                     
               INSERT INTO #OptimizeItemToPack                   
               (  Storerkey, SKU, Dim1, Dim2, Dim3, Quantity  )  
               SELECT   
                  p.Storerkey  
               ,  p.Sku   
               , CONVERT(DECIMAL(10,6), p.[Length])   
               , CONVERT(DECIMAL(10,6), p.Width)   
               , CONVERT(DECIMAL(10,6), p.Height)  
               , Quantity = SUM(p.Qty) / p.PackQtyIndicator 
               FROM #PICKDETAIL_WIP p  
               WHERE p.CartonType = @c_CartonType              
               AND p.CartonSeqNo  = @n_CartonSeqNo             
               AND p.orderkey = @c_Orderkey             
               GROUP BY p.Storerkey  
                     ,  p.Sku  
                     ,  p.[Length]  
                     ,  p.Width   
                     ,  p.Height
                     , p.PackQtyIndicator                   
                     
               SET @n_Qty_Recalc = 0
               SELECT TOP 1 @n_Qty_Recalc = Quantity
               FROM #OptimizeItemToPack                     
               ORDER BY ID DESC        
                     
               IF @b_debug = 1    
               BEGIN    
                  PRINT 'Recalculate @c_cartonType: ' +  @c_CartonType   
                  + ', @n_CartonSeqNo: ' + CAST (@n_CartonSeqNo AS NVARCHAR)  
                  + ', @c_NewCartonType: ' + @c_NewCartonType
                  + ', @c_Orderkey: ' + @c_Orderkey 
                        
                  PRINT '@n_TotalPickCube: ' + CAST (@n_TotalPickCube AS NVARCHAR) 
                  + ', @n_TotalPickWgt: ' + CAST (@n_TotalPickWgt AS NVARCHAR)                          
                  + ', @n_MaxLength: ' + CAST (@n_MaxLength AS NVARCHAR) 
                  + ', @n_MaxWidth: ' + CAST (@n_MaxWidth AS NVARCHAR)   
                  + ', @n_MaxHeight: ' + CAST (@n_MaxHeight AS NVARCHAR) 
               END    
             
               EXEC isp_CartonOptimizeCheck  
                     @c_CartonGroup  = @c_CartonGroup  
                  , @c_CartonType   = @c_NewCartonType   OUTPUT  
                  , @n_MaxCube      = @n_MaxCube         OUTPUT  
                  , @n_MaxWeight    = @n_MaxWeight       OUTPUT  
                  , @n_QtyToPack    = @n_Qty_Recalc      OUTPUT 
                  , @b_Success      = @b_Success         OUTPUT  
                  , @n_Err          = @n_Err             OUTPUT  
                  , @c_ErrMsg       = @c_ErrMsg          OUTPUT  
            
               IF @b_Success = 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @n_err = 83030     
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_CartonOptimizeCheck. (ispRLWAV52_PACK)'     
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '     
                  GOTO QUIT_SP    
               END  
                     
               IF @c_CartonType <> @c_NewCartonType AND @n_Qty_Recalc > 0           -- Not to change Cartontype if @n_Qty_Recalc return does not fit to new cartontype.  
               BEGIN
                  UPDATE PD  
                     SET CartonType = @c_NewCartonType  
                        ,CartonCube = @n_MaxCube   
                  FROM #PICKDETAIL_WIP PD  
                  WHERE PD.Orderkey = @c_Orderkey  
                  AND   PD.CartonType = @c_CartonType  
                  AND   PD.CartonSeqNo= @n_CartonSeqNo  
               END
            END  
         END
      END
      --------------------------------------------
      -- Re-Calulate CartonType - END
      -------------------------------------------- 
      
      IF @b_debug = 1
      BEGIN
         SELECT pw.CartonSeqNo,pw.CartonType,pw.sku,pw.* FROM #PICKDETAIL_WIP AS pw
      END
      --------------------------------------------
      -- UOM IN ('6','7') 
      --------------------------------------------
      
      ------------------------------------------
      --- Create PACK  - START
      ------------------------------------------
      SET @c_PickSlipNo = ''
      SELECT @c_PickSlipNo = PH.PickHeaderKey
      FROM PICKHEADER PH WITH (NOLOCK)
      WHERE PH.Orderkey = @c_Orderkey
      AND   PH.ExternOrderkey = @c_Loadkey
      AND   PH.[Zone] = '3'

      IF @c_PickSlipNo = ''
      BEGIN
         SET @b_success = 1  
         EXECUTE nspg_getkey  
               'PickSlip'  
               , 9  
               , @c_PickSlipNo   OUTPUT  
               , @b_success      OUTPUT  
               , @n_err          OUTPUT  
               , @c_errmsg       OUTPUT
                 
         IF NOT @b_success = 1  
         BEGIN  
            SET @n_continue = 3
            GOTO QUIT_SP  
         END  
 
         SET @c_Pickslipno = 'P' + @c_Pickslipno

         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Wavekey, Storerkey) 
         VALUES (@c_Pickslipno , @c_LoadKey, @c_Orderkey, '0', '3', @c_Loadkey, @c_Wavekey, @c_Storerkey)       
               
         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 83040
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (ispRLWAV52_PACK)' 
            GOTO QUIT_SP
         END   

         INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
         VALUES (@c_Pickslipno , NULL, NULL, NULL) 

         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 83050 
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed. (ispRLWAV52_PACK)' 
            GOTO QUIT_SP
         END   
      END

      --Re-Cartonization Again If Packdetail exists
      ---------------------------------------------------
      -- Delete PackDetail
      ---------------------------------------------------
      SET @CUR_DELPCK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PCK.CartonNo
      FROM PACKDETAIL PCK WITH (NOLOCK)
      WHERE PCK.PickSlipNo = @c_PickSlipNo
      ORDER BY PCK.PickSlipNo
            ,  PCK.CartonNo

      OPEN @CUR_DELPCK

      FETCH NEXT FROM @CUR_DELPCK INTO @n_CartonNo

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DELETE PACKDETAIL 
         WHERE PickSlipNo = @c_PickSlipNo
         AND   CartonNo   = @n_CartonNo

         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 83060
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL Failed. (ispRLWAV52_PACK)' 
            GOTO QUIT_SP
         END  

         FETCH NEXT FROM @CUR_DELPCK INTO @n_CartonNo
      END
      CLOSE @CUR_DELPCK
      DEALLOCATE @CUR_DELPCK 


      IF NOT EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
         INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, Consigneekey, [Route], OrderRefNo )  
         VALUES (@c_Pickslipno , @c_Storerkey, @c_Orderkey, @c_Loadkey, @c_Consigneekey, @c_Route, @c_ExternOrderkey)    

         SET @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 83070
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER Failed. (ispRLWAV52_PACK)' 
            GOTO QUIT_SP
         END         
      END

      -------------------------------------------------------
      -- Gen Label#,Stamp CaseID and Split PickDetail - START
      -------------------------------------------------------
      SET @n_CartonSeqNo_Prev = 0
      SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRef = ISNULL(PD.RowRef,0)    
            ,P.PickDetailKey
            ,P.UOM           
            ,P.DropID        
            ,Qty = ISNULL(PD.Qty,0)
            ,CartonSeqNo = ISNULL(PD.CartonSeqNo,0)
            ,[Status] = ISNULL(PD.[Status],'0')
      FROM PICKDETAIL P WITH  (NOLOCK) 
      LEFT OUTER JOIN #PICKDETAIL_WIP PD ON  P.Orderkey = PD.Orderkey
                                         AND P.DropID   = PD.DropID
                                         AND P.PickDetailKey = PD.Pickdetailkey
      WHERE P.Orderkey = @c_Orderkey
      AND   P.UOM = '2'
      UNION ALL                              
      SELECT PD.RowRef
            ,PD.PickDetailKey
            ,PD.UOM           
            ,PD.DropID        
            ,PD.Qty
            ,PD.CartonSeqNo
            ,PD.[Status]
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      AND   PD.UOM IN ('6','7') 
      AND   PD.CartonType <> ''
      ORDER BY CartonSeqNo
            ,  PickDetailKey
            ,  RowRef

      OPEN @CUR_PD
   
      FETCH NEXT FROM @CUR_PD INTO @n_RowRef
                                ,  @c_PickDetailKey
                                ,  @c_UOM          
                                ,  @c_DropID       
                                ,  @n_Qty
                                ,  @n_CartonSeqNo
                                ,  @n_Status

                                
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_UOM = '2'   
         BEGIN
            SET @c_LabelNo = @c_DropID
         END 
         ELSE
         BEGIN
            IF @n_CartonSeqNo_Prev <> @n_CartonSeqNo
            BEGIN
               SET @c_LabelNo = ''
               EXEC isp_GenUCCLabelNo_Std    
                     @cPickslipNo   = @c_PickSlipNo  
                  ,  @nCartonNo     = 0  
                  ,  @cLabelNo      = @c_LabelNo   OUTPUT  
                  ,  @b_success     = @b_success   OUTPUT  
                  ,  @n_err         = @n_err       OUTPUT  
                  ,  @c_errmsg      = @c_errmsg    OUTPUT  
  
               IF @b_Success <> 1  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_err = 83080   
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_GenUCCLabelNo_Std. (ispRLWAV52_PACK)'   
                               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
                  GOTO QUIT_SP 
               END  
            END
         END   
         
         IF @n_Status = 2
         BEGIN
            SET @b_success = 1  
            EXECUTE nspg_getkey  
                  'Pickdetailkey'  
                  , 10  
                  , @c_NewPickDetailKey   OUTPUT  
                  , @b_success            OUTPUT  
                  , @n_err                OUTPUT  
                  , @c_errmsg             OUTPUT
                 
            IF NOT @b_success = 1  
            BEGIN  
               SET @n_continue = 3
               GOTO QUIT_SP  
            END  

            INSERT INTO PICKDETAIL 
                  (  PickDetailKey
                  ,  CaseID
                  ,  PickHeaderKey
                  ,  OrderKey
                  ,  OrderLineNumber
                  ,  Lot
                  ,  Storerkey
                  ,  Sku
                  ,  AltSku
                  ,  UOM
                  ,  UOMQty
                  ,  Qty
                  ,  QtyMoved
                  ,  [Status]
                  ,  DropID
                  ,  Loc
                  ,  ID
                  ,  PackKey
                  ,  UpdateSource
                  ,  CartonGroup
                  ,  CartonType
                  ,  ToLoc
                  ,  DoReplenish
                  ,  ReplenishZone
                  ,  DoCartonize
                  ,  PickMethod
                  ,  WaveKey
                  ,  EffectiveDate
                  ,  OptimizeCop
                  ,  ShipFlag
                  ,  PickSlipNo
                  ,  Taskdetailkey
                  ,  TaskManagerReasonkey
                  ,  Notes 
                  )
            SELECT @c_NewPickDetailKey
                 , @c_LabelNo
                 , PD.PickHeaderKey
                 , PD.OrderKey
                 , PD.OrderLineNumber
                 , PD.Lot
                 , PD.Storerkey
                 , PD.Sku
                 , PD.AltSku
                 , PD.UOM
                 , @n_Qty
                 , @n_Qty
                 , PD.QtyMoved
                 , PD.[Status]
                 , PD.DropID
                 , PD.Loc
                 , PD.ID
                 , PD.PackKey
                 , PD.UpdateSource
                 , PD.CartonGroup
                 , PD.CartonType
                 , PD.ToLoc
                 , PD.DoReplenish
                 , PD.ReplenishZone
                 , PD.DoCartonize
                 , PD.PickMethod
                 , PD.WaveKey
                 , PD.EffectiveDate
                 , '9'
                 , PD.ShipFlag
                 , @c_PickSlipNo 
                 , PD.Taskdetailkey
                 , PD.TaskManagerReasonkey
                 , @c_PickDetailKey + ', Originalqty = ' + CAST(PD.UOMQty AS VARCHAR)      
            FROM PICKDETAIL PD WITH (NOLOCK) 
            WHERE PD.PickDetailKey = @c_PickDetailKey

            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN
               SET @n_continue = 3  
               SET @n_Err = 83090 
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKDETAIL Failed. (ispRLWAV52_PACK)' 
               GOTO QUIT_SP
            END 
         END
         ELSE
         BEGIN
            UPDATE PICKDETAIL
               SET CaseID = @c_LabelNo
                  ,Qty = CASE WHEN @n_Status = 0 THEN Qty ELSE @n_Qty END
                  ,PickSlipNo = @c_PickSlipNo
                  ,Trafficcop = NULL
                  ,EditWho    = SUSER_SNAME()
                  ,EditDate   = GETDATE()
            WHERE PickDetailKey = @c_PickDetailkey

            SET @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN
               SET @n_continue = 3  
               SET @n_Err = 83100
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed. (ispRLWAV52_PACK)' 
               GOTO QUIT_SP
            END 
         END

         IF @n_RowRef > 0  
         BEGIN 
            Update #PICKDETAIL_WIP
            SET CaseID = @c_labelNo
               ,PickSlipNo = @c_PickSlipNo
            WHERE RowRef = @n_RowRef
         END              

         SET @n_CartonSeqNo_Prev = @n_CartonSeqNo
         FETCH NEXT FROM @CUR_PD INTO @n_RowRef
                                    , @c_PickDetailKey
                                    , @c_UOM          
                                    , @c_DropID       
                                    , @n_Qty
                                    , @n_CartonSeqNo
                                    , @n_Status
      END
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD
      -----------------------------------------------------
      -- Gen Label#,Stamp CaseID and Split PickDetail - END
      -----------------------------------------------------
      
      IF @b_debug = 1
      BEGIN
         SELECT @c_Orderkey '@c_Orderkey', * from #PICKDETAIL_WIP 
         where orderkey = @c_Orderkey
         ORDER BY orderkey, busr7, loclevel, logicallocation,CartonSeqNo, sku

               SELECT @c_PickSlipNo
            ,CartonNo = PD.CartonSeqNo 
            ,[Weight] = ISNULL(SUM(PD.StdGrossWgt * PD.Qty),0.00)
            ,[Cube]   = PD.CartonCube                              
            ,Qty = ISNULL(SUM(PD.Qty),0)
            ,PD.CartonType
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      GROUP BY PD.CartonSeqNo
            ,  PD.CartonType
            ,  PD.CartonCube                                      
            
         SELECT @c_PickSlipNo
               ,CartonNo = PD.CartonSeqNo --+ @n_CartonNo
               ,PD.Caseid
               ,LabelLine = RIGHT('00000' + CONVERT(NVARCHAR(5), ROW_NUMBER() OVER (PARTITION BY PD.Caseid ORDER BY PD.CartonSeqNo, PD.Storerkey, PD.Sku)),5)
               ,PD.Storerkey
               ,PD.Sku
               ,Qty = ISNULL(SUM(Qty),0)
         FROM #PICKDETAIL_WIP PD
         WHERE PD.Orderkey = @c_Orderkey
         GROUP BY PD.CartonSeqNo
               ,  PD.CaseID
               ,  PD.Storerkey
               ,  PD.Sku
               
               
         SELECT @c_PickSlipNo
               ,CartonNo = PD.CartonSeqNo 
               ,PD.Caseid
               ,PD.Storerkey
               ,PD.Sku
               ,PD.Qty
               ,ItemClass, SIZE
               , Cartontype,cartonseqno
               , status
         FROM #PICKDETAIL_WIP PD
         WHERE PD.Orderkey = @c_Orderkey  
         ORDER BY CartonSeqNo    
      END
                      
      INSERT INTO PACKDETAIL
         (  PickSlipNo
         ,  CartonNo
         ,  LabelNo
         ,  LabelLine
         ,  Storerkey
         ,  Sku
         ,  Qty
         )
      SELECT @c_PickSlipNo
            ,CartonNo = PD.CartonSeqNo 
            ,PD.Caseid
            ,LabelLine = RIGHT('00000' + CONVERT(NVARCHAR(5), ROW_NUMBER() OVER (PARTITION BY PD.Caseid ORDER BY PD.CartonSeqNo, PD.Storerkey, PD.Sku)),5)
            ,PD.Storerkey
            ,PD.Sku
            ,Qty = ISNULL(SUM(Qty),0)
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      GROUP BY PD.CartonSeqNo
            ,  PD.CaseID
            ,  PD.Storerkey
            ,  PD.Sku

      SET @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 83110
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKDETAIL Failed. (ispRLWAV52_PACK)' 
         GOTO QUIT_SP
      END 

      INSERT INTO PACKINFO
         (  PickSlipNo
         ,  CartonNo
         ,  [Weight]
         ,  [Cube]
         ,  Qty
         ,  CartonType
         )
      SELECT @c_PickSlipNo
            ,CartonNo = PD.CartonSeqNo 
            ,[Weight] = ISNULL(SUM(PD.StdGrossWgt * PD.Qty),0.00)
            ,[Cube]   = PD.CartonCube                            
            ,Qty = ISNULL(SUM(PD.Qty),0)
            ,PD.CartonType
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      GROUP BY PD.CartonSeqNo
            ,  PD.CartonType
            ,  PD.CartonCube                                     
 
      SET @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 83120
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKINFO Failed. (ispRLWAV52_PACK)' 
         GOTO QUIT_SP
      END 

      ------------------------------------------
      --- Create PACK  - END
      ------------------------------------------

      FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey
                                 ,  @c_Loadkey
                                 ,  @c_Route
                                 ,  @c_ExternOrderkey
   END
   CLOSE @CUR_ORD
   DEALLOCATE @CUR_ORD  

QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV52_PACK'
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