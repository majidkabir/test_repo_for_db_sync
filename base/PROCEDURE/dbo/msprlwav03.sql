SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: mspRLWAV03                                         */
/* Creation Date: 08-MAY-2024                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: UWP-18747 - Levis US MPOC and Cartonization                 */
/*                                                                      */
/* Called By: Wave                                                      */
/*                                                                      */
/* GitHub Version: 2.9                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 13-Aug-2024  SHONG    1.0  Bug Fixing                                */
/* 20-Aug-2024  SHONG    1.1  Chane Mapping in PackInfo Insert          */
/* 22-Aug-2024  SHONG    1.2 FCR-243 Not mix SKUGroup and Item Class    */
/* 09-Sep-2024  SHONG    1.3 Group by Item Group and Class, not checking*/
/*                           LxWxH for SKU                              */
/* 09-Sep-2024  Yung     1.4 Block Releave wave if replenishment        */
/*                           incomplete                                 */
/* 11-Sep-2024  Shong    1.5 Fixing VAS Order Issues                    */
/* 12-Sep-2024  Shong    1.6 If OrderInfo03 = J05, set Carton Max SKU=5 */
/* 15-Sep-2024  Shong    1.7 VAS LPN_SIZE - No Volume restriction       */
/*                       (SWT01)                                        */
/* 17-Sep-2024  WLChooi  1.8 Bug Fix + FCR version v2.1 (WL01)          */
/* 18-Sep-2024  WLChooi  1.9 Map Workorderdetail.Type instead of Order  */
/*                           info - FCR V2.2 (WL02)                     */
/* 20-Sep-2024  WLChooi  2.0 Merge with ALiang01 changes from PROD      */
/* 01-Oct-2024  Shong    2.1 Need to check Carton size for VAS Carton   */
/*                           specified. Adding checking to reject when  */
/*                           SKU Cube or LxWxH can't fit                */
/* 03-Oct-2024 Shong     2.2 Fixing VAS Carton Size issue  (SWT03)      */
/* 16-Oct-2024 Shong     2.2.1 Hot Fix for Carton Type Override (SWT04) */
/* 10-Oct-2024 Shong     2.3 Force Generate Replenishment before Release*/
/*                           Wave (SWT04)-> tmep remove                 */
/* 21-Oct-2024 WLChooi   2.4 Stamp Packheader.ConsoOrderkey = Ordergroup*/
/*                           for MPOC order (WL03)                      */
/* 23-Oct-2024 WLChooi   2.5 Remove TL2 Insertion (WL04)                */
/* 25-Oct-2024 WLChooi   2.6 Bug Fix for MPOC Flag (WL05)               */
/* 31-Oct-2024 WLChooi   2.8 Fix MPOC multiple orders in 1 ctn (WL07)   */
/* 11-Nov-2024 Shong     2.9 FCR-1132 Wave Release SCE Trigger for      */ 
/*                           BOLbyConsignee (SWT05)                     */ 
/* 20-Nov-2024 Wan01     3.0 UWP-27137 - [FCR-1348] [Levi's] Wave Release*/
/*                           (Automation and Manual Operations)         */
/* 30-Jan-2025 SSA01     3.1 UWP-27137 - [FCR-1348] Single tote for     */
/*                           Single Sku                                 */
/* 30-Jan-2025 SSA02     3.2 UWP-27137 -NonSortable and Nonconveyable   */
/*                             cartonization fix                        */
/* 11-Feb-2025 SWT06     3.3 Performance Tuning                         */
/* 14-Feb-2025 Shong     3.4 UWP-27137 Fixing Case ID issues (SWT07)    */
/* 19-Feb-2025 SSA03     3.5 UWP-27137 added condition #ORDERSKU.wcs=0  */
/* 24-Feb-2025 WLC015    3.6 UWP-27137 Fix infinite loop when assigning */
/*                           DropID (WL08)                              */
/************************************************************************/
CREATE   PROC [dbo].[mspRLWAV03]
   @c_WaveKey NVARCHAR(10)
 , @b_Success INT           OUTPUT
 , @n_Err     INT           OUTPUT
 , @c_ErrMsg  NVARCHAR(250) OUTPUT
 , @b_debug   INT = 0
AS
BEGIN
   SET NOCOUNT ON                    
   SET ANSI_NULLS OFF                 
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF   
                                      
   DECLARE @c_SourceType              NVARCHAR(30)            
          ,@n_StartTCnt               INT          = 0
          ,@n_Continue                INT          = 1
          ,@c_Storerkey               NVARCHAR(15) 
          ,@c_Facility                NVARCHAR(5)          
          ,@c_CartonGroup             NVARCHAR(10) = ''          
          ,@c_RLWAV_Opt5              NVARCHAR(4000)
          ,@c_CartonItemOptimize      NVARCHAR(30) = 'Y'
          ,@c_NewCarton               NVARCHAR(1)
          ,@n_CartonNo                INT
          ,@c_CartonType              NVARCHAR(10)
          ,@c_NewCartonType           NVARCHAR(10)  --SWT03
          ,@n_CartonMaxCube           DECIMAL(15,7)
          ,@n_NewCartonMaxCube        DECIMAL(15,7) --SWT03 
          ,@n_CartonRemainCube        DECIMAL(15,7)
          ,@n_CartonMaxWeight         DECIMAL(20,7)   
                 
          ,@n_CartonMaxCount          INT
          ,@n_CartonMaxSku            INT
          ,@n_ForceCartonMaxSku       INT
          ,@c_Orderkey                NVARCHAR(10)
          ,@n_OrderCube               DECIMAL(15,7)
          ,@n_OrderWeight             DECIMAL(15,7)                         
          ,@n_RowID                   INT
          ,@n_OrderQty                INT
          ,@c_Sku                     NVARCHAR(20)
          ,@n_StdCube                 DECIMAL(15,7)
          ,@n_CartonLength            DECIMAL(15,7)      
          ,@n_CartonWidth             DECIMAL(15,7)      
          ,@n_CartonHeight            DECIMAL(15,7)
          ,@n_SKULength               DECIMAL(15,7) 
          ,@n_SKUWidth                DECIMAL(15,7)
          ,@n_SKUHeight               DECIMAL(15,7)
          ,@n_QtyCanPackByCube        INT
          ,@n_QtyCanPackByCount       INT
          ,@n_QtyCanPack              INT
          ,@c_PickslipNo              NVARCHAR(10)
          ,@c_LabelNo                 NVARCHAR(20)
          ,@n_TotCartonCube           DECIMAL(15,7)
          ,@n_TotCartonWeight         DECIMAL(15,7)
          ,@n_TotCartonQty            INT
          ,@n_PackQty                 INT      
          ,@n_PickdetQty              INT
          ,@c_PickDetailKey           NVARCHAR(10)
          ,@c_NewPickDetailKey        NVARCHAR(10)
          ,@n_SplitQty                INT
          ,@c_KeyName                 NVARCHAR(18)
          ,@c_UCCNo                   NVARCHAR(20)
          ,@c_SkuGroup                NVARCHAR(10)
          ,@c_ItemClass               NVARCHAR(10)
          ,@n_MPOCFlag                INT = 0 
          ,@c_OrderGroup              NVARCHAR(10) = '' 
          ,@c_PreOrderGroup           NVARCHAR(10) = ''
          ,@n_SortSeq                 INT    
          ,@n_CTNRowID                INT = 0 
          ,@n_SKUGroupCube            DECIMAL(15,7)=0
          ,@c_Replenishmentkey        NVARCHAR(10)
          ,@b_OneSKUPerCarton         BIT = 0 
          ,@b_MDS_Flag                BIT = 0 --SWT03
          ,@c_LabelLine               NVARCHAR(10)   --WL07           

   DECLARE @n_VAS_LineCount INT = 0,
           @n_VAS_QtyCanPack INT = 0,
           @c_VAS_CartonType NVARCHAR(12);

   DECLARE @b_WCS                      INT          = 0                             --(Wan01)
         , @n_NoOfCarton               INT          = 0                             --(Wan01)  
         , @n_Qty_PD                   INT          = 0                             --(Wan01)
         , @n_Qty_WO                   INT          = 0                             --(Wan01)
         , @n_PendingMoveIn            INT          = 0                             --(Wan01)         
         , @n_ToteSize                 FLOAT        = 0.00                          --(Wan01)
         , @n_TotalCube                FLOAT        = 0.00                          --(Wan01)
         , @c_Automation               NVARCHAR(10) = ''                            --(Wan01)
         , @c_PNDLoc                   NVARCHAR(10) = ''                            --(Wan01)
         , @c_LocType_PND              NVARCHAR(10) = ''                            --(Wan01)
         , @c_LocFac_PND               NVARCHAR(5)  = ''                            --(Wan01)
         , @c_OrderLineNumber          NVARCHAR(5)  = ''                            --(Wan01)
         , @c_Sku_Last                 NVARCHAR(20) = ''                            --(Wan01)
         , @c_Loc                      NVARCHAR(10) = ''                            --(Wan01)
         , @c_Loc_Last                 NVARCHAR(10) = ''                            --(Wan01)
         , @c_DropID                   NVARCHAR(20) = ''                            --(Wan01)
         , @c_UOM                      NVARCHAR(10) = ''                            --(Wan01)
         , @c_PickMethod               NVARCHAR(10) = ''                            --(Wan01)
         , @c_FromLocType              NVARCHAR(10) = ''                            --(Wan01)
         , @c_FromLogicalLoc           NVARCHAR(10) = ''                            --(Wan01)
         , @c_FromPAZone               NVARCHAR(10) = ''                            --(Wan01) 
         , @c_FromPAZone_Last          NVARCHAR(10) = ''                            --(Wan01) 
         , @c_ToLocType                NVARCHAR(10) = ''                            --(Wan01)
         , @c_ToLocCategory            NVARCHAR(10) = ''                            --(Wan01)
         , @c_ToPAZone                 NVARCHAR(10) = ''                            --(Wan01) 
         , @c_TaskType                 NVARCHAR(10) = ''                            --(Wan01) 
         , @c_TaskStatus               NVARCHAR(10) = ''                            --(Wan01) 
         , @c_FinalLoc                 NVARCHAR(10) = ''                            --(Wan01)     
         , @c_PickMethod_TD            NVARCHAR(10) = ''                            --(Wan01)          
         , @c_RefTaskkey               NVARCHAR(10) = ''                            --(Wan01)   
         
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = '', @c_SourceType = 'mspRLWAV03'
    
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   --Create pickdetail Work in progress temporary table    
   IF @n_continue IN(1,2)
   BEGIN
      CREATE TABLE #PickDetail_WIP(
         [PickDetailKey] [NVARCHAR](18) NOT NULL PRIMARY KEY,
         [CaseID] [NVARCHAR](20) NOT NULL DEFAULT (' '),
         [PickHeaderKey] [NVARCHAR](18) NOT NULL,
         [OrderKey] [NVARCHAR](10) NOT NULL,
         [OrderLineNumber] [NVARCHAR](5) NOT NULL,
         [Lot] [NVARCHAR](10) NOT NULL,
         [Storerkey] [NVARCHAR](15) NOT NULL,
         [Sku] [NVARCHAR](20) NOT NULL,
         [AltSku] [NVARCHAR](20) NOT NULL DEFAULT (' '),
         [UOM] [NVARCHAR](10) NOT NULL DEFAULT (' '),
         [UOMQty] [INT] NOT NULL DEFAULT ((0)),
         [Qty] [INT] NOT NULL DEFAULT ((0)),
         [QtyMoved] [INT] NOT NULL DEFAULT ((0)),
         [Status] [NVARCHAR](10) NOT NULL DEFAULT ('0'),
         [DropID] [NVARCHAR](20) NOT NULL DEFAULT (''),
         [Loc] [NVARCHAR](10) NOT NULL DEFAULT ('UNKNOWN'),
         [ID] [NVARCHAR](18) NOT NULL DEFAULT (' '),
         [PackKey] [NVARCHAR](10) NULL DEFAULT (' '),
         [UpdateSource] [NVARCHAR](10) NULL DEFAULT ('0'),
         [CartonGroup] [nvarchar](10) NULL,
         [CartonType] [nvarchar](10) NULL,
         [ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
         [DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
         [ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
         [DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
         [PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
         [WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
         [EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
         [AddDate] [datetime] NOT NULL DEFAULT (getdate()),
         [AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
         [EditDate] [datetime] NOT NULL DEFAULT (getdate()),
         [EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
         [TrafficCop] [nvarchar](1) NULL,
         [ArchiveCop] [nvarchar](1) NULL,
         [OptimizeCop] [nvarchar](1) NULL,
         [ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
         [PickSlipNo] [nvarchar](10) NULL,
         [TaskDetailKey] [nvarchar](10) NULL,
         [TaskManagerReasonKey] [nvarchar](10) NULL,
         [Notes] [nvarchar](4000) NULL,
         [MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
         [WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
         [Channel_ID] [bigint] NULL DEFAULT ((0)))
   END    

   --Validation
   IF @n_continue IN(1,2)
   BEGIN
      SELECT @c_Automation = ISNULL(w.Userdefine09,'')                              --(Wan01)
            ,@c_PNDLoc     = w.DispatchCasePickMethod
      FROM WAVE w (NOLOCK)
      WHERE w.Wavekey = @c_WaveKey

      SELECT TOP 1 @c_Storerkey = O.StorerKey,
               @c_Facility = O.Facility
      FROM dbo.WAVEDETAIL WD (NOLOCK)
      JOIN dbo.ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      WHERE WD.WaveKey = @c_WaveKey
          
      SELECT @c_CartonGroup = CartonGroup
      FROM dbo.STORER (NOLOCK)
      WHERE Storerkey = @c_Storerkey
    
      IF EXISTS(SELECT 1
               FROM dbo.PACKHEADER PH (NOLOCK)
               JOIN dbo.PACKDETAIL PD (NOLOCK) ON PH.PickslipNo = PD.Pickslipno
               JOIN dbo.WAVEDETAIL WD (NOLOCK) ON PH.Orderkey = WD.Orderkey
               WHERE WD.WaveKey = @c_WaveKey)
      BEGIN
            SET @n_continue = 3
            SET @n_Err = 82000
            SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': This Wave was cartonized before. (mspRLWAV03)'     
            GOTO QUIT_SP  
      END                         

      IF NOT EXISTS(SELECT 1
                     FROM dbo.CARTONIZATION CZ (NOLOCK)
                     WHERE CZ.CartonizationGroup = @c_CartonGroup)
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 562201
         SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': CartonizationGroup ' + RTRIM(ISNULL(@c_CartonGroup,'')) + ' is not setup yet. (mspRLWAV03)'    
         GOTO QUIT_SP  
      END              
     
      SET @c_CartonType = ''
      SELECT TOP 1 @c_CartonType = CartonType
      FROM dbo.CARTONIZATION (NOLOCK)
      WHERE CartonizationGroup = @c_CartonGroup
      AND Cube = 0 
      AND (CartonWidth = 0 OR CartonLength = 0 OR CartonHeight = 0)         
      ORDER BY CartonType
     
      IF ISNULL(@c_CartonType,'') <> ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 562202
         SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Cube or LxWxH must setup for carton type ' + RTRIM(@c_CartonType) + '. (mspRLWAV03)'     
         GOTO QUIT_SP  
      END                 
     
      SET @c_Sku = ''
      SELECT TOP 1 @c_Sku = OD.Sku
      FROM dbo.WAVEDETAIL WD (NOLOCK)
      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON WD.Orderkey = OD.Orderkey
      JOIN dbo.SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      WHERE WD.WaveKey = @c_WaveKey                      
      AND STDCUBE = 0 
      AND (Width = 0 OR Length = 0 OR Height = 0)
      ORDER BY OD.Sku

      IF ISNULL(@c_Sku,'') <> ''
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 562203
         SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': StdCube or LxWxH must setup for Sku ' + RTRIM(@c_Sku) + '. (mspRLWAV03)'     
         GOTO QUIT_SP  
      END     
   
      IF @c_Automation = 'Y'                                                       --(Wan01)
      BEGIN
         IF EXISTS ( SELECT 1 FROM TASKDETAIL td (NOLOCK)
                     WHERE td.Wavekey = @c_Wavekey
                     AND   td.Sourcetype = @c_SourceType
                     AND   td.TaskType IN ('FCP', 'RPF', 'ASTCPK')
                     AND   td.[Status] <> 'X'
                   )
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 82011
            SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)
                         +': Release Task found. (mspRLWAV03)'     
            GOTO QUIT_SP    
         END

         IF @c_PNDLoc = ''
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 82018
            SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)
                         +': Replenishment PND Lane Assignment is missing. (mspRLWAV03)'     
            GOTO QUIT_SP   
         END
         
         SELECT @c_LocType_PND = l.Locationtype
               ,@c_LocFac_PND  = l.Facility 
         FROM LOC l (NOLOCK) 
         WHERE l.Loc = @c_PNDLoc
 
         IF @c_LocType_PND <> 'PND' OR @c_LocFac_PND <> @c_Facility
         BEGIN 
            SET @n_continue = 3
            SET @n_Err = 82020
            SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)
                         +': None PND Location / Unmatch PND Facility Found. (mspRLWAV03)'     
            GOTO QUIT_SP             
         END

         IF EXISTS ( SELECT 1
                     FROM LOTxLOCxID lli (NOLOCK)
                     WHERE lli.Storerkey = @c_Storerkey
                     AND   lli.Loc       = @c_PNDLoc                     
                     AND   lli.Qty + lli.PendingMoveIN > 0
                   )
         BEGIN 
            SET @n_continue = 3
            SET @n_Err = 82012
            SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)
                         +': PND Location is currently being used by another Wave. (mspRLWAV03)'     
            GOTO QUIT_SP             
         END

         SELECT TOP 1 @c_Sku = RTRIM(PD.Sku)
         FROM dbo.WAVEDETAIL WD (NOLOCK)
         JOIN dbo.PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
         LEFT OUTER JOIN dbo.SKUxLOC sl (NOLOCK) ON  sl.Storerkey = PD.Storerkey AND sl.Sku = PD.Sku
                                                 AND sl.LocationType IN ('CASE', 'PICK')
         WHERE WD.WaveKey = @c_WaveKey 
         AND sl.Loc IS NULL
         ORDER BY PD.Sku
         
         IF @c_Sku <> ''
         BEGIN 
            SET @n_continue = 3
            SET @n_Err = 82013
            SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)
                         +': PickFace must setup for sku: ' + @c_Sku + '. (mspRLWAV03)'     
            GOTO QUIT_SP             
         END
      END
      ELSE
      BEGIN
         SET @C_Replenishmentkey ='' --Yung
         SELECT TOP 1 @C_Replenishmentkey = RP.Replenishmentkey 
         FROM replenishment RP (NOLOCK) 
         INNER JOIN wave W (nolock)  on RP.Wavekey = W.Wavekey
         WHERE W.wavekey = @C_Wavekey
         AND RP.Confirmed <> 'Y'

         IF ISNULL(@C_Replenishmentkey,'') <> ''
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 561016
            SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Replenishment incomplete ' + RTRIM(@C_Replenishmentkey) + '. (mspRLWAV03)'     
            GOTO QUIT_SP  
         END    

         -- Reject when Replenishment not generate yet SWT04
         -- 2025-01-27 Temp remove as nobody to confirm to go-live. Need to add back if levis need this feature.
         --IF NOT EXISTS(SELECT 1 FROM dbo.WAVE WITH (NOLOCK) WHERE WaveKey = @c_WaveKey AND UserDefine01 = 'Y')
         --BEGIN
         --   SET @n_continue = 3
         --   SET @n_Err = 561016
         --   SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Please execute replenishment before release Wave. (mspRLWAV03)'     
         --   GOTO QUIT_SP  
         --END   
      END
   END -- @n_continue IN(1,2)
  --Initialize Pickdetail work in progress staging table    
   IF @n_continue IN(1,2)
   BEGIN      
      EXEC dbo.isp_CreatePickdetail_WIP
           @c_Loadkey               = ''
          ,@c_WaveKey               = @c_WaveKey
          ,@c_WIP_RefNo             = @c_SourceType
          ,@c_PickCondition_SQL     = ''
          ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
          ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
          ,@b_Success               = @b_Success OUTPUT
          ,@n_Err                   = @n_Err     OUTPUT
          ,@c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END

   IF @n_Continue IN (1,2)                                                           --(Wan01)                    
   BEGIN
      IF @c_Automation = 'Y'                                                                                                              
      BEGIN
         UPDATE #PickDetail_WIP 
            SET UOM = '6'
               ,PickMethod = '3'
         FROM #PickDetail_WIP pd
         JOIN dbo.WorkOrderDetail wod (NOLOCK) ON  wod.ExternWorkOrderKey = pd.Orderkey
                                                AND wod.ExternLineNo = pd.OrderLineNumber
         WHERE pd.UOM = '2'
         AND wod.[Type] IN ( 'S02', 'S06', 'J05' )
         AND wod.Qty > 0
      END
   END
   
   --Prepare common data
   IF @n_continue IN(1,2)
   BEGIN
      CREATE TABLE #OrderGroup
      (
         OrderKey NVARCHAR(10) NOT NULL, 
         MPOCFlag CHAR(1) NULL,
         OrderGroup NVARCHAR(10) NULL
      )

      CREATE TABLE #ORDERSKU
      (
          RowID INT IDENTITY(1, 1) PRIMARY KEY,
          Orderkey NVARCHAR(10),
          Storerkey NVARCHAR(15),
          Sku NVARCHAR(20),
          TotalQty INT,
          TotalCube DECIMAL(15, 7),
          TotalQtyPacked INT,
          TotalCubePacked DECIMAL(15, 7),
          StdCube DECIMAL(15, 7),
          Length DECIMAL(15, 7),
          Width DECIMAL(15, 7),
          Height DECIMAL(15, 7),
          OrderGroup NVARCHAR(10), 
          MasterShipmentID NVARCHAR(10)
        , WCS                 INT   DEFAULT(0)                                      --(Wan01) 
        , SoftCartonization   INT   DEFAULT(0)                                      --(Wan01)
      );
      CREATE INDEX IDX_ORDERSKU_ORD ON #ORDERSKU (Orderkey)                              
                              
      CREATE TABLE #CARTONIZATION (RowID INT IDENTITY(1,1) PRIMARY KEY,
                                   CartonizationGroup NVARCHAR(10), 
                                   CartonType   NVARCHAR(10),       
                                   UseSequence  INT,  
                                   Cube         DECIMAL(15,7),              
                                   MaxWeight    DECIMAL(20,7),         
                                   MaxCount     INT,
                                   MaxSku       INT,
                                   CartonLength DECIMAL(15,7),      
                                   CartonWidth  DECIMAL(15,7),      
                                   CartonHeight DECIMAL(15,7),
                                   IsGeneric    INT DEFAULT 1)   --WL01

      CREATE TABLE #CARTON (RowID        INT IDENTITY(1,1) PRIMARY KEY,
                            OrderGroup   NVARCHAR(10) NOT NULL,
                            Orderkey     NVARCHAR(10) NOT NULL, 
                            CartonNo     INT NULL DEFAULT 0,
                            LabelNo      NVARCHAR(20) NULL DEFAULT '',
                            CartonGroup  NVARCHAR(10) NULL DEFAULT '',
                            CartonType   NVARCHAR(10) NULL DEFAULT '',
                            MaxCube      DECIMAL(15,7) NULL DEFAULT 0,                            
                            MaxWeight    DECIMAL(20,7) NULL DEFAULT 0,
                            MaxCount     INT NULL DEFAULT 0,
                            MaxSku       INT NULL DEFAULT 0,
                            CartonLength DECIMAL(15,7) NULL DEFAULT 0,      
                            CartonWidth  DECIMAL(15,7) NULL DEFAULT 0,
                            CartonHeight DECIMAL(15,7) NULL DEFAULT 0,
                            UCCNo        NVARCHAR(20) NULL DEFAULT '',
                            VASCartonType NVARCHAR(10) NULL DEFAULT '') -- SWT03
      CREATE INDEX IDX_CTN ON #CARTON (OrderGroup, Orderkey)                              

      CREATE TABLE #CARTONDETAIL (RowID       INT IDENTITY(1,1) PRIMARY KEY,
                                  OrderGroup   NVARCHAR(10) NOT NULL,
                                  Orderkey    NVARCHAR(10) NOT NULL, 
                                  CartonNo    INT, 
                                  Storerkey   NVARCHAR(15), 
                                  Sku         NVARCHAR(20), 
                                  Qty         INT,                                   
                                  RowRef      INT)              
      CREATE INDEX IDX_CTNDET ON #CARTONDETAIL (OrderGroup, Orderkey, CartonNo)                                                               
      
      CREATE TABLE #ROWTRACK (RowID INT)
      CREATE TABLE #CTNTRACK (RowID INT)

      CREATE TABLE #SKUGROUP (RowID INT IDENTITY(1,1) PRIMARY KEY,
                              SkuGroup  NVARCHAR(10),
                              ItemClass NVARCHAR(10),
                              TotalCube DECIMAL(15,7),
                              WCS       INT     DEFAULT(0)                          --(Wan01)
                              )
                                                                                                          
      SELECT @c_RLWAV_Opt5 = SC.Option5
      FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'WAVGENPACKFROMPICKED_SP') AS SC 
            
      SELECT @c_CartonItemOptimize = dbo.fnc_GetParamValueFromString('@c_CartonItemOptimize', @c_RLWAV_Opt5, @c_CartonItemOptimize)        

      -- MPOC Order Group
      INSERT INTO #OrderGroup
      (
          OrderKey,
          MPOCFlag,
          OrderGroup
      )
      SELECT DISTINCT PD.OrderKey, '0', ''
      FROM #PICKDETAIL_WIP PD 

      -- Assign MPOC Flag
      IF @n_continue IN(1,2) 
      BEGIN      
         DECLARE CUR_MPOCFLAG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT OrderKey
         FROM #OrderGroup OG
      
         OPEN CUR_MPOCFLAG
      
         FETCH NEXT FROM CUR_MPOCFLAG INTO @c_Orderkey
      
         WHILE @@FETCH_STATUS = 0
         BEGIN
             EXEC dbo.msp_GetMPOCRequired 
                @c_OrderKey =@c_Orderkey,
                @n_MPOCFlag =@n_MPOCFlag OUTPUT,
                @b_Success = 1,
                @n_Err = @n_Err OUTPUT,
                @c_ErrMsg = @c_ErrMsg OUTPUT,
                @b_debug = @b_debug
      
            IF @b_debug>0
            BEGIN
              PRINT 'OrderKey: ' + @c_OrderKey + ' MPOC Flag: ' + CAST(@n_MPOCFlag as VARCHAR(5))
            END
            
             -- None MPOC Order, Pack by OrderKey
            --IF @n_MPOCFlag = 1   --WL05
            IF @n_MPOCFlag > 0   --WL05
            BEGIN
               UPDATE #OrderGroup
               SET MPOCFlag = CAST(@n_MPOCFlag AS CHAR(1))
               WHERE OrderKey = @c_Orderkey
            END

            FETCH NEXT FROM CUR_MPOCFLAG INTO @c_Orderkey
         END      
         CLOSE CUR_MPOCFLAG
         DEALLOCATE CUR_MPOCFLAG
      END -- IF @n_continue IN(1,2)

      --Cartonization info
      INSERT INTO #CARTONIZATION (CartonizationGroup,
                                  CartonType,
                                  UseSequence,
                                  Cube,
                                  MaxWeight,
                                  MaxCount,
                                  MaxSku,
                                  CartonLength,
                                  CartonWidth,
                                  CartonHeight,
                                  IsGeneric)   --WL01
      SELECT CZ.CartonizationGroup, CZ.CartonType, CZ.UseSequence,
             CASE WHEN ISNULL(CZ.CartonLength,0) * ISNULL(CZ.CartonWidth,0) * ISNULL(CZ.CartonHeight,0) > 0 THEN
                       CZ.CartonLength * CZ.CartonWidth * CZ.CartonHeight
                  ELSE CZ.Cube  
             END * (CASE WHEN ISNULL(CZ.FillTolerance,0) = 0 THEN 1 ELSE CZ.FillTolerance * 0.01 END ) AS  [Cube],
             CZ.MaxWeight,
             CASE WHEN CZ.MaxCount = 0 THEN 9999999 ELSE CZ.MaxCount END AS [MaxCount],
             9999999 AS[MaxSku],
             ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0), 1   --WL01
      FROM dbo.CARTONIZATION CZ (NOLOCK)                                                                       
      WHERE CZ.CartonizationGroup = @c_CartonGroup         
      
      IF @b_debug = 1
        SELECT * FROM #CARTONIZATION    

      --WL01 S
      --For VAS CartonType
      INSERT INTO #CARTONIZATION (CartonizationGroup,
                                  CartonType,
                                  UseSequence,
                                  Cube,
                                  MaxWeight,
                                  MaxCount,
                                  MaxSku,
                                  CartonLength,
                                  CartonWidth,
                                  CartonHeight,
                                  IsGeneric)
      SELECT CZ.CartonizationGroup, CZ.CartonType, CZ.UseSequence,
             CASE WHEN ISNULL(CZ.CartonLength,0) * ISNULL(CZ.CartonWidth,0) * ISNULL(CZ.CartonHeight,0) > 0 THEN
                       CZ.CartonLength * CZ.CartonWidth * CZ.CartonHeight
                  ELSE CZ.Cube  
             END * (CASE WHEN ISNULL(CZ.FillTolerance,0) = 0 THEN 1 ELSE CZ.FillTolerance * 0.01 END ) AS  [Cube],
             CZ.MaxWeight,
             CASE WHEN CZ.MaxCount = 0 THEN 9999999 ELSE CZ.MaxCount END AS [MaxCount],
             9999999 AS[MaxSku],
             ISNULL(CZ.CartonLength,0), ISNULL(CZ.CartonWidth,0), ISNULL(CZ.CartonHeight,0), 0
      FROM dbo.CARTONIZATION CZ (NOLOCK)                                                                       
      WHERE CZ.CartonizationGroup = TRIM(@c_CartonGroup) + 'CUST'
      --WL01 E                                                                                       
                                            
      --Order sku info
      INSERT INTO #ORDERSKU (Orderkey, Storerkey, Sku, TotalQty, TotalCube, TotalQtyPacked, TotalCubePacked, StdCube, Length, Width, Height, OrderGroup, MasterShipmentID)
      SELECT PD.OrderKey, PD.Storerkey, PD.Sku, 
             SUM(PD.Qty) AS TotalQty,
             SUM(PD.Qty * CASE WHEN (SKU.Length * SKU.Width * SKU.Height) > 0 THEN  
                              (SKU.Length * SKU.Width * SKU.Height)
                          ELSE SKU.STDCUBE END) AS TotalCube,     
             0 TotalQtyPacked,
             0 TotalCubePacked,             
             CASE WHEN (SKU.Length * SKU.Width * SKU.Height) > 0 THEN
                  (SKU.Length * SKU.Width * SKU.Height)
             ELSE SKU.STDCUBE END AS StdCube,
             SKU.Length,
             SKU.Width,
             SKU.Height,
             OG.OrderGroup AS OrderGroup,
             '' AS MasterShipmentID
      FROM #PICKDETAIL_WIP PD
      JOIN dbo.LOC (NOLOCK) LOC ON PD.Loc = LOC.Loc
      JOIN dbo.SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN dbo.PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      JOIN #OrderGroup OG ON OG.OrderKey = PD.OrderKey 
      GROUP BY PD.OrderKey, PD.Storerkey, PD.Sku, SKU.Length, SKU.Width, SKU.Height,
               CASE WHEN (SKU.Length * SKU.Width * SKU.Height) > 0 THEN
                  (SKU.Length * SKU.Width * SKU.Height)
               ELSE SKU.STDCUBE END, OG.OrderGroup                
      ORDER BY PD.OrderKey, TotalCube DESC, PD.Sku

      IF @c_Automation = 'Y'                                                       --(Wan01)                                                          
      BEGIN
         UPDATE #ORDERSKU
            SET WCS = 1
         FROM #ORDERSKU os
         JOIN SKUInfo si (NOLOCK) ON  si.Storerkey = os.Storerkey          
                                  AND si.Sku = os.Sku 
         WHERE si.ExtendedField06 = 'sortable' 
         AND   si.ExtendedField07 = 'conveyable'

         UPDATE #ORDERSKU
            SET SoftCartonization = 1
         FROM #ORDERSKU os
         JOIN ORDERS O (NOLOCK) ON O.Orderkey = os.Orderkey
         WHERE O.Ordergroup = '30'
      END

      -- Assign Order Group for MPOC Orders
      -- Group by Orders.Consigneekey, Orders.Billtokey, Orders.Markforkey 
      /* declare variables */
      DECLARE @c_ConsigneeKey NVARCHAR(15),
               @c_BillToKey NVARCHAR(15),
               @c_MarkforKey NVARCHAR(15),
               @c_MPOCOrder  NVARCHAR(25);

      DECLARE CUR_MPOC_GROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT O.ConsigneeKey, O.BillToKey, O.MarkforKey
      FROM #ORDERSKU OS 
      JOIN dbo.ORDERS O WITH (NOLOCK) ON OS.Orderkey = O.OrderKey 
      JOIN #OrderGroup OG ON OG.OrderKey = O.OrderKey 
      WHERE OG.MPOCFlag <> '0'

      OPEN CUR_MPOC_GROUP
      
      FETCH NEXT FROM CUR_MPOC_GROUP INTO @c_ConsigneeKey, @c_BillToKey, @c_MarkforKey
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_MPOCOrder = ''
         SET @b_Success=1
         EXEC dbo.nspg_GetKey @KeyName = N'MPOC',        
                              @fieldlength = 9,              
                              @keystring = @c_MPOCOrder OUTPUT, 
                              @b_Success = @b_Success OUTPUT, 
                              @n_err = @n_err OUTPUT,         
                              @c_errmsg = @c_errmsg OUTPUT  

         IF @c_MPOCOrder<>'' AND @b_Success=1
         BEGIN
            UPDATE OS
            SET OS.OrderGroup='M' + @c_MPOCOrder
            FROM #ORDERSKU OS 
            JOIN dbo.ORDERS O WITH (NOLOCK) ON OS.Orderkey = O.OrderKey
            WHERE OS.OrderGroup=''
            AND O.ConsigneeKey = @c_ConsigneeKey 
            AND O.BillToKey  = @c_BillToKey
            AND O.MarkforKey = @c_MarkforKey            
            
            UPDATE OG
            SET OG.OrderGroup='M' + @c_MPOCOrder
            FROM #OrderGroup OG
            JOIN dbo.ORDERS O WITH (NOLOCK) ON OG.Orderkey = O.OrderKey
            WHERE OG.OrderGroup=''
            AND O.ConsigneeKey = @c_ConsigneeKey 
            AND O.BillToKey  = @c_BillToKey
            AND O.MarkforKey = @c_MarkforKey            
         END

         FETCH NEXT FROM CUR_MPOC_GROUP INTO @c_ConsigneeKey, @c_BillToKey, @c_MarkforKey
      END
      
      CLOSE CUR_MPOC_GROUP
      DEALLOCATE CUR_MPOC_GROUP

      /* declare variables */
      DECLARE @n_OSRowID   INT=0,
              @c_MPOCFlag  CHAR(1) = '',
              @c_MasterShpmntID NVARCHAR(20) = '',
              @c_DepartmentID NVARCHAR(100) = ''
      
      DECLARE CUR_ORDER_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT OS.RowID, OS.Storerkey, OS.Sku, OG.MPOCFlag, ISNULL(OI.Notes, '')
      FROM #ORDERSKU OS 
      JOIN #OrderGroup OG ON OG.OrderKey = OS.OrderKey
      JOIN dbo.OrderInfo OI WITH (NOLOCK) ON OI.OrderKey = OG.OrderKey
      WHERE OG.MPOCFlag <> '0'

      OPEN CUR_ORDER_SKU
      
      FETCH NEXT FROM CUR_ORDER_SKU INTO @n_OSRowID, @c_Storerkey, @c_Sku, @c_MPOCFlag, @c_DepartmentID 
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @c_MasterShpmntID = ''

         IF ISNULL(@c_DepartmentID,'') <> ''
         BEGIN
            SELECT @c_MasterShpmntID = CLK.Short
            FROM dbo.CODELKUP CLK WITH (NOLOCK) 
            WHERE CLK.LISTNAME='MPOCDEP'
            AND CLK.Storerkey = @c_Storerkey 
            AND CLK.Code = @c_DepartmentID 

            IF @c_MasterShpmntID<>''
            BEGIN
               UPDATE #ORDERSKU
                  SET MasterShipmentID = @c_MasterShpmntID
               WHERE RowID = @n_OSRowID
            END
             
         END
         FETCH NEXT FROM CUR_ORDER_SKU INTO @n_OSRowID, @c_Storerkey, @c_Sku, @c_MPOCFlag, @c_DepartmentID 
      END      
      CLOSE CUR_ORDER_SKU
      DEALLOCATE CUR_ORDER_SKU

      IF @b_debug > 0
         SELECT * FROM #ORDERSKU                                                                                           

   END  -- IF @n_continue IN(1,2)

   --------------------------------------------------
   -- Process Cartonization for None MPOC Orders
   --------------------------------------------------
   IF @n_continue IN(1,2) 
   BEGIN
      IF @b_debug=2
      BEGIN
          PRINT '*** Process Cartonization for None MPOC Orders ***'
          PRINT '** Carton Group: ' + @c_CartonGroup 
      END
      DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT OS.Orderkey
       FROM #ORDERSKU OS
         JOIN #OrderGroup OG ON OG.OrderKey = OS.Orderkey
         WHERE OG.MPOCFlag = '0'
       ORDER BY OS.Orderkey
      
      OPEN CUR_ORD
      
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
      BEGIN            
         TRUNCATE TABLE #SKUGROUP

         SET @c_NewCarton = 'Y'
         SET @n_CartonNo = 0
         
         IF @b_debug=2
         BEGIN
            PRINT '---- OrderKey: ' + @c_Orderkey + '  ------'
         END

         --WL02 S
         SET @n_ForceCartonMaxSku = 0
         --SELECT @n_ForceCartonMaxSku = CASE WHEN ORDERINFO03 = 'J05' then 5 ELSE 0 END
         --FROM ORDERINFO (NOLOCK)
         --WHERE OrderKey = @c_Orderkey
         SELECT TOP 1 @n_ForceCartonMaxSku = IIF(WOD.[Type] = 'J05', 5, 0)
         FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
         WHERE WOD.ExternWorkOrderKey = @c_Orderkey
         AND WOD.ExternLineNo = '0H'
         --WL02 E

         -- (SWT01) 
         SET @c_VAS_CartonType=N''
         SELECT TOP 1 
               @c_VAS_CartonType= REPLACE(WOD.Type, 'U', 'RS')   --WL01
         FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
         WHERE WOD.ExternWorkOrderKey = @c_Orderkey
         AND WOD.Remarks='LPNSIZE'   --WL01
         ORDER BY WOD.ExternLineNo   

         -- (SWT02) checking is all SKU can fit into this carton type
         IF @c_VAS_CartonType <> '' 
         BEGIN
            SELECT @n_CartonLength=CZ.CartonLength, 
                   @n_CartonWidth=CZ.CartonWidth,
                   @n_CartonHeight=CZ.CartonHeight,
                   @n_CartonMaxCube=CZ.Cube
            FROM #CARTONIZATION CZ 
            WHERE CZ.CartonType = @c_VAS_CartonType

            IF EXISTS( SELECT 1 FROM #ORDERSKU OS WHERE OS.Orderkey = @c_Orderkey AND OS.StdCube > @n_CartonMaxCube )
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 562204
               SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': SKU(s) Standard Cube cannot fit into carton type ' + RTRIM(@c_VAS_CartonType) + '. (mspRLWAV03)'     
               GOTO QUIT_SP  
            END
         END -- IF @c_VAS_CartonType <> ''      

         --Pack full carton qty, UCC full carton
         IF @n_continue IN(1,2) 
         BEGIN                                         
            DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT OS.RowID, OS.Sku, PD.Qty, PD.DropID, OS.StdCube
            FROM #ORDERSKU OS (NOLOCK)
            JOIN #PickDetail_WIP PD (NOLOCK) ON OS.Orderkey = PD.Orderkey AND OS.Storerkey = PD.Storerkey AND OS.Sku = PD.Sku        
            WHERE OS.Orderkey = @c_Orderkey
            AND PD.UOM = '2'
            AND ISNULL(PD.DropID,'') <> ''
            ORDER BY OS.RowID

            OPEN CUR_UCC
   
            FETCH NEXT FROM CUR_UCC INTO @n_RowID, @c_Sku, @n_PackQty, @c_UCCNo, @n_StdCube
   
            WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
            BEGIN                 
               SET @n_CartonNo = @n_CartonNo + 1            
                     --SWT03 
               INSERT INTO #CARTON (Orderkey, CartonNo, LabelNo, CartonGroup, CartonType, MaxCube, MaxWeight, MaxCount, MaxSku, 
                                    CartonLength, CartonWidth, CartonHeight, UCCNo, OrderGroup, VASCartonType)
               VALUES (@c_Orderkey, @n_CartonNo, '', @c_CartonGroup, '9999', 0, 0, 0, 0, 0, 0, 0, @c_UCCNo, '', '') --ALiang01 hardcode 9999 for carton type                                 
            
               INSERT INTO #CARTONDETAIL (OrderGroup, Orderkey, Storerkey, Sku, CartonNo, Qty, RowRef)  --refer to ORDERSKU.RowID
               VALUES ('', @c_Orderkey, @c_Storerkey, @c_Sku, @n_CartonNo, @n_PackQty, @n_RowID) 
                           
               UPDATE #ORDERSKU 
               SET TotalQtyPacked = TotalQtyPacked + @n_PackQty, 
                  TotalCubePacked = TotalCubePacked + (@n_PackQty * @n_StdCube)
               WHERE RowID = @n_RowID                    
                           
               FETCH NEXT FROM CUR_UCC INTO @n_RowID, @c_Sku, @n_PackQty, @c_UCCNo, @n_StdCube
            END
            CLOSE CUR_UCC
            DEALLOCATE CUR_UCC                                                                                      
         END -- IF @n_continue IN(1,2) 
         
         IF @b_debug=2
         BEGIN         
            IF EXISTS(SELECT 1 FROM #CARTONDETAIL)
            BEGIN
               PRINT '*** Full Carton '
               SELECT * 
               FROM  #CARTONDETAIL
               Where Orderkey = @c_Orderkey 
            END 
         END 

         /**************************************************/
         --      Pack loose carton
         /**************************************************/
         SET @c_NewCarton = 'Y'

         INSERT INTO #SKUGroup (SkuGroup, ItemClass, TotalCube, WCS)                --(Wan01)
         SELECT SKU.SKUGROUP, 
                  SKU.ItemClass,
                  SUM(SKU.STDCUBE * (O.TotalQty - O.TotalQtyPacked))
               ,  o.WCS                                                             --(Wan01)
         FROM #ORDERSKU O
         JOIN dbo.SKU SKU WITH (NOLOCK) ON O.Storerkey = SKU.StorerKey AND O.Sku = SKU.Sku
         WHERE O.Orderkey = @c_Orderkey
            AND O.TotalQty - O.TotalQtyPacked > 0
         GROUP BY SKU.SKUGROUP, SKU.ItemClass, O.WCS                                --(Wan01)      

         SELECT @n_OrderCube = SUM(O.TotalCube - O.TotalCubePacked)
         FROM #ORDERSKU O
         WHERE O.Orderkey = @c_Orderkey
         AND O.TotalQty - O.TotalQtyPacked > 0
           
         DECLARE CUR_ORDCTNGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.Sku,
                SUM(O.TotalQty - O.TotalQtyPacked), 
                O.Length,
                O.Width,
                O.Height, 
                O.StdCube, 
                SKU.SKUGROUP, 
                SKU.ItemClass
               ,O.WCS                                                               --(Wan01)
         FROM #ORDERSKU O
         JOIN dbo.SKU SKU WITH (NOLOCK) ON O.Storerkey = SKU.StorerKey AND O.Sku = SKU.Sku
         WHERE O.Orderkey = @c_Orderkey
           AND O.TotalQty - O.TotalQtyPacked > 0
           AND O.WCS = 0                                                            --(Wan01)
           --AND O.SoftCartonization = 0                                              --(Wan01) (SSA02)
         GROUP BY O.Sku,
                  O.Length,
                  O.Width,
                  O.Height,
                  O.StdCube, 
                SKU.SKUGROUP, 
                SKU.ItemClass
                , O.WCS                                                             --(Wan01)
         ORDER BY SKU.SKUGROUP, SKU.ItemClass, O.WCS, O.Sku;                        --(Wan01)
         
         OPEN CUR_ORDCTNGROUP
         
         FETCH NEXT FROM CUR_ORDCTNGROUP INTO @c_Sku, @n_OrderQty, @n_SKULength, @n_SKUWidth, @n_SKUHeight, @n_StdCube, @c_SkuGroup, @c_ItemClass 
                                             ,@b_WCS                                --(Wan01)
         
         SET @n_CartonNo = 0         
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --pack by order
         BEGIN        
            SELECT @n_VAS_LineCount = 0
            SELECT @n_VAS_QtyCanPack = 0   --WL01

            SELECT @n_VAS_LineCount = COUNT(1) 
            FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
            JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
            WHERE WOD.ExternWorkOrderKey = @c_Orderkey
            AND OD.Sku = @c_Sku
            AND WOD.Type IN ('S02','S06')

            --SWT03 
            -- @b_MDS_Flag
            IF EXISTS(SELECT 1
                     FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
                     JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
                     WHERE WOD.ExternWorkOrderKey = @c_Orderkey
                     AND OD.Sku = @c_Sku
                     AND WOD.Type = 'MDS')
               SET @b_MDS_Flag = 1
            ELSE
               SET @b_MDS_Flag = 0

            IF @n_VAS_LineCount = 1
            BEGIN
               SET @c_NewCarton = 'Y'

               SELECT @n_VAS_QtyCanPack = WOD.Qty 
               FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
               JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
               WHERE WOD.ExternWorkOrderKey = @c_Orderkey
               AND OD.Sku = @c_Sku
               AND WOD.Type IN ('S02','S06')   --WL01
            END
            ELSE IF @n_VAS_LineCount > 1
            BEGIN
               SET @c_NewCarton = 'Y'

               SELECT @n_VAS_QtyCanPack = WOD.Qty 
               FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
               JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
               WHERE WOD.ExternWorkOrderKey = @c_Orderkey
               AND OD.Sku = @c_Sku
               AND WOD.Type = 'S02'                 
            END
         
            SELECT TOP 1 @c_OrderGroup = O.OrderGroup
            FROM dbo.ORDERS O WITH (NOLOCK) 
            WHERE OrderKey = @c_Orderkey

            /* FCR-243 OrderGroup 30 Roles*/
            --IF @c_OrderGroup='30' AND @c_NewCarton='N'
            IF @c_NewCarton='N'
            BEGIN
               -- If Current Carton SKU Group and Item Class not match to current SKU. Pack to new carton
               IF NOT EXISTS(SELECT 1 FROM #CARTONDETAIL CTD 
                             JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.StorerKey = CTD.Storerkey AND SKU.Sku = CTD.Sku
                             JOIN #ORDERSKU os ON os.StorerKey = CTD.Storerkey      --(Wan01)
                                               AND os.Sku = CTD.Sku                 --(Wan01)   
                             WHERE SKU.SKUGROUP = @c_SkuGroup AND SKU.ItemClass = @c_ItemClass
                             AND CTD.CartonNo = @n_CartonNo AND CTD.Orderkey = @c_Orderkey
                             AND os.WCS = @b_WCS                                    --(Wan01)
                             )
               BEGIN
                   SET @c_NewCarton='Y'
               END
            END 
            -- IF ORDERINFO03 > 0, Force to pack to new carton if SKU count >= ORDERINFO03
            IF @n_ForceCartonMaxSku > 0
            BEGIN
               IF (SELECT COUNT(DISTINCT SKU) FROM #CARTONDETAIL WHERE Orderkey = @c_Orderkey AND CartonNo = @n_CartonNo) >= @n_ForceCartonMaxSku
               BEGIN
                  SET @c_NewCarton = 'Y'

                  IF @b_debug=2
                     PRINT 'ForceCartonMaxSku: ' + CAST(@n_ForceCartonMaxSku AS VARCHAR(20)) 
               END
            END

            WHILE 1=1 AND @n_continue IN(1,2) AND @n_OrderQty > 0
            BEGIN    
               SELECT @n_QtyCanPackByCube = 0, @n_QtyCanPackByCount = 0, @n_QtyCanPack = 0

               --SELECT @n_OrderCube = @n_OrderQty * @n_StdCube

               IF @b_debug=2
               BEGIN
                  PRINT 'NewCarton: ' + @c_NewCarton + ' Order Qty: ' +CAST(@n_OrderQty AS VARCHAR(20)) + ' Order Cube: ' + CAST(@n_OrderCube AS VARCHAR(20)) 
                        + ' StdCube: ' + CAST(@n_StdCube AS VARCHAR(20)) 
               END
               
               IF @c_NewCarton = 'Y' --new carton
               BEGIN             
                  SELECT @n_CartonMaxCube = 0, @n_CartonMaxCount = 0, @n_CartonMaxWeight = 0, @c_NewCarton = 'N', @n_CartonNo = 0, @c_CartonType = ''
                  SELECT @n_CartonLength = 0, @n_CartonWidth = 0, @n_CartonHeight = 0, @n_CartonRemainCube=0   
                  
                  IF @n_VAS_QtyCanPack > 0 
                  BEGIN
                     SET @c_NewCarton = 'Y'   --WL01

                     IF @b_debug=2 PRINT 'VAS_QtyCanPack > 0, Ner Carton'
                  END 
                  SELECT @n_CartonNo = MAX(CartonNo)
                  FROM #CARTON
                  WHERE Orderkey = @c_Orderkey
                    
                  SET @n_CartonNo = ISNULL(@n_CartonNo,0)
                                                
                  SET @n_CartonNo = @n_CartonNo + 1
                    
                  -- Getting Right Carton Type by LWH and Cube (SWT01)
                  IF @c_VAS_CartonType <> ''
                  BEGIN
                     SET @c_CartonType = @c_VAS_CartonType

                     -- (SWT02) Check if SKU LxWxH can fit into the carton type
                     SELECT @c_CartonType=CZ.CartonType, @n_CartonLength=CZ.CartonLength, 
                            @n_CartonWidth=CZ.CartonWidth, @n_CartonHeight=CZ.CartonHeight                              
                     FROM #CARTONIZATION CZ 
                     WHERE CZ.CartonType = @c_VAS_CartonType
                  
                     IF dbo.fnc_CartonCanFit(@n_SKULength, @n_SKUWidth, @n_SKUHeight, @n_CartonLength, @n_CartonWidth, @n_CartonHeight) = 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 562204
                        SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': SKU(s) LxWxH cannot fit into carton type ' + RTRIM(@c_VAS_CartonType) + '. (mspRLWAV03)'     
                        GOTO QUIT_SP
                     END;
                  END
                  IF @c_CartonType = N''
                  BEGIN
                     TRUNCATE TABLE #CTNTRACK

                     WHILE 1=1 AND @n_continue IN(1,2) 
                     BEGIN
                        SET @c_CartonType = N''
                        
                        --WL01 S
                        --WITH MDS - 30 Qty per Line, S02/S06 = 10, 10 Qty/ctn, total 3 CTNs, no remainder
                        --NOT MDS  - 30 Qty per Line, S02/S06 = 8, 3 Cartons - 8 Qty, 1 Carton - 6 Qty total 4 CTNs, with remainder
                        IF @n_VAS_QtyCanPack > 0
                        BEGIN
                           SELECT TOP 1
                                     @n_CTNRowID = RowID,
                                     @c_CartonType = CZ.CartonType,
                                     @n_CartonLength = CZ.CartonLength,
                                     @n_CartonWidth = CZ.CartonWidth,
                                     @n_CartonHeight = CZ.CartonHeight
                           FROM #CARTONIZATION CZ
                           WHERE CZ.Cube >= (@n_StdCube * IIF(@n_OrderQty >= @n_VAS_QtyCanPack, @n_VAS_QtyCanPack, @n_OrderQty) )
                           AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID)
                           AND CZ.IsGeneric = 1
                           ORDER BY CZ.Cube;

                           IF @b_Debug = 10
                              SELECT 'VAS Qty', (@n_StdCube * IIF(@n_OrderQty >= @n_VAS_QtyCanPack, @n_VAS_QtyCanPack, @n_OrderQty) ), @c_SKU, @n_OrderQty
                        END

                        IF @c_CartonType = N'' --WL01 E Pick Carton that can fit the order cube
                        SELECT TOP 1
                                 @n_CTNRowID = RowID,
                                 @c_CartonType = CZ.CartonType,
                                 @n_CartonLength = CZ.CartonLength,
                                 @n_CartonWidth = CZ.CartonWidth,
                                 @n_CartonHeight = CZ.CartonHeight
                        FROM #CARTONIZATION CZ
                        WHERE CZ.Cube >= @n_OrderCube
                        AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID)
                        AND CZ.IsGeneric = 1   --WL01
                        ORDER BY CZ.Cube;
                        -- Pick carton type that can fit the entire SKU Group total Cude
                        IF @c_CartonType = N''
                        BEGIN
                           SET @n_SKUGroupCube = 0

                           SELECT @n_SKUGroupCube = TotalCube 
                           FROM #SKUGROUP 
                           WHERE SkuGroup = @c_SkuGroup 
                           and ItemClass = @c_ItemClass
                           AND WCS       = @b_WCS                                   --(Wan01)

                           IF @b_debug=2
                           BEGIN
                              PRINT ' SKUGroup Cube: ' + CAST(@n_SKUGroupCube AS VARCHAR(20)) 
                                      + ' Sku Group: ' + @c_SkuGroup + ' Item Class: ' + @c_ItemClass 
                              SELECT * FROM #SKUGROUP
                           END

                           IF @n_SKUGroupCube > 0 
                           BEGIN
                              SELECT TOP 1 @n_CTNRowID = RowID,
                                 @c_CartonType= CZ.CartonType, 
                                 @n_CartonLength=CZ.CartonLength, 
                                 @n_CartonWidth=CZ.CartonWidth, 
                                 @n_CartonHeight=CZ.CartonHeight 
                              FROM #CARTONIZATION CZ 
                              WHERE CZ.Cube >= @n_SKUGroupCube
                              AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID) 
                              AND CZ.IsGeneric = 1   --WL01
                              ORDER BY CZ.Cube DESC 
                           END 
                        END
                        -- If can't find carton can fit SKU Group Cube, 
                        -- Pick other carton that can fit the SKU Standard Cude
                        IF @c_CartonType = N''
                        BEGIN
                           SELECT TOP 1 @n_CTNRowID = RowID,
                              @c_CartonType= CZ.CartonType, @n_CartonLength=CZ.CartonLength, 
                              @n_CartonWidth=CZ.CartonWidth, @n_CartonHeight=CZ.CartonHeight 
                           FROM #CARTONIZATION CZ 
                           WHERE CZ.Cube >= @n_StdCube
                           AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID) 
                           AND CZ.IsGeneric = 1   --WL01
                           ORDER BY CZ.Cube DESC 
                        END
                        IF @c_CartonType=N'' 
                        BEGIN
                            SET @n_OrderQty=0;
                            IF @b_debug=2
                            BEGIN
                               PRINT 'Cannot find any carton type can fit. Order No: ' + @c_Orderkey
                               --SELECT * FROM #CARTONIZATION CZ
                               --SELECT * FROM #CTNTRACK C  
                            END 
                            BREAK;
                        END
                        ELSE
                           BREAK;
                        -- Do not check L,W and H
                        -- IF dbo.fnc_CartonCanFit(@n_SKULength, @n_SKUWidth, @n_SKUHeight, @n_CartonLength, @n_CartonWidth, @n_CartonHeight) = 1
                        -- BEGIN                           
                        --    BREAK
                        -- END
                        -- ELSE 
                        -- BEGIN
                        --    IF @b_debug=2
                        --    BEGIN
                        --       PRINT 'Carton Type: ' + @c_CartonType + ' Can''t Fit'
                        --       PRINT 'SKU Length: ' + CAST(@n_SKULength AS VARCHAR(20)) + ' SKU Width: ' + CAST(@n_SKUWidth AS VARCHAR(20)) + ' SKU Height: ' + CAST(@n_SKUHeight AS VARCHAR(20))  
                        --       + ' Carton Length: ' + CAST(@n_CartonLength AS VARCHAR(20)) + ' Carton Width: ' + CAST(@n_CartonWidth AS VARCHAR(20)) + ' Carton Height: ' + CAST(@n_CartonHeight AS VARCHAR(20)) 
                        --    END 
                        --    SET @c_CartonType = N''
                        -- END 

                        INSERT INTO #CTNTRACK VALUES (@n_CTNRowID)
                     END -- WHILE 1=1
                  END -- IF @c_CartonType = N''
                                       
                  IF @c_CartonType = ''
                  BEGIN
                     SET @n_OrderQty=0

                     SET @n_continue = 3
                     SET @n_Err = 562204
                     SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Unable to find Carton type for Order: ' + RTRIM(@c_Orderkey) + '.(mspRLWAV03)'

                     IF @b_debug=2
                        PRINT @c_Errmsg

                     BREAK                 
                  END                                           
                   
                  --Get carton setup
                  SELECT @n_CartonMaxCube = CZ.Cube,
                        @n_CartonRemainCube = CZ.Cube,
                        @n_CartonMaxWeight = CZ.MaxWeight,
                        @n_CartonMaxCount = CZ.MaxCount,
                        @n_CartonMaxSku = CZ.MaxSku
                  FROM #CARTONIZATION CZ (NOLOCK)
                  WHERE CZ.CartonType = @c_CartonType

                  -- SWT03
                  INSERT INTO #CARTON (Orderkey, CartonNo, LabelNo, CartonGroup, CartonType, MaxCube, MaxWeight, MaxCount, 
                                       MaxSku, CartonLength, CartonWidth, CartonHeight, UCCNo, OrderGroup, VASCartonType)
                  VALUES (@c_Orderkey, @n_CartonNo, '', @c_CartonGroup, @c_CartonType, @n_CartonMaxCube, @n_CartonMaxWeight, 
                         @n_CartonMaxCount, @n_CartonMaxSku, @n_CartonLength , @n_CartonWidth, @n_CartonHeight, '', '', @c_VAS_CartonType)  
               END -- IF @c_NewCarton = 'Y'
               
               IF @b_debug=2
               BEGIN
                     PRINT 'Carton No: ' + CAST(@n_CartonNo As varchar(10)) + ' Carton Type: ' + @c_CartonType + ' Max Cube: ' + CAST(@n_CartonMaxCube AS VARCHAR(20))
               END

               --Get item to pack
               TRUNCATE TABLE #ROWTRACK

               --Try search all items of the order that can fit the remaining space of the carton, priority by Sku 
               WHILE @n_QtyCanPack = 0 AND @n_continue IN(1,2)  
               BEGIN                   
                  SET @n_RowID = 0                    

                  IF EXISTS(SELECT 1 FROM #CARTONDETAIL WHERE CartonNo = @n_CartonNo AND Orderkey = @c_Orderkey)
                  BEGIN
                     IF @b_debug=2
                     BEGIN
                        PRINT '-- Exists in Carton Detail'
                        PRINT '-- CartonRemainCube: ' + CAST(@n_CartonRemainCube as VARCHAR(20)) + ', @n_StdCube: ' + CAST(@n_StdCube as VARCHAR(20))
                     END

                     IF @c_VAS_CartonType <> '' -- (SWT01) 
                     BEGIN
                        --Get the SKU remaining Qty regardless of Volume
                        SELECT TOP 1 @n_RowID = OS.RowID,                           
                              @n_StdCube = OS.StdCube,
                              @n_PackQty = OS.TotalQty - OS.TotalQtyPacked
                        FROM #ORDERSKU OS (NOLOCK)
                        WHERE OS.Orderkey = @c_Orderkey
                        AND OS.TotalQty - OS.TotalQtyPacked > 0
                        AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)
                        AND OS.Sku = @c_Sku
                        ORDER BY (OS.TotalCube - OS.TotalCubePacked) DESC, OS.Sku
                     END

                     IF @n_RowID = 0
                     BEGIN
                        --Get the sku can fully best fit in the existing carton
                        SELECT TOP 1 @n_RowID = OS.RowID,                           
                              @n_StdCube = OS.StdCube,
                              @n_PackQty = OS.TotalQty - OS.TotalQtyPacked
                        FROM #ORDERSKU OS (NOLOCK)
                        WHERE OS.Orderkey = @c_Orderkey
                        AND OS.TotalQty - OS.TotalQtyPacked > 0
                        AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)
                        AND @n_CartonRemainCube >= (OS.TotalCube - OS.TotalCubePacked)
                        AND OS.Sku = @c_Sku
                        ORDER BY (OS.TotalCube - OS.TotalCubePacked) DESC, OS.Sku
                     END  
                     IF @n_RowID = 0
                     BEGIN
                       --Get the smaller cube of the sku mix with existing carton 
                       SELECT TOP 1 @n_RowID = OS.RowID,
                             @n_StdCube = OS.StdCube,
                             @n_PackQty = OS.TotalQty - OS.TotalQtyPacked
                       FROM #ORDERSKU OS (NOLOCK)
                       WHERE OS.Orderkey = @c_Orderkey
                       AND OS.TotalQty - OS.TotalQtyPacked > 0
                       AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)
                       AND OS.StdCube <= @n_CartonRemainCube
                       AND OS.Sku = @c_Sku
                       ORDER BY (OS.TotalCube - OS.TotalCubePacked), OS.Sku                         
                     END    
                      
                 END
                 ELSE
                 BEGIN
                     --Get the sku by larger cube sequence to the new carton
                     SELECT TOP 1 @n_RowID = OS.RowID,
                           @c_Sku = OS.Sku,
                           @n_StdCube = OS.StdCube,
                           @n_PackQty = OS.TotalQty - OS.TotalQtyPacked
                     FROM #ORDERSKU OS (NOLOCK)
                     WHERE OS.Orderkey = @c_Orderkey
                     AND OS.TotalQty - OS.TotalQtyPacked > 0
                     AND OS.Sku = @c_Sku
                     AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)
                     ORDER BY OS.RowID
                  END                                                                   

                  IF @b_debug=2
                  BEGIN
                        PRINT 'SKU: ' + @c_Sku + ' StdCube: ' + CAST(@n_StdCube AS VARCHAR(20)) 
                     + ' Pack Qty: ' + CAST(@n_PackQty AS VARCHAR(20)) + ' Row ID: ' + CAST(@n_RowID AS VARCHAR(20))
                  END
          
                  -- No outstanding Item to pack, go to next order
                  IF @n_RowID = 0
                  BEGIN
                     -- PRINT '-- @n_RowID = 0'
                      SET @n_QtyCanPack = 0;

                      IF @c_NewCarton = 'Y'
                          SET @n_OrderQty = 0;

                      BREAK;
                  END;

                  INSERT INTO #ROWTRACK(RowID) VALUES (@n_RowID)
                                       
                  --Validate the carton at lease can fit 1 qty of the sku
                  IF NOT EXISTS(SELECT 1 FROM #CARTONIZATION WHERE Cube >= @n_StdCube AND CartonType = @c_CartonType) 
                  BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 562205
                     SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': No Carton type can fit a Sku ' + RTRIM(@c_Sku) + '.(mspRLWAV03)'

                     IF @b_debug=2
                     BEGIN
                        PRINT 'Error: ' + @c_Errmsg
                     END

                     BREAK
                  END                
                  -- (SWT01) Do not check total cube is VAS Carton Type is set
                  -- (SWT02) Still need to check total cube if VAS Carton Type is set
                  -- IF @c_VAS_CartonType <> ''
                  -- BEGIN
                  --    SET @n_QtyCanPack = @n_PackQty 
                  -- END 
                  -- ELSE 
                  -- BEGIN
                     IF @n_StdCube > 0
                     BEGIN 
                        SET @n_QtyCanPackByCube = FLOOR(@n_CartonRemainCube / @n_StdCube)  
                        SET @n_QtyCanPack = @n_QtyCanPackByCube 
                     END 
                     ELSE 
                        SET @n_QtyCanPack = @n_PackQty                   
                  -- END 
                 
                  IF @n_VAS_QtyCanPack > 0
                  BEGIN
                     IF @n_QtyCanPack > @n_VAS_QtyCanPack
                        SET @n_QtyCanPack = @n_VAS_QtyCanPack
                  END

                  IF @n_StdCube = 0  --if sku cube not setup just pack all qty
                    SET @n_QtyCanPack = @n_PackQty                                             
                                      
                  IF @n_PackQty < @n_QtyCanPack
                    SET @n_QtyCanPack = @n_PackQty
                 
                  IF @b_debug=2
                  BEGIN
                      PRINT '>>> QtyCanPackByCube: ' + CAST(@n_QtyCanPackByCube AS VARCHAR(10)) + ' QtyCanPack: ' 
                       + CAST(@n_QtyCanPack AS VARCHAR(10)) + ' Remain Cube: ' + CAST(@n_CartonRemainCube AS VARCHAR(20))
                  END

                  -- SWT03 
                  IF @n_QtyCanPack <> @n_VAS_QtyCanPack and @b_MDS_Flag = 1 and @n_VAS_QtyCanPack > 0
                  BEGIN 
                     SET @n_continue = 3
                     SET @n_Err = 562206
                     SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Pack Qty not match with VAS Qty for MDS VAS Code. (mspRLWAV03)'

                     IF @b_debug=2
                     BEGIN
                        PRINT 'Error: ' + @c_Errmsg
                     END

                     BREAK
                  END

                  IF @c_CartonItemOptimize <> 'Y'
                    BREAK --if current item cannot fit current carton open new carton and not search for other/next item. 
               END -- WHILE @n_QtyCanPack = 0 
                                
               IF @n_continue = 3
                  BREAK
                   
               IF @n_QtyCanPack = 0  --carton full 
               BEGIN
                  IF @b_debug=2
                     PRINT '>>> QtyCanPack = 0,New Carton = Y, OrderQty=' + CAST(@n_OrderQty as varchar(10))

                  SET @c_NewCarton = 'Y'
               END
               ELSE
               BEGIN                                      
                  --Pack to Carton
                  INSERT INTO #CARTONDETAIL (OrderGroup, Orderkey, Storerkey, Sku, CartonNo, Qty, RowRef)  --refer to ORDERSKU.RowID
                  VALUES ('', @c_Orderkey, @c_Storerkey, @c_Sku, @n_CartonNo, @n_QtyCanPack, @n_RowID) 
                
                  --Update counters
                  SET @n_OrderCube = @n_OrderCube - (@n_QtyCanPack * @n_StdCube)
                  SET @n_OrderQty = @n_OrderQty - @n_QtyCanPack
                  SET @n_CartonRemainCube = @n_CartonRemainCube - (@n_QtyCanPack * @n_StdCube)       
                         
                  UPDATE #ORDERSKU
                  SET TotalQtyPacked = TotalQtyPacked + @n_QtyCanPack, 
                     TotalCubePacked = TotalCubePacked + (@n_QtyCanPack * @n_StdCube)
                  WHERE RowID = @n_RowID 
               END 
            END -- WHILE @n_OrderQty > 0

            NEXT_CTNORSKU:     

            FETCH NEXT FROM CUR_ORDCTNGROUP INTO @c_Sku, @n_OrderQty, @n_SKULength, @n_SKUWidth, @n_SKUHeight, @n_StdCube, @c_SkuGroup, @c_ItemClass 
                                             ,   @b_WCS                             --(Wan01)
         END
         CLOSE CUR_ORDCTNGROUP
         DEALLOCATE CUR_ORDCTNGROUP

         FETCH_ORDER:
         FETCH NEXT FROM CUR_ORD INTO @c_Orderkey       
      END
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END -- No MPOC Orders  

   --------------------------------------------------
   -- Process Cartonization for MPOC Orders
   --------------------------------------------------   
   IF @n_continue IN(1,2) 
   BEGIN
      IF @b_debug=3
      BEGIN
          PRINT '*** Process Cartonization for MPOC Orders ***'
          PRINT '** Carton Group: ' + @c_CartonGroup 
      END

      DECLARE CUR_MPOC_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT OG.OrderGroup
       FROM #ORDERSKU OG
        WHERE OG.OrderGroup > ''
       ORDER BY OG.OrderGroup
      
      OPEN CUR_MPOC_ORD
      
      FETCH NEXT FROM CUR_MPOC_ORD INTO @c_OrderGroup
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
      BEGIN            
         TRUNCATE TABLE #SKUGROUP
                  
         SET @c_NewCarton = 'Y'
         SET @n_CartonNo = 0

         IF @b_debug=3
         BEGIN
             PRINT '---- OrderGroup: ' + @c_OrderGroup + '  ------'
         END
         
         -- Getting Force Carton Maximun SKU 
         SET @n_ForceCartonMaxSku = 0
         IF EXISTS(
            SELECT 1 FROM dbo.WorkOrderDetail WOD WITH (NOLOCK)
            JOIN #ORDERSKU OG ON OG.OrderKey = WOD.ExternWorkOrderKey 
            WHERE WOD.ExternLineNo = '0H' AND WOD.[Type] = 'J05'
            AND OG.OrderGroup = @c_OrderGroup)
         BEGIN
            SET @n_ForceCartonMaxSku = 5
         END 

         SET @c_VAS_CartonType=N''
         SELECT TOP 1 
               @c_VAS_CartonType= REPLACE(WOD.Type, 'U', 'RS')   --WL01
         FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
         JOIN #ORDERSKU OG ON OG.OrderKey = WOD.ExternWorkOrderKey
         WHERE OG.OrderGroup = @c_OrderGroup
         AND WOD.Remarks='LPNSIZE'    
         ORDER BY WOD.ExternLineNo            

         IF @c_VAS_CartonType <> '' 
         BEGIN
            SELECT @n_CartonLength=0, 
                   @n_CartonWidth=0,
                   @n_CartonHeight=0,
                   @n_CartonMaxCube=0

            SELECT @n_CartonLength=CZ.CartonLength, 
                   @n_CartonWidth=CZ.CartonWidth,
                   @n_CartonHeight=CZ.CartonHeight,
                   @n_CartonMaxCube=CZ.Cube
            FROM #CARTONIZATION CZ 
            WHERE CZ.CartonType = @c_VAS_CartonType

            IF EXISTS( SELECT 1 FROM #ORDERSKU OS 
                      WHERE OS.OrderGroup = @c_OrderGroup 
                      AND OS.StdCube > @n_CartonMaxCube )
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 562204
               SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': SKU(s) Standard Cube cannot fit into carton type ' + RTRIM(@c_VAS_CartonType) + '. (mspRLWAV03)'     
               GOTO QUIT_SP  
            END
         END -- IF @c_VAS_CartonType <> ''  

         --pack UCC full carton qty
         IF @n_continue IN(1,2) 
         BEGIN                                         
            DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT OS.RowID, OS.Sku, PD.Qty, PD.DropID, OS.StdCube, OS.Orderkey    
               FROM #ORDERSKU OS (NOLOCK)
               JOIN #PickDetail_WIP PD (NOLOCK) ON OS.Orderkey = PD.Orderkey AND OS.Storerkey = PD.Storerkey AND OS.Sku = PD.Sku        
               WHERE OS.OrderGroup = @c_OrderGroup
               AND PD.UOM = '2'
               AND ISNULL(PD.DropID,'') <> ''
               ORDER BY OS.RowID

            OPEN CUR_UCC
      
            FETCH NEXT FROM CUR_UCC INTO @n_RowID, @c_Sku, @n_PackQty, @c_UCCNo, @n_StdCube, @c_Orderkey
      
            WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
            BEGIN                
               SET @n_CartonNo = @n_CartonNo + 1            

               -- SWT03
               INSERT INTO #CARTON (Orderkey, CartonNo, LabelNo, CartonGroup, CartonType, MaxCube, MaxWeight, 
                           MaxCount, MaxSku, CartonLength, CartonWidth, CartonHeight, UCCNo, OrderGroup, VASCartonType)
               VALUES ('', @n_CartonNo, '', @c_CartonGroup, '9999', 0, 0, 0, 0, 0, 0, 0, @c_UCCNo, @c_OrderGroup, '')  --ALiang01 hardcode 9999 for carton type   --WL07
               
               INSERT INTO #CARTONDETAIL (OrderGroup, Orderkey, Storerkey, Sku, CartonNo, Qty, RowRef)  --refer to ORDERSKU.RowID
               VALUES (@c_OrderGroup, @c_Orderkey, @c_Storerkey, @c_Sku, @n_CartonNo, @n_PackQty, @n_RowID)
                              
               UPDATE #ORDERSKU 
               SET TotalQtyPacked = TotalQtyPacked + @n_PackQty, 
                  TotalCubePacked = TotalCubePacked + (@n_PackQty * @n_StdCube)
               WHERE RowID = @n_RowID                    
                              
               FETCH NEXT FROM CUR_UCC INTO @n_RowID, @c_Sku, @n_PackQty, @c_UCCNo, @n_StdCube, @c_Orderkey
            END -- While
            CLOSE CUR_UCC
            DEALLOCATE CUR_UCC                                                                                      
         END -- continue = 1 pack UCC full carton qty

         /**************************************************/
         --      Pack loose carton for MPOC
         /**************************************************/

         SET @c_NewCarton = 'Y'

         SELECT @n_OrderCube = SUM(O.TotalCube - O.TotalCubePacked)
         FROM #ORDERSKU O
         WHERE O.OrderGroup = @c_OrderGroup
         AND O.TotalQty - O.TotalQtyPacked > 0

         DECLARE CUR_MPOC_ORDCTNGROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.StdCube,   --WL07
                SUM(O.TotalQty - O.TotalQtyPacked),
                O.Sku,
                O.Length,
                O.Width,
                O.Height, 
                O.MasterShipmentID, 
                SKU.SKUGROUP, 
                SKU.ItemClass 
            ,   O.WCS                                                               --(Wan01)
         FROM #ORDERSKU O
         JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.StorerKey = O.Storerkey AND SKU.Sku = O.Sku
         WHERE O.OrderGroup = @c_OrderGroup
            AND O.TotalQty - O.TotalQtyPacked > 0
            AND O.WCS = 0        --(SSA02)
         GROUP BY O.Sku,
                  O.Length,
                  O.Width,
                  O.Height, 
                  O.MasterShipmentID, 
                  SKU.SKUGROUP, 
                  SKU.ItemClass
               ,  O.StdCube   --WL07
               ,  O.WCS                                                             --(Wan01)        
         ORDER BY O.MasterShipmentID, O.WCS, O.Sku;                                 --(Wan01)   --WL07
      
         OPEN CUR_MPOC_ORDCTNGROUP
         
         FETCH NEXT FROM CUR_MPOC_ORDCTNGROUP INTO @n_StdCube, @n_OrderQty, @c_Sku, @n_SKULength,   --WL07 
                     @n_SKUWidth, @n_SKUHeight, @c_MasterShpmntID, @c_SkuGroup, @c_ItemClass  
                  ,  @b_WCS                                                         --(Wan01)
         SET @n_CartonNo = 0         
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --pack by order
         BEGIN                        
            SELECT @n_VAS_LineCount = 0
            SELECT @n_VAS_QtyCanPack = 0   --WL01          

            SELECT @n_VAS_LineCount = COUNT(1) 
            FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
            JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
            JOIN #ORDERSKU OS ON OS.OrderKey = WOD.ExternWorkOrderKey 
            WHERE OS.OrderGroup = @c_OrderGroup
            AND OD.Sku = @c_Sku
            AND WOD.Type IN ('S02','S06')

            -- @b_MDS_Flag
            IF EXISTS(SELECT 1
                  FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
                  JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
                  JOIN #ORDERSKU OS ON OS.OrderKey = WOD.ExternWorkOrderKey 
                  WHERE OS.OrderGroup = @c_OrderGroup
                  AND OD.Sku = @c_Sku
                  AND WOD.Type = 'MDS')
               SET @b_MDS_Flag = 1
            ELSE
               SET @b_MDS_Flag = 0

            IF @n_VAS_LineCount = 1
            BEGIN
               SET @c_NewCarton = 'Y'

               SELECT TOP 1
                  @n_VAS_QtyCanPack = WOD.Qty 
               FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
               JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
               JOIN #ORDERSKU OS ON OS.OrderKey = WOD.ExternWorkOrderKey 
               WHERE OS.OrderGroup = @c_OrderGroup 
               AND OD.Sku = @c_Sku
               AND WOD.Type IN ('S02','S06')   --WL01    
               ORDER BY WOD.Qty DESC          
            END
            ELSE IF @n_VAS_LineCount > 1
            BEGIN
               SET @c_NewCarton = 'Y'

               SELECT TOP 1 
                  @n_VAS_QtyCanPack = WOD.Qty 
               FROM dbo.WorkOrderDetail WOD WITH (NOLOCK) 
               JOIN ORDERDETAIL OD WITH (NOLOCK) ON WOD.ExternWorkOrderKey = OD.OrderKey and WOD.ExternLineNo = OD.OrderLineNumber
               JOIN #ORDERSKU OS ON OS.OrderKey = WOD.ExternWorkOrderKey 
               WHERE OS.OrderGroup = @c_OrderGroup
               AND OD.Sku = @c_Sku
               AND WOD.Type = 'S02'         
               ORDER BY WOD.Qty DESC        
            END               

            IF @c_NewCarton='N'
            BEGIN
               -- If Current MasterShipmentID not match. Pack to new carton
               IF NOT EXISTS(SELECT 1 FROM #CARTONDETAIL CTD 
                             --JOIN dbo.SKU SKU WITH (NOLOCK) ON SKU.StorerKey = CTD.Storerkey AND SKU.Sku = CTD.Sku   --WL07
                             JOIN #ORDERSKU os ON os.StorerKey = CTD.Storerkey      --(Wan01)
                                               AND os.Sku = CTD.Sku
                             WHERE OS.MasterShipmentID = @c_MasterShpmntID   --WL07
                             AND CTD.CartonNo = @n_CartonNo 
                             AND CTD.OrderGroup = @c_OrderGroup
                             AND os.WCS = @b_WCS                                    --(Wan01)
                             )
               BEGIN
                   SET @c_NewCarton='Y'
               END
            END 
            -- IF ORDERINFO03 > 0, Force to pack to new carton if SKU count >= ORDERINFO03
            IF @n_ForceCartonMaxSku > 0
            BEGIN
               IF (SELECT COUNT(DISTINCT SKU) FROM #CARTONDETAIL WHERE OrderGroup = @c_OrderGroup AND CartonNo = @n_CartonNo) >= @n_ForceCartonMaxSku
                  SET @c_NewCarton = 'Y'
            END            

            WHILE 1=1 AND @n_continue IN(1,2) AND @n_OrderQty > 0
            BEGIN    
               SELECT @n_QtyCanPackByCube = 0, @n_QtyCanPackByCount = 0, @n_QtyCanPack = 0

               IF @b_debug=2
               BEGIN
                  PRINT 'NewCarton: ' + @c_NewCarton + ' Order Qty: ' +CAST(@n_OrderQty AS VARCHAR(20)) + ' Order Cube: ' + CAST(@n_OrderCube AS VARCHAR(20)) 
                        + ' StdCube: ' + CAST(@n_StdCube AS VARCHAR(20)) 
               END

            
               IF @c_NewCarton = 'Y' --new carton
               BEGIN              
                  SELECT @n_CartonMaxCube = 0, @n_CartonMaxCount = 0, @n_CartonMaxWeight = 0, @c_NewCarton = 'N', @n_CartonNo = 0, @c_CartonType = ''
                  SELECT @n_CartonLength = 0, @n_CartonWidth = 0, @n_CartonHeight = 0, @n_CartonRemainCube=0 

                  SELECT @n_CartonNo = MAX(CartonNo)
                  FROM #CARTON
                  WHERE OrderGroup = @c_OrderGroup
                    
                  SET @n_CartonNo = ISNULL(@n_CartonNo,0)
                                                
                  SET @n_CartonNo = @n_CartonNo + 1

                  -- Getting Right Carton Type by LWH and Cube (SWT01)
                  IF @c_VAS_CartonType <> ''
                  BEGIN
                     SET @c_CartonType = @c_VAS_CartonType

                     -- (SWT02) Check if SKU LxWxH can fit into the carton type
                     SELECT @c_CartonType=CZ.CartonType, @n_CartonLength=CZ.CartonLength, 
                            @n_CartonWidth=CZ.CartonWidth, @n_CartonHeight=CZ.CartonHeight                              
                     FROM #CARTONIZATION CZ 
                     WHERE CZ.CartonType = @c_VAS_CartonType
                  
                     IF dbo.fnc_CartonCanFit(@n_SKULength, @n_SKUWidth, @n_SKUHeight, @n_CartonLength, @n_CartonWidth, @n_CartonHeight) = 0
                     BEGIN
                        SET @n_continue = 3
                        SET @n_Err = 562204
                        SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': SKU(s) LxWxH cannot fit into carton type ' + RTRIM(@c_VAS_CartonType) + '. (mspRLWAV03)'     
                        GOTO QUIT_SP
                     END;
                  END
                  IF @c_CartonType = N''
                  BEGIN
                     TRUNCATE TABLE #CTNTRACK

                     WHILE 1=1 AND @n_continue IN(1,2) 
                     BEGIN
                        SET @c_CartonType = N''
                        
                        --WL01 S
                        --WITH MDS - 30 Qty per Line, S02/S06 = 10, 10 Qty/ctn, total 3 CTNs, no remainder
                        --NOT MDS  - 30 Qty per Line, S02/S06 = 8, 3 Cartons - 8 Qty, 1 Carton - 6 Qty total 4 CTNs, with remainder
                        IF @n_VAS_QtyCanPack > 0
                        BEGIN
                           SELECT TOP 1
                                     @n_CTNRowID = RowID,
                                     @c_CartonType = CZ.CartonType,
                                     @n_CartonLength = CZ.CartonLength,
                                     @n_CartonWidth = CZ.CartonWidth,
                                     @n_CartonHeight = CZ.CartonHeight
                           FROM #CARTONIZATION CZ
                           WHERE CZ.Cube >= (@n_StdCube * IIF(@n_OrderQty >= @n_VAS_QtyCanPack, @n_VAS_QtyCanPack, @n_OrderQty) )
                           AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID)
                           AND CZ.IsGeneric = 1
                           ORDER BY CZ.Cube;

                           IF @b_Debug = 10
                              SELECT 'VAS Qty', (@n_StdCube * IIF(@n_OrderQty >= @n_VAS_QtyCanPack, @n_VAS_QtyCanPack, @n_OrderQty) ), @c_SKU, @n_OrderQty
                        END

                        IF @c_CartonType = N'' --WL01 E Pick Carton that can fit the order cube
                        SELECT TOP 1
                                 @n_CTNRowID = RowID,
                                 @c_CartonType = CZ.CartonType,
                                 @n_CartonLength = CZ.CartonLength,
                                 @n_CartonWidth = CZ.CartonWidth,
                                 @n_CartonHeight = CZ.CartonHeight
                        FROM #CARTONIZATION CZ
                        WHERE CZ.Cube >= @n_OrderCube
                        AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID)
                        AND CZ.IsGeneric = 1   --WL01
                        ORDER BY CZ.Cube;

                        --WL07 S
                        -- Pick carton type that can fit the entire MasterShipmentID
                        IF @c_CartonType = N''
                        BEGIN
                           SET @n_SKUGroupCube = 0

                           SELECT @n_SKUGroupCube = SUM(O.TotalCube - O.TotalCubePacked) 
                           FROM #ORDERSKU O
                           WHERE O.OrderGroup = @c_OrderGroup
                           AND O.WCS          = @b_WCS                                   --(Wan01)
                           AND O.MasterShipmentID = @c_MasterShpmntID
                           AND O.TotalQty - O.TotalQtyPacked > 0

                           IF @b_debug=2
                           BEGIN
                              PRINT ' MasterShipmentID Cube: ' + CAST(@n_SKUGroupCube AS VARCHAR(20)) 
                                      + ' MasterShipmentID: ' + @c_MasterShpmntID
                           END
                           --WL07 E

                           IF @n_SKUGroupCube > 0 
                           BEGIN
                              SELECT TOP 1 @n_CTNRowID = RowID,
                                 @c_CartonType= CZ.CartonType, 
                                 @n_CartonLength=CZ.CartonLength, 
                                 @n_CartonWidth=CZ.CartonWidth, 
                                 @n_CartonHeight=CZ.CartonHeight 
                              FROM #CARTONIZATION CZ 
                              WHERE CZ.Cube >= @n_SKUGroupCube
                              AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID) 
                              AND CZ.IsGeneric = 1   --WL01
                              ORDER BY CZ.Cube DESC 
                           END 
                        END

                        -- If can't find carton can fit MasterShipmentID 
                        -- Pick other carton that can fit the SKU Standard Cude
                        IF @c_CartonType = N''
                        BEGIN
                           SELECT TOP 1 @n_CTNRowID = RowID,
                              @c_CartonType= CZ.CartonType, @n_CartonLength=CZ.CartonLength, 
                              @n_CartonWidth=CZ.CartonWidth, @n_CartonHeight=CZ.CartonHeight 
                           FROM #CARTONIZATION CZ 
                           WHERE CZ.Cube >= @n_StdCube
                           AND NOT EXISTS(SELECT 1 FROM #CTNTRACK C WHERE C.ROWID = CZ.RowID) 
                           AND CZ.IsGeneric = 1   --WL01
                           ORDER BY CZ.Cube DESC 
                        END
                        IF @c_CartonType=N'' 
                        BEGIN
                            SET @n_OrderQty=0;
                            IF @b_debug=2
                            BEGIN
                               PRINT 'Cannot find any carton type can fit. Order No: ' + @c_Orderkey 
                            END 
                            BREAK;
                        END
                        ELSE
                           BREAK;
                        -- Do not check L,W and H
                        -- IF dbo.fnc_CartonCanFit(@n_SKULength, @n_SKUWidth, @n_SKUHeight, @n_CartonLength, @n_CartonWidth, @n_CartonHeight) = 1
                        -- BEGIN                           
                        --    BREAK
                        -- END
                        -- ELSE 
                        -- BEGIN
                        --    IF @b_debug=2
                        --    BEGIN
                        --       PRINT 'Carton Type: ' + @c_CartonType + ' Can''t Fit'
                        --       PRINT 'SKU Length: ' + CAST(@n_SKULength AS VARCHAR(20)) + ' SKU Width: ' + CAST(@n_SKUWidth AS VARCHAR(20)) + ' SKU Height: ' + CAST(@n_SKUHeight AS VARCHAR(20))  
                        --       + ' Carton Length: ' + CAST(@n_CartonLength AS VARCHAR(20)) + ' Carton Width: ' + CAST(@n_CartonWidth AS VARCHAR(20)) + ' Carton Height: ' + CAST(@n_CartonHeight AS VARCHAR(20)) 
                        --    END 
                        --    SET @c_CartonType = N''
                        -- END 

                        INSERT INTO #CTNTRACK VALUES (@n_CTNRowID)
                     END -- WHILE 1=1
                      
                  END -- IF @c_CartonType = N''
                                       
                  IF @c_CartonType = ''
                  BEGIN
                    SET @n_OrderQty=0

                    SET @n_continue = 3
                    SET @n_Err = 562204
                    SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Unable to find Carton type for Order: ' 
                                 + RTRIM(@c_Orderkey) + '.(mspRLWAV03)'

                    IF @b_debug=2
                       PRINT @c_Errmsg

                    BREAK                 
                  END                                               
                   
                  --Get carton setup
                  SELECT @n_CartonMaxCube = CZ.Cube,
                        @n_CartonRemainCube = CZ.Cube,
                        @n_CartonMaxWeight = CZ.MaxWeight,
                        @n_CartonMaxCount = CZ.MaxCount,
                        @n_CartonMaxSku = CZ.MaxSku
                  FROM #CARTONIZATION CZ (NOLOCK)
                  WHERE CZ.CartonType = @c_CartonType

                  -- SWT03
                  INSERT INTO #CARTON (Orderkey, CartonNo, LabelNo, CartonGroup, CartonType, MaxCube, MaxWeight, MaxCount, MaxSku, 
                              CartonLength, CartonWidth, CartonHeight, UCCNo, OrderGroup, VASCartonType)
                VALUES ('', @n_CartonNo, '', @c_CartonGroup, @c_CartonType, @n_CartonMaxCube, @n_CartonMaxWeight, @n_CartonMaxCount, @n_CartonMaxSku, 
                        @n_CartonLength , @n_CartonWidth, @n_CartonHeight, '', @c_OrderGroup, @c_VAS_CartonType)                                            
              END --IF @c_NewCarton = 'Y'

               IF @b_debug=2
               BEGIN
                     PRINT 'Carton No: ' + CAST(@n_CartonNo As varchar(10)) + ' Carton Type: ' + @c_CartonType + ' Max Cube: ' + CAST(@n_CartonMaxCube AS VARCHAR(20))
               END

              --Get item to pack
              TRUNCATE TABLE #ROWTRACK

              --Try search all items of the order that can fit the remaining space of the carton, priority by Sku 
              WHILE @n_QtyCanPack = 0 AND @n_continue IN(1,2)  
              BEGIN                   
                 SET @n_RowID = 0                    

                 IF EXISTS(SELECT 1 FROM #CARTON WHERE CartonNo = @n_CartonNo AND OrderGroup = @c_OrderGroup)
                 BEGIN
                    IF @b_debug=2
                    BEGIN
                        PRINT 'Exists in Carton Detail'
                    END 
                    IF @c_VAS_CartonType <> '' -- (SWT01) 
                    BEGIN
                       --Get the SKU remaining Qty regardless of Volume
                        SELECT TOP 1 @n_RowID = OS.RowID,                           
                              @n_StdCube = OS.StdCube,
                              @n_PackQty = OS.TotalQty - OS.TotalQtyPacked,
                              @c_Orderkey = OS.Orderkey
                        FROM #ORDERSKU OS (NOLOCK)
                        WHERE OS.OrderGroup = @c_OrderGroup
                        AND OS.TotalQty - OS.TotalQtyPacked > 0
                        AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)
                        AND OS.Sku = @c_Sku
                        AND OS.MasterShipmentID = @c_MasterShpmntID
                        ORDER BY (OS.TotalCube - OS.TotalCubePacked) DESC, OS.Sku
                    END                                    
                    IF @n_RowID = 0
                    BEGIN
                     --Get the sku can fully best fit in the existing carton
                     SELECT TOP 1 @n_RowID = OS.RowID,
                           @c_Sku = OS.Sku,
                           @n_StdCube = OS.StdCube,
                           @n_PackQty = OS.TotalQty - OS.TotalQtyPacked,
                           @c_Orderkey = OS.Orderkey
                     FROM #ORDERSKU OS (NOLOCK) 
                     WHERE OS.OrderGroup = @c_OrderGroup
                     AND OS.TotalQty - OS.TotalQtyPacked > 0
                     AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)
                     AND @n_CartonRemainCube >= (OS.TotalCube - OS.TotalCubePacked)   --WL07
                     AND OS.MasterShipmentID = @c_MasterShpmntID
                     AND OS.Sku = @c_Sku   --WL07
                     ORDER BY (OS.TotalCube - OS.TotalCubePacked) DESC, OS.Sku
                    END   
                    IF @n_RowID = 0
                    BEGIN
                        --Get the smaller cube of the sku mix with existing carton 
                       SELECT TOP 1 @n_RowID = OS.RowID,
                             @c_Sku = OS.Sku,
                             @n_StdCube = OS.StdCube,
                             @n_PackQty = OS.TotalQty - OS.TotalQtyPacked,
                             @c_Orderkey = OS.Orderkey
                       FROM #ORDERSKU OS (NOLOCK)
                       WHERE OS.OrderGroup = @c_OrderGroup
                       AND OS.TotalQty - OS.TotalQtyPacked > 0
                       AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)
                       AND OS.MasterShipmentID = @c_MasterShpmntID 
                       AND OS.StdCube <= @n_CartonRemainCube   --WL07
                       AND OS.Sku = @c_Sku   --WL07
                       ORDER BY (OS.TotalCube - OS.TotalCubePacked), OS.Sku                         
                    END                       
                 END
                 ELSE
                 BEGIN
                    --Get the sku by larger cube sequence to the new carton
                    SELECT TOP 1 @n_RowID = OS.RowID,
                          @c_Sku = OS.Sku,
                          @n_StdCube = OS.StdCube,
                          @n_PackQty = OS.TotalQty - OS.TotalQtyPacked,
                          @c_Orderkey = OS.Orderkey
                    FROM #ORDERSKU OS (NOLOCK)
                    WHERE OS.OrderGroup = @c_OrderGroup
                    AND OS.TotalQty - OS.TotalQtyPacked > 0
                    AND OS.MasterShipmentID = @c_MasterShpmntID 
                    AND OS.Sku = @c_Sku   --WL07
                    AND OS.RowID NOT IN(SELECT RowID FROM #ROWTRACK)                      
                    ORDER BY OS.RowID
                 END                                                                   

                  IF @b_debug=2
                  BEGIN
                      PRINT 'SKU: ' + @c_Sku + ' StdCube: ' + CAST(@n_StdCube AS VARCHAR(20)) 
                     + ' Pack Qty: ' + CAST(@n_PackQty AS VARCHAR(20)) + ' Row ID: ' + CAST(@n_RowID AS VARCHAR(20))
                  END

                  -- No outstanding Item to pack, go to next order
                  IF @n_RowID = 0
                  BEGIN
                      SET @n_QtyCanPack = 0;

                      IF @c_NewCarton = 'Y'
                          SET @n_OrderQty = 0;

                      BREAK;
                  END;
                   
                 INSERT INTO #ROWTRACK(RowID) VALUES (@n_RowID)
                                       
                 --Validate the carton at lease can fit 1 qty of the sku
                IF NOT EXISTS(SELECT 1 FROM #CARTONIZATION WHERE Cube >= @n_StdCube AND CartonType = @c_CartonType) 
                BEGIN
                     SET @n_continue = 3
                     SET @n_Err = 562207
                     SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': No Carton type can fit a Sku ' + RTRIM(@c_Sku) + '.(mspRLWAV03)'

                     IF @b_debug=2
                     BEGIN
                        PRINT 'Error: ' + @c_Errmsg
                     END

                     BREAK
                END                

                  IF @n_StdCube > 0
                  BEGIN 
                     SET @n_QtyCanPackByCube = FLOOR(@n_CartonRemainCube / @n_StdCube)  
                     SET @n_QtyCanPack = @n_QtyCanPackByCube 
                  END 
                  ELSE 
                     SET @n_QtyCanPack = @n_PackQty

                  IF @n_VAS_QtyCanPack > 0
                  BEGIN
                     IF @n_QtyCanPack > @n_VAS_QtyCanPack
                        SET @n_QtyCanPack = @n_VAS_QtyCanPack
                  END
                    
                 IF @n_StdCube = 0  --if sku cube not setup just pack all qty
                    SET @n_QtyCanPack = @n_PackQty                         
                   
                         
                 IF @n_PackQty < @n_QtyCanPack
                    SET @n_QtyCanPack = @n_PackQty

                  IF @b_debug=2
                  BEGIN
                      PRINT '>>> QtyCanPackByCube: ' + CAST(@n_QtyCanPackByCube AS VARCHAR(10)) + ' QtyCanPack: ' 
                       + CAST(@n_QtyCanPack AS VARCHAR(10)) + ' Remain Cube: ' + CAST(@n_CartonRemainCube AS VARCHAR(20))
                  END

                  IF @n_QtyCanPack <> @n_VAS_QtyCanPack and @b_MDS_Flag = 1 and @n_VAS_QtyCanPack > 0
                  BEGIN 
                     SET @n_continue = 3
                     SET @n_Err = 562206
                     SET @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Pack Qty not match with VAS Qty for MDS VAS Code. (mspRLWAV03)'

                     IF @b_debug=2
                     BEGIN
                        PRINT 'Error: ' + @c_Errmsg
                     END

                     BREAK
                  END                  
                  
                 IF @c_CartonItemOptimize <> 'Y'
                    BREAK --if current item cannot fit current carton open new carton and not search for other/next item. 
             END -- WHILE @n_QtyCanPack
                                
              IF @n_continue = 3
                 BREAK
                   
              IF @n_QtyCanPack = 0  --carton full 
              BEGIN
                 IF @b_debug=2
                     PRINT '>>> QtyCanPack = 0,New Carton = Y, OrderQty=' + CAST(@n_OrderQty as varchar(10))
                                   
                 SET @c_NewCarton = 'Y'
              END
              ELSE 
              BEGIN
               --Pack to Carton
               INSERT INTO #CARTONDETAIL (OrderGroup, Orderkey, Storerkey, Sku, CartonNo, Qty, RowRef)  --refer to ORDERSKU.RowID
               VALUES (@c_OrderGroup, @c_OrderKey, @c_Storerkey, @c_Sku, @n_CartonNo, @n_QtyCanPack, @n_RowID) 
                  
               --Update counters
               SET @n_OrderCube = @n_OrderCube - (@n_QtyCanPack * @n_StdCube)
               SET @n_OrderQty = @n_OrderQty - @n_QtyCanPack
               SET @n_CartonRemainCube = @n_CartonRemainCube - (@n_QtyCanPack * @n_StdCube)   --WL07
                                    
               UPDATE #ORDERSKU
               SET TotalQtyPacked = TotalQtyPacked + @n_QtyCanPack, 
                  TotalCubePacked = TotalCubePacked + (@n_QtyCanPack * @n_StdCube)
               WHERE RowID = @n_RowID               
              END                                     
                                                                          
          END -- @n_OrderQty > 0
            NEXT_CTNORSKU2:    
               
            FETCH NEXT FROM CUR_MPOC_ORDCTNGROUP INTO @n_StdCube, @n_OrderQty, @c_Sku, @n_SKULength, @n_SKUWidth, @n_SKUHeight
                                                   ,  @c_MasterShpmntID, @c_SkuGroup, @c_ItemClass   --WL07  
                                                   ,  @b_WCS
         END
         CLOSE CUR_MPOC_ORDCTNGROUP
         DEALLOCATE CUR_MPOC_ORDCTNGROUP

         FETCH NEXT FROM CUR_MPOC_ORD INTO @c_OrderGroup      
      END
      CLOSE CUR_MPOC_ORD
      DEALLOCATE CUR_MPOC_ORD
   END -- No MPOC Orders    

   --Create pickslip
   IF @n_continue IN(1,2)
   BEGIN
      EXEC dbo.isp_CreatePickSlip
             @c_WaveKey = @c_WaveKey
            ,@c_PickslipType = ''      
            ,@c_ConsolidateByLoad  = 'N'
            ,@c_Refkeylookup       = 'N'    
            ,@c_LinkPickSlipToPick = 'Y'    
            ,@c_AutoScanIn         = 'N'    
            ,@b_Success            = @b_Success OUTPUT
            ,@n_Err                = @n_Err     OUTPUT
            ,@c_ErrMsg             = @c_ErrMsg  OUTPUT
      
      IF @b_Success <> 1
         SET @n_Continue = 3          
   END

   IF @b_debug > 0
   BEGIN
      SELECT * FROM #CARTON
      SELECT * FROM #CARTONDETAIL
   END
      
   --Create packing records For None MPOC Orders
   IF @n_continue IN(1,2) 
   BEGIN    
      IF @b_debug <> 0 
      BEGIN
            PRINT '*** Create packing records  ***'
      END 
      SET @c_OrderGroup = ''
      SET @c_PreOrderGroup = ''

      DECLARE CUR_PACKORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT DISTINCT CT.OrderGroup, CT.Orderkey, PH.PickHeaderKey
        FROM #CARTONDETAIL CT 
        JOIN dbo.PICKHEADER PH (NOLOCK) ON CT.Orderkey = PH.Orderkey
        ORDER BY CT.OrderGroup, CT.Orderkey

      OPEN CUR_PACKORDER

      FETCH NEXT FROM CUR_PACKORDER INTO @c_OrderGroup, @c_Orderkey, @c_Pickslipno
                 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --get order       
      BEGIN         
         IF @b_debug <> 0 
            PRINT '@c_OrderGroup: ' + @c_OrderGroup + ' @c_Orderkey:' + @c_Orderkey + ' @c_Pickslipno: ' + @c_Pickslipno

         --Create packheader
         IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
         BEGIN
            INSERT INTO dbo.PackHeader (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, ConsoOrderkey)   --WL03
            SELECT TOP 1 O.Route, O.Orderkey, '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo, @c_OrderGroup   --WL03
            FROM  dbo.PICKHEADER PH (NOLOCK)
            JOIN  dbo.ORDERS O (NOLOCK) ON (PH.Orderkey = O.Orderkey)
            WHERE PH.PickHeaderKey = @c_PickSlipNo
         
            SET @n_Err = @@ERROR
            
            IF @n_Err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_Errmsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 562208
               SELECT @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Error Insert Packheader Table (mspRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '
            END
         END

             -- SWT03 Add Vas Column
         DECLARE CUR_PACKCARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
         SELECT DISTINCT CT.CartonNo, CT.CartonType, CT.UCCNo, CT.CartonLength, CT.CartonWidth, CT.CartonHeight, CT.VASCartonType
                       , CT.LabelNo   --WL07
         FROM #CARTON CT
         JOIN #CARTONDETAIL CTD ON CT.Orderkey = CTD.Orderkey AND CT.CartonNo = CTD.CartonNo
         WHERE CT.Orderkey = @c_Orderkey AND CT.OrderGroup = ''
         UNION ALL 
         SELECT DISTINCT CT.CartonNo, CT.CartonType, CT.UCCNo, CT.CartonLength, CT.CartonWidth, CT.CartonHeight, CT.VASCartonType
                       , CT.LabelNo   --WL07
         FROM #CARTON CT
         JOIN #CARTONDETAIL CTD ON CT.OrderGroup = CTD.OrderGroup AND CT.CartonNo = CTD.CartonNo
         WHERE CT.OrderGroup = @c_OrderGroup 
         AND CT.OrderGroup > ''
         AND CTD.Orderkey = @c_Orderkey   --WL07
         ORDER BY CT.CartonNo
         
         OPEN CUR_PACKCARTON
         
         -- SWT03 
         FETCH NEXT FROM CUR_PACKCARTON INTO @n_CartonNo, @c_CartonType, @c_UCCNo, @n_CartonLength, @n_CartonWidth, @n_CartonHeight, @c_VAS_CartonType
                                          ,  @c_LabelNo   --WL07
                    
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --get Carton
         BEGIN   
            IF @b_debug <> 0 
              PRINT  '@n_CartonNo: ' + CAST(@n_CartonNo AS VARCHAR(5)) + ' @c_CartonType: ' + @c_CartonType + ' @c_PreOrderGroup: ' + @c_PreOrderGroup
          
      -- Relabel All Carton Even with UCC 
          --IF ISNULL(@c_UCCNo,'') <> ''
          --BEGIN
          --    SET @c_LabelNo = @c_UCCNo
          --END
          --ELSE
          --BEGIN
            IF @c_LabelNo = ''   --WL07
            BEGIN
               --IF @c_OrderGroup <> @c_PreOrderGroup OR @c_OrderGroup = ''
               --BEGIN
               EXEC dbo.isp_GenUCCLabelNo_Std
               @cPickslipNo = @c_Pickslipno,
               @nCartonNo   = @n_CartonNo,
               @cLabelNo    = @c_LabelNo  OUTPUT,
               @b_success   = @b_Success  OUTPUT,
               @n_err       = @n_Err      OUTPUT,
               @c_errmsg    = @c_Errmsg   OUTPUT                

               IF @b_Success <> 1
                  SET @n_continue = 3

               SET @c_PreOrderGroup = @c_OrderGroup
     
               --Update labelno to #CARTON
               IF @c_OrderGroup = ''
               BEGIN
                  UPDATE #CARTON 
                     SET LabelNo = @c_LabelNo
                  WHERE Orderkey = @c_Orderkey
                  AND CartonNo = @n_CartonNo  
               END
               ELSE
               BEGIN
                  UPDATE #CARTON 
                  SET LabelNo = @c_LabelNo
                  WHERE OrderGroup = @c_OrderGroup
                  AND CartonNo = @n_CartonNo                 
                  AND Orderkey=''
               END
            END
            --END

            -- SWT03
            SELECT @n_TotCartonQty = 0, @n_TotCartonCube = 0, @n_TotCartonWeight = 0, @n_CartonMaxCube=0
            IF @c_OrderGroup = ''
            BEGIN
               -- SWT03
               SELECT @n_CartonMaxCube = CT.MaxCube
               FROM #Carton CT 
               WHERE CT.OrderKey = @c_Orderkey -- SWT04
               AND CartonNo = @n_CartonNo

               SELECT @n_TotCartonQty  = SUM(CTD.Qty), 
                     @n_TotCartonCube = SUM(CTD.Qty * SKU.StdCube),
                     @n_TotCartonWeight = 0 
               FROM #CARTONDETAIL CTD
               JOIN SKU WITH (NOLOCK) ON CTD.Storerkey = SKU.StorerKey AND CTD.SKU = SKU.Sku 
               JOIN #CARTON CT ON CTD.CartonNo = CT.CartonNo AND CT.Orderkey = CTD.Orderkey
               WHERE CTD.Orderkey = @c_Orderkey
               AND CTD.CartonNo = @n_CartonNo
            END
            ELSE
            BEGIN
               -- SWT03
               SELECT @n_CartonMaxCube = CT.MaxCube
               FROM #Carton CT 
               WHERE CT.OrderGroup = @c_OrderGroup
               AND CartonNo = @n_CartonNo                 
               AND Orderkey=''

               SELECT @n_TotCartonQty  = SUM(CTD.Qty), 
                     @n_TotCartonCube = SUM(CTD.Qty * SKU.StdCube),
                     @n_TotCartonWeight = 0 
               FROM #CARTONDETAIL CTD
               JOIN #CARTON CT ON CTD.CartonNo = CT.CartonNo AND CT.OrderGroup = CTD.OrderGroup
               JOIN SKU WITH (NOLOCK) ON CTD.Storerkey = SKU.StorerKey AND CTD.SKU = SKU.Sku
               WHERE CT.OrderGroup = @c_OrderGroup
               AND CTD.CartonNo = @n_CartonNo
            END

            -- Check the System Calculate Carton Size and Total SKU Cube, if can find small carton, then use the small carton
            -- CartonType = '' means not VAS Carton Type
            -- CartonType = '9999' means UCC Carton Type
            -- (SWT03)
            IF @n_TotCartonCube > 0 AND @c_VAS_CartonType = '' AND @c_CartonType <> '9999' AND @n_CartonMaxCube > 0
            BEGIN
               -- if assign carton size with empty percentage more than 10%, then use the small carton
               IF @n_CartonMaxCube / @n_TotCartonCube > 1.1
               BEGIN
                  SELECT @c_NewCartonType = '', @n_NewCartonMaxCube = 0
                  SELECT TOP 1
                         @c_NewCartonType = CZ.CartonType, 
                         @n_NewCartonMaxCube= CZ.Cube,
                         @n_CartonLength = CZ.CartonLength, -- SWT04
                         @n_CartonWidth = CZ.CartonWidth,  
                         @n_CartonHeight = CZ.CartonHeight   
                  FROM #CARTONIZATION CZ
                  WHERE CZ.Cube >= @n_TotCartonCube
                  AND CZ.IsGeneric = 1
                  ORDER BY CZ.Cube
                  IF @c_NewCartonType <> '' and @c_NewCartonType <> @c_CartonType
                  BEGIN
                     UPDATE #CARTON
                        SET CartonType = @c_NewCartonType, 
                           MaxCube = @n_NewCartonMaxCube, 
                           CartonLength = @n_CartonLength, -- SWT04
                           CartonWidth  = @n_CartonWidth, 
                           CartonHeight  = @n_CartonHeight 
                     WHERE OrderGroup = @c_OrderGroup
                     AND CartonNo = @n_CartonNo

                     SET @n_TotCartonCube = @n_NewCartonMaxCube
                     SET @c_CartonType = @c_NewCartonType

                     IF @b_debug=2
                     BEGIN
                        PRINT '   >>> Reassign New Carton Type: ' + @c_CartonType 
                     END 
                  END
                  -- Might need to check Length, Width, Height. KIV now

               END
            END
            
            --WL07 S
            IF @c_OrderGroup <> ''
            BEGIN
               SELECT @n_TotCartonCube = SUM(CTD.Qty * SKU.StdCube)
               FROM #CARTONDETAIL CTD
               JOIN #CARTON CT ON CTD.CartonNo = CT.CartonNo AND CT.OrderGroup = CTD.OrderGroup
               JOIN SKU WITH (NOLOCK) ON CTD.Storerkey = SKU.StorerKey AND CTD.SKU = SKU.Sku
               WHERE CT.OrderGroup = @c_OrderGroup
               AND CTD.CartonNo = @n_CartonNo
               AND CTD.Orderkey = @c_Orderkey
            END
            
            --Get packed carton cube,qty,weight            
            --Create packinfo            
            IF EXISTS (SELECT 1 FROM dbo.PackInfo (NOLOCK) WHERE Pickslipno = @c_PickslipNo
                           AND CartonNo = @n_CartonNo)
            BEGIN
              DELETE FROM dbo.PackInfo WHERE Pickslipno = @c_PickslipNo AND CartonNo = @n_CartonNo
            END                 

            INSERT INTO dbo.PackInfo (Pickslipno, CartonNo, CartonType, Cube, Weight, Qty, Length, Width, Height, RefNo) --(SWT01)
            VALUES (@c_PickslipNo, @n_CartonNo, @c_CartonType, @n_TotCartonCube, 
                    @n_TotCartonWeight, 0, @n_CartonLength, @n_CartonWidth, @n_CartonHeight, @c_LabelNo)
            
            SET @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_Errmsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 562209
               SELECT @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Error Insert Packinfo Table (mspRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '
            END 

            DECLARE CUR_PACKSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT CTD.Storerkey, CTD.Sku, SUM(CTD.Qty)
               FROM #CARTONDETAIL CTD 
               WHERE CTD.Orderkey = @c_Orderkey
               AND CTD.CartonNo = @n_CartonNo
               GROUP BY CTD.Storerkey, CTD.Sku
               ORDER BY MIN(CTD.RowID)            

            OPEN CUR_PACKSKU
           
            FETCH NEXT FROM CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_PackQty

            WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)  --get sku
            BEGIN   --WL07 E     
               --WL07 S
               SET @c_LabelLine = ''

               SELECT @c_LabelLine = RIGHT('00000' + CAST(CAST(ISNULL(MAX(PD.LabelLine), 0) AS INT) + 1 AS NVARCHAR(5)), 5)
               FROM PACKDETAIL PD (NOLOCK)
               WHERE PD.Pickslipno = @c_Pickslipno
               AND PD.CartonNo = @n_CartonNo
               --WL07 E
                                      
               -- CartonNo and LabelLineNo will be inserted by trigger
               INSERT INTO dbo.PackDetail (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno, DropId)
               VALUES (@c_PickSlipNo, @n_CartonNo, @c_LabelNo, @c_LabelLine, @c_StorerKey, @c_SKU,   --WL07
                       @n_PackQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @c_UCCNo, '')
               
               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_Errmsg = CONVERT(NVARCHAR(250),@n_Err), @n_Err = 562210
                  SELECT @c_Errmsg='NSQL'+CONVERT(NVARCHAR(10),@n_Err)+': Error Insert Packdetail Table (mspRLWAV03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_Errmsg) + ' ) '
               END
              
               FETCH NEXT FROM CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_PackQty            
            END
            CLOSE CUR_PACKSKU
            DEALLOCATE CUR_PACKSKU
                                                      
            FETCH NEXT FROM CUR_PACKCARTON INTO @n_CartonNo, @c_CartonType, @c_UCCNo, @n_CartonLength, @n_CartonWidth, @n_CartonHeight, @c_VAS_CartonType 
                                             ,  @c_LabelNo   --WL07                   
         END
         CLOSE CUR_PACKCARTON
         DEALLOCATE CUR_PACKCARTON      
         
         FETCH NEXT FROM CUR_PACKORDER INTO @c_OrderGroup, @c_Orderkey, @c_Pickslipno         
      END                 
      CLOSE CUR_PACKORDER 
      DEALLOCATE CUR_PACKORDER
   END
   --IF @b_debug=3
   --BEGIN
   --    --SELECT * FROM #CARTON
   --END

   --Update labelno to pickdetail caseid
   IF @n_continue IN(1,2) 
   BEGIN            
      UPDATE #PICKDETAIL_WIP SET CaseID = ''
      
      DECLARE CUR_LABELUPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT CTD.Orderkey, CT.CartonNo, CTD.Storerkey, CTD.Sku, CTD.Qty, CT.LabelNo, CT.UCCNo
         FROM #CARTON CT
         JOIN #CARTONDETAIL CTD ON CT.Orderkey = CTD.Orderkey AND CT.CartonNo = CTD.CartonNo
         WHERE CT.Orderkey > ''
         UNION ALL
         SELECT CTD.Orderkey, CT.CartonNo, CTD.Storerkey, CTD.Sku, CTD.Qty, CT.LabelNo, CT.UCCNo
         FROM #CARTON CT
         JOIN #CARTONDETAIL CTD ON CT.OrderGroup = CTD.OrderGroup AND CT.CartonNo = CTD.CartonNo
         WHERE CT.Orderkey = ''
         ORDER BY CTD.Orderkey, CT.CartonNo, CTD.Storerkey, CTD.Sku

      OPEN CUR_LABELUPD

      FETCH NEXT FROM CUR_LABELUPD INTO @c_Orderkey, @n_CartonNo, @c_Storerkey, @c_Sku, @n_PackQty, @c_LabelNo, @c_UCCNo
                 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2) 
      BEGIN                     
         DECLARE CUR_PICKDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey, PD.Qty
            FROM #PICKDETAIL_WIP PD (NOLOCK) 
            JOIN dbo.LOC LOC (NOLOCK) ON PD.Loc = LOC.Loc
            JOIN dbo.SKU SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
            JOIN dbo.PACK PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
            WHERE PD.OrderKey = @c_Orderkey
            AND PD.Storerkey = @c_Storerkey
            AND PD.Sku = @c_Sku
            AND ISNULL(PD.CaseID,'') = ''
            ORDER BY CASE WHEN PD.DropID = @c_UCCNo THEN 1 ELSE 2 END, LOC.Putawayzone, LogicalLocation, PD.PickDetailKey
         
         OPEN CUR_PICKDET_UPDATE
         
         FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
         
         WHILE @@FETCH_STATUS <> -1 AND @n_packqty > 0
         BEGIN
            IF @n_PickdetQty <= @n_packqty
            BEGIN
               UPDATE #PICKDETAIL_WIP WITH (ROWLOCK)
               SET CaseId = @c_labelno,
                   UOMQty = CASE WHEN UOM = '6' THEN Qty ELSE UOMQty END
               WHERE PickDetailKey = @c_PickDetailKey
         
              SELECT @n_packqty = @n_packqty - @n_PickdetQty
            END
            ELSE
            BEGIN  -- pickqty > packqty
               SELECT @n_splitqty = @n_PickdetQty - @n_packqty
               
               EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10,
               @c_NewPickdetailkey OUTPUT,
               @b_Success OUTPUT,
               @n_Err OUTPUT,
               @c_Errmsg OUTPUT
               
               IF NOT @b_Success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
         
               INSERT #PICKDETAIL_WIP
                      (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes, WIP_Refno, Channel_ID)
               SELECT @c_newpickdetailkey, '', PD.PickHeaderKey, PD.OrderKey, PD.OrderLineNumber, PD.Lot,
                      PD.Storerkey, PD.Sku, PD.AltSku, PD.UOM, 
                      CASE WHEN PD.UOM = '6' THEN @n_splitqty 
                           WHEN PD.UOM = '2' AND CaseCnt > 0 AND @n_splitqty % CAST(IIF(CaseCnt > 0, CaseCnt, 1) AS INT) = 0 THEN FLOOR(@n_splitqty / CaseCnt) 
                      ELSE PD.UOMQty END , 
                      @n_splitqty, PD.QtyMoved, PD.Status,
                      PD.DropID, PD.Loc, PD.ID, PD.PackKey, PD.UpdateSource, PD.CartonGroup, PD.CartonType,
                      PD.ToLoc, PD.DoReplenish, PD.ReplenishZone, PD.DoCartonize, PD.PickMethod,
                      PD.WaveKey, PD.EffectiveDate, '9', PD.ShipFlag, PD.PickSlipNo, PD.TaskDetailKey, PD.TaskManagerReasonKey, PD.Notes, PD.WIP_Refno, PD.Channel_ID
               FROM #PickDetail_WIP PD (NOLOCK)
               JOIN dbo.SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
               JOIN dbo.PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
               WHERE PD.PickDetailKey = @c_PickDetailKey
                  
               UPDATE #PICKDETAIL_WIP 
               SET CaseID = @c_labelno,
                   Qty = @n_packqty,
                   UOMQty = 
                   CASE WHEN UOM = '6' THEN @n_packqty 
                        WHEN UOM = '2' AND CaseCnt > 0 AND @n_packqty % CAST(IIF(CaseCnt > 0, CaseCnt, 1) AS INT) = 0 THEN FLOOR(@n_packqty / CaseCnt) 
                   ELSE UOMQty END 
                   --UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END
               FROM #PICKDETAIL_WIP 
               JOIN dbo.SKU (NOLOCK) ON #PICKDETAIL_WIP .Storerkey = SKU.Storerkey AND #PICKDETAIL_WIP .Sku = SKU.Sku
               JOIN dbo.PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
               WHERE PickDetailKey = @c_PickDetailKey
         
               SELECT @n_packqty = 0
            END
            FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickdetQty
         END
         CLOSE CUR_PICKDET_UPDATE
         DEALLOCATE CUR_PICKDET_UPDATE   
   
         FETCH NEXT FROM CUR_LABELUPD INTO @c_Orderkey, @n_CartonNo, @c_Storerkey, @c_Sku, @n_PackQty, @c_LabelNo, @c_UCCNo               
      END               
      CLOSE CUR_LABELUPD
      DEALLOCATE CUR_LABELUPD     
   END
   
   IF @n_Continue IN (1,2) AND @c_Automation = 'Y'                                  --(Wan01) - START                                                                          
   BEGIN
      --------------------------------------------------------------------
      -- Create Temp ToteId for Picking
      --------------------------------------------------------------------
      SELECT @n_ToteSize = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'WCSPICKTOTE')

      SET @n_TotalCube = 0.00
      DECLARE CUR_UPDATEDROPID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT P.Pickdetailkey, P.Sku, P.Loc, l.PutawayZone, P.Qty, od.StdCube 
      FROM #PickDetail_WIP P
      JOIN #ORDERSKU od ON  od.Orderkey = p.Orderkey 
                        AND od.Storerkey = p.Storerkey
                        AND od.Sku = p.Sku
      JOIN LOC l (NOLOCK) ON l.loc = p.Loc
      WHERE P.UOM = '6'
      AND p.PickMethod = '3'
      AND od.WCS = '1'
      AND l.LocationType = 'PickWCS'
      ORDER BY P.Sku, l.PutawayZone, l.Loc

      OPEN CUR_UPDATEDROPID
      
      FETCH NEXT FROM CUR_UPDATEDROPID INTO @c_PickDetailKey, @c_Sku, @c_Loc, @c_FromPAZone
                                          , @n_Qty_PD, @n_StdCube
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2)
      BEGIN
         --WL08 S
         TOTEID_ASGM:
         IF @n_TotalCube = 0.00 OR
            @c_Sku <> @c_Sku_Last OR @c_FromPAZone <> @c_FromPAZone_Last OR @c_Loc <> @c_Loc_Last   --WL08
         BEGIN
            EXECUTE dbo.nspg_Getkey
                @KeyName     = 'LVSDropID'
               ,@fieldlength = 9
               ,@keystring   = @c_DropID        OUTPUT
               ,@b_Success   = @b_success       OUTPUT
               ,@n_err       = @n_err           OUTPUT
               ,@c_errmsg    = @c_errmsg        OUTPUT

            IF @b_success = 0
            BEGIN
               SET @n_Continue = 3
            END
            ELSE
            BEGIN
               SET @c_DropID = 'T' + @c_DropID 
            END

            SET @c_Sku_Last = @c_Sku
            SET @c_Loc_Last = @c_Loc
            SET @c_FromPAZone_Last = @c_FromPAZone
            SET @n_TotalCube = 0   --WL08
         END

         --(SSA01) start--
         SET @n_SplitQty  = 0
         SET @n_TotalCube = @n_TotalCube + (@n_Qty_PD * @n_StdCube)

         IF @c_Sku <> @c_Sku_Last OR @c_FromPAZone <> @c_FromPAZone_Last OR @c_Loc <> @c_Loc_Last OR
            @n_TotalCube > @n_ToteSize OR @c_DropID = ''
         BEGIN
            IF @n_TotalCube > @n_ToteSize
            BEGIN
               SET @n_SplitQty = CEILING((@n_TotalCube - @n_ToteSize)/@n_StdCube)
               SET @n_Qty_PD   = @n_Qty_PD - @n_SplitQty
            END

            SET @n_TotalCube = 0
         END
         --(SSA01) end--
         --WL08 E

         IF @n_Continue IN (1,2)
         BEGIN
            UPDATE #PickDetail_WIP
               SET DropID = @c_DropID
                  ,CaseID = @c_DropID                                               --(Wan01) CR V1.9
                  ,Qty    = @n_Qty_PD
                  ,UOMQty = @n_Qty_PD
            WHERE PickdetailKey = @c_PickDetailKey

            IF @n_SplitQty > 0 
            BEGIN
               SET @c_NewPickdetailkey = ''
               EXECUTE dbo.nspg_GetKey
                   @KeyName     = 'PICKDETAILKEY' 
                  ,@fieldlength = 10 
                  ,@keystring   = @c_NewPickdetailkey OUTPUT 
                  ,@b_Success   = @b_Success OUTPUT 
                  ,@n_err       = @n_Err     OUTPUT 
                  ,@c_errmsg    = @c_Errmsg  OUTPUT
               
               IF NOT @b_Success = 1
               BEGIN
                  SELECT @n_continue = 3
               END
               ELSE
               BEGIN
                  INSERT #PICKDETAIL_WIP
                           (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot
                           ,Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, [Status]
                           ,DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType
                           ,ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod
                           ,WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo
                           ,Taskdetailkey, TaskManagerReasonkey
                           ,Notes
                           ,WIP_Refno, Channel_ID
                        )
                  SELECT @c_Newpickdetailkey, '', PickHeaderKey, OrderKey, OrderLineNumber, Lot
                        ,Storerkey, Sku, AltSku, UOM, @n_SplitQty, @n_SplitQty, QtyMoved, [Status]
                        ,'', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType
                        ,ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod
                        ,WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo
                        ,Taskdetailkey, TaskManagerReasonkey
                        ,'Original PickdetailKey: ' + @c_PickDetailKey + ',Qty: ' + CONVERT(NVARCHAR(10),@n_Qty_PD+@n_SplitQty)
                        ,WIP_Refno, Channel_ID
                  FROM #PickDetail_WIP 
                  WHERE PickDetailKey = @c_PickDetailKey

                  SET @n_Qty_PD = @n_SplitQty
                  SET @c_PickDetailKey = @c_NewPickdetailkey
                  GOTO TOTEID_ASGM
               END
            END 
         END

         FETCH NEXT FROM CUR_UPDATEDROPID INTO @c_PickDetailKey, @c_Sku, @c_Loc, @c_FromPAZone
                                             , @n_Qty_PD, @n_StdCube
      END
      CLOSE CUR_UPDATEDROPID
      DEALLOCATE CUR_UPDATEDROPID
   END                                                                               --(Wan01) - END 
   

   -- Gegerate Pick Tasks
   IF @n_continue IN(1,2) AND @c_Automation <> 'Y'                                  --(Wan01)
   BEGIN 
      /* declare variables */
      DECLARE @c_LOT NVARCHAR(10) = '', 
              @c_FromLOC NVARCHAR(10) = '',
              @c_ToLOC NVARCHAR(10) = '',
              @c_TaskdetailKey NVARCHAR(10)='',
              @c_ID NVARCHAR(18) = '',
              @c_AreaKey NVARCHAR(10) = ''
      
      DECLARE CUR_PICKTASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT P.PickDetailKey, P.CaseID, P.WaveKey, P.Storerkey, P.Sku, P.LOT, P.LOC, P.Qty, P.ID
      FROM #PickDetail_WIP P
      WHERE P.UOM='6'
      
      OPEN CUR_PICKTASK
      
      FETCH NEXT FROM CUR_PICKTASK INTO @c_PickDetailKey, @c_LabelNo, @c_WaveKey, @c_Storerkey, @c_Sku, @c_LOT, @c_FromLOC, @n_PickdetQty, @c_ID 
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @c_Facility = Facility, @c_AreaKey = AD.AreaKey
         FROM dbo.LOC WITH (NOLOCK) 
         JOIN dbo.AreaDetail AD WITH (NOLOCK) ON AD.PutawayZone = LOC.PutawayZone 
         WHERE Loc = @c_FromLOC

         SELECT TOP 1 @c_ToLOC = LOC
         FROM dbo.LOC WITH (NOLOCK) 
         WHERE Facility = @c_Facility
         AND PutawayZone='LVSVAS'
         ORDER BY LogicalLocation

         EXECUTE dbo.nspg_Getkey
            'TaskDetailKey'
           , 10
           , @c_TaskdetailKey OUTPUT
           , @b_success       OUTPUT
           , @n_err           OUTPUT
           , @c_errmsg        OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3
         END         

         INSERT dbo.TASKDETAIL
               ( TaskDetailKey, TaskType, Storerkey, Sku, Lot
               , UOM, UOMQty, Qty, FromLoc, FromID, ToLoc
               , ToId, SourceType, SourceKey, Caseid, Priority
               , SourcePriority, OrderKey, OrderLineNumber, PickDetailKey
               , PickMethod, STATUS, WaveKey, Areakey
               , Message01, SystemQty, GroupKey)  
         VALUES (
                 @c_TaskDetailKey
               , 'ASTCPK' -- TaskType
               , @c_Storerkey
               , @c_Sku
               , @c_Lot -- Lot,
               , '6' -- UOM
               , @n_PickdetQty  -- UOMQty,
               , @n_PickdetQty
               , @c_fromloc
               , @c_ID
               , @c_ToLoc
               , @c_ID
               , 'mspRLWAV03' --SourceType
               , @c_PickDetailKey  --SourceKey
               , @c_LabelNo -- Caseid
               , '5' -- Priority
               , '9' -- SourcePriority
               , '' -- Orderkey,
               , '' -- OrderLineNumber
               ,  @c_PickDetailKey -- PickDetailKey
               , 'B2B-Loose'
               , '0'  --Status
               , @c_WaveKey
               , @c_AreaKey
               , ''
               , @n_PickdetQty
               , '')  

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 562211
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(6) ,@n_err) + ': Insert Into TaskDetail Failed (mspRLWAV03)' +
                               ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
            GOTO QUIT_SP
         END
      
         -- Update Temp Table instead of physical.  (SWT06)
         -- UPDATE dbo.PICKDETAIL WITH (ROWLOCK)

         UPDATE #PickDetail_WIP 
            SET TaskDetailKey=@c_TaskDetailKey, TrafficCop=NULL
         WHERE PickDetailKey=@c_PickDetailKey
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_err), @n_err = 562211
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Updating PickDetail Failed (mspRLWAV03)' +
                              ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_PICKTASK INTO @c_PickDetailKey, @c_LabelNo, @c_WaveKey, @c_Storerkey, @c_Sku, @c_LOT, @c_FromLOC, @n_PickdetQty, @c_ID 
      END
      
      CLOSE CUR_PICKTASK
      DEALLOCATE CUR_PICKTASK
   END -- IF @n_continue IN(1,2)
 
   
   --WL04 S
   -- Insert Transmitlog2
   --IF @n_continue IN(1,2)
   --BEGIN
   --   EXEC  [dbo].[ispGenTransmitLog2]
   --     @c_TableName      = 'WSWVRLSLVS' 
   --   , @c_Key1           = @c_WaveKey
   --   , @c_Key2           = ''
   --   , @c_Key3           = @c_Storerkey
   --   , @c_TransmitBatch  = 1
   --   , @b_Success        = @b_Success    OUTPUT
   --   , @n_err            = @n_Err        OUTPUT
   --   , @c_errmsg         = @c_ErrMsg     OUTPUT
   --END
   --WL04 E

   -- (SWT05) Start  
   -------------------------------------------------- 
   -- FCR-1132 Wave Release SCE Trigger for BOLbyConsignee 
   --------------------------------------------------  
   IF @n_continue IN(1,2) 
   BEGIN 
      DECLARE @c_BOLbyConsigneeKey NVARCHAR(20) = '', 
              @c_FacilityPrefix NVARCHAR(60) = '', 
              @n_FieldLength INT = 0 
 
      DECLARE CUR_BOLbyConsigneekey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT OH.ConsigneeKey, OH.Facility, MAX(ISNULL(OI.ReferenceId,''))  
         FROM dbo.ORDERS OH WITH (NOLOCK)  
         JOIN dbo.OrderInfo OI WITH (NOLOCK) ON OH.OrderKey = OI.OrderKey 
         JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = OH.OrderKey 
         WHERE WD.WaveKey = @c_WaveKey  
         AND OH.OrderGroup='30' 
         GROUP BY OH.ConsigneeKey, OH.Facility  
       
      OPEN CUR_BOLbyConsigneekey 
    
      FETCH NEXT FROM CUR_BOLbyConsigneekey INTO @c_ConsigneeKey, @c_Facility, @c_BOLbyConsigneeKey 
    
      WHILE @@FETCH_STATUS = 0 
      BEGIN 
          IF TRIM(@c_BOLbyConsigneeKey) = '' 
          BEGIN 
             SET @c_FacilityPrefix = '' 
              
             SELECT @c_FacilityPrefix = ISNULL(TRIM(CODELKUP.UDF01),'0') 
             FROM dbo.CODELKUP (NOLOCK) 
             WHERE CODELKUP.LISTNAME = 'LVSFAC' 
             AND CODELKUP.Code = @c_Facility 
 
             SET @n_FieldLength = 10 - LEN(@c_FacilityPrefix) 
              
             EXECUTE dbo.nspg_GetKey   
               @KeyName='BOLbyCons',   
               @fieldlength=@n_FieldLength,   
               @keystring=@c_BOLbyConsigneeKey OUTPUT,   
               @b_Success = @b_success OUTPUT,   
               @n_err = @n_err OUTPUT,   
               @c_errmsg = @c_errmsg OUTPUT   
              
             IF NOT @b_success = 1   
             BEGIN   
                SELECT @n_continue = 3   
                BREAK   
             END     
              
             SET @c_BOLbyConsigneeKey = RIGHT(@c_FacilityPrefix + @c_BOLbyConsigneeKey, 10)  
             DECLARE CUR_UPDATE_BOLbyConsigneekey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
             SELECT OH.OrderKey 
             FROM dbo.ORDERS OH WITH (NOLOCK)  
             JOIN dbo.OrderInfo OI WITH (NOLOCK) ON OH.OrderKey = OI.OrderKey 
             JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = OH.OrderKey 
             WHERE WD.WaveKey = @c_WaveKey  
             AND OH.OrderGroup='30' 
             AND OH.ConsigneeKey = @c_ConsigneeKey              
             AND OH.Facility = @c_Facility 
             AND (OI.ReferenceId = '' OR OI.ReferenceId IS NULL) 
              
             OPEN CUR_UPDATE_BOLbyConsigneekey 
              
             FETCH NEXT FROM CUR_UPDATE_BOLbyConsigneekey INTO @c_Orderkey 
              
             WHILE @@FETCH_STATUS = 0 
             BEGIN 
                 UPDATE dbo.OrderInfo WITH (ROWLOCK)  
                  SET ReferenceId = @c_BOLbyConsigneeKey, EditDate=GETDATE() 
                 WHERE OrderKey= @c_Orderkey 
              
                 FETCH NEXT FROM CUR_UPDATE_BOLbyConsigneekey INTO @c_Orderkey 
             END 
              
             CLOSE CUR_UPDATE_BOLbyConsigneekey 
             DEALLOCATE CUR_UPDATE_BOLbyConsigneekey 
          END 
    
          FETCH NEXT FROM CUR_BOLbyConsigneekey INTO @c_ConsigneeKey, @c_Facility, @c_BOLbyConsigneeKey 
      END 
      CLOSE CUR_BOLbyConsigneekey 
      DEALLOCATE CUR_BOLbyConsigneekey 
   END  
   -- (SWT05) End

   -------------------------------------------------- 
   -- Automation Release Tasks 
   --------------------------------------------------  
   IF @n_Continue IN (1,2)  AND @c_Automation = 'Y'                                 --(Wan01)                    
   BEGIN
      DECLARE CUR_UPDATEORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT OG.OrderKey
      FROM #OrderGroup OG
      ORDER BY OG.OrderKey

      OPEN CUR_UPDATEORD
              
      FETCH NEXT FROM CUR_UPDATEORD INTO @c_OrderKey
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2)
      BEGIN
         SELECT @n_NoOfCarton = COUNT(DISTINCT pd.CaseID)
         FROM  PICKDETAIL pd (NOLOCK)
         WHERE pd.Orderkey = @c_OrderKey

         UPDATE ORDERS WITH (ROWLOCK)
            SET ContainerQty = @n_NoOfCarton
             ,  EditDate   = GETDATE()
             ,  TrafficCop = NULL
         WHERE Orderkey = @c_Orderkey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            Set @n_Err = 82014
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Updating Orders Failed (mspRLWAV03)'  
                          + ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
         END

         FETCH NEXT FROM CUR_UPDATEORD INTO @c_OrderKey
      END
      CLOSE CUR_UPDATEORD
      DEALLOCATE CUR_UPDATEORD

      --------------------------------------
      -- GEN PICK OR REPL TASK 
      --------------------------------------
      IF @n_Continue IN (1,2)                                                                             
      BEGIN
         DECLARE CUR_PTASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT P.WaveKey
               , Orderkey = CASE WHEN P.UOM = '2' THEN P.Orderkey ELSE '' END
               , OrderLineNumber = CASE WHEN P.UOM = '2' THEN P.OrderLineNumber ELSE '' END
               , P.Storerkey, P.Sku, P.LOT, P.LOC, P.ID
               , Qty = SUM(P.Qty)
               , P.UOM, P.PickMethod, P.Dropid, od.WCS
               , l.LogicalLocation, l.LocationType, l.PutawayZone
         FROM #PickDetail_WIP P
         JOIN #ORDERSKU od ON  od.Orderkey = p.Orderkey
                           AND od.Storerkey = p.Storerkey
                           AND od.Sku = p.Sku
         JOIN LOC l (NOLOCK) ON l.loc = p.Loc
         WHERE P.UOM IN ('2','6')
         GROUP BY P.WaveKey
               ,  CASE WHEN P.UOM = '2' THEN P.Orderkey ELSE '' END
               ,  CASE WHEN P.UOM = '2' THEN P.OrderLineNumber ELSE '' END
               ,  P.Storerkey
               ,  P.Sku
               ,  P.LOT
               ,  P.LOC
               ,  P.ID
               ,  P.UOM
               ,  P.PickMethod
               ,  P.Dropid
               ,  od.WCS
               ,  l.LogicalLocation
               ,  l.LocationType
               ,  l.PutawayZone
         ORDER BY P.UOM
               ,  CASE WHEN P.UOM = '2' THEN P.Orderkey ELSE '' END
               ,  CASE WHEN P.UOM = '2' THEN P.OrderLineNumber ELSE '' END
               ,  P.PickMethod
               ,  P.Sku
      
         OPEN CUR_PTASK
      
         FETCH NEXT FROM CUR_PTASK INTO @c_WaveKey, @c_Orderkey, @c_OrderLineNumber
                                       ,@c_Storerkey, @c_Sku, @c_LOT, @c_FromLOC, @c_ID, @n_PickdetQty 
                                       ,@c_UOM, @c_PickMethod, @c_DropId, @b_WCS 
                                       ,@c_FromLogicalLoc, @c_FromLocType, @c_FromPAZone
      
         WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2)
         BEGIN
            SET @c_TaskStatus    = 'H'
            SET @c_ToLoc         = ''
            SET @c_ToLocType     = ''
            SET @c_ToLocCategory = ''
            SET @c_ToPAZone      = ''  
            SET @c_FinalLoc      = ''
                                  
            IF @c_UOM = '2'
            BEGIN
               IF @b_WCS = 0
               BEGIN
                  SET @c_TaskType      = 'FCP'
                  SET @c_PickMethod_TD = 'PP'
                  SET @c_ToLocType     = 'PackWCS'
                  SET @c_ToLocCategory = 'Stage'
                  SET @c_ToPAZone      = 'VAS'

                  IF EXISTS ( SELECT 1
                              FROM dbo.WorkOrderDetail wod (NOLOCK)
                              WHERE wod.[Type] = ''
                              AND   wod.ExternWorkOrderKey = @c_Orderkey
                              AND   wod.ExternLineNo = @c_OrderLineNumber
                              )
                  BEGIN
                     SET @c_ToLocType = 'StageWCS'
                     SET @c_ToPAZone = 'PCB'
                  END
                  
                  SELECT TOP 1 @c_ToLoc = l.Loc
                  FROM LOC l (NOLOCK) 
                  WHERE l.Facility = @c_Facility
                  AND   l.LocationType = @c_ToLocType
                  AND   l.LocationCategory = @c_ToLocCategory
                  AND   l.PutawayZone = @c_ToPAZone
                  ORDER BY l.loc
               END
               ELSE
               BEGIN
                  IF @c_FromLocType = 'CASE'
                  BEGIN
                     SET @c_TaskType      = 'RPF'
                     SET @c_PickMethod_TD = 'PP'
                     SET @c_ToLoc         = @c_PNDLoc
                  END
               END
            END
            ELSE IF @c_UOM = '6'
            BEGIN
               IF @c_PickMethod IN ('C', '3') AND @c_DropID <> '' 
               BEGIN
                  IF @b_WCS = 0
                  BEGIN
                     SET @c_TaskType      = 'RPF'
                     SET @c_PickMethod_TD = 'PP'

                     SELECT TOP 1 @c_ToLoc = LOC.Loc 
                     FROM dbo.SKUXLOC sl (NOLOCK) 
                     JOIN dbo.LOC LOC (NOLOCK) ON loc.loc = sl.loc
                     LEFT OUTER JOIN dbo.LOTxLOCxID lli (NOLOCK) ON  lli.StorerKey = SL.StorerKey 
                                                                 AND lli.sku = SL.SKU 
                                                                 AND lli.loc = sl.loc
                     WHERE sl.SKU = @c_Sku
                     AND sl.StorerKey = @c_StorerKey
                     AND sl.LocationType = 'PICK'
                     AND loc.Facility = @c_Facility
                     AND loc.LocationFlag NOT IN ('DAMAGE','HOLD')  
                     AND loc.MaxCarton > 0
                     GROUP BY LOC.Loc, loc.LogicalLocation, LOC.LocAisle
                     HAVING SUM(ISNULL(lli.Qty - lli.QtyPicked + lli.PendingMoveIn,0)) 
                            + @n_PickdetQty <= MAX(sl.QtyLocationLimit)
                     ORDER BY loc.LogicalLocation

                     IF @c_ToLoc = ''
                     BEGIN
                        SELECT TOP 1 @c_ToLoc = loc.Loc 
                        FROM LOC LOC (NOLOCK) 
                        JOIN LOTxLOCxID LLI (NOLOCK) ON LLI.Loc = LOC.Loc
                        WHERE lli.SKU = @c_Sku
                        AND lli.StorerKey = @c_StorerKey
                        AND loc.LocationType = 'DYNAMICPK'
                        AND loc.Facility = @c_Facility
                        AND loc.LocationFlag NOT IN ('DAMAGE','HOLD')  
                        AND loc.MaxCarton > 0
                        AND (LLI.Qty - LLI.QtyPicked + LLI.PendingMoveIn) > 0    
                        GROUP BY loc.Loc, loc.MaxCarton, loc.LogicalLocation, LOC.LocAisle
                        HAVING CEILING(SUM(lli.Qty - lli.QtyPicked + lli.PendingMoveIn)/@n_PickdetQty) < LOC.MaxCarton
                        ORDER BY loc.LogicalLocation
                     END

                     -- Find Empty in DP loc can fit in
                     IF @c_ToLoc = ''
                     BEGIN
                        SELECT TOP 1 
                           @c_ToLoc = loc.Loc 
                        FROM LOC loc (NOLOCK)
                        LEFT OUTER JOIN LOTxLOCxID lli (NOLOCK)  ON  loc.loc = lli.loc
                        WHERE loc.LocationType = 'DYNAMICPK'
                        AND  loc.Facility = @c_Facility
                        AND loc.LocationFlag NOT IN ('DAMAGE','HOLD')  
                        AND loc.MaxCarton > 0
                        GROUP BY loc.Loc, loc.LogicalLocation, LOC.LocAisle
                        HAVING SUM(ISNULL(lli.Qty,0) - ISNULL(lli.QtyPicked,0) + ISNULL(lli.PendingMoveIn,0)) = 0
                        ORDER BY loc.LogicalLocation
                     END

                     IF @c_ToLoc = ''
                     BEGIN
                        SET @n_continue = 3
                        SET @n_err = 82019
                        SET @c_errmsg='NSQL' + CONVERT(char(6), @n_err) 
                                     + ':No empty dynamic/pick face location available for SKU. (mspRLWAV03)'
                     END

                     IF @n_continue = 1
                     BEGIN
                        SELECT TOP 1 @c_FinalLoc = l.Loc
                        FROM LOC l (NOLOCK)
                        WHERE l.Facility = @c_Facility
                        AND   l.LocationType = 'PackWCS'
                        AND   l.LocationCategory = 'Stage'
                        AND   l.PutawayZone = 'VAS'
                     END
                  END
                  ELSE
                  BEGIN 
                     SET @c_TaskType      = 'RPF'
                     SET @c_PickMethod_TD = 'PP'
                     IF @c_FromLocType    = 'CASE'
                     BEGIN
                        SET @c_ToLoc    = @c_PNDLoc
                        --SET @c_FinalLoc = @c_ToLoc
                     END
                     ELSE IF @c_FromLocType = 'PickWCS' AND  @c_PickMethod = '3' 
                     BEGIN
                        SET @c_TaskType      = 'ASTCPK'
                        SET @c_PickMethod_TD = 'B2B-Loose'

                        SELECT TOP 1 @c_ToLoc = ISNULL(cl.long,'')
                        FROM CODELKUP cl (NOLOCK)
                        WHERE ListName = 'BBDefLoc'
                        AND Code  = '3'
                        AND Short = @c_Facility
                        AND Storerkey = @c_Storerkey
                     END
                  END
               END    
            END

            IF @n_continue = 1 AND @c_ToLoc > '' 
            BEGIN
               SELECT @c_AreaKey = ad.AreaKey
               FROM AreaDetail ad (NOLOCK)
               WHERE ad.PutawayZone =  @c_FromPAZone
               
               IF @c_TaskType = 'RPF'
               BEGIN 
                  SELECT @n_PickdetQty = SUM(UCC.Qty) 
                  FROM UCC (NOLOCK)
                  WHERE UCC.Storerkey = @c_Storerkey
                  AND   UCC.UCCNo = @c_DropID
                  AND   UCC.[Status] = '3'
               END

               SET @b_success = 1
               EXECUTE dbo.nspg_Getkey
                  @KeyName       = 'TaskDetailKey'
               ,  @fieldlength   =  10
               ,  @keystring     =  @c_TaskdetailKey OUTPUT
               ,  @b_Success     =  @b_success       OUTPUT
               ,  @n_err         =  @n_err           OUTPUT
               ,  @c_errmsg      =  @c_errmsg        OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @n_continue = 3
               END  
               
               IF @n_continue = 1
               BEGIN
                  SET @c_RefTaskkey = ''
                  IF @c_ToLoc <> @c_FinalLoc AND @c_FinalLoc > ''
                  BEGIN
                     SET @c_RefTaskkey = @c_TaskdetailKey
                  END

                  SET @n_PendingMoveIn = 0
                  IF @c_TaskType = 'RPF' 
                  BEGIN
                     SET @n_PendingMoveIn = @n_PickdetQty
                  END

                  INSERT dbo.TASKDETAIL
                        ( TaskDetailKey, TaskType, Storerkey, Sku, Lot
                        , UOM, UOMQty, Qty, FromLoc, LogicalFromLoc, FromID, ToLoc, LogicalToLoc
                        , ToId, SourceType, SourceKey, Caseid, Priority
                        , SourcePriority, OrderKey, OrderLineNumber, PickDetailKey
                        , PickMethod, STATUS, WaveKey, Areakey
                        , Message01, SystemQty, PendingMoveIn, FinalLoc, GroupKey, RefTaskKey)  
                  VALUES (
                    @c_TaskDetailKey
                  , @c_TaskType
                  , @c_Storerkey
                  , @c_Sku
                  , @c_Lot -- Lot,
                  , @c_UOM -- UOM
                  , @n_PickdetQty  -- UOMQty,
                  , @n_PickdetQty
                  , @c_Fromloc
                  , @c_FromLogicalLoc
                  , @c_ID
                  , @c_ToLoc
                  , @c_ToLoc
                  , @c_ID
                  , @c_SourceType
                  , '' --SourceKey
                  , @c_DropId
                  , '5' -- Priority
                  , '9' -- SourcePriority
                  , '' -- Orderkey,
                  , '' -- OrderLineNumber
                  , '' -- PickDetailKey
                  , @c_PickMethod_TD
                  , @c_TaskStatus  --Status
                  , @c_WaveKey
                  , @c_AreaKey
                  , ''
                  , @n_PickdetQty
                  , @n_PendingMoveIn
                  , @c_FinalLoc      
                  , ''
                  , @c_RefTaskkey
                  )  

                  SET @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_ErrMsg = CONVERT(CHAR(250), @n_err)
                     SET @n_err = 82015
                     SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Insert Into TaskDetail Failed (mspRLWAV03)'  
                                    +    ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
                  END
               END

               IF @n_Continue IN (1, 2)
               BEGIN
                  DECLARE CUR_UDPATEPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
                  SELECT P.PickDetailKey
                  FROM #PickDetail_WIP P
                  WHERE P.UOM = @c_UOM
                  AND   P.PickMethod = @c_PickMethod
                  AND   p.Lot = @c_Lot
                  AND   p.Loc = @c_FromLoc
                  AND   p.ID  = @c_ID
                  AND   p.DropID  = @c_DropID

                  OPEN CUR_UDPATEPD

                  FETCH NEXT FROM CUR_UDPATEPD INTO @c_PickDetailKey
         
                  WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2)
                  BEGIN
                     UPDATE #PickDetail_WIP  
                        SET TaskDetailKey=@c_TaskDetailKey 
                     WHERE PickDetailKey=@c_PickDetailKey

                     -- (SWT999) Only update temp table.
                     --UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
                     --   SET TaskDetailKey=@c_TaskDetailKey, TrafficCop=NULL
                     --WHERE PickDetailKey=@c_PickDetailKey

                     SET @n_err = @@ERROR
                     IF @n_err <> 0
                     BEGIN
                        SET @n_continue = 3
                        SET @c_ErrMsg = CONVERT(CHAR(250), @n_err)
                        SET @n_err = 82016
                        SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Updating PickDetail Failed (mspRLWAV03)'  
                                       + ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
                     END
                     FETCH NEXT FROM CUR_UDPATEPD INTO @c_PickDetailKey
                  END
                  CLOSE CUR_UDPATEPD
                  DEALLOCATE CUR_UDPATEPD
               END
            END
            FETCH NEXT FROM CUR_PTASK INTO @c_WaveKey, @c_Orderkey, @c_OrderLineNumber
                                       ,   @c_Storerkey, @c_Sku, @c_LOT, @c_FromLOC, @c_ID, @n_PickdetQty  
                                       ,   @c_UOM, @c_PickMethod, @c_DropId, @b_WCS 
                                       ,   @c_FromLogicalLoc, @c_FromLocType, @c_FromPAZone 
         END
         CLOSE CUR_PTASK
         DEALLOCATE CUR_PTASK
      END
   END

   --------------------------------------
   -- GEN PICK AND PACK TASK 
   --------------------------------------
   IF @n_Continue IN (1,2)                                                                            
   BEGIN
      DECLARE CUR_PNPTASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT td.WaveKey
            , td.Storerkey, td.Sku, td.LOT, td.ToLoc, td.ToID, td.FinalLoc 
            , td.Qty 
            , td.UOM, P.DropID, td.RefTaskKey
            , l.LogicalLocation, l.LocationType, l.PutawayZone
      FROM #PickDetail_WIP P
      JOIN Taskdetail td (NOLOCK) ON td.TaskDetailKey = P.TaskdetailKey
      JOIN LOC l (NOLOCK) ON l.loc = td.ToLoc
      WHERE td.UOM = '6'
      AND td.TaskType = 'RPF'
      AND td.ToLoc <> td.FinalLOC AND td.FinalLOC > ''
      AND td.RefTaskkey > ''
      GROUP BY td.WaveKey
            ,  td.Storerkey
            ,  td.Sku
            ,  td.LOT
            ,  td.ToLoc
            ,  td.ToID
            ,  td.FinalLoc 
            ,  td.Qty             
            ,  td.UOM
            ,  P.DropID
            ,  td.RefTaskKey
            ,  l.LogicalLocation
            ,  l.LocationType
            ,  l.PutawayZone
      ORDER BY td.UOM
            ,  td.Sku
      
      OPEN CUR_PNPTASK
      
      FETCH NEXT FROM CUR_PNPTASK INTO @c_WaveKey  
                                    ,  @c_Storerkey, @c_Sku, @c_LOT, @c_FromLOC, @c_ID, @c_ToLoc
                                    ,  @n_PickdetQty ,@c_UOM, @c_DropID, @c_RefTaskKey
                                    ,  @c_FromLogicalLoc, @c_FromLocType, @c_FromPAZone
      
      WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2)
      BEGIN
         SET @c_TaskType      = 'ASTCPK'
         SET @c_PickMethod_TD = 'B2B-Loose'
         SET @c_TaskStatus    = 'H'
         SET @c_FinalLoc      = ''
           
         SELECT @c_AreaKey = ad.AreaKey
         FROM AreaDetail ad (NOLOCK)
         WHERE ad.PutawayZone =  @c_FromPAZone

         SET @b_success = 1
         EXECUTE dbo.nspg_Getkey
            @KeyName       = 'TaskDetailKey'
         ,  @fieldlength   =  10
         ,  @keystring     =  @c_TaskdetailKey OUTPUT
         ,  @b_Success     =  @b_success       OUTPUT
         ,  @n_err         =  @n_err           OUTPUT
         ,  @c_errmsg      =  @c_errmsg        OUTPUT

         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3
         END         

         INSERT dbo.TASKDETAIL
               ( TaskDetailKey, TaskType, Storerkey, Sku, Lot
               , UOM, UOMQty, Qty, FromLoc, LogicalFromLoc, FromID, ToLoc, LogicalToLoc
               , ToId, SourceType, SourceKey, Caseid, Priority
               , SourcePriority, OrderKey, OrderLineNumber, PickDetailKey
               , PickMethod, STATUS, WaveKey, Areakey
               , Message01, SystemQty, FinalLoc, GroupKey, RefTaskkey)  
         VALUES (
           @c_TaskDetailKey
         , @c_TaskType
         , @c_Storerkey
         , @c_Sku
         , @c_Lot -- Lot,
         , @c_UOM -- UOM
         , @n_PickdetQty  -- UOMQty,
         , @n_PickdetQty
         , @c_Fromloc
         , @c_FromLogicalLoc
         , @c_ID
         , @c_ToLoc
         , @c_ToLoc
         , @c_ID
         , @c_SourceType
         , '' --SourceKey
         , @c_DropID 
         , '5' -- Priority
         , '9' -- SourcePriority
         , '' -- Orderkey,
         , '' -- OrderLineNumber
         , '' -- PickDetailKey
         , @c_PickMethod_TD
         , @c_TaskStatus  --Status
         , @c_WaveKey
         , @c_AreaKey
         , ''
         , @n_PickdetQty
         , @c_FinalLoc
         , ''
         , @c_RefTaskkey
         )  

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_ErrMsg = CONVERT(CHAR(250), @n_err)
            SET @n_err = 82017
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err) + ': Insert Into TaskDetail Failed (mspRLWAV03)' 
                           + ' ( '+' SQLSvr MESSAGE= ' + @c_ErrMsg + ' ) '
         END
 
         FETCH NEXT FROM CUR_PNPTASK INTO @c_WaveKey  
                                       ,  @c_Storerkey, @c_Sku, @c_LOT, @c_FromLOC, @c_ID, @c_ToLoc
                                       ,  @n_PickdetQty ,@c_UOM, @c_DropID, @c_RefTaskKey 
                                       ,  @c_FromLogicalLoc, @c_FromLocType, @c_FromPAZone
      END
      CLOSE CUR_PNPTASK
      DEALLOCATE CUR_PNPTASK
      -- (SWT07)
      -- Split 'ASTCPK' Task Type to PickDetail.CaseID instead of PickDetail.DropID
      DECLARE @n_SerialNo          INT = 0,
              @c_NewTaskDetailKey  NVARCHAR(10) = N''

      DECLARE CUR_ASTCPK_TASK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TD.TaskDetailKey, PD.CaseID, PD.Qty,
                ROW_NUMBER() OVER (PARTITION BY TD.TaskDetailKey ORDER BY PD.CaseID) AS SerialNo
         FROM #PickDetail_WIP PD (NOLOCK)
         JOIN TaskDetail TD (NOLOCK) ON PD.TaskDetailKey = TD.RefTaskKey AND TD.LOT = PD.LOT AND TD.CaseID = PD.DropID
         JOIN #ORDERSKU OS (NOLOCK) ON PD.StorerKey = OS.StorerKey AND PD.SKU = OS.SKU AND PD.OrderKey = OS.OrderKey  --(SSA03)
         WHERE TD.WaveKey = @c_WaveKey
         AND TD.TaskType = 'ASTCPK'
         AND TD.PickMethod = 'B2B-Loose'
         AND PD.UOM = '6'
         AND OS.WCS = 0                         --(SSA03)
         ORDER BY TD.TaskDetailKey

      OPEN CUR_ASTCPK_TASK

      FETCH NEXT FROM CUR_ASTCPK_TASK INTO @c_TaskdetailKey, @c_DropId, @n_PickdetQty, @n_SerialNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @n_SerialNo = 1
         BEGIN
            UPDATE TASKDETAIL
               SET Qty = @n_PickdetQty,
			       UOMQty = @n_PickdetQty,
                   Caseid = @c_DropId,
                   EditDate=GETDATE(),
                   EditWho = SUSER_SNAME()
            WHERE TaskDetailKey = @c_TaskdetailKey
         END
         ELSE
         BEGIN
            SET @b_success = 1
            EXECUTE dbo.nspg_Getkey
               @KeyName       = 'TaskDetailKey'
            ,  @fieldlength   =  10
            ,  @keystring     =  @c_NewTaskDetailKey OUTPUT
            ,  @b_Success     =  @b_success       OUTPUT
            ,  @n_err         =  @n_err           OUTPUT
            ,  @c_errmsg      =  @c_errmsg        OUTPUT

            IF @b_success <> 1
            BEGIN
               SET @n_continue = 3
            END
            ELSE
            BEGIN
               INSERT dbo.TASKDETAIL
               ( TaskDetailKey, TaskType, Storerkey, Sku, Lot
               , UOM, UOMQty, Qty, FromLoc, LogicalFromLoc, FromID, ToLoc, LogicalToLoc
               , ToId, SourceType, SourceKey, Caseid, Priority
               , SourcePriority, OrderKey, OrderLineNumber, PickDetailKey
               , PickMethod, STATUS, WaveKey, Areakey
               , Message01, SystemQty, PendingMoveIn, FinalLoc, GroupKey, RefTaskKey)
               SELECT @c_NewTaskDetailKey, TaskType, Storerkey, Sku, Lot
               , UOM, @n_PickdetQty, @n_PickdetQty, FromLoc, LogicalFromLoc, FromID, ToLoc, LogicalToLoc
               , ToId, SourceType, SourceKey, @c_DropId, Priority
               , SourcePriority, OrderKey, OrderLineNumber, PickDetailKey
               , PickMethod, STATUS, WaveKey, Areakey
               , Message01, SystemQty, PendingMoveIn, FinalLoc, GroupKey, RefTaskKey
               FROM TASKDETAIL (NOLOCK)
               WHERE TaskDetailKey = @c_TaskdetailKey
            END
         END

         FETCH NEXT FROM CUR_ASTCPK_TASK INTO @c_TaskdetailKey, @c_DropId, @n_PickdetQty, @n_SerialNo
      END -- WHile
      CLOSE CUR_ASTCPK_TASK
      DEALLOCATE CUR_ASTCPK_TASK
   END


   -----Update pickdetail_WIP work in progress staging table back to pickdetail    
   IF @n_continue IN(1,2)
   BEGIN
      EXEC dbo.isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_WaveKey               = @c_WaveKey
           ,@c_WIP_RefNo             = @c_SourceType
           ,@c_PickCondition_SQL     = ''
           ,@c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
           ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_Err     OUTPUT
           ,@c_ErrMsg                = @c_ErrMsg  OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END
   END     
   QUIT_SP:

   IF @n_Continue = 3 -- Error Occured - Process AND Return  
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'mspRLWAV03'
      RAISERROR(@c_ErrMsg, 16, 1) WITH SETERROR -- SQL2012  
      --RAISERROR @nErr @cErrmsg  
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO