SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: ispRLWAV49                                          */  
/* Creation Date: 26-Jan-2022                                            */  
/* Copyright: LFL                                                        */  
/* Written by: WLChooi                                                   */  
/*                                                                       */  
/* Purpose: WMS-18741 - [TW]LOR_WaveReleaseTask_CR                       */
/*          Copy and modified from ispRLWAV15                            */  
/*                                                                       */  
/* Called By: Wave                                                       */  
/*                                                                       */  
/* GitLab Version: 1.1                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver.  Purposes                                  */  
/* 26-Jan-2022  WLChooi  1.0   DevOps Combine Script                     */
/* 29-Apr-2022  WLChooi  1.1   Bug Fix - Fix TaskType = FCP for non PTL  */
/*                             (WL01)                                    */
/*************************************************************************/   

CREATE PROCEDURE [dbo].[ispRLWAV49]      
       @c_wavekey      NVARCHAR(10)  
      ,@b_Success      INT            OUTPUT  
      ,@n_err          INT            OUTPUT  
      ,@c_errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue  INT,    
           @n_starttcnt INT,         -- Holds the current transaction count  
           @n_debug     INT,
           @n_cnt       INT
   
   IF @n_err > 0
      SET @n_debug = @n_err

   SELECT  @n_starttcnt = @@TRANCOUNT , @n_continue = 1, @b_success = 0,@n_err = 0,@c_errmsg = '',@n_cnt = 0
   
   DECLARE  @c_Storerkey               NVARCHAR(15)
           ,@c_Facility                NVARCHAR(5)
           ,@c_Sku                     NVARCHAR(20)
           ,@c_Lot                     NVARCHAR(10)
           ,@c_FromLoc                 NVARCHAR(10)
           ,@c_ID                      NVARCHAR(18)
           ,@n_Qty                     INT
           ,@c_SourceType              NVARCHAR(30)
           ,@c_Orderkey                NVARCHAR(10)
           ,@c_OrderLineNumber         NVARCHAR(5)
           ,@c_DispatchCasePickMethod  NVARCHAR(10)
           ,@c_Packstation             NVARCHAR(10)
           ,@c_TaskType                NVARCHAR(10)
           ,@c_UOM                     NVARCHAR(10)
           ,@n_UOMQty                  INT
           ,@c_PickMethod              NVARCHAR(10)            
           ,@c_Priority                NVARCHAR(10)
           ,@c_Toloc                   NVARCHAR(10)
           ,@c_Taskdetailkey           NVARCHAR(10)  
           ,@c_LinkTaskToPick_SQL      NVARCHAR(4000)
           ,@c_Pickdetailkey           NVARCHAR(10)
           ,@c_PickslipNo              NVARCHAR(10)
           ,@c_Userdefine05            NVARCHAR(18)
           ,@c_LocationType            NVARCHAR(10)
           ,@c_PrevOrderkey            NVARCHAR(10)
           ,@c_Groupkey                NVARCHAR(10)
           ,@c_SUSR3                   NVARCHAR(20)
           ,@dt_DeliveryDate           DATETIME
           ,@n_Shipday                 INT
           ,@n_Holiday                 INT
           ,@c_Code                    NVARCHAR(30)
           ,@C_Consigneekey            NVARCHAR(15)
           ,@c_WaveType                NVARCHAR(50)
           ,@c_AllFinalLoc             NVARCHAR(500)
           ,@n_CurrFinalLocIndex       INT
           ,@c_Loadkey                 NVARCHAR(10)
           ,@c_PrevLoadkey             NVARCHAR(10)
           ,@c_IntermodalVehicle       NVARCHAR(100)
           ,@n_MaxIndex                INT = 0
           ,@n_Interval                INT = 4
           ,@c_Brand                   NVARCHAR(100)
           ,@n_RowID                   INT = 0
           ,@n_CountTempRow            INT = 0
           ,@n_CountActualRow          INT = 0
           ,@c_QuitLoop                NVARCHAR(10) = 'N'
           ,@c_AllIntermodalVehicle    NVARCHAR(500)
           ,@c_BrandGroup              NVARCHAR(30)
           ,@c_LoadCount               NVARCHAR(10)
           ,@c_AllTaskType             NVARCHAR(500) = ''
                       
   SET @c_SourceType = 'ispRLWAV49'    
   SET @c_Priority = '9'
   --SET @c_TaskType = 'FCP'
   SET @c_PickMethod = 'PP'
   
   -----Wave Validation-----            
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      SELECT @c_Storerkey = OH.Storerkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.WaveKey = @c_wavekey

      SELECT @c_AllTaskType = STUFF((SELECT DISTINCT ',' + RTRIM(CL.code2) 
                                     FROM CODELKUP CL (NOLOCK)
                                     WHERE CL.Listname = 'LORBRAND' AND CL.Storerkey = @c_Storerkey
                                     ORDER BY 1 FOR XML PATH('')),1,1,'' )
      IF NOT EXISTS (SELECT 1 
                     FROM WAVEDETAIL WD (NOLOCK)
                     JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                     LEFT JOIN TASKDETAIL TD (NOLOCK) ON PD.Taskdetailkey = TD.Taskdetailkey AND TD.Sourcetype = @c_SourceType 
                                                     AND (TD.Tasktype IN (SELECT DISTINCT ColValue FROM dbo.fnc_DelimSplit(',', @c_AllTaskType))
                                                          OR TD.Tasktype IN ('FCP') )  --WL01
                     WHERE WD.Wavekey = @c_Wavekey                   
                     AND PD.Status = '0'
                     AND TD.Taskdetailkey IS NULL
                    )
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83000  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (ispRLWAV49)'       
      END      
   END

   --Create pickdetail Work in progress temporary table    
   IF @n_continue = 1 OR @n_continue = 2
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
         [CartonGroup] [NVARCHAR](10) NULL,
         [CartonType] [NVARCHAR](10) NULL,
         [ToLoc] [NVARCHAR](10) NULL  DEFAULT (' '),
         [DoReplenish] [NVARCHAR](1) NULL DEFAULT ('N'),
         [ReplenishZone] [NVARCHAR](10) NULL DEFAULT (' '),
         [DoCartonize] [NVARCHAR](1) NULL DEFAULT ('N'),
         [PickMethod] [NVARCHAR](1) NOT NULL DEFAULT (' '),
         [WaveKey] [NVARCHAR](10) NOT NULL DEFAULT (' '),
         [EffectiveDate] [datetime] NOT NULL DEFAULT (GETDATE()),
         [AddDate] [datetime] NOT NULL DEFAULT (GETDATE()),
         [AddWho] [NVARCHAR](128) NOT NULL DEFAULT (SUSER_SNAME()),
         [EditDate] [datetime] NOT NULL DEFAULT (GETDATE()),
         [EditWho] [NVARCHAR](128) NOT NULL DEFAULT (SUSER_SNAME()),
         [TrafficCop] [NVARCHAR](1) NULL,
         [ArchiveCop] [NVARCHAR](1) NULL,
         [OptimizeCop] [NVARCHAR](1) NULL,
         [ShipFlag] [NVARCHAR](1) NULL DEFAULT ('0'),
         [PickSlipNo] [NVARCHAR](10) NULL,
         [TaskDetailKey] [NVARCHAR](10) NULL,
         [TaskManagerReasonKey] [NVARCHAR](10) NULL,
         [Notes] [NVARCHAR](4000) NULL,
         [MoveRefKey] [NVARCHAR](10) NULL DEFAULT (''),
         [WIP_Refno] [NVARCHAR](30) NULL DEFAULT (''),
         [Channel_ID] [BIGINT] NULL DEFAULT ((0)))    
         
      CREATE TABLE #TMP_FinalLoc (
         IntermodalVehicle       NVARCHAR(100)
       , AllFinalLoc             NVARCHAR(500)
       , CurrFinalLocIndex       INT
       , BrandGroup              NVARCHAR(100)
       , GroupSeq                NVARCHAR(100)
       , LoadCount               NVARCHAR(10)
       , TaskType                NVARCHAR(20)
      )             

   END

   --Initialize Pickdetail work in progress staging table  
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN    	 	    	 	    	 
      EXEC isp_CreatePickdetail_WIP
            @c_Loadkey               = ''
           ,@c_Wavekey               = @c_wavekey  
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
     
   -----Get Storerkey, facility and order group
   IF  (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = O.Storerkey, 
                   @c_Facility = O.Facility,
                   @c_DispatchCasePickMethod = W.DispatchCasePickMethod,
                   @c_WaveType = W.WaveType
      FROM WAVE W (NOLOCK)
      JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      AND W.Wavekey = @c_Wavekey   
      
      SELECT @c_AllIntermodalVehicle = STUFF((SELECT DISTINCT ',' + RTRIM(OH.IntermodalVehicle) 
                                              FROM WAVEDETAIL WD (NOLOCK)
                                              JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
                                              WHERE WD.WaveKey = @c_wavekey
                                              ORDER BY 1 FOR XML PATH('')),1,1,'' )

      INSERT INTO #TMP_FinalLoc (IntermodalVehicle, AllFinalLoc, CurrFinalLocIndex
                               , BrandGroup, GroupSeq, LoadCount, TaskType)
      SELECT DISTINCT CL.Code, CL.Long
                    , CASE WHEN ISNULL(CL.Notes,'') = '' THEN 0
                           WHEN ISNUMERIC(CL.Notes) <> 1 THEN 0
                           ELSE CAST(CL.Notes AS INT) END
                    , ISNULL(CL.UDF03,'')
                    , ISNULL(CL.UDF04,'')
                    , ISNULL(CL.UDF05,'')
                    , ISNULL(CL.code2,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'LORBRAND'
      --AND CL.Code2 IN ('PTL')  
      AND CL.Storerkey = @c_Storerkey    
      AND CL.Code IN (SELECT DISTINCT ColValue FROM dbo.fnc_DelimSplit(',', @c_AllIntermodalVehicle) FDS)
   END  
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN 
      IF @c_WaveType NOT IN ('PTL','0','POY','WTSONS')
      BEGIN
         SELECT @n_continue = 3  
         SELECT @n_err = 83001  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave Type Cannot Release Task. (ispRLWAV49)'       
      END      
   END  
   
   --Remove taskdetailkey 
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      UPDATE #PICKDETAIL_WIP WITH (ROWLOCK) 
      SET #PICKDETAIL_WIP.TaskdetailKey = '',
          #PICKDETAIL_WIP.TrafficCop = NULL
      FROM WAVEDETAIL (NOLOCK)  
      JOIN #PICKDETAIL_WIP ON WAVEDETAIL.Orderkey = #PICKDETAIL_WIP.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey 
      AND #PICKDETAIL_WIP.WIP_RefNo = @c_SourceType
      
      SELECT @n_err = @@ERROR
      IF @n_err <> 0 
      BEGIN
        SELECT @n_continue = 3  
        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83050  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #PickDetail_WIP Table Failed. (ispRLWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END 
   END

   CREATE TABLE #TMP_PTL_TEMP (
         RowID                INT NOT NULL IDENTITY(1,1) PRIMARY KEY
       , Storerkey            NVARCHAR(15) NULL
       , Sku                  NVARCHAR(20) NULL
       , Lot                  NVARCHAR(10) NULL
       , Loc                  NVARCHAR(10) NULL
       , ID                   NVARCHAR(18) NULL
       , Qty                  INT NULL
       , UOM                  NVARCHAR(10) NULL
       , UOMQty               INT NULL
       , LocationType         NVARCHAR(10) NULL
       , LoadKey              NVARCHAR(10) NULL
       , IntermodalVehicle    NVARCHAR(100) NULL
       , Userdefine05         NVARCHAR(18) NULL
       , Inserted             NVARCHAR(10) NULL
       , BrandGroup           NVARCHAR(30) NULL
       , TaskType             NVARCHAR(20)
   )

   CREATE TABLE #TMP_PTL (
         RowID                INT NOT NULL IDENTITY(1,1) PRIMARY KEY
       , Storerkey            NVARCHAR(15) NULL
       , Sku                  NVARCHAR(20) NULL
       , Lot                  NVARCHAR(10) NULL
       , Loc                  NVARCHAR(10) NULL
       , ID                   NVARCHAR(18) NULL
       , Qty                  INT NULL
       , UOM                  NVARCHAR(10) NULL
       , UOMQty               INT NULL
       , LocationType         NVARCHAR(10) NULL
       , LoadKey              NVARCHAR(10) NULL
       , IntermodalVehicle    NVARCHAR(100) NULL
       , Userdefine05         NVARCHAR(18) NULL
       , BrandGroup           NVARCHAR(30) NULL
       , TaskType             NVARCHAR(20)
   )

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_WaveType IN ('PTL')
   BEGIN
      INSERT INTO #TMP_PTL_TEMP(Storerkey, Sku, Lot, Loc, ID, Qty, UOM, UOMQty, LocationType, LoadKey, IntermodalVehicle
                              , Userdefine05, Inserted, BrandGroup, TaskType)
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
             MAX(PD.UOM), SUM(PD.UOMQty) AS UOMQty, LOC.LocationType,
             O.LoadKey, MAX(O.IntermodalVehicle), MAX(ISNULL(OD.Userdefine05,'')), 'N', TFL.BrandGroup,
             TFL.TaskType
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey              
      JOIN #PickDetail_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber 
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
      JOIN #TMP_FinalLoc TFL ON TFL.IntermodalVehicle = O.IntermodalVehicle
      WHERE WD.Wavekey = @c_Wavekey
      AND PD.Status = '0'
      AND PD.WIP_RefNo = @c_SourceType
      GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, LOC.LocationType, LOC.LogicalLocation
             , O.LoadKey, TFL.BrandGroup, TFL.GroupSeq, TFL.TaskType
      ORDER BY TFL.BrandGroup, TFL.GroupSeq, PD.Storerkey, O.LoadKey, LOC.LogicalLocation, PD.LOC, PD.Sku,
               CASE WHEN LOC.LocationType = 'PICK' THEN 1 ELSE 2 END,
               CASE WHEN LOC.LocationType = 'PICK' THEN LOC.LogicalLocation ELSE PD.Sku END, 
               PD.Lot 

      DECLARE CUR_GROUP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TFL.BrandGroup, MAX(TFL.LoadCount)
      FROM #TMP_FinalLoc TFL
      GROUP BY TFL.BrandGroup
      ORDER BY TFL.BrandGroup

      OPEN CUR_GROUP

      FETCH NEXT FROM CUR_GROUP INTO @c_BrandGroup, @c_LoadCount

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @n_CountTempRow = COUNT(DISTINCT TPT.RowID)
         FROM #TMP_PTL_TEMP TPT
         WHERE TPT.BrandGroup = @c_BrandGroup

         SET @c_QuitLoop = 'N'
         
         WHILE @c_QuitLoop = 'N'
         BEGIN
            DECLARE CUR_BRAND CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TFL.IntermodalVehicle
            FROM #TMP_FinalLoc TFL
            WHERE TFL.BrandGroup = @c_BrandGroup
            GROUP BY TFL.IntermodalVehicle, TFL.BrandGroup, TFL.GroupSeq
            ORDER BY TFL.BrandGroup, TFL.GroupSeq
         
            OPEN CUR_BRAND
         
            FETCH NEXT FROM CUR_BRAND INTO @c_Brand
         
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF CURSOR_STATUS('LOCAL', 'CUR_ROW') IN (0 , 1)
               BEGIN
                  CLOSE CUR_ROW
                  DEALLOCATE CUR_ROW   
               END
               
               SET @n_Interval = CASE WHEN ISNUMERIC(@c_LoadCount) = 1 THEN CAST(@c_LoadCount AS INT) ELSE 0 END

               DECLARE CUR_ROW CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT TOP (@n_Interval) TPT.LoadKey
               FROM #TMP_PTL_TEMP TPT
               WHERE TPT.IntermodalVehicle = @c_Brand
               AND TPT.Inserted = 'N'
               GROUP BY TPT.LoadKey
               ORDER BY MIN(TPT.RowID)
               
               OPEN CUR_ROW
               
               FETCH NEXT FROM CUR_ROW INTO @c_Loadkey
               
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF @n_debug = 1
                  BEGIN
                     PRINT @c_BrandGroup + ' ' + @c_Brand + ' ' + @c_Loadkey
                  END

                  INSERT INTO #TMP_PTL(Storerkey, Sku, Lot, Loc, ID, Qty, UOM, UOMQty, LocationType
                                     , LoadKey, IntermodalVehicle, Userdefine05, BrandGroup, TaskType)
                  SELECT Storerkey, Sku, Lot, Loc, ID, Qty, UOM, UOMQty, LocationType
                       , LoadKey, IntermodalVehicle, Userdefine05, @c_BrandGroup, TaskType
                  FROM #TMP_PTL_TEMP TPT
                  WHERE TPT.LoadKey = @c_Loadkey
                  ORDER BY TPT.RowID
         
                  UPDATE #TMP_PTL_TEMP
                  SET Inserted = 'Y'
                  WHERE LoadKey = @c_Loadkey
         
                  FETCH NEXT FROM CUR_ROW INTO @c_Loadkey
               END
               CLOSE CUR_ROW
               DEALLOCATE CUR_ROW
         
               FETCH NEXT FROM CUR_BRAND INTO @c_Brand
            END
            CLOSE CUR_BRAND
            DEALLOCATE CUR_BRAND
         
            SELECT @n_CountActualRow = COUNT(DISTINCT TP.RowID)
            FROM #TMP_PTL TP 
            WHERE TP.BrandGroup = @c_BrandGroup
            
            IF @n_CountActualRow >= @n_CountTempRow
               SET @c_QuitLoop = 'Y'
         END

         FETCH NEXT FROM CUR_GROUP INTO @c_BrandGroup, @c_LoadCount
      END
      CLOSE CUR_GROUP
      DEALLOCATE CUR_GROUP

      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Storerkey, Sku, Lot, Loc, ID, Qty, UOM, UOMQty, LocationType
              , LoadKey, IntermodalVehicle, Userdefine05, TaskType
         FROM #TMP_PTL TP
         ORDER BY TP.RowID
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty
                                  , @c_UOM, @n_UOMQty, @c_LocationType
                                  , @c_Loadkey, @c_IntermodalVehicle, @c_Userdefine05   
                                  , @c_TaskType
      
      SET @c_PrevLoadkey = ''
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN                     
         SET @c_LinkTaskToPick_SQL = '' 
         SET @c_UOM = ''
         SET @n_UOMQty = 0
         SET @c_OrderLineNumber = ''
         SET @c_PackStation = ''

         --IF @c_WaveType = 'PTL-Light' SET @c_TaskType = 'CPK'
         --IF @c_WaveType = 'PTL-Cart'  SET @c_TaskType = 'CPK2'

         IF @c_PrevLoadkey <> @c_Loadkey
         BEGIN
            SET @c_Groupkey = ''
            SET @n_Shipday = 0
            SET @n_Holiday = 0
            SET @c_Susr3 = ''
            SET @dt_DeliveryDate = NULL
            SET @c_Code = ''
            SET @c_Priority = ''

            IF ISNULL(@c_Groupkey,'') = ''
            BEGIN
               SET @c_Groupkey = @c_Loadkey
            END 
         
            SELECT @n_Shipday = DATEDIFF (DAY, GETDATE(), ORDERS.DeliveryDate),
                   @c_Susr3 = STORER.Susr3,
                   @dt_DeliveryDate = ORDERS.DeliveryDate,
                   @c_Consigneekey = ORDERS.Consigneekey
            FROM ORDERS (NOLOCK)
            JOIN STORER (NOLOCK) ON ORDERS.Consigneekey = STORER.Storerkey
            JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.OrderKey = ORDERS.OrderKey
            WHERE LOADPLANDETAIL.LoadKey = @c_Loadkey                                                                      
            
            SELECT @n_Holiday = COUNT(1) 
            FROM HOLIDAYDETAIL H (NOLOCK) 
            JOIN STORERSODEFAULT S (NOLOCK) ON H.Holidaykey = S.Holidaykey
            WHERE S.Storerkey = @c_Consigneekey
            AND CONVERT(NVARCHAR, H.HolidayDate, 111) BETWEEN  
                CONVERT(NVARCHAR, GETDATE(),111) AND 
                CONVERT(NVARCHAR, @dt_DeliveryDate, 111)

            IF ISNULL(@n_Shipday,0) - ISNULL(@n_Holiday,0) = 1    
               SET @c_Code = 'D1' + RTRIM(LTRIM(ISNULL(@c_Susr3,'')))
            ELSE   
               SET @c_Code = 'D2' + RTRIM(LTRIM(ISNULL(@c_Susr3,'')))
                
            SELECT @c_Priority = Short
            FROM CODELKUP (NOLOCK)
            WHERE Listname = 'TMPRIORITY' 
            AND Storerkey = @c_Storerkey
            AND Code = @c_Code    
            
            IF ISNULL(@c_Priority,'') = ''
               SET @c_Priority = '9'

            SELECT @n_CurrFinalLocIndex = TFL.CurrFinalLocIndex
                 , @c_AllFinalLoc       = TFL.AllFinalLoc
            FROM #TMP_FinalLoc TFL
            WHERE TFL.IntermodalVehicle = @c_IntermodalVehicle
            
            SELECT @n_MaxIndex = MAX(FDS.SeqNo)
            FROM dbo.fnc_DelimSplit(',', @c_AllFinalLoc) FDS
            
            IF @n_CurrFinalLocIndex >= @n_MaxIndex
            BEGIN
               SET @n_CurrFinalLocIndex = 1
            END
            ELSE
            BEGIN
               SET @n_CurrFinalLocIndex = @n_CurrFinalLocIndex + 1
            END
            
            SELECT @c_Packstation = FDS.ColValue
            FROM dbo.fnc_DelimSplit(',', @c_AllFinalLoc) FDS
            WHERE FDS.SeqNo = @n_CurrFinalLocIndex
            
            IF ISNULL(@c_PackStation,'') = ''
            BEGIN         
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Pack Station setup. (ispRLWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO NEXT_LOOP_CONSO
            END               
            
            SET @c_ToLoc = @c_PackStation
         END

         EXEC isp_InsertTaskDetail   
            @c_TaskType              = @c_TaskType             
           ,@c_Storerkey             = @c_Storerkey
           ,@c_Sku                   = @c_Sku
           ,@c_Lot                   = @c_Lot 
           ,@c_UOM                   = @c_UOM      
           ,@n_UOMQty                = @n_UOMQty     
           ,@n_Qty                   = @n_Qty      
           ,@c_FromLoc               = @c_Fromloc      
           ,@c_LogicalFromLoc        = @c_FromLoc 
           ,@c_FromID                = @c_ID     
           ,@c_ToLoc                 = @c_ToLoc 
           ,@c_LogicalToLoc          = @c_ToLoc 
           ,@c_FinalLOC              = @c_ToLoc
           ,@c_ToID                  = @c_ID       
           ,@c_PickMethod            = @c_PickMethod
           ,@c_Priority              = @c_Priority     
           ,@c_SourcePriority        = '9'      
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey      
           ,@c_LoadKey               = @c_LoadKey      
           ,@c_Groupkey              = @c_Groupkey
           ,@c_WaveKey               = @c_Wavekey      
           ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
           ,@c_Message03             = @c_Userdefine05
           ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
           ,@c_WIP_RefNo             = @c_SourceType
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_err OUTPUT 
           ,@c_ErrMsg                = @c_errmsg OUTPUT        
         
         IF @b_Success <> 1 
         BEGIN
            SELECT @n_continue = 3  
         END
         
         SET @c_PrevLoadkey = @c_Loadkey

         UPDATE #TMP_FinalLoc
         SET CurrFinalLocIndex = @n_CurrFinalLocIndex
         WHERE IntermodalVehicle = @c_IntermodalVehicle
         AND AllFinalLoc = @c_AllFinalLoc

         NEXT_LOOP_CONSO:
         FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty
                                     , @c_UOM, @n_UOMQty, @c_LocationType
                                     , @c_Loadkey, @c_IntermodalVehicle, @c_Userdefine05  
                                     , @c_TaskType
      END                              
      CLOSE cur_pick
      DEALLOCATE cur_pick
   END
   ELSE IF (@n_continue = 1 OR @n_continue = 2)   --@c_Wavetype <> PTL
   BEGIN             
      DECLARE cur_pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty,  
                MAX(PD.UOM), SUM(PD.UOMQty) AS UOMQty,
                O.Orderkey, ISNULL(OD.Userdefine05,''), LOC.LocationType
         FROM WAVEDETAIL WD (NOLOCK)
         JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey              
         JOIN #PickDetail_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber 
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
         JOIN SKUXLOC SL (NOLOCK) ON PD.Storerkey = SL.Storerkey AND PD.Sku = SL.Sku AND PD.Loc = SL.Loc
         JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         LEFT JOIN TASKDETAIL TD (NOLOCK) ON TD.SourceType = @c_SourceType AND TD.WaveKey = WD.Wavekey         --WL01
                                         AND TD.OrderKey = PD.OrderKey                                         --WL01
                                         AND TD.Storerkey = PD.Storerkey AND TD.SKU = PD.SKU                   --WL01
                                         AND TD.LOT = PD.Lot AND TD.FromLoc = PD.Loc                           --WL01
                                         AND TD.FROMID = PD.ID AND TD.Message03 = ISNULL(OD.Userdefine05,'')   --WL01 
         WHERE WD.Wavekey = @c_Wavekey
         AND TD.TaskDetailKey IS NULL   --WL01
         AND PD.Status = '0'
         AND PD.WIP_RefNo = @c_SourceType
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID,  
                  O.Orderkey, ISNULL(OD.Userdefine05,''), LOC.LocationType, LOC.LogicalLocation, W.WaveType 
         ORDER BY PD.Storerkey, O.Orderkey, 
                  CASE WHEN W.WaveType <> 'WTSONS' THEN LOC.LogicalLocation ELSE '' END, 
                  CASE WHEN W.WaveType <> 'WTSONS' THEN PD.LOC ELSE '' END, 
                  CASE WHEN W.WaveType <> 'WTSONS' THEN PD.Sku ELSE '' END, 
                  CASE WHEN ISNULL(OD.Userdefine05,'') <> '' THEN 1 ELSE 2 END,
                  CASE WHEN LOC.LocationType = 'PICK' THEN 1 ELSE 2 END,
                  CASE WHEN LOC.LocationType = 'PICK' THEN LOC.LogicalLocation ELSE PD.Sku END,
                  LOC.LogicalLocation, PD.Loc, PD.Sku, PD.Lot       
      
      OPEN cur_pick  
      
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey, @c_Userdefine05, @c_LocationType
      
      SET @c_PrevOrderkey = ''
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN                     
         SET @c_LinkTaskToPick_SQL = '' 
         SET @c_UOM = ''
         SET @n_UOMQty = 0
         SET @c_OrderLineNumber = ''
         SET @c_PackStation = ''
         SET @c_TaskType = 'FCP'   --WL01
           
         IF @c_PrevOrderkey <> @c_Orderkey
         BEGIN
            SET @c_Groupkey = ''
            SET @n_Shipday = 0
            SET @n_Holiday = 0
            SET @c_Susr3 = ''
            SET @dt_DeliveryDate = NULL
            SET @c_Code = ''
            SET @c_Priority = ''
            
            SELECT TOP 1 @c_Groupkey = TD.Groupkey 
            FROM TASKDETAIL TD (NOLOCK) 
            WHERE TD.Orderkey = @c_Orderkey 
            AND TD.Sourcetype = @c_SourceType 
            AND TD.Tasktype IN('FCP')
            ORDER BY TD.Groupkey   
            
            IF ISNULL(@c_Groupkey,'') = ''
            BEGIN
               EXEC dbo.nspg_GetKey               
                    'RLWAV49GRPKEY'    
                  ,10    
                  ,@c_Groupkey OUTPUT    
                  ,@b_Success OUTPUT    
                  ,@n_err     OUTPUT    
                  ,@c_errmsg  OUTPUT
            END 
         
            SELECT @n_Shipday = DATEDIFF (DAY, GETDATE(), ORDERS.DeliveryDate),
                   @c_Susr3 = STORER.Susr3,
                   @dt_DeliveryDate = ORDERS.DeliveryDate,
                   @c_Consigneekey = ORDERS.Consigneekey
            FROM ORDERS (NOLOCK)
            JOIN STORER (NOLOCK) ON ORDERS.Consigneekey = STORER.Storerkey
            WHERE ORDERS.Orderkey = @c_Orderkey                                                                      
            
            SELECT @n_Holiday = COUNT(1) 
            FROM HOLIDAYDETAIL H (NOLOCK) 
            JOIN STORERSODEFAULT S (NOLOCK) ON H.Holidaykey = S.Holidaykey
            WHERE S.Storerkey = @c_Consigneekey
            AND CONVERT(NVARCHAR, H.HolidayDate, 111) BETWEEN  
                CONVERT(NVARCHAR, GETDATE(),111) AND 
                CONVERT(NVARCHAR, @dt_DeliveryDate, 111)
            
            /*
            SELECT @n_Holiday = COUNT(*) 
            FROM HOLIDAYDETAIL (NOLOCK) 
            WHERE Holidaykey IN (SELECT UDF01 
                                 FROM CODELKUP (NOLOCK) 
                                 WHERE ListName = 'HOLIDAY' 
                                 AND Code = @c_Susr3) 
            AND CONVERT(NVARCHAR, HolidayDate, 111) BETWEEN  
                CONVERT(NVARCHAR, GETDATE(),111) AND 
                CONVERT(NVARCHAR, @dt_DeliveryDate, 111)
            */
                
            IF ISNULL(@n_Shipday,0) - ISNULL(@n_Holiday,0) = 1    
               SET @c_Code = 'D1' + RTRIM(LTRIM(ISNULL(@c_Susr3,'')))
            ELSE   
               SET @c_Code = 'D2' + RTRIM(LTRIM(ISNULL(@c_Susr3,'')))
                
            SELECT @c_Priority = Short
            FROM CODELKUP (NOLOCK)
            WHERE Listname = 'TMPRIORITY' 
            AND Storerkey = @c_Storerkey
            AND Code = @c_Code    
            
            IF ISNULL(@c_Priority,'') = ''
               SET @c_Priority = '9'
         END
           
         /* 
         SELECT TOP 1 @c_Packstation = Long
         FROM CODELKUP(NOLOCK)
         WHERE Listname = 'TM_TOLOC'
         AND Storerkey = @c_Storerkey
         AND (ISNULL(UDF01,'') = '' OR UDF01 = 'FCP')
         AND (ISNULL(UDF02,'') = '' OR UDF02 = @c_UOM)
         AND (ISNULL(UDF03,'') = '' OR UDF03 = @c_LocationType)
         ORDER BY CASE WHEN UDF01 = 'FCP' THEN 1 ELSE 2 END,
                  CASE WHEN UDF02 = @c_UOM THEN 1 ELSE 2 END, 
                  CASE WHEN UDF03 = @c_LocationType THEN 1 ELSE 2 END
         */
         
         IF ISNULL(@c_Susr3,'') = ''
            SET @c_Susr3 = 'OTHER'
          
         SELECT TOP 1 @c_Packstation = Long
         FROM CODELKUP(NOLOCK)
         WHERE Listname = 'TM_TOLOC'
         AND Storerkey = @c_Storerkey
         AND Code = @c_Susr3
                     
         IF ISNULL(@c_PackStation,'') = ''
         BEGIN         
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83060  -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Pack Station setup. (ispRLWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END               
   
         SET @c_ToLoc = @c_PackStation             
   
         EXEC isp_InsertTaskDetail   
            @c_TaskType              = @c_TaskType             
           ,@c_Storerkey             = @c_Storerkey
           ,@c_Sku                   = @c_Sku
           ,@c_Lot                   = @c_Lot 
           ,@c_UOM                   = @c_UOM      
           ,@n_UOMQty                = @n_UOMQty     
           ,@n_Qty                   = @n_Qty      
           ,@c_FromLoc               = @c_Fromloc      
           ,@c_LogicalFromLoc        = @c_FromLoc 
           ,@c_FromID                = @c_ID     
           ,@c_ToLoc                 = @c_ToLoc       
           ,@c_LogicalToLoc          = @c_ToLoc 
           ,@c_ToID                  = @c_ID       
           ,@c_PickMethod            = @c_PickMethod
           ,@c_Priority              = @c_Priority     
           ,@c_SourcePriority        = '9'      
           ,@c_SourceType            = @c_SourceType      
           ,@c_SourceKey             = @c_Wavekey      
           ,@c_OrderKey              = @c_Orderkey      
           ,@c_OrderLineNumber       = @c_OrderLineNumber
           ,@c_Groupkey              = @c_Groupkey
           ,@c_WaveKey               = @c_Wavekey      
           ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey 
           ,@c_Message03             = @c_Userdefine05
           ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip
           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL  
           ,@c_WIP_RefNo             = @c_SourceType
           ,@b_Success               = @b_Success OUTPUT
           ,@n_Err                   = @n_err OUTPUT 
           ,@c_ErrMsg                = @c_errmsg OUTPUT        
         
         IF @b_Success <> 1 
         BEGIN
            SELECT @n_continue = 3  
         END
         
         SET @c_PrevOrderkey = @c_Orderkey
   
         FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @n_UOMQty, @c_Orderkey, @c_Userdefine05, @c_LocationType           
      END
      CLOSE cur_pick
      DEALLOCATE cur_pick
   END

   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
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

    -----Update Wave Status-----
    IF @n_continue = 1 or @n_continue = 2  
    BEGIN  
      UPDATE WAVE 
      SET TMReleaseFlag = 'Y'     
       ,  TrafficCop = NULL       
       ,  EditWho = SUSER_SNAME() 
       ,  EditDate= GETDATE()     
      WHERE WAVEKEY = @c_wavekey  

      SELECT @n_err = @@ERROR  

      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  
   
RETURN_SP:
   IF @n_continue IN (1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
             @c_Loadkey               = ''
            ,@c_Wavekey               = @c_wavekey  
            ,@c_WIP_RefNo             = @c_SourceType 
            ,@c_PickCondition_SQL     = ''
            ,@c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
            ,@c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
            ,@b_Success               = @b_Success OUTPUT
            ,@n_Err                   = @n_Err     OUTPUT 
            ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END             
   END 
   
   --Update last used Final Loc back to Codelkup
   IF @n_continue IN (1,2)
   BEGIN 
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TFL.IntermodalVehicle, TFL.AllFinalLoc, TFL.CurrFinalLocIndex
      FROM #TMP_FinalLoc TFL
      WHERE TFL.CurrFinalLocIndex > 0
      
      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_IntermodalVehicle, @c_AllFinalLoc, @n_CurrFinalLocIndex

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE dbo.CODELKUP
         SET Notes = @n_CurrFinalLocIndex
         WHERE LISTNAME = 'LORBRAND'
         AND Code = @c_IntermodalVehicle
         AND Storerkey = @c_Storerkey
         --AND Code2 IN ('PTL')
         AND Long = @c_AllFinalLoc

         SELECT @n_err = @@ERROR  

         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83125   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on CODELKUP Failed (ispRLWAV49)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 

         FETCH NEXT FROM CUR_LOOP INTO @c_IntermodalVehicle, @c_AllFinalLoc, @n_CurrFinalLocIndex
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END   

   IF OBJECT_ID('tempdb..#PickDetail_WIP') IS NOT NULL
      DROP TABLE #PickDetail_WIP

   IF OBJECT_ID('tempdb..#TMP_FinalLoc') IS NOT NULL
      DROP TABLE #TMP_FinalLoc

   IF OBJECT_ID('tempdb..#TMP_PTL') IS NOT NULL
      DROP TABLE #TMP_PTL

   IF OBJECT_ID('tempdb..#TMP_PTL_TEMP') IS NOT NULL
      DROP TABLE #TMP_PTL_TEMP
      
   IF CURSOR_STATUS('LOCAL', 'cur_pick') IN (0 , 1)
   BEGIN
      CLOSE cur_pick
      DEALLOCATE cur_pick   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_ROW') IN (0 , 1)
   BEGIN
      CLOSE CUR_ROW
      DEALLOCATE CUR_ROW   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_BRAND') IN (0 , 1)
   BEGIN
      CLOSE CUR_BRAND
      DEALLOCATE CUR_BRAND   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_GROUP') IN (0 , 1)
   BEGIN
      CLOSE CUR_GROUP
      DEALLOCATE CUR_GROUP   
   END
   
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV49'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END --sp end

GO