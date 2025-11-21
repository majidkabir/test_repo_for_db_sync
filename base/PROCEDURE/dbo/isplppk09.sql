SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispLPPK09                                               */
/* Creation Date: 2021-03-25                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-16585 - [CN] 511_WMS_Cartonization_CR                   */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-03-25  Wan      1.0   Created                                   */
/* 2021-11-25  WLChooi  1.1   DevOps Combine Script                     */
/* 2021-11-25  WLChooi  1.1   WMS-18445 Add Cartonization.CartonWeight  */
/*                            when calculating Packinfo.Weight (WL01)   */
/************************************************************************/
CREATE PROC [dbo].[ispLPPK09]
           @cLoadkey       NVARCHAR(10)
         , @bSuccess       INT            = 1   OUTPUT
         , @nErr           INT            = 0   OUTPUT
         , @cErrMsg        NVARCHAR(255)  = ''  OUTPUT
         , @n_debug        INT            = 0 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT         = @@TRANCOUNT
         , @n_Continue           INT         = 1
         
         , @b_Success            INT            = @bSuccess
         , @n_Err                INT            = @nErr
         , @c_ErrMsg             NVARCHAR(255)  = @cErrMsg

         , @c_PackLabelToOrd     NVARCHAR(10)   = ''
         , @c_RCMLOADLOG         NVARCHAR(30)   = ''           --2021-06-22 CR1.5
         , @c_WSCRPCKFED         NVARCHAR(30)   = ''
         , @c_TableName          NVARCHAR(30)   = 'WSCRPCKFED'
         
         , @n_RowRef             INT         = 0

         , @c_Facility           NVARCHAR(5) = ''  --QHW51
         , @c_Loadkey            NVARCHAR(10)= @cLoadkey
         , @c_Orderkey           NVARCHAR(10)= ''
         , @c_SkuGroup           NVARCHAR(10)= ''
         , @c_Userdefine01_LP    NVARCHAR(20)= ''              --2021-06-22 CR1.5

         , @n_TotalPickCube      FLOAT       = 0.00
         , @n_SumUnpackCube      FLOAT       = 0.00
         , @n_CartonCube         FLOAT       = 0.00
         , @n_CartonMix          INT         = 0
         , @n_MixSkuGroup        INT         = 0

         , @n_SkuGroupDiff_Cnt   INT         = 0
         , @n_Item_Cnt           INT         = 0

         , @n_CartonSeqNo        INT         = 0
         , @c_CartonGroup        NVARCHAR(10)= ''
         , @c_CartonType         NVARCHAR(10)= ''
         
         , @n_AvailableCube      FLOAT       = 0.00

         , @c_PickDetailKey      NVARCHAR(10)= ''
         , @c_Storerkey          NVARCHAR(15)= '' --18555
         , @c_Sku                NVARCHAR(20)= ''
         , @c_UOM                NVARCHAR(10)= ''
         , @n_PickStdCube        FLOAT       = 0.00
         , @n_StdCube            FLOAT       = 0.00
         , @n_Qty                INT         = 0
         , @c_Status             NVARCHAR(2) = '0' --0:Original, S:Split, N:New
         
         , @n_MaxLength          FLOAT       = 0.00
         , @n_MaxWidth           FLOAT       = 0.00
         , @n_MaxHeight          FLOAT       = 0.00

         --, @c_LogicalLocation    NVARCHAR(10)= ''

         , @n_CartonNo           INT         = 0
         , @c_PickSlipNo         NVARCHAR(10)= ''
         , @c_CartonNo           NVARCHAR(10)= ''
         , @c_LabelNo            NVARCHAR(20)= ''
         , @c_NewPickDetailKey   NVARCHAR(10)= '' 
         
         , @CUR_ORD              CURSOR
         , @CUR_PD               CURSOR

         , @n_CartonWgt          FLOAT       = 0.00   --WL01

   SET @n_Err      = 0
   SET @c_ErrMsg   = ''
  
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP','U') IS NULL
   BEGIN
      CREATE TABLE #PICKDETAIL_WIP  
      (  RowRef            INT          IDENTITY(1,1)     PRIMARY KEY
      ,  Loadkey           NVARCHAR(10) DEFAULT('')
      ,  Orderkey          NVARCHAR(10) DEFAULT('')
      ,  Pickdetailkey     NVARCHAR(10) DEFAULT('')   
      ,  SkuGroup          NVARCHAR(30) DEFAULT('')      --FW, Apparel
      ,  Storerkey         NVARCHAR(15) DEFAULT('')
      ,  Sku               NVARCHAR(20) DEFAULT('')
      ,  Qty               INT          DEFAULT(0)
      ,  PickStdCube       FLOAT        DEFAULT(0.00)
      ,  PickStdGrossWgt   FLOAT        DEFAULT(0.00)      
      ,  StdCube           FLOAT        DEFAULT(0.00)
      ,  StdGrossWgt       FLOAT        DEFAULT(0.00)  
      ,  Logicallocation   NVARCHAR(10) DEFAULT('')
      ,  PickSlipNo        NVARCHAR(10) DEFAULT('')
      ,  CartonType        NVARCHAR(10) DEFAULT('')
      ,  CaseID            NVARCHAR(20) DEFAULT('')
      ,  CartonSeqNo       INT          DEFAULT(0)
      ,  CartonCube        FLOAT        DEFAULT(0.00)
      ,  [Status]          NVARCHAR(2)  DEFAULT('0')
      ,  CartonWeight     FLOAT         DEFAULT(0.00)   --WL01
      )
   END

   IF OBJECT_ID('tempdb..#CTNGroup','U') IS NULL
   BEGIN
       CREATE TABLE #CTNGroup
         (  RowRef               INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  CartonizationGroup   NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  CartonType           NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  [Cube]               FLOAT          NOT NULL DEFAULT (0.00)
         ,  MaxWeight            FLOAT          NOT NULL DEFAULT (0.00)
         ,  SkuGroup             NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  MixSkuGroup          INT            NOT NULL DEFAULT(0)
         ,  CartonWeight         FLOAT          NOT NULL DEFAULT (0.00)   --WL01
         )
   END
   
   IF OBJECT_ID('tempdb..#PackToCarton','U') IS NULL
   BEGIN
       CREATE TABLE #PackToCarton 
         (  RowRef               INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  CartonType           NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  CartonCube           FLOAT          NOT NULL DEFAULT (0.00)
         ,  CartonMix            INT            NOT NULL DEFAULT (0)
         ,  RowRef_PD            INT            NOT NULL DEFAULT (0)
         ,  PickdetailKey        NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  Qty                  INT            NOT NULL DEFAULT (0)        
         ,  StdCube              FLOAT          NOT NULL DEFAULT (0.00)
         ,  SkuGroup             NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  AccumulatedCube      FLOAT          NOT NULL DEFAULT (0.00)
         ,  AvailableCube        FLOAT          NOT NULL DEFAULT (0.00)
         ,  CubeNeed             FLOAT          NOT NULL DEFAULT (0.00)
         ,  SplitQty             INT            NOT NULL DEFAULT (0)         
         ,  SplitPick            INT            NOT NULL DEFAULT (0)
         ,  CartonWeight         FLOAT          NOT NULL DEFAULT (0.00)   --WL01
         )
   END
   
   SELECT @c_CartonGroup = ISNULL(f.UserDefine20,'')
         ,@c_Facility    = LP.facility
         ,@c_Userdefine01_LP = ISNULL(LP.UserDefine01,'')
   FROM LOADPLAN LP WITH (NOLOCK)
   JOIN FACILITY AS f WITH (NOLOCK) ON LP.facility = f.Facility
   WHERE LP.LoadKey = @c_Loadkey

   IF @c_CartonGroup = ''
   BEGIN
      SET @n_continue = 3  
      SET @n_Err = 82010
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Blank Carton Group Found. (ispLPPK09)' 
      GOTO QUIT_SP
   END 

   --BEGIN TRAN
   INSERT INTO #PICKDETAIL_WIP  
         (  
            Loadkey           
         ,  Orderkey          
         ,  Pickdetailkey     
         ,  SkuGroup          
         ,  Storerkey         
         ,  Sku               
         ,  Qty               
         ,  StdCube 
         ,  StdGrossWgt          
         )
      SELECT  
           OH.Loadkey  
         , PD.Orderkey  
         , PD.PickDetailKey
         , SkuGroup = CASE WHEN CL.Code IS NULL THEN 'NONFW' ELSE 'FW' END
         , PD.Storerkey  
         , PD.Sku  
         , PD.Qty
         , SKU.StdCube 
         , SKU.StdGrossWgt
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)  
   JOIN PICKDETAIL PD WITH (NOLOCK) ON LPD.Orderkey = PD.Orderkey  
   JOIN ORDERS     OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey  
   JOIN SKU SKU WITH (NOLOCK) ON  PD.Storerkey = SKU.Storerkey  
                              AND PD.Sku = SKU.Sku  
   JOIN LOC L WITH (NOLOCK) ON  PD.Loc = L.Loc 
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  CL.ListName = '511FW'
                                       AND CL.Code = SKU.Skugroup
                                       AND CL.Storerkey = PD.Storerkey
   WHERE LPD.Loadkey = @c_Loadkey
   AND   PD.[Status] <= '3'
   AND   PD.Qty > 0
   ORDER BY PD.OrderKey
         ,  CL.ListName DESC
         ,  CL.Code
         ,  PD.Sku
         ,  L.LogicalLocation
         ,  PD.PickDetailKey
            
   IF EXISTS (SELECT 1 FROM #PICKDETAIL_WIP AS pw WITH (NOLOCK) WHERE StdCube = 0.00)
   BEGIN
      SET @n_continue = 3  
      SET @n_Err = 82020
      SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': 0 StdCube Found. (ispLPPK09)' 
      GOTO QUIT_SP      
   END

   SELECT TOP 1 @c_Storerkey = PD.Storerkey
   FROM #PICKDETAIL_WIP PD
   
   EXEC nspGetRight   
      @c_Facility = @c_facility          
   ,  @c_Storerkey= @c_storerkey         
   ,  @c_Sku = NULL                      
   ,  @c_ConfigKey= 'AssignPackLabelToOrdCfg'       
   ,  @b_success  = @b_success         OUTPUT   
   ,  @c_authority= @c_PackLabelToOrd  OUTPUT   
   ,  @n_err      = @n_err             OUTPUT   
   ,  @c_errmsg   = @c_errmsg          OUTPUT  
  
   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 82030   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight - AssignPackLabelToOrdCfg. (ispLPPK09)'   
                     + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP 
   END   

   --2021-06-22 v1.5 CR
   IF EXISTS (SELECT 1 FROM dbo.CODELKUP AS c WITH (NOLOCK) 
              WHERE c.ListName = 'LF2BJ' AND c.Storerkey = @c_Storerkey
              AND c.code2 = @c_Userdefine01_LP
             )
   BEGIN 
      EXEC nspGetRight   
         @c_Facility = @c_facility          
      ,  @c_Storerkey= @c_storerkey         
      ,  @c_Sku = NULL                      
      ,  @c_ConfigKey= 'RCMLOADLOG'       
      ,  @b_success  = @b_success         OUTPUT   
      ,  @c_authority= @c_RCMLOADLOG      OUTPUT   
      ,  @n_err      = @n_err             OUTPUT   
      ,  @c_errmsg   = @c_errmsg          OUTPUT  
  
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 82040   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight - RCMLOADLOG. (ispLPPK09)'   
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT_SP 
      END  
      SET @c_TableName = 'RCMLOADLOG' 
   END
   ELSE
   BEGIN
      EXEC nspGetRight   
         @c_Facility = @c_facility          
      ,  @c_Storerkey= @c_storerkey         
      ,  @c_Sku = NULL                      
      ,  @c_ConfigKey= 'WSCRPCKFED'       
      ,  @b_success  = @b_success         OUTPUT   
      ,  @c_authority= @c_WSCRPCKFED      OUTPUT   
      ,  @n_err      = @n_err             OUTPUT   
      ,  @c_errmsg   = @c_errmsg          OUTPUT  
  
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3  
         SET @n_err = 82050   
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight - WSCRPCKFED. (ispLPPK09)'   
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT_SP 
      END 
      SET @c_TableName = 'WSCRPCKFED'
   END
   
   INSERT INTO #CTNGroup
      (     CartonizationGroup  
         ,  CartonType          
         ,  [Cube]              
         ,  MaxWeight           
         ,  SkuGroup            
         ,  MixSkuGroup        
         ,  CartonWeight   --WL01   
      )
   SELECT CartonizationGroup  
      ,  CartonType          
      ,  [Cube]              
      ,  MaxWeight 
      ,  'FW'
      ,  MixSkuGroup = CASE WHEN ROW_NUMBER() OVER (ORDER BY [Cube] DESC) >= 2 THEN 1 ELSE 0 END
      ,  ISNULL(CZ.CartonWeight, 0.00)   --WL01
   FROM CARTONIZATION CZ WITH (NOLOCK)
   WHERE CZ.CartonizationGroup = @c_CartonGroup
   ORDER BY CZ.[Cube] DESC
   
   INSERT INTO #CTNGroup
      (     CartonizationGroup  
         ,  CartonType          
         ,  [Cube]              
         ,  MaxWeight           
         ,  SkuGroup            
         ,  MixSkuGroup
         ,  CartonWeight   --WL01
      )
   SELECT CartonizationGroup  
      ,  CartonType          
      ,  [Cube]              
      ,  MaxWeight 
      ,  'NONFW'
      ,  1
      ,  CartonWeight   --WL01
   FROM #CTNGroup CZ WITH (NOLOCK)
   WHERE CZ.RowRef > 1


   SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT  PD.Orderkey
   FROM #PICKDETAIL_WIP PD
   GROUP BY PD.Orderkey
   ORDER BY PD.Orderkey
          
   OPEN @CUR_ORD
   
   FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @n_debug = 1
      BEGIN
         PRINT '@c_Orderkey: ' + @c_Orderkey
      END
    
      SET @n_CartonSeqNo = 0
      ------------------------------------------
      -- Assign Item To Carton Type - START
      ------------------------------------------
      WHILE 1 = 1
      BEGIN   
         IF @n_debug = 1
         BEGIN
            SELECT PD.CartonType, PD.CartonCube, PD.*
            FROM #PICKDETAIL_WIP PD
            WHERE PD.Orderkey = @c_Orderkey
            AND   PD.CartonType = ''

            
            SELECT TOP 1
                 PD.SkuGroup
               , SumUnpackCube = SUM(PD.StdCube * pd.Qty) OVER (ORDER BY PD.RowRef DESC) 
            FROM #PICKDETAIL_WIP PD
            WHERE PD.Orderkey = @c_Orderkey
            AND   PD.CartonType = ''
            ORDER BY PD.RowRef
         END 
                      
         SET @n_SumUnpackCube = 0    
         SET @c_SkuGroup = ''    
         SELECT TOP 1
                 @c_SkuGroup = PD.SkuGroup
               , @n_SumUnpackCube = SUM(PD.StdCube * pd.Qty) OVER (ORDER BY PD.RowRef DESC) 
         FROM #PICKDETAIL_WIP PD
         WHERE PD.Orderkey = @c_Orderkey
         AND   PD.CartonType = ''
         ORDER BY PD.RowRef
         
         IF @@ROWCOUNT = 0 OR @c_SkuGroup = ''
         BEGIN
            BREAK
         END

         TRUNCATE TABLE #PackToCarton; 
         SET @n_CartonSeqNo = @n_CartonSeqNo + 1
         
         IF @n_debug = 1
         BEGIN
            PRINT '@n_CartonSeqNo: ' + CAST(@n_CartonSeqNo AS NVARCHAR)
            SELECT @n_CartonSeqNo '@n_CartonSeqNo' 
         END 

         SELECT @n_SkuGroupDiff_Cnt = COUNT(DISTINCT PD.SkuGroup)
         FROM #PICKDETAIL_WIP PD
         WHERE PD.Orderkey = @c_Orderkey
         AND   PD.CartonType = ''

         SET @n_MixSkuGroup = 0
         
         GET_CTNTYPE:
         SELECT TOP 1 
                @c_Cartontype = cg.CartonType
               ,@n_CartonCube = cg.[Cube]
               ,@n_CartonMix  = cg.MixSkuGroup
               ,@n_CartonWgt  = cg.CartonWeight   --WL01
         FROM #CTNGroup AS cg WITH (NOLOCK) 
         WHERE cg.SkuGroup = @c_SkuGroup
         AND cg.MixSkuGroup IN (1, @n_MixSkuGroup)
         ORDER BY CASE WHEN cg.[Cube] >= @n_SumUnpackCube THEN 0 ELSE 1 END
                 ,CASE WHEN cg.[Cube] >= @n_SumUnpackCube THEN cg.[Cube] - @n_SumUnpackCube ELSE @n_SumUnpackCube - cg.[Cube] END 
         
         -- Check Large Carton able to pack all and have different Sku group, if not, use large else get another cartontype
         IF @n_CartonCube > @n_SumUnpackCube AND @n_SkuGroupDiff_Cnt > 1 AND @n_CartonMix = 0
         BEGIN
            SET @n_MixSkuGroup = 1
            GOTO GET_CTNTYPE
         END

         IF @n_debug = 1
         BEGIN
            PRINT '@n_MixSkuGroup: ' + CAST(@n_MixSkuGroup AS NVARCHAR) 
            SELECT @n_MixSkuGroup '@n_MixSkuGroup' , @n_SumUnpackCube '@n_SumUnpackCube', @c_SkuGroup '@c_SkuGroup'
                  ,@n_CartonCube '@n_CartonCube', @n_CartonWgt '@n_CartonWgt'   --WL01
            
               SELECT 
                      cg.CartonType
                     ,cg.[Cube]
                     ,cg.MixSkuGroup
                     ,cg.SkuGroup
                     ,cg.CartonWeight   --WL01
               FROM #CTNGroup AS cg WITH (NOLOCK) 
               WHERE cg.SkuGroup = @c_SkuGroup
               --AND cg.[Cube] <= @n_SumUnpackCube
               AND cg.MixSkuGroup IN (1, @n_MixSkuGroup)
               ORDER BY CASE WHEN cg.[Cube] >= @n_SumUnpackCube THEN 0 ELSE 1 END
                       ,CASE WHEN cg.[Cube] >= @n_SumUnpackCube THEN cg.[Cube] - @n_SumUnpackCube ELSE @n_SumUnpackCube - cg.[Cube] END   
                       
               SELECT RowNum = ROW_NUMBER() OVER (ORDER BY PD.SkuGroup, PD.Sku, PD.RowRef)
                     ,RowRef_PD = PD.RowRef
                     ,PD.Pickdetailkey
                     ,PD.StdCube
                     ,PD.Qty
                     ,AccumulatedCube = sum(PD.StdCube * pd.Qty) OVER (ORDER BY PD.SkuGroup, PD.Sku, PD.RowRef) 
                     ,PD.SkuGroup
               FROM #PICKDETAIL_WIP PD
               WHERE PD.Orderkey = @c_Orderkey
               AND   PD.CartonType = ''               
         END 
         
         INSERT INTO #PackToCarton 
               ( CartonType
               , CartonCube
               , CartonMix
               , RowRef_PD
               , PickdetailKey
               , Qty
               , StdCube
               , SkuGroup
               , AccumulatedCube
               , AvailableCube
               , CubeNeed
               , SplitQty
               , SplitPick
               , CartonWeight   --WL01
               )
         SELECT CartonType = @c_CartonType
               ,CartonCube = @n_CartonCube
               ,CartonMix  = @n_CartonMix
               ,t.RowRef_PD
               ,t.Pickdetailkey
               ,t.Qty
               ,t.StdCube               
               ,t.SkuGroup
               ,t.AccumulatedCube
               ,AvailableCube = LAG(@n_CartonCube - t.AccumulatedCube, 1, @n_CartonCube) --First Reccord default carton Cube
                                OVER (ORDER BY t.AccumulatedCube) 
               ,CubeNeed  = CASE WHEN t.AccumulatedCube <= @n_CartonCube THEN t.Qty * t.StdCube 
                                 --WHEN t.StdCube > t.AccumulatedCube - @n_CartonCube THEN t.StdCube
                                 ELSE FLOOR((@n_CartonCube - (t.AccumulatedCube - ( t.Qty * t.StdCube)) )/t.StdCube) * t.StdCube END
               ,SplitQty  = CASE WHEN t.AccumulatedCube <= @n_CartonCube THEN 0 
                                 --WHEN t.StdCube > t.AccumulatedCube - @n_CartonCube THEN 1
                                 --ELSE t.Qty - FLOOR((t.AccumulatedCube - @n_CartonCube)/t.StdCube) END
                                 ELSE t.Qty - FLOOR((@n_CartonCube - (t.AccumulatedCube - ( t.Qty * t.StdCube)) )/t.StdCube) END
               ,SplitPick = CASE WHEN t.AccumulatedCube <= @n_CartonCube THEN 0 
                                 --WHEN t.StdCube > t.AccumulatedCube - @n_CartonCube THEN 1
                                 ELSE 1 END
               ,CartonWeight = @n_CartonWgt   --WL01
         FROM 
         (
               SELECT RowNum = ROW_NUMBER() OVER (ORDER BY PD.SkuGroup, PD.Sku, PD.RowRef)
                     ,RowRef_PD = PD.RowRef
                     ,PD.Pickdetailkey
                     ,PD.StdCube
                     ,PD.Qty
                     ,AccumulatedCube = sum(PD.StdCube * pd.Qty) OVER (ORDER BY PD.SkuGroup, PD.Sku, PD.RowRef) 
                     ,PD.SkuGroup
               FROM #PICKDETAIL_WIP PD
               WHERE PD.Orderkey = @c_Orderkey
               AND   PD.CartonType = ''
         ) AS t
         WHERE @n_CartonCube - (t.AccumulatedCube - ( t.Qty * t.StdCube ) ) >= t.StdCube
         ORDER BY t.RowNum
         
         IF @n_debug = 1
         BEGIN
            SELECT 1,* FROM #PackToCarton
         END
         
         --Get SkuGroup and total item in the carton
         SELECT @n_SkuGroupDiff_Cnt = COUNT(DISTINCT PTC.SkuGroup)
               ,@n_Item_Cnt = COUNT(1)
         FROM #PackToCarton PTC
         WHERE PTC.CartonType = @c_CartonType
         AND PTC.CartonMix    = @n_CartonMix
         AND PTC.AvailableCube> 0
         AND PTC.CubeNeed > 0
         
         IF @n_SkuGroupDiff_Cnt > 1 AND @n_CartonMix = 0  -- Large But Have Mix
         BEGIN
            SET @n_MixSkuGroup = 1                        -- Get Mix CartonType
            GOTO GET_CTNTYPE
         END

         IF @n_debug = 1
         BEGIN
             SELECT @n_Item_Cnt '@n_Item_Cnt', @c_CartonType  '@c_CartonType', @c_SkuGroup '@c_SkuGroup', @n_SkuGroupDiff_Cnt '@n_SkuGroupDiff_Cnt'
            ,@n_CartonSeqNo '@n_CartonSeqNo'
            
            SELECT COUNT(1) FROM #PackToCarton PTC        
            WHERE PTC.CartonMix    = 0
                        AND PTC.AvailableCube> 0
                        AND PTC.CubeNeed     > 0
                        AND PTC.SkuGroup     = @c_SkuGroup
                        GROUP BY PTC.CartonType
         END
                       
         IF @n_CartonMix = 1 AND @n_SkuGroupDiff_Cnt = 1
         BEGIN
            --Get Large Carton contains 1 FW
            --Get Mix Carton cantains 1 FW
            --If Large Carton fit more item then use large else use mix carton
            --If Both same item, mean last carton, use small carton (mix carton)
            SELECT @n_CartonMix = 0                -- Use Large Carton
                  ,@c_CartonType = PTC.CartonType
            FROM #PackToCarton PTC        
            WHERE PTC.CartonMix  = 0
            AND PTC.AvailableCube> 0
            AND PTC.CubeNeed     > 0
            AND PTC.SkuGroup     = @c_SkuGroup
            GROUP BY PTC.CartonType
            HAVING COUNT(1) > @n_Item_Cnt
            
            IF @n_CartonMix = 0
            BEGIN
               IF @n_debug = 1
               BEGIN
                  PRINT 'Use Large Instead.'
               END

               DELETE #PackToCarton             
               WHERE CartonMix  = 0
               AND   SkuGroup   NOT IN ( @c_SkuGroup )
            END
         END
         ----------------------------------------
         -- Split Pick - START
         ----------------------------------------
         INSERT INTO #PICKDETAIL_WIP 
            (  Loadkey
            ,  Orderkey
            ,  PickDetailKey
            ,  SkuGroup
            ,  Storerkey
            ,  Sku
            ,  Qty
            ,  PickStdCube
            ,  PickStdGrossWgt
            ,  StdCube
            ,  StdGrossWgt
            ,  Logicallocation
            ,  CartonType
            ,  CartonCube
            ,  CartonSeqNo
            ,  [Status])
         SELECT 
               p.Loadkey
            ,  p.Orderkey
            ,  p.PickDetailKey
            ,  p.SkuGroup
            ,  p.Storerkey
            ,  p.Sku
            ,  PTC.SplitQty
            ,  PickStdCube = PTC.SplitQty * p.StdCube
            ,  PickStdGrossWgt = PTC.SplitQty * p.StdGrossWgt            
            ,  p.StdCube
            ,  p.StdGrossWgt
            ,  p.Logicallocation
            ,  ''
            ,  0.00
            ,  0
            ,  [Status] = 'N'
         FROM #PICKDETAIL_WIP p
         JOIN #PackToCarton PTC ON (p.RowRef = ptc.RowRef_PD)
         WHERE PTC.CartonType = @c_CartonType
         AND PTC.CartonMix = @n_CartonMix
         AND PTC.AvailableCube > 0
         AND PTC.CubeNeed > 0
         AND PTC.SplitPick = 1
         ----------------------------------------
         -- Split Pick - END
         ----------------------------------------
         
         UPDATE p 
         SET CartonType = PTC.CartonType
            ,CartonCube = PTC.CartonCube 
            ,CartonSeqNo= @n_CartonSeqNo
            ,Qty        = p.Qty - PTC.SplitQty
            ,PickStdCube=(p.Qty - PTC.SplitQty) * p.StdCube
            ,PickStdGrossWgt=(p.Qty - PTC.SplitQty) * p.StdGrossWgt
            ,[Status]   = CASE WHEN PTC.SplitPick = 1 AND p.[Status] NOT IN ('N') THEN 'S' ELSE p.[Status] END
            ,CartonWeight = PTC.CartonWeight   --WL01
         FROM #PICKDETAIL_WIP p
         JOIN #PackToCarton PTC ON (p.RowRef = ptc.RowRef_PD)
         WHERE PTC.CartonType = @c_CartonType
         AND PTC.CartonMix = @n_CartonMix        
         AND PTC.AvailableCube > 0
         AND PTC.CubeNeed > 0
         
         IF @n_Debug = 1
         BEGIN
            SELECT 3, PD.CartonSeqNo, PD.CartonType,  PD.CartonCube, PD.*
            FROM #PICKDETAIL_WIP PD
            WHERE PD.Orderkey = @c_Orderkey
            AND   PD.CartonType <> ''
            ORDER BY PD.CartonSeqNo, PD.SkuGroup, PD.Sku
         END
      END
      ------------------------------------------
      -- Assign Item To Carton Type - END
      ------------------------------------------

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
         SET @b_Success = 1  
         EXECUTE nspg_getkey  
               'PickSlip'  
               , 9  
               , @c_PickSlipNo   OUTPUT  
               , @b_Success      OUTPUT  
               , @n_Err          OUTPUT  
               , @c_ErrMsg       OUTPUT
                 
         IF NOT @b_Success = 1  
         BEGIN  
            SET @n_continue = 3
            GOTO QUIT_SP  
         END  
 
         SET @c_Pickslipno = 'P' + @c_Pickslipno

         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, Loadkey, Wavekey, Storerkey) 
         VALUES (@c_Pickslipno , @c_Loadkey, @c_Orderkey, '0', '3', @c_Loadkey, '', @c_Storerkey)       
               
         SET @n_Err = @@ERROR  
         IF @n_Err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 82060
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PICKHEADER Failed. (ispLPPK09)' 
            GOTO QUIT_SP
         END   

         INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
         VALUES (@c_Pickslipno , NULL, NULL, NULL) 

         SET @n_Err = @@ERROR  
         IF @n_Err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 82070 
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PICKINGINFO Failed. (ispLPPK09)' 
            GOTO QUIT_SP
         END   
      END

      IF NOT EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
         INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, Consigneekey, [Route], OrderRefNo )  
         SELECT  PickSlipNo = @c_Pickslipno 
               , Storerkey  = @c_Storerkey
               , o.Orderkey
               , Loadkey    = @c_Loadkey
               , o.Consigneekey
               , o.[Route]
               , o.ExternOrderkey
         FROM ORDERS o WITH (NOLOCK)
         WHERE o.Orderkey = @c_Orderkey

         SET @n_Err = @@ERROR  
         IF @n_Err <> 0  
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 82080 
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PACKHEADER Failed. (ispLPPK09)' 
            GOTO QUIT_SP
         END         
      END

      -------------------------------------------------------
      -- Split PickDetail - START
      -------------------------------------------------------

      SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey
            ,PD.Qty
            ,PD.[Status]
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      AND   PD.CartonType <> ''
      AND   PD.[Status] IN ('S', 'N')
      ORDER BY PickDetailKey

      OPEN @CUR_PD
   
      FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey
                                ,  @n_Qty
                                ,  @c_Status

                                
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         IF @c_Status = 'N'
         BEGIN
            SET @b_Success = 1  
            EXECUTE nspg_getkey  
                  'Pickdetailkey'  
                  , 10  
                  , @c_NewPickDetailKey   OUTPUT  
                  , @b_Success            OUTPUT  
                  , @n_Err                OUTPUT  
                  , @c_ErrMsg             OUTPUT
                 
            IF NOT @b_Success = 1  
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
                 , ''
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
                 , '' 
                 , PD.Taskdetailkey
                 , PD.TaskManagerReasonkey
                 , Notes = 'Split From: ' + PD.PickDetailKey
            FROM PICKDETAIL PD WITH (NOLOCK) 
            WHERE PD.PickDetailKey = @c_PickDetailKey

            SET @n_Err = @@ERROR  
            IF @n_Err <> 0  
            BEGIN
               SET @n_continue = 3  
               SET @n_Err = 82090 
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PICKDETAIL Failed. (ispLPPK09)' 
               GOTO QUIT_SP
            END 
         END
         ELSE IF @c_Status = 'S'
         BEGIN
            UPDATE PICKDETAIL
               SET Notes = 'Originalqty: ' + CONVERT(NVARCHAR(10), Qty)
                  , Qty = @n_Qty
                  ,Trafficcop = NULL
                  ,EditWho    = SUSER_SNAME()
                  ,EditDate   = GETDATE()
            WHERE PickDetailKey = @c_PickDetailkey

            SET @n_Err = @@ERROR  
            
            IF @n_Err <> 0  
            BEGIN
               SET @n_continue = 3  
               SET @n_Err = 82100 
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update PICKDETAIL Failed. (ispLPPK09)' 
               GOTO QUIT_SP
            END 
         END

         FETCH NEXT FROM @CUR_PD INTO @c_PickDetailKey
                                    , @n_Qty
                                    , @c_Status
      END
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD

      -------------------------------------------------------
      -- Gen Label#,Stamp CaseID - START
      -------------------------------------------------------
      SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.CartonSeqNo
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      AND   PD.CartonType <> ''
      AND   PD.CaseID = ''
      GROUP BY PD.CartonSeqNo
      ORDER BY PD.CartonSeqNo

      OPEN @CUR_PD
   
      FETCH NEXT FROM @CUR_PD INTO @n_CartonSeqNo
                                
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      
         SET @c_LabelNo = ''
         EXEC isp_GenUCCLabelNo_Std    
               @cPickslipNo   = @c_PickSlipNo  
            ,  @nCartonNo     = 0  
            ,  @cLabelNo      = @c_LabelNo   OUTPUT  
            ,  @b_Success     = @b_Success   OUTPUT  
            ,  @n_Err         = @n_Err       OUTPUT  
            ,  @c_ErrMsg      = @c_ErrMsg    OUTPUT  
  
         IF @b_Success <> 1  
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 82110   
            SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Error Executing isp_GenUCCLabelNo_Std. (ispLPPK09)'   
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '   
            GOTO QUIT_SP 
         END  
            
         UPDATE #PICKDETAIL_WIP
         SET CaseID = @c_LabelNo
         WHERE Orderkey = @c_Orderkey
         AND CartonSeqNo = @n_CartonSeqNo
            
         FETCH NEXT FROM @CUR_PD INTO @n_CartonSeqNo

      END
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD
      
      -------------------------------------------------------
      -- Gen Label#,Stamp CaseID - END
      -------------------------------------------------------
 
      IF @n_debug = 1
      BEGIN
         SELECT @c_Orderkey '@c_Orderkey', * from #PICKDETAIL_WIP 
         where orderkey = @c_Orderkey
         ORDER BY orderkey, skugroup, sku, logicallocation,CartonSeqNo

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

      SET @n_Err = @@ERROR  
      IF @n_Err <> 0  
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 82120 
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PACKDETAIL Failed. (ispLPPK09)' 
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
            ,[Weight] = ISNULL(SUM(PD.StdGrossWgt * PD.Qty),0.00) + ISNULL(PD.CartonWeight,0.00)   --WL01
            ,[Cube]   = PD.CartonCube                             
            ,Qty = ISNULL(SUM(PD.Qty),0)
            ,PD.CartonType
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      GROUP BY PD.CartonSeqNo
            ,  PD.CartonType
            ,  PD.CartonCube             
            ,  ISNULL(PD.CartonWeight,0.00)   --WL01                        
 
      SET @n_Err = @@ERROR  
      IF @n_Err <> 0  
      BEGIN
         SET @n_continue = 3  
         SET @n_Err = 82130 
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert PACKINFO Failed. (ispLPPK09)' 
         GOTO QUIT_SP
      END 

      ------------------------------------------
      --- Create PACK  - END
      ------------------------------------------
      
      ----------------------------------------------
      --- Assign Label to PickDetail CaseID  - START
      ----------------------------------------------
      IF @c_PackLabelToOrd = '1'  
      BEGIN  
         EXEC isp_AssignPackLabelToOrderByLoad  
               @c_PickSlipNo= @c_PickSlipNo  
            ,  @b_Success   = @b_Success  OUTPUT  
            ,  @n_Err       = @n_Err      OUTPUT  
            ,  @c_ErrMsg    = @c_ErrMsg   OUTPUT  
  
         IF @b_Success <> 1  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_Err = 82140  
            SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'    
                           + 'Error Executing isp_AssignPackLabelToOrderByLoad.(ispLPPK09)'  
            GOTO QUIT_SP  
         END  
      END  
      ----------------------------------------------
      --- Assign Label to PickDetail CaseID  - END
      ----------------------------------------------
      
      --2021-07-07 CR1.7 - Remove Auto Pack Confirm- START
      ----------------------------------------------
      --- Auto Pack Confirm  - START
      ----------------------------------------------
      --UPDATE dbo.PackHeader
      --   SET STATUS = '9'
      --      ,EditWho = SUSER_SNAME()
      --      ,EditDate= GETDATE()
      --WHERE PickSlipNo = @c_PickSlipNo
      ----------------------------------------------
      --- Auto Pack Confirm  - END
      ----------------------------------------------  
      --2021-07-07 CR1.7 - Remove Auto Pack Confirm- END
      
      ----------------------------------------
      -- Send EDI to Fedex - START
      ----------------------------------------
      IF @c_WSCRPCKFED = '1'  
      BEGIN  
         SET @n_CartonNo = 0
         
         WHILE 1=1
         BEGIN
            SELECT TOP 1 @n_CartonNo = PIF.CartonNo
            FROM PACKINFO PIF WITH (NOLOCK)
            WHERE PIF.PickSlipNo = @c_PickSlipNo
            AND PIF.CartonNo > @n_CartonNo
            ORDER BY PIF.CartonNo
      
            IF @n_CartonNo = 0 OR @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            SET @c_CartonNo = CAST(@n_CartonNo AS NVARCHAR)
            EXEC dbo.ispGenTransmitLog2
                 @c_TableName    = @c_TableName
               , @c_Key1         = @c_PickSlipNo
               , @c_Key2         = @c_CartonNo
               , @c_Key3         = @c_StorerKey
               , @c_TransmitBatch=  ''  
               , @b_success      = @b_success   OUTPUT  
               , @n_err          = @n_err       OUTPUT  
               , @c_errmsg       = @c_errmsg    OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SET @n_continue = 3 
               SET @n_Err = 82150  
               SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'    
                           + 'Error Executing ispGenTransmitLog2.(ispLPPK09)'   
               GOTO QUIT_SP
            END  
         END
      END  
      ----------------------------------------
      -- Send EDI to Fedex - END
      ----------------------------------------
      FETCH NEXT FROM @CUR_ORD INTO @c_Orderkey
   END
   CLOSE @CUR_ORD
   DEALLOCATE @CUR_ORD  
   
   ----------------------------------------
   -- Send Load Interface - START
   ----------------------------------------
   --2021-06-22 v1.5 CR
   IF @c_RCMLOADLOG = '1'
   BEGIN
      EXEC dbo.ispGenTransmitLog3
           @c_TableName   = @c_TableName
         , @c_Key1         = @c_Loadkey
         , @c_Key2         = @c_Facility
         , @c_Key3         = @c_StorerKey
         , @c_TransmitBatch=  ''  
         , @b_success      = @b_success   OUTPUT  
         , @n_err          = @n_err       OUTPUT  
         , @c_errmsg       = @c_errmsg    OUTPUT  
  
      IF @b_success <> 1  
      BEGIN  
         SET @n_continue = 3 
         SET @n_Err = 82160  
         SET @c_ErrMsg = 'NSQL' +  CONVERT(CHAR(5),@n_Err)  + ':'    
                     + 'Error Executing ispGenTransmitLog2.(ispLPPK09)'   
         GOTO QUIT_SP
      END  
   END
   ----------------------------------------
   -- Send Load Interface - END
   ----------------------------------------

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

      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispLPPK09'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   SET @bSuccess = @b_Success
   SET @nErr     = @n_Err
   SET @cErrMsg  = @c_ErrMsg
END -- procedure

GO