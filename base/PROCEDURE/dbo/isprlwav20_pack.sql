SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispRLWAV20_PACK                                         */
/* Creation Date: 2020-03-20                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-12136 - NIKE - PH Cartonization                         */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-09-14  Wan      1.0   FBR Version 3.0                           */
/* 2020-09-24  Wan01    1.1   Fixed Not to split If qtytopack = 0       */
/* 2020-09-25  Wan01    1.1   Start Labelline '00001' for each carton   */
/* 2020-09-26  Wan01    1.1   Fixed to get from Task.LogicaltoLoc due to*/
/*                            Share UCC. RPF Move UCC->inLoc->RPF.Toloc */
/*                            RDT Updates inLoc to RPF.Toloc &          */
/*                            Pickdetail.loc                            */
/* 2020-10-01  Wan01    1.1   Fixed. Group UOM=2 > Pickdetail line      */
/*                            Update Pickdetail.Caseid for Dropid       */
/* 2020-09-23  Wan02    1.2   Sku Bundle CR                             */
/* 2020-09-04  Wan03    1.2   FBR Version 4.2 - Optimization            */
/* 2020-11-18  Wan03    1.2   Get per piece LWH for bundle item         */
/* 2020-11-27  Wan04    1.3   Fixed                                     */
/* 2021-04-27  Wan05    1.4   WMS-16805-NIKE-PH Cartonization Enhancement*/
/*             Wan06          Standardize #OptimizeItemToPack Temp Table*/
/*                            use at isp_SubmitToCartonizeAPI           */
/* 2021-09-27  Wan06    1.4   DevOps Combine Script                     */
/* 2021-11-29  Wan07    1.5   Fixed. Getting other orderkey to split issue*/
/* 2021-12-14  Wan08    1.6   Fixed. Initialize CarotNo for new pickslip*/
/* 2022-01-03  Wan09    1.7   Fixed. infinity Loop casuse group by UOM  */
/* 2022-03-18  Wan10    1.8   JSM-57583 - Tune performance by subtracting*/
/*                            largest possible Qty to reduce API load   */
/* 2022-07-29  BeeTin   1.9   JSM-76147 -excess qty w/multi sku in      */      
/*                            one carton  1 DN                          */  
/************************************************************************/   
CREATE PROC [dbo].[ispRLWAV20_PACK]
           @c_Wavekey            NVARCHAR(10)
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
         , @n_debug              INT            = 0
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
         , @b_InsSkuToPack       INT         = 0      --CR1.8

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
         , @n_ItemClass_Cube     FLOAT       = 0.00      --CR1.8
         , @n_ItemClass_Wgt      FLOAT       = 0.00      --CR1.8

         , @n_QtyCubeExceed      INT         = 0         --2020-08-22
         , @n_QtyWgtExceed       INT         = 0         --2020-08-22
         , @n_QtyToReduce        INT         = 0         --2020-08-22
         , @n_QtyToPack          INT         = 0
         , @n_Qty_Recalc         INT         = 0         --2021-07-13
         , @n_Qty_PD             INT         = 0         --2021-07-13
         , @n_QtyToPack_REM      INT         = 0         --2021-07-13
         , @n_QtyToPack_TTL      INT         = 0         --2021-07-13

         , @c_PickDetailKey      NVARCHAR(10)= ''
         , @c_Storerkey          NVARCHAR(15)= ''
         , @c_Sku                NVARCHAR(20)= ''
         , @c_UOM                NVARCHAR(10)= ''
         , @c_DropID             NVARCHAR(20)= ''     --2020-08-10
         , @n_PickStdCube        FLOAT       = 0.00
         , @n_PickStdGrossWgt    FLOAT       = 0.00
         , @n_StdCube            FLOAT       = 0.00
         , @n_StdGrossWgt        FLOAT       = 0.00
         , @n_PackQtyIndicator   INT         = 0      --(Wan02)
         , @n_QtyToPackBundle    INT         = 0      --(Wan02)
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

         , @n_CartonItem         INT         = 0  --(Wan03) 2020-09-04
         , @c_Facility           NVARCHAR(5) = '' --(Wan03) 2020-09-04
         , @c_NewCartonType      NVARCHAR(10)= '' --(Wan03) 2020-09-04
         , @c_CartonOptimizeChk  NVARCHAR(30)= '' --(Wan03) 2020-09-04

         , @n_AccessQty          INT         = 0  --(Wan05)
         , @n_PickedQty          INT         = 0  --(Wan05)
         , @c_ItemClass          NVARCHAR(10)= '' --(Wan05)
         , @c_Size               NVARCHAR(10)= '' --(Wan05)

         , @CUR_ORD              CURSOR
         , @CUR_PD               CURSOR
         , @CUR_DELPCK           CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP','U') IS NULL
   BEGIN
      CREATE TABLE #PICKDETAIL_WIP
      (  RowRef            INT         IDENTITY(1,1)     PRIMARY KEY
      ,  Wavekey           NVARCHAR(10) DEFAULT('')
      ,  Loadkey    NVARCHAR(10) DEFAULT('')
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
      ,  SkuStdCube        FLOAT        DEFAULT(0.00)    --2020-08-27
      ,  SkuStdGrossWgt    FLOAT        DEFAULT(0.00)    --2020-11-27
      ,  CubeTolerance     FLOAT        DEFAULT(0.00)    --2020-08-27
      ,  [Length]          FLOAT        DEFAULT(0.00)    --2020-08-07
      ,  Width             FLOAT        DEFAULT(0.00)    --2020-08-07
      ,  Height            FLOAT        DEFAULT(0.00)    --2020-08-07
      ,  PackQtyIndicator  INT          DEFAULT(0)       --(Wan02)
      ,  DropID            NVARCHAR(20) DEFAULT('')
      ,  LocLevel          NVARCHAR(10) DEFAULT('')
      ,  Logicallocation   NVARCHAR(10) DEFAULT('')
      ,  PickSlipNo        NVARCHAR(10) DEFAULT('')
      ,  CartonType        NVARCHAR(10) DEFAULT('')
      ,  CaseID            NVARCHAR(20) DEFAULT('')
      ,  CartonSeqNo       INT          DEFAULT(0)
      ,  CartonCube        FLOAT        DEFAULT(0.00)
      ,  [Status]          INT          DEFAULT(0)
      ,  ItemClass         NVARCHAR(10) DEFAULT('')      --(Wan05)
      ,  Size              NVARCHAR(10) DEFAULT('')      --(Wan05)
      )
   END

   IF OBJECT_ID('tempdb..#NikeCTNGroup','U') IS NULL
   BEGIN
       CREATE TABLE #NikeCTNGroup
         (  RowRef               INT            IDENTITY(1,1) PRIMARY KEY
         ,  CartonizationGroup   NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  CartonType           NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  [Cube]               FLOAT          NOT NULL DEFAULT (0.00)
         ,  MaxWeight            FLOAT          NOT NULL DEFAULT (0.00)
         ,  CartonLength         FLOAT          NOT NULL DEFAULT (0.00) --2020-08-07
         ,  CartonWidth          FLOAT          NOT NULL DEFAULT (0.00) --2020-08-07
         ,  CartonHeight         FLOAT          NOT NULL DEFAULT (0.00) --2020-08-07
         )
   END
   --(Wan03) 2020-09-04 - START
   --IF OBJECT_ID('tempdb..#t_ItemPack','U') IS NULL
   --BEGIN
   --   CREATE TABLE #t_ItemPack
   --      (
   --         ID          INT         IDENTITY(0,1)
   --      ,  Storerkey   NVARCHAR(15)
   --      ,  SKU         NVARCHAR(20)
   --      ,  Dim1        DECIMAL(10,6)
   --      ,  Dim2        DECIMAL(10,6)
   --      ,  Dim3        DECIMAL(10,6)
   --      ,  Quantity    INT
   --      )
   --END
   --(Wan03) 2020-09-04 - END

   IF OBJECT_ID('tempdb..#OptimizeItemToPack','U') IS NULL     --(Wan06)
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

   --(Wan03) 2020-09-04
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
      SET @n_err = 82005
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ispRLWAV20_PACK)'
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      GOTO QUIT_SP
   END
   --(Wan03) 2020-09-04 - END

   -- (Wan01) - 2020-10-01 - SPLIT SELECT FOR UOM = '2'
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
      ,  SkuStdGrossWgt             --2020-11-27
      ,  CubeTolerance
      ,  [Length]
      ,  [Width]
      ,  [Height]
      ,  PackQtyIndicator           --(Wan02)
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
         , SkuStdGrossWgt = SKU.StdGrossWgt                 --2020-11-27
         , CubeTolerance = CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END
         , [Length]= ISNULL(SKU.[Length],0.00)
         , Width   = ISNULL(SKU.Width,0.00)
         , Height  = ISNULL(SKU.Height,0.00)
         , PackQtyIndicator = ISNULL(SKU.PackQtyIndicator,1)   --(Wan02)
         , PD.DropID
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
   JOIN ORDERS     OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN SKU SKU WITH (NOLOCK) ON  PD.Storerkey = SKU.Storerkey
                              AND PD.Sku = SKU.Sku
   LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON  PD.DropID = TD.CaseID
                                         AND TD.TaskType  = 'RPF'
                                         AND TD.Sourcetype IN ( 'ispRLWAV20-INLINE', 'ispRLWAV20-DTC', 'ispRLWAV20-REPLEN' )
   WHERE WD.Wavekey = @c_Wavekey
   AND   PD.UOM = '2'
   AND   PD.Qty > 0                 -- (Wan05)
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
         , ISNULL(SKU.PackQtyIndicator,1)   --(Wan02)
         , PD.DropID
   ORDER BY PD.Orderkey
         ,  MIN(PD.PickDetailKey)
   --(Wan01) 2020-10-01 - END

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
      ,  SkuStdCube     --2020-08-27
      ,  SkuStdGrossWgt --2020-11-27
      ,  CubeTolerance  --2020-08-27
      ,  [Length] --2020-08-07
      ,  [Width]  --2020-08-07
      ,  [Height] --2020-08-07
      ,  PackQtyIndicator  --(Wan02)
      ,  DropID
      ,  ItemClass                  --(Wan05)
      ,  Size                       --(Wan05)
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
         , ToLoc = CASE WHEN TD.TaskDetailKey IS NULL THEN PD.Loc ELSE TD.LogicalToLoc END            --(Wan01)
         , PickStdCube = PD.Qty / (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)   --(Wan02) -- 2020-10-19
                        * (SKU.StdCube + (CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END / 100.00 * SKU.StdCube)) --2020-08-27
         , PickStdWgt  = PD.Qty / (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)   --(Wan02) -- 2020-10-19
                       * SKU.StdGrossWgt
         --(Wan05) - START CR1.8
         --, StdCube = (SKU.StdCube + (CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END / 100.00 * SKU.StdCube))                      --2020-08-27
                     /  (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)                   --2020-08-27
         --, StdWgt  = SKU.StdGrossWgt /  (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)   --2020-08-27
         , StdCube = SKU.StdCube
         , StdWgt  = SKU.StdGrossWgt
         --(Wan05) - END CR1.8
         , SkuStdCube = SKU.StdCube
         , SkuStdGrossWgt = SKU.StdGrossWgt                 --2020-11-27
         , CubeTolerance = CASE WHEN ISNUMERIC(SKU.BUSR5) = 1 THEN SKU.BUSR5 ELSE 0 END  --2020-08-27
         --(Wan05) - START CR1.8
         --, [Length]= ISNULL(SKU.[Length],0.00) / (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)  --(Wan03) 2020-11-18
         --, Width   = ISNULL(SKU.Width,0.00)    / (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)  --(Wan03) 2020-11-18
         --, Height  = ISNULL(SKU.Height,0.00)   / (1.00 * CASE WHEN ISNULL(SKU.PackQtyIndicator,0) <= 1 THEN 1 ELSE ISNULL(SKU.PackQtyIndicator,0) END)  --(Wan03) 2020-11-18
         , [Length]= ISNULL(SKU.[Length],0.00)
         , Width   = ISNULL(SKU.Width,0.00)
         , Height  = ISNULL(SKU.Height,0.00)
         --(Wan05) - END CR1.8
         , PackQtyIndicator = ISNULL(SKU.PackQtyIndicator,1)
         , PD.DropID
         , ItemClass = ISNULL(SKU.ItemClass,'')                --(Wan05)
         , Size = ISNULL(SKU.Size,'')                     --(Wan05)
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
   JOIN ORDERS     OH WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN SKU SKU WITH (NOLOCK) ON  PD.Storerkey = SKU.Storerkey
                              AND PD.Sku = SKU.Sku
   LEFT JOIN TASKDETAIL TD WITH (NOLOCK) ON  PD.DropID = TD.CaseID
                                         AND TD.TaskType  = 'RPF'
                                         AND TD.Sourcetype IN ( 'ispRLWAV20-INLINE', 'ispRLWAV20-DTC', 'ispRLWAV20-REPLEN' )  --(Wan01)
   WHERE WD.Wavekey = @c_WaveKey
   AND   PD.UOM IN ('6', '7')             --(Wan01) 2020-10-01
   AND   PD.Qty > 0                       --(Wan05)   Get Qty > 0 as Floor(qty/PackQtyIndicator) may have 0 and pickqty = 0 tp process loose qty
   ORDER BY PD.Orderkey

   UPDATE #PICKDETAIL_WIP
      SET LocLevel = L.LocLevel
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
      ,  CartonLength                              --2020-08-07
      ,  CartonWidth                               --2020-08-07
      ,  CartonHeight                              --2020-08-07
      )
   SELECT CartonizationGroup
      ,  CartonType
      ,  [Cube]
      ,  MaxWeight
      ,  CartonLength = ISNULL(CartonLength,0.00)  --2020-08-07
      ,  CartonWidth  = ISNULL(CartonWidth,0.00)   --2020-08-07
      ,  CartonHeight = ISNULL(CartonHeight,0.00)  --2020-08-07
   FROM CARTONIZATION CZ WITH (NOLOCK)
   WHERE CZ.CartonizationGroup = @c_CartonGroup
   ORDER BY [Cube]
           ,MaxWeight

   --(Wan05) - START
   SET @n_AccessQty = 0
   SELECT @n_AccessQty = ISNULL(CL.Short,0)
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'NIKPHCZCFG'
   AND CL.Code = 'AccessValue'
   --(Wan05) - END

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
      IF @n_debug = 1
      BEGIN
         PRINT '@c_Orderkey: ' + @c_Orderkey
      END

      SET @n_CartonSeqNo = 0                 --2021-12-14 (Wan08)

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

         IF @n_debug = 1
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
            IF @n_debug = 1
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

      --SET @n_CartonSeqNo = 0
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

            SET @n_PickedQty = 0 --2021-05-25 Fixed. Floor (qty/packqtyindicator) may have 0 qty
            SET @b_NewCarton = 1 --2021-07-13 fixed, New Carton If Change Access Qty
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
               ,UOM = MIN(PD.UOM)                                    --(Wan09)
               ,PD.PackQtyIndicator                                  --(Wan02)
         FROM #PICKDETAIL_WIP PD
         WHERE PD.Orderkey = @c_Orderkey
         AND   PD.UOM IN ('6','7')
         AND   PD.CartonType = ''
         AND   PD.ItemClass = @c_ItemClass                           --(Wan05)
         AND   PD.Size = @c_Size                                     --(Wan05)
         AND   PD.Busr7 = @c_Busr7
         AND   PD.LocLevel = @c_LocLevel
         GROUP BY PD.Storerkey                                       --(Wan05) - Add Grou By And Having
               ,  PD.Sku
               ,  PD.StdCube
               ,  PD.StdGrossWgt
               ,  PD.SkuStdCube
               ,  PD.SkuStdGrossWgt
               ,  PD.CubeTolerance
               --,  PD.UOM                                           --(Wan09)
               ,  PD.PackQtyIndicator
         HAVING SUM(FLOOR(PD.Qty/PD.PackQtyIndicator)) > @n_PickedQty
         ORDER BY SUM(PD.Qty) DESC                                   --(Wan05)
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
                                    , @n_PackQtyIndicator   --(Wan02)

         WHILE @@FETCH_STATUS <> -1 AND @b_SplitPickdetail = 0    --2021-06-10 fixed to process new split record again
         BEGIN
            --(Wan05) - START CR1.8
            IF @n_Qty >= @n_PackQtyIndicator
            BEGIN
               SET @n_Qty = FLOOR(@n_Qty/@n_PackQtyIndicator) * @n_PackQtyIndicator
            END
            --(Wan05) - END CR1.8

            IF @n_debug = 1
            BEGIN
               PRINT '@n_RowRef_Sku: ' + CAST(@n_RowRef_Sku AS NVARCHAR)
                     +', @c_UOM:' +  @c_UOM
                     +', @c_Busr7:' +  @c_Busr7
                     +', @c_LocLevel: ' + @c_LocLevel
            END
            SET @n_Status = 0

            IF @n_debug = 1
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
               --(Wan10) - START
               --IF @c_CartonOptimizeChk = '1'       --(Wan05) - 2021-07-26 Let API to calculate
               --BEGIN
               --   SET @n_QtyToPack = @n_Qty
               --END
               --ELSE           
               --(Wan10) - END
               BEGIN
                  --CR1.8 - START
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
                     AND   p.Busr7 = @c_Busr7            --2021-10-22
                     AND   p.LocLevel = @c_LocLevel      --2021-10-22
                     GROUP BY P.ItemClass

            --IF @n_QtyNeedCube <> @n_ItemClass_Cube OR @n_QtyNeedWgt < @n_ItemClass_Wgt -- New Itemclass cannot fully fit into current box  
                     IF @n_AvailableCube < @n_ItemClass_Cube or @n_AvailableWgt < @n_ItemClass_Wgt  --(JSM-76147) 
                     BEGIN
                        SET @b_NewCarton = 1
                        GOTO NEW_CARTON
                     END
                  END
                  --CR1.8 - END

                  SET @n_QtyNeedCube = FLOOR( @n_AvailableCube / @n_StdCube ) * @n_PackQtyIndicator         --(Wan05)
                  SET @n_QtyNeedWgt  = FLOOR( @n_AvailableWgt / @n_StdGrossWgt ) * @n_PackQtyIndicator      --(Wan05)

                  IF @n_debug = 1
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
                     GOTO NEW_CARTON            --(Wan05)
                  END

                  /* (Wan05) 2021-07-17 - START
                  --(Wan02) - START
                  ELSE IF @n_PackQtyIndicator > 1 AND @n_Qty > @n_QtyToPack
                  BEGIN
                     IF @n_QtyToPack < @n_PackQtyIndicator
                     BEGIN
                        SET @b_NewCarton = 1
                        GOTO NEW_CARTON            --(Wan05)
                     END
                     ELSE
                     BEGIN
                       -- Check Remaining is loose and if bundle + loose able to fit.
                       SET @n_QtyToPackBundle = FLOOR( @n_QtyToPack / @n_PackQtyIndicator * 1.00) * @n_PackQtyIndicator
                       IF @n_Qty - @n_QtyToPackBundle > @n_PackQtyIndicator
                       BEGIN
                          SET @n_QtyToPack = @n_QtyToPackBundle  -- pack bundle qtyp.ItemClass <> @c_ItemClass                       END
                     END
                  END
                  --(Wan02) - END
                  --(Wan05) 2021-07-17 - END  */

                  --(Wan05) - START CR1.3 & 1.4 - 2021-07-01
                  IF @n_PickedQty > 0 AND @n_Qty > @n_QtyToPack AND                                                                    --2021-08-11
                   ((@n_Qty - @n_QtyToPack)/@n_PackQtyIndicator <= @n_PickedQty OR (@n_QtyToPack/@n_PackQtyIndicator) <= @n_PickedQty) --2021-08-11
                  BEGIN
                     SET @b_NewCarton = 1
                     GOTO NEW_CARTON
                  END
                  --(Wan05) - END CR1.3 & 1.4 - 2021-07-01
               END --(Wan05) - 2021-07-26
            END

            NEW_CARTON:

            IF @b_NewCarton = 1
            BEGIN
               SET @n_PackedCube = 0.00
               SET @n_PackEdWgt = 0.00

               SET @n_TotalPickCube = 0.00
               SET @n_TotalPickWgt  = 0.00

               IF @n_PickedQty = 0           --2021-06-17 Fixed. Floor (qty/packqtyindicator) may have 0 qty, hence pickedqty = 0 --(Wan05) - START
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
                  AND   PD.ItemClass = @c_ItemClass         --(Wan05)
                  AND   PD.UOM IN ('6', '7')
                  AND   PD.CartonType = ''
               END   --(Wan05) - END
               --2020-08-07 - START
               SET @n_MaxDimension = @n_MaxLength

               IF @n_MaxLength < @n_MaxWidth
                  SET @n_MaxDimension = @n_MaxWidth

         IF @n_MaxDimension < @n_MaxHeight
                  SET @n_MaxDimension = @n_MaxHeight
               --2020-08-07 - END

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

                  --2020-08-21 - Fixed if the pickdetail pickstdcube and/or @n_PickStdGrossWgt > Carton Maxcube and/or MaxWeight
                  SET @n_QtyCubeExceed = 0
                  SET @n_QtyWgtExceed  = 0

                  IF @n_MaxCube   < @n_PickStdCube
                     SET @n_QtyCubeExceed = CEILING((@n_PickStdCube - @n_MaxCube)/@n_StdCube) * @n_PackQtyIndicator --(Wan05)

                  IF @n_MaxWeight < @n_PickStdGrossWgt
                     SET @n_QtyWgtExceed  = CEILING((@n_PickStdGrossWgt - @n_MaxWeight)/@n_StdGrossWgt) * @n_PackQtyIndicator --(Wan05)


                  IF @n_QtyCubeExceed > @n_QtyWgtExceed
                  BEGIN
                     SET @n_QtyToReduce = @n_QtyCubeExceed
                  END
                  ELSE
                  BEGIN
                     SET @n_QtyToReduce = @n_QtyWgtExceed
                  END
                  --2020-08-21 - Fixed

                  /*(Wan05) 2021-07-17 - START
                  --(Wan02) 2020-11-19 - START
                  IF @n_PackQtyIndicator > 1
                  BEGIN
                     SET @n_QtyToReduce = @n_Qty - (FLOOR((@n_Qty - @n_QtyToReduce) / @n_PackQtyIndicator) * @n_PackQtyIndicator)
                  END
                  --(Wan02) 2020-11-19 - END
                  --(Wan05) 2021-07-17 - END */
               END

               IF @n_debug = 1
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

               IF @n_QtyToReduce > 0 --(Wan10) --AND @c_CartonOptimizeChk <> '1'--2020-08-22 Fixed (Wan05) Only Reduce Qty if not API to calculate  
               BEGIN
                  SET @n_QtyToPack = @n_Qty - @n_QtyToReduce
                  SET @n_QtyToReduce = 0
               END --2020-08-22 Fixed

               SET @n_CartonSeqNo = @n_CartonSeqNo + 1
            END

            IF @c_CartonOptimizeChk = '1' -- (Wan03) 2020-09-04 - START
            BEGIN
       IF @n_QtyToPack = 0        --If New Carton and QtyToPack is 0, Pass Item Qty to Optimizer to check if can fit.
               BEGIN
                  SET @n_QtyToPack = @n_Qty
               END

               SET @n_CartonItem = 0

               TRUNCATE TABLE #OptimizeItemToPack;    --(Wan06)

               INSERT INTO #OptimizeItemToPack        --(Wan06)
               (  Storerkey, SKU, Dim1, Dim2, Dim3, Quantity  )
               SELECT
                  p.Storerkey
               ,  p.Sku
               , CONVERT(DECIMAL(10,6), p.[Length])
               , CONVERT(DECIMAL(10,6), p.Width)
               , CONVERT(DECIMAL(10,6), p.Height)
               , Quantity = SUM(p.Qty) / p.PackQtyIndicator --(Wan06) CR1.8
               FROM #PICKDETAIL_WIP p
               WHERE p.CartonType = @c_CartonType
               AND p.CartonSeqNo  = @n_CartonSeqNo
               AND p.orderkey = @c_Orderkey              --Wan04
               GROUP BY p.Storerkey
                     ,  p.Sku
                     ,  p.[Length]
                     ,  p.Width
                     ,  p.Height
                     ,  p.PackQtyIndicator --(Wan06) CR1.8

               --CR1.8 - START
               --SET @n_CartonItem = @@ROWCOUNT
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
                     AND   p.Busr7 = @c_Busr7            --2021-10-22
                     AND   p.LocLevel = @c_LocLevel      --2021-10-22
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

                     IF @n_QtyToPack = 0 -- Not Fixed
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
                  INSERT INTO #OptimizeItemToPack           --(Wan06)
                     (  Storerkey, SKU, Dim1, Dim2, Dim3, Quantity  )
                  SELECT
                     p.Storerkey
                  , p.Sku
                  , CONVERT(DECIMAL(10,6), p.Length)
                  , CONVERT(DECIMAL(10,6), p.Width)
                  , CONVERT(DECIMAL(10,6), p.Height)
                  , Quantity = @n_QtyToPack / @n_PackQtyIndicator --(Wan06) CR1.8
                  FROM #PICKDETAIL_WIP p
                  WHERE P.RowRef = @n_RowRef_Sku
               END
               --CR1.8 - END

               IF @n_debug = 1
               BEGIN
                  PRINT 'Before @n_QtyToPack: ' +  cast(@n_QtyToPack as nvarchar)
                  + ', @n_Qty: ' + CAST (@n_Qty AS NVARCHAR)
                  + ', @n_MaxCube: ' + CAST(@n_MaxCube AS NVARCHAR)
                  + ', @n_MaxWeight: ' + CAST(@n_MaxWeight AS NVARCHAR)

                  SELECT * from #OptimizeItemToPack         --(Wan06)
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
                  SET @n_err = 82008
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_CartonOptimizeCheck. (ispRLWAV20_PACK)'
                              + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                  GOTO QUIT_SP
               END

               IF @n_debug = 1
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

               --(Wan05) - START CR1.3 & 1.4 2021-07-01
               -- Pack to Current Carton, total qty = 12, pack qty = 8, remain qty = 4, pack 8 to current box
               -- Pack to Current Carton, total qty = 12, pack qty = 1, remain qty = 11, close current box and pack 12 to new box
               -- Pack to Current Carton, total qty = 12, pack qty = 11,remain qty = 1,  close current box and pack 12 to new box
               IF @n_CartonItem > 0 AND @n_PickedQty > 0 AND @n_Qty > @n_QtyToPack AND                                                                   --2021-08-11
                 ((@n_Qty - @n_QtyToPack)/@n_PackQtyIndicator <= @n_PickedQty OR (@n_QtyToPack/@n_PackQtyIndicator) <= @n_PickedQty)                     --2021-08-11
               BEGIN
                  SET @b_NewCarton = 1
           GOTO NEW_CARTON
               END
               --(Wan05) - END CR1.3  & 1.4 2021-07-01

               IF @c_CartonType <> @c_NewCartonType  -- Change to Biger Carton
               BEGIN
                  UPDATE #PICKDETAIL_WIP
                     SET CartonType= @c_NewCartonType
                        ,CartonCube= @n_MaxCube          -- 2020-10-12
                  WHERE CartonType = @c_CartonType
                  AND CartonSeqNo  = @n_CartonSeqNo

                  SET @c_CartonType = @c_NewCartonType   -- 2020-10-12

                  IF @n_debug = 1                        -- 2020-10-12
                  BEGIN
                     SELECT CartonType, CartonCube, * from #PICKDETAIL_WIP
                     WHERE CartonSeqNo = @n_CartonSeqNo
                  END
               END
            END  --(Wan03) - END

            --CR 1.6 - 2021-08-04 - START - Put Sku.StdCube > Large Carton's Cube
            IF @n_QtyToPack = 0 --AND @n_StdCube > @n_MaxCube    --If 0 qty can fit, at least put 1 even system calculate pick item cube < Large Carton Cube
            BEGIN
               SET @n_QtyToPack = 1 * @n_PackQtyIndicator
            END
            --CR 1.6 - 2021-08-04 - END - Put Sku.StdCube > Large Carton's Cube

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
               AND   pw.LocLevel = @c_LocLevel      --2021-10-22
               AND   pw.Orderkey = @c_Orderkey      --Wan07 2021-11-29
               ORDER BY pw.Qty DESC
                      , pw.RowRef

               IF @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END

               IF @n_Qty_PD > @n_QtyToPack_REM AND @n_QtyToPack_REM > 0   --2020-09-24 Wan01
               BEGIN
                  SET @n_QtyToPack = @n_QtyToPack_REM

                  SET @b_SplitPickdetail = 1

                  INSERT INTO #PICKDETAIL_WIP      --(Wan05) - START
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
                     ,  SkuStdCube        --2020-08-27
                     ,  SkuStdGrossWgt    --2020-11-27
                     ,  [Length]          --2020-08-07
                     ,  Width             --2020-08-07
                     ,  Height            --2020-08-07
                     ,  CubeTolerance     --2020-08-27
                     ,  PackQtyIndicator  --(Wan02)
                     ,  Lot
                     ,  ToLoc
                     ,  DropID
                     ,  LocLevel
                     ,  LogicalLocation
                     ,  [Status]
                     ,  ItemClass         --(Wan05)
                     ,  Size              --(Wan05)
                     )                      SELECT
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
                     ,  UOMQty = CASE WHEN PD.DropID = '' THEN @n_QtyToPack ELSE PD.UOMQty END                    --(WAn05)
                     ,  Qty    = @n_Qty_PD - @n_QtyToPack
                     ,  PickStdCube    = ((@n_Qty_PD - @n_QtyToPack) / (1.00 * @n_PackQtyIndicator)) * @n_StdCube    --(WAn05)
                     ,  PickStdGrosWgt = ((@n_Qty_PD - @n_QtyToPack) / (1.00 * @n_PackQtyIndicator)) * @n_StdGrossWgt--(WAn05)
                     ,  StdCube     = @n_StdCube
                     ,  StdGrossWgt = @n_StdGrossWgt
                     ,  PD.SkuStdCube        --2020-08-27
                     ,  PD.SkuStdGrossWgt    --2020-11-27
                     ,  PD.[Length]          --2020-08-07
                     ,  PD.Width             --2020-08-07
                     ,  PD.Height            --2020-08-07
                     ,  PD.CubeTolerance     --2020-08-27
                     ,  @n_PackQtyIndicator  --(Wan02)   Bundle Sku should not be splitted, just keep a record for split sku
                     ,  PD.Lot
                     ,  PD.ToLoc
                     ,  PD.DropID
                     ,  PD.LocLevel
                     ,  PD.LogicalLocation
                     ,  [Status]  = 2
                     ,  PD.ItemClass               --(Wan05)
                     ,  PD.Size                    --(Wan05)
                  FROM #PICKDETAIL_WIP PD
                  WHERE PD.RowRef = @n_RowRef_PD

                  SET @n_Status = 1
               END
               ELSE
               BEGIN
                  SET @n_QtyToPack_Rem = @n_QtyToPack_Rem - @n_Qty_PD   --2021-10-11 fix @n_QtyToPack - @n_Qty_PD
                  SET @n_QtyToPack = @n_Qty_PD
               END

               IF @n_debug = 1
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
                  , PickStdCube    = (@n_QtyToPack / (1.00 * @n_PackQtyIndicator)) * StdCube             --2020-10-19 --CASE WHEN @n_Status = 1 THEN @n_QtyToPack * StdCube ELSE PickStdCube END
                  , PickStdGrossWgt= (@n_QtyToPack / (1.00 * @n_PackQtyIndicator)) * StdGrossWgt         --2020-10-19 --CASE WHEN @n_Status = 1 THEN @n_QtyToPack * StdGrossWgt ELSE PickStdGrossWgt END
                  , [Status]       = CASE WHEN [Status] = 0 THEN @n_Status ELSE [Status] END
               WHERE RowRef        = @n_RowRef_PD

               IF @b_SplitPickdetail = 1
               BEGIN
                  BREAK
               END
               SET @n_QtyToPack_TTL = @n_QtyToPack_TTL + @n_QtyToPack
            END

            --Move Down
            SET @n_PackedCube= @n_PackedCube + (@n_StdCube * (@n_QtyToPack / (1.00 * @n_PackQtyIndicator)))       --2020-10-19
            SET @n_PackedWgt = @n_PackedWgt  + (@n_StdGrossWgt * ( @n_QtyToPack / (1.00 * @n_PackQtyIndicator)))  --2020-10-19

            SET @n_AvailableCube = @n_MaxCube - @n_PackedCube
            SET @n_AvailableWgt  = @n_MaxWeight - @n_PackedWgt
            --(Wan05) - END

            NEXT_PD:

            --IF @b_SplitPickdetail = 1      --(Wan05)
            --BEGIN
            --   SET @b_SplitPickdetail = 0
            --   GOTO GET_PICK_REC           --(Wan05)
            --END

            FETCH NEXT FROM @CUR_PD INTO @n_RowRef_Sku
                                       , @c_Storerkey
                                       , @c_Sku
                                       , @n_PickStdCube
                                       , @n_PickStdGrossWgt
                                       , @n_StdCube
                                       , @n_StdGrossWgt
                                       , @n_Qty
                                       , @c_UOM
                                       , @n_PackQtyIndicator   --(Wan02)

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
               TRUNCATE TABLE #OptimizeItemToPack;             --(Wan06)

               INSERT INTO #OptimizeItemToPack                 --(Wan06)
               (  Storerkey, SKU, Dim1, Dim2, Dim3, Quantity  )
               SELECT
                  p.Storerkey
               ,  p.Sku
               , CONVERT(DECIMAL(10,6), p.[Length])
               , CONVERT(DECIMAL(10,6), p.Width)
               , CONVERT(DECIMAL(10,6), p.Height)
               , Quantity = SUM(p.Qty) / p.PackQtyIndicator --(Wan06) CR1.8
               FROM #PICKDETAIL_WIP p
               WHERE p.CartonType = @c_CartonType
               AND p.CartonSeqNo  = @n_CartonSeqNo
               AND p.orderkey = @c_Orderkey              --Wan04
          GROUP BY p.Storerkey
                     ,  p.Sku
                     ,  p.[Length]
                     ,  p.Width
                     ,  p.Height
                     , p.PackQtyIndicator                   --(Wan06) CR1.8

               SET @n_Qty_Recalc = 0
               SELECT TOP 1 @n_Qty_Recalc = Quantity
               FROM #OptimizeItemToPack                        --(Wan06)
               ORDER BY ID DESC

               IF @n_debug = 1
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
                  SET @n_err = 82009
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_CartonOptimizeCheck. (ispRLWAV20_PACK)'
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
            SET @n_Err = 82010
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKHEADER Failed. (ispRLWAV20_PACK)'
            GOTO QUIT_SP
         END

         INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
         VALUES (@c_Pickslipno , NULL, NULL, NULL)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 82020
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKINGINFO Failed. (ispRLWAV20_PACK)'
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
            SET @n_Err = 82030
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL Failed. (ispRLWAV20_PACK)'
            GOTO QUIT_SP
         END

         FETCH NEXT FROM @CUR_DELPCK INTO @n_CartonNo
      END
      CLOSE @CUR_DELPCK
      DEALLOCATE @CUR_DELPCK


      IF NOT EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
         INSERT INTO PACKHEADER (PickSlipNo, Storerkey, Orderkey, Loadkey, Consigneekey, [Route], OrderRefNo )
         VALUES (@c_Pickslipno , @c_Storerkey, @c_Orderkey, @c_Loadkey, @c_Consigneekey, @c_Route, @c_ExternOrderkey)    --(Wan08)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 82040
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKHEADER Failed. (ispRLWAV20_PACK)'
            GOTO QUIT_SP
         END
      END

      -------------------------------------------------------
      -- Gen Label#,Stamp CaseID and Split PickDetail - START
      -------------------------------------------------------
      SET @n_CartonSeqNo_Prev = 0
      SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRef = ISNULL(PD.RowRef,0)    -- Wan01 2020-10-01 - START
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
      UNION ALL                              -- Wan01 2020-10-01 - END
      SELECT PD.RowRef
            ,PD.PickDetailKey
            ,PD.UOM          --2020-08-10
            ,PD.DropID        --2020-08-10
            ,PD.Qty
            ,PD.CartonSeqNo
            ,PD.[Status]
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      AND   PD.UOM IN ('6','7') -- Wan01 2020-10-01
      AND   PD.CartonType <> ''
      ORDER BY CartonSeqNo
            ,  PickDetailKey
            ,  RowRef

      OPEN @CUR_PD

      FETCH NEXT FROM @CUR_PD INTO @n_RowRef
                                ,  @c_PickDetailKey
                                ,  @c_UOM          --2020-08-10
                                ,  @c_DropID       --2020-08-10
                                ,  @n_Qty
                                ,  @n_CartonSeqNo
                                ,  @n_Status


      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_UOM = '2'   --2020-08-10
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
                  SET @n_err = 82050
                  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing isp_GenUCCLabelNo_Std. (ispRLWAV20_PACK)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  GOTO QUIT_SP
               END
            END
         END   --2020-08-10

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
                 , @c_PickDetailKey + ', Originalqty = ' + CAST(PD.UOMQty AS VARCHAR)      --PD.Notes  --2020-11-19 To link B
            FROM PICKDETAIL PD WITH (NOLOCK)
            WHERE PD.PickDetailKey = @c_PickDetailKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 82060
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PICKDETAIL Failed. (ispRLWAV20_PACK)'
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
               SET @n_Err = 82070
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PICKDETAIL Failed. (ispRLWAV20_PACK)'
               GOTO QUIT_SP
            END
         END

         IF @n_RowRef > 0  -- Wan01 2020-10-01
         BEGIN
            Update #PICKDETAIL_WIP
            SET CaseID = @c_labelNo
               ,PickSlipNo = @c_PickSlipNo
            WHERE RowRef = @n_RowRef
         END               -- Wan01 2020-10-01

         SET @n_CartonSeqNo_Prev = @n_CartonSeqNo
         FETCH NEXT FROM @CUR_PD INTO @n_RowRef
                                    , @c_PickDetailKey
                                    , @c_UOM          --2020-08-10
                                    , @c_DropID       --2020-08-10
                                    , @n_Qty
                                    , @n_CartonSeqNo
                                    , @n_Status
      END
      CLOSE @CUR_PD
      DEALLOCATE @CUR_PD
      -----------------------------------------------------
      -- Gen Label#,Stamp CaseID and Split PickDetail - END
      -----------------------------------------------------

      IF @n_debug = 1
      BEGIN
         SELECT @c_Orderkey '@c_Orderkey', * from #PICKDETAIL_WIP
         where orderkey = @c_Orderkey
         ORDER BY orderkey, busr7, loclevel, logicallocation,CartonSeqNo, sku

               SELECT @c_PickSlipNo
            ,CartonNo = PD.CartonSeqNo --+ @n_CartonNo
            ,[Weight] = ISNULL(SUM(PD.StdGrossWgt * PD.Qty),0.00)
            --,[Cube]   = ISNULL(SUM(PD.StdCube * PD.Qty),0.00)
            ,[Cube]   = PD.CartonCube                              --2020-09-14
            ,Qty = ISNULL(SUM(PD.Qty),0)
            ,PD.CartonType
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      GROUP BY PD.CartonSeqNo
            ,  PD.CartonType
            ,  PD.CartonCube                                      --2020-09-14

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
               ,CartonNo = PD.CartonSeqNo --+ @n_CartonNo
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
            ,CartonNo = PD.CartonSeqNo --+ @n_CartonNo
            ,PD.Caseid
            ,LabelLine = RIGHT('00000' + CONVERT(NVARCHAR(5), ROW_NUMBER() OVER (PARTITION BY PD.Caseid ORDER BY PD.CartonSeqNo, PD.Storerkey, PD.Sku)),5)-- 2020-09-25
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
         SET @n_Err = 82080
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKDETAIL Failed. (ispRLWAV20_PACK)'
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
            ,CartonNo = PD.CartonSeqNo --+ @n_CartonNo
            ,[Weight] = ISNULL(SUM(PD.StdGrossWgt * PD.Qty),0.00)
            --,[Cube]   = ISNULL(SUM(PD.StdCube * PD.Qty),0.00)
            ,[Cube]   = PD.CartonCube                              --2020-09-14
            ,Qty = ISNULL(SUM(PD.Qty),0)
            ,PD.CartonType
      FROM #PICKDETAIL_WIP PD
      WHERE PD.Orderkey = @c_Orderkey
      GROUP BY PD.CartonSeqNo
            ,  PD.CartonType
            ,  PD.CartonCube                                      --2020-09-14

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 82090
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PACKINFO Failed. (ispRLWAV20_PACK)'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLWAV20_PACK'
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