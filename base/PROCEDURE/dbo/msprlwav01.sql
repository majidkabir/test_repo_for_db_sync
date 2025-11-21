SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/**************************************************************************/    
/* Stored Procedure: mspRLWAV01                                           */    
/* Creation Date: 2024-04-17                                              */    
/* Copyright: Maersk                                                      */    
/* Written by:                                                            */    
/*                                                                        */    
/* Purpose: WMS-7994 - Adjusted for Mattel                                */  
/*                                                                        */  
/*                                                                        */    
/* Called By: Wave Release                                                */    
/*                                                                        */    
/* PVCS Version: 1.9                                                      */    
/*                                                                        */    
/* Version: 7.0                                                           */    
/*                                                                        */    
/* Data Modifications:                                                    */    
/*                                                                        */    
/* Updates:                                                               */    
/* Date        Author   Ver   Purposes                                    */    
/* 2024-04-17  Wan      1.0   UWP-18534-Mettel-Add consolidated picking   */  
/* 2024-04-26  Wan01    1.1   UWP-18534-conso picking by wave & for uom1  */ 
/* 2024-05-02  Wan02    1.1   UWP-18535-Mattel-Add OverAlloc Replenishment*/ 
/* 2024-05-22  Wan03    1.2   UWP-18535-Fix Change logic overalloated loc */ 
/*                            & Lot to replen as overallocate program has */ 
/*                            strategy to find DPP & Pick face Location   */
/*                            UWP-18535-Fix FCP not hold                  */ 
/* 2024-05-28  Wan04    1.3   UWP-18535-Hold FCP when FromLoc has RPF task*/ 
/* 2024-07-09  Wan05    1.4   UWP-19537-Mattel Overallocation             */
/*                            -EmptyLoc= Qty-QtyPicked. New Formula for   */
/*                            qtyexpected                                 */
/* 2024-07-18  Wan06    1.5   UWP-22202-Mattel DPP with commingleSku      */
/*                            Prompt Error if DPP different Sku           */
/* 2024-09-02  WLChooi  1.6   UWP-23643-Get ToLoc from LoadplanLanedetail */
/*                            (WL01)                                      */
/* 2024-09-02  SSA01    1.7   UWP-23370 & 23372-query for priority value  */
/*                            from codelkup and takeout deliverydate for  */
/*                            consolidated pick                           */
/* 2024-09-18  WLChooi  1.8   UWP-23368-Dispatch TM task with cube data   */
/*                            (WL02)                                      */
/* 2025-01-23  WLChooi  1.9   INC7625461-Review groupkey logic for UOM2   */
/*                            (WL03)                                      */
/* 2025-02-19  Calvin   2.0   FCR-3026 Mattel Allow Multiple Replen Tasks */
/*                            per SKU (CLVN01)                            */
/**************************************************************************/     
CREATE   PROCEDURE [dbo].[mspRLWAV01]        
  @c_wavekey      NVARCHAR(10)    
 ,@b_Success      int            = 1   OUTPUT    
 ,@n_err          int            = 0   OUTPUT    
 ,@c_errmsg       NVARCHAR(250)  = ''  OUTPUT    
 AS    
 BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
      
   DECLARE @n_continue    int = 1     
         , @n_starttcnt   int = @@TRANCOUNT         -- Holds the current transaction count    
         , @n_debug       int = 0 
         , @n_cnt         int = 0
              
   SET @b_success = 0
   SET @n_err = 0
   SET @c_errmsg = ''

   DECLARE @c_Storerkey                NVARCHAR(15)   = ''  
         , @c_Facility                 NVARCHAR(5)    = ''
         , @c_TaskType                 NVARCHAR(10)   = ''           
         , @c_SourceType               NVARCHAR(30)   = ''
         , @c_WaveType                 NVARCHAR(10)   = ''
         , @c_Sku                      NVARCHAR(20)   = ''
         , @c_Lot                      NVARCHAR(10)   = ''
         , @c_FromLoc                  NVARCHAR(10)   = ''
         , @c_ID                       NVARCHAR(18)   = ''
         , @n_Qty                      INT            = 0
         , @n_UOMQty                   INT            = 0
         , @c_UOM                      NVARCHAR(10)   = ''
         , @c_Orderkey                 NVARCHAR(10)   = ''
         , @c_LoadKey                  NVARCHAR(10)   = ''
         , @c_Groupkey                 NVARCHAR(10)   = ''
         , @c_Toloc                    NVARCHAR(10)   = ''                                   
         , @c_Priority                 NVARCHAR(10)   = ''           
         , @c_PickMethod               NVARCHAR(10)   = ''           
         , @c_Message03                NVARCHAR(20)   = ''
         , @C_Zip                      NVARCHAR(18)   = ''           
         , @c_LinkTaskToPick_SQL       NVARCHAR(4000) = '' 
         , @c_SQL                      NVARCHAR(MAX)  = ''
         , @c_Route                    NVARCHAR(10)   = ''
         , @c_Taskdetailkey            NVARCHAR(10)   = ''
         , @c_DefaultLoc               NVARCHAR(10)   = ''
         , @dt_deliveryDate            DATETIME        
         , @c_DispatchCasePickMethod   NVARCHAR(10)   = ''
         , @c_TaskStatus               NVARCHAR(10)   = '0'                         --(Wan02) 
         , @c_FromID                   NVARCHAR(18)   = ''                          --(Wan02)
         , @c_DynPickFace              NVARCHAR(10)   = ''                          --(Wan02)
         , @n_QtyNeed                  INT            = 0                           --(Wan02)
         , @n_QtyToReplen              INT            = 0                           --(Wan02)
         , @n_QtyRelease2Pick          INT            = 0                           --(Wan02)
         , @c_LPLDLoc                  NVARCHAR(10)   = ''                          --WL01
         --WL02 S
         , @c_Areakey                  NVARCHAR(10)   = '' 
         , @n_Volume                   FLOAT = 0.00        
         , @n_CubeUOM1                 FLOAT = 0.00        
         , @n_CubeUOM3                 FLOAT = 0.00        
         , @n_TTLVolume                FLOAT = 0.00        
         , @c_MaxSkuVol                NVARCHAR(10)   = '' 
         , @n_MaxSkuVol                FLOAT = 0.00        
         , @c_PrevOrderkey             NVARCHAR(10)   = '' 
         , @c_PrevAreakey              NVARCHAR(10)   = '' 
         , @c_KeyName                  NVARCHAR(18)   = '' 
         , @c_Option5                  NVARCHAR(MAX)  = '' 
         , @n_LocLevel                 INT                 
         , @c_StampGrpKey              NVARCHAR(1)    = 'N'
         , @c_InsGrpKey                NVARCHAR(10)   = '' 
         , @n_QtyToRelease             INT = 0
         , @n_UOMQtyToRelease          INT = 0
         , @n_NoOfGroup                INT = 0
         , @n_MaxQtyPerGroup           INT = 0
         , @n_Casecnt                  INT = 0
         --WL02 E

         ,@cur_waveord                 CURSOR
         ,@cur_WaveReplfr              CURSOR                                       --(Wan02)
         ,@cur_WaveReplto              CURSOR                                       --(Wan02)
         ,@cur_WaveReplLot             CURSOR                                       --(Wan02)
                              
   SET @c_SourceType = 'mspRLWAV01'      
   SET @c_Priority   = '9'  
   SET @c_TaskType   = 'FCP'  
   SET @c_PickMethod = 'PP'  
  
   -----Get Storerkey and facility  
   IF  (@n_continue = 1 OR @n_continue = 2)  
   BEGIN  
      SELECT TOP 1 @c_Storerkey = O.Storerkey  
                  ,@c_Facility = O.Facility 
                  ,@c_Loadkey  = O.Loadkey
                  ,@c_WaveType = W.WaveType 
                  ,@c_DispatchCasePickMethod = w.DispatchCasePickMethod
      FROM WAVE W (NOLOCK)  
      JOIN WAVEDETAIL WD(NOLOCK) ON W.Wavekey = WD.Wavekey  
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
      AND  W.Wavekey = @c_Wavekey 
      ORDER BY o.Loadkey
        
      IF @c_Loadkey = ''
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 83010    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loadplan has not generated yet. (mspRLWAV01)'         
      END 
   END

   -----Wave Validation-----              
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN   
      IF NOT EXISTS (SELECT 1   
                     FROM WAVEDETAIL WD (NOLOCK)  
                     JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
                     LEFT JOIN TASKDETAIL TD (NOLOCK) ON  PD.Taskdetailkey = TD.Taskdetailkey 
                                                      AND TD.Sourcetype = @c_SourceType 
                                                      AND TD.Tasktype IN ('FPK','FCP','FPP')  
                     WHERE WD.Wavekey = @c_Wavekey                     
                     AND PD.Status = '0'  
                     AND TD.Taskdetailkey IS NULL  
                  )  
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 83020    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Nothing to release. (mspRLWAV01)'         
      END        
   END  
   
   --WL02 S
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_Option5 = fgr.Option5 
      FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'ReleaseWave_SP') AS fgr
   
      SELECT @c_MaxSkuVol = dbo.fnc_GetParamValueFromString('@n_MaxSkuVol', @c_Option5, @c_MaxSkuVol)

      IF ISNUMERIC(@c_MaxSkuVol) = 1
         SET @n_MaxSkuVol = CAST(@c_MaxSkuVol AS FLOAT)
      ELSE
         SET @n_MaxSkuVol = 0.00
   END
   --WL02 E
         
   --Create pickdetail Work in progress temporary table  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN 
      IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL  
         DROP TABLE #PICKDETAIL_WIP   

      CREATE TABLE #PickDetail_WIP(  
         [PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,  
         [CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),  
         [PickHeaderKey] [nvarchar](18) NOT NULL,  
         [OrderKey] [nvarchar](10) NOT NULL,  
         [OrderLineNumber] [nvarchar](5) NOT NULL,  
         [Lot] [nvarchar](10) NOT NULL,  
         [Storerkey] [nvarchar](15) NOT NULL,  
         [Sku] [nvarchar](20) NOT NULL,  
         [AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),  
         [UOM] [nvarchar](10) NOT NULL DEFAULT (' '),  
         [UOMQty] [int] NOT NULL DEFAULT ((0)),  
         [Qty] [int] NOT NULL DEFAULT ((0)),  
         [QtyMoved] [int] NOT NULL DEFAULT ((0)),  
         [Status] [nvarchar](10) NOT NULL DEFAULT ('0'),  
         [DropID] [nvarchar](20) NOT NULL DEFAULT (''),  
         [Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),  
         [ID] [nvarchar](18) NOT NULL DEFAULT (' '),  
         [PackKey] [nvarchar](10) NULL DEFAULT (' '),  
         [UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),  
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
            
   IF @@TRANCOUNT = 0  
      BEGIN TRAN  
          
   --Initialize Pickdetail work in progress staging table  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      EXEC isp_CreatePickdetail_WIP  
          @c_Loadkey               = '' --@c_Loadkey                                --(Wan01)    
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
      ELSE
      BEGIN
         UPDATE #PICKDETAIL_WIP  
         SET #PICKDETAIL_WIP.Taskdetailkey = ''  
         FROM #PICKDETAIL_WIP  
         LEFT JOIN TASKDETAIL TD (NOLOCK) ON  TD.Taskdetailkey = #PICKDETAIL_WIP.Taskdetailkey 
                                          AND TD.Sourcetype = @c_SourceType 
                                          AND TD.Tasktype IN ('FPK','FCP','FPP')    --(wan02) Fixed             
                                          AND TD.Status <> 'X'   
         WHERE TD.Taskdetailkey IS NULL 
      END   
   END  

   --(Wan02) Over Allocation Replenishment - START
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SET @cur_WaveReplto = CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT PD.Storerkey, PD.Sku, PD.Loc, PD.Lot                                   --(Wan03)
         , QtyNeed = lli.QtyAllocated+(lli.QtyPicked-lli.Qty)-lli.PendingMoveIn     --(Wan05)                  
      FROM #PICKDETAIL_WIP PD (NOLOCK)
      JOIN LOTATTRIBUTE la  (NOLOCK) ON pd.Lot = la.Lot
      JOIN LOTxLOCxID   lli (NOLOCK) ON pd.Lot = lli.Lot 
                                    AND pd.Loc = lli.loc
                                    AND pd.ID  = lli.ID
      JOIN LOC l (NOLOCK) ON pd.loc = l.loc
      LEFT OUTER JOIN TASKDETAIL td (NOLOCK) ON  td.TaskType = 'RPF'
                                             AND td.Storerkey = pd.Storerkey
                                             AND td.Sku   = pd.Sku
                                             AND td.ToLoc = pd.Loc
                                             AND td.[Status] NOT IN ('9','X')
                                             --AND td.Wavekey = @c_Wavekey
      WHERE PD.UOM IN ('2','6')
      AND PD.[Status] = '0'
      AND td.Taskdetailkey IS NULL
      AND (lli.Qty-lli.QtyAllocated-lli.QtyPicked)+lli.PendingMoveIn < 0            --(Wan05)
      GROUP BY PD.Storerkey, PD.Sku, PD.Loc, PD.Lot                                 --(Wan03) 
            ,  lli.Qty,lli.QtyAllocated,lli.QtyPicked,lli.PendingMoveIn             --(Wan05)
      ORDER BY PD.Loc, PD.Lot                                                       --(Wan03) 
 
      OPEN @cur_WaveReplto    
         
      FETCH NEXT FROM @cur_WaveReplto INTO @c_Storerkey, @c_Sku, @c_ToLoc, @c_Lot   --(Wan03) 
                                        ,  @n_QtyNeed                            
         
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)  
      BEGIN
         IF EXISTS (SELECT 1                                                        --(Wan06)-START
                    FROM dbo.LOTxLOCxID l1 (NOLOCK) 
                    WHERE l1.Storerkey = @c_Storerkey
                    AND   l1.loc = @c_ToLoc
                    AND   l1.Sku <> @c_Sku
                    AND   (l1.QtyAllocated + (l1.QtyPicked-l1.Qty) > 0 
                    OR     l1.PendingMoveIn > 0
                          )
                    )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 83040
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)
                         +': Different Sku found in DPP location: ' + @c_ToLoc
                         +'. (mspRLWAV01)' 
            GOTO RETURN_SP
         END                                                                        --(Wan06)-END
         --SET @cur_WaveReplLot = CURSOR FAST_FORWARD READ_ONLY FOR                 --(Wan03) - START
         --SELECT PD.Lot
         --      ,QtyNeed = SUM(lli.QtyExpected - lli.PendingMoveIn)                  
         --      ,DynPickFace = ISNULL(sl.loc, 'DPP')
         --FROM #PICKDETAIL_WIP PD (NOLOCK)
         --LEFT OUTER JOIN SKUxLOC sl (NOLOCK) ON  sl.Storerkey = pd.Storerkey
         --                                    AND sl.Sku = pd.Sku
         --                                    AND sl.Loc = pd.loc
         --                                    AND sl.LocationType IN ('PICK', 'CASE') 
         --WHERE PD.Storerkey = @c_Storerkey
         --AND   PD.Sku = @c_Sku
         --AND   PD.Loc = @c_ToLoc
         --AND   PD.UOM IN ('2','6')
         --GROUP BY PD.Lot, PD.Loc, ISNULL(sl.loc, 'DPP')
         --ORDER BY PD.Loc                                                                                                 

         --OPEN @cur_WaveReplLot    
         
         --FETCH NEXT FROM @cur_WaveReplLot INTO @c_Lot, @c_DynPickFace
         
         --WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2) AND @n_QtyNeed > 0
         --BEGIN                                                                    
         SET @cur_WaveReplfr = CURSOR FAST_FORWARD READ_ONLY FOR 
         --SELECT TOP 1	  --(CLVN01)
         SELECT           --(CLVN01)
                 FromLoc = lli.Loc
               , FromID  = lli.ID
               , QtyToReplen = lli.qty - lli.QtyPicked - lli.QtyAllocated - lli.QtyReplen
         FROM LOTxLOCxID lli (NOLOCK) 
         JOIN LOT (NOLOCK) ON LOT.Lot = lli.Lot
         JOIN ID  (NOLOCK) ON ID.id = lli.id
         JOIN LOTATTRIBUTE la (NOLOCK) ON la.Lot = lli.Lot
         JOIN LOC (NOLOCK) ON LOC.loc = lli.loc 
         JOIN SKUxLOC sl (NOLOCK) ON  lli.Storerkey = sl.Storerkey 
                                  AND lli.Sku = sl.Sku
                                  AND lli.Loc = sl.Loc
         WHERE lli.Storerkey = @c_Storerkey
         AND   lli.Sku = @c_Sku
         AND   lli.Lot = @c_Lot      
         AND   lli.Loc <> @c_ToLoc
         AND   lli.qty - lli.QtyPicked - lli.QtyAllocated - lli.QtyReplen > 0
         AND   sl.LocationType NOT IN ('PICK','CASE')
         AND   LOT.[Status] = 'OK'
         AND   ID.[Status]  = 'OK'
         AND   LOC.[Status] = 'OK'
         AND   LOC.LocationFlag NOT IN ('DAMAGE','HOLD')
         AND   LOC.Facility = @c_Facility
         AND   LOC.LocLevel > 0
		 ORDER BY lli.qty - lli.QtyPicked - lli.QtyAllocated - lli.QtyReplen DESC --(CLVN01)

         OPEN @cur_WaveReplfr

         FETCH NEXT FROM @cur_WaveReplfr INTO  @c_FromLoc, @c_FromID, @n_QtyToReplen

         WHILE @@FETCH_STATUS = 0 AND @n_Continue IN (1,2) AND @n_QtyNeed > 0
         BEGIN
            SET @c_Taskdetailkey = '' 
            SET @n_Qty     = @n_QtyToReplen
            SET @n_QtyNeed = @n_QtyNeed - @n_Qty

            --IF @c_DynPickFace = 'DPP'                                             --(Wan03)
            --BEGIN                                                                 --(Wan03)
            --   SET @n_QtyNeed = 0                                                 --(Wan03)
            --END                                                                   --(Wan03)
            
            SET @c_ID      = @c_FromID

            EXEC isp_InsertTaskDetail     
                @c_Taskdetailkey         = @c_Taskdetailkey OUTPUT  
               ,@c_TaskType              = 'RPF'               
               ,@c_Storerkey             = @c_Storerkey  
               ,@c_Sku                   = @c_Sku  
               ,@c_Lot                   = @c_Lot   
               ,@c_UOM                   = '1'        
               ,@n_UOMQty                = @n_Qty       
               ,@n_Qty                   = @n_Qty        
               ,@c_FromLoc               = @c_Fromloc        
               ,@c_LogicalFromLoc        = @c_FromLoc   
               ,@c_FromID                = @c_FromID       
               ,@c_ToLoc                 = @c_ToLoc         
               ,@c_LogicalToLoc          = @c_ToLoc   
               ,@c_ToID                  = @c_ID         
               ,@c_PickMethod            = 'FP'  
               ,@c_Priority              = '5'       
               ,@c_SourcePriority        = '5'        
               ,@c_SourceType            = @c_SourceType        
               ,@c_SourceKey             = @c_Wavekey        
               ,@c_OrderKey              = ''        
               ,@c_Groupkey              = ''  
               ,@n_PendingMoveIn         = @n_Qty
               ,@n_QtyReplen             = @n_Qty
               ,@c_WaveKey               = @c_Wavekey        
               ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
               ,@c_Message03             = ''  
               ,@c_LinkTaskToPick        = '' -- WIP=Update taskdetailkey to pickdetail_wip  
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL    
               ,@c_WIP_RefNo             = @c_SourceType  
               ,@b_Success               = @b_Success OUTPUT  
               ,@n_Err                   = @n_err OUTPUT   
               ,@c_ErrMsg                = @c_errmsg OUTPUT  
                
            IF @b_Success <> 1   
            BEGIN  
               SET @n_continue = 3    
            END 

            FETCH NEXT FROM @cur_WaveReplfr INTO  @c_FromLoc, @c_FromID, @n_QtyToReplen
         END
         CLOSE @cur_WaveReplfr
         DEALLOCATE @cur_WaveReplfr

         --   FETCH NEXT FROM @cur_WaveReplLot INTO @c_Lot, @c_DynPickFace         
         --END                                                                     
         --CLOSE @cur_WaveReplLot                                                  
         --DEALLOCATE @cur_WaveReplLot                                              --(wan03) - END

         FETCH NEXT FROM @cur_WaveReplto INTO @c_Storerkey, @c_Sku, @c_ToLoc, @c_Lot--(Wan03) 
                                            , @n_QtyNeed                         
      END
      CLOSE @cur_WaveReplto
      DEALLOCATE @cur_WaveReplto
   END
   --(Wan02) Over Allocation Replenishment - END

   IF @n_continue IN(1,2)   
   BEGIN  
      SELECT @c_DefaultLoc = CL.Long  
      FROM CODELKUP CL (NOLOCK)  
      JOIN LOC (NOLOCK) ON CL.Long = LOC.Loc  
      WHERE CL.Listname = 'TM_TOLOC'  
      AND CL.Storerkey = @c_Storerkey  
      AND CL.Code = 'DEFAULT'

      SELECT @c_Priority = CL.Short                                               --(SSA01)
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Storerkey = @c_Storerkey
      AND CL.LISTNAME = 'TMPKPRIORI'
      AND CL.Code = 'Lowest'

      IF ISNULL(@c_Priority,'') = ''                                              --(SSA01)
           SET @c_Priority = '9'

      SET @c_SQL = N'  
          DECLARE cur_pick CURSOR FAST_FORWARD READ_ONLY FOR    
          SELECT PD.Storerkey, PD.Sku
                ,CASE WHEN @c_DispatchCasePickMethod =''1''                         --(Wan01)
                      THEN PD.Lot ELSE '''' END AS Lot
                ,PD.Loc, PD.ID, SUM(PD.Qty) AS Qty     
                ,PD.UOM, SUM(PD.UOMQty) AS UOMQty                                    
                ,O.Route   
                ,CASE WHEN @c_DispatchCasePickMethod =''1''                         --(Wan01)
                      THEN O.Orderkey ELSE '''' END AS Orderkey    
                ,TOLOC.Loc AS ToLoc   
                ,@c_Priority AS Priority                                            --(SSA01)
                ,CASE WHEN @c_DispatchCasePickMethod =''1''                         --(SSA01)
                      THEN CONVERT(NVARCHAR(8), O.DeliveryDate, 112) ELSE '''' END AS DeliveryDate
                ,'''' AS Loadkey                                                    --(Wan01)   
                ,LPLD.Loc   --WL01
                ,AD.Areakey   --WL02
                ,ISNULL(P.CubeUOM1, 0.00)   --WL02
                ,ISNULL(P.CubeUOM3, 0.00)   --WL02
                ,LOC.LocLevel   --WL02
                ,P.Casecnt   --WL03 
          FROM WAVEDETAIL WD (NOLOCK)  
          JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey                            
          JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
          JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey    
          JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
          LEFT JOIN TASKDETAIL TD (NOLOCK) ON  PD.Taskdetailkey = TD.Taskdetailkey 
                                           AND TD.Sourcetype = @c_SourceType 
                                           AND TD.Tasktype IN (''FPK'',''FCP'',''FPP'') 
                                           AND TD.Status <> ''X''              
          LEFT JOIN STORERSODEFAULT SSO (NOLOCK) ON SSO.Storerkey = O.Consigneekey
          --(SSA01)  -- removing joinng codelkup
          --LEFT JOIN CODELKUP CL (NOLOCK) ON O.Storerkey = CL.Storerkey AND CL.Listname = ''TMPRIORITY''
          --                               AND LEFT(O.Route,1) = CL.Short
          OUTER APPLY (SELECT TOP 1 TL.Loc FROM LOC TL (NOLOCK) WHERE TL.Putawayzone = SSO.Route) AS TOLOC  
          OUTER APPLY (SELECT TOP 1 ISNULL(LPD.Loc, '''') AS Loc   --WL01
                       FROM LoadPlanLaneDetail LPD (NOLOCK)        --WL01
                       WHERE LPD.LoadKey = O.Loadkey) AS LPLD      --WL01
          JOIN AreaDetail AD (NOLOCK) ON LOC.PutawayZone = AD.PutawayZone   --WL02
          JOIN SKU S (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.SKU = PD.Sku   --WL02
          JOIN PACK P (NOLOCK) ON P.PackKey = S.PACKKey   --WL02
          WHERE WD.Wavekey = @c_Wavekey  
          AND PD.Status = ''0''  
          AND PD.WIP_RefNo = @c_SourceType  
          AND TD.Taskdetailkey IS NULL              
          GROUP BY PD.Storerkey, PD.Sku
                  , CASE WHEN @c_DispatchCasePickMethod =''1''                      --(Wan01)  
                         THEN PD.Lot ELSE '''' END
                  , PD.Loc, PD.ID, PD.UOM, O.Route                                  --(Wan01)
              , CASE WHEN @c_DispatchCasePickMethod =''1''                          --(Wan01)
                     THEN O.Consigneekey ELSE '''' END
                  , CASE WHEN @c_DispatchCasePickMethod =''1''                      --(Wan01)
                        THEN O.Orderkey ELSE '''' END
                  --,O.loadkey                                                      --(Wan01)
                  ,CASE WHEN @c_DispatchCasePickMethod =''1''                       --(SSA01)
                      THEN CONVERT(NVARCHAR(8), O.DeliveryDate, 112) ELSE '''' END
                  ,LOC.LogicalLocation
                  ,TOLOC.Loc                                                        --(SSA01)                  
                  ,LPLD.Loc   --WL01
                  ,AD.Areakey   --WL02
                  ,ISNULL(P.CubeUOM1, 0.00)   --WL02
                  ,ISNULL(P.CubeUOM3, 0.00)   --WL02
                  ,LOC.LocLevel   --WL02
                  ,P.Casecnt   --WL03 
          ORDER BY O.Route                                                          --(Wan01)  
              , CASE WHEN @c_DispatchCasePickMethod =''1''                          --(Wan01)
                     THEN O.Consigneekey ELSE '''' END                                       
                  ,CASE WHEN @c_DispatchCasePickMethod =''1''                       --(Wan01)
                        THEN O.Orderkey ELSE '''' END
                  --,O.loadkey                                                      --(Wan01)
                  ,AD.Areakey   --WL02
                  ,Loc.LogicalLocation, PD.Loc '           
  
      EXEC sp_executesql @c_SQL   
         , N'@c_Wavekey    NVARCHAR(10)
            ,@c_SourceType NVARCHAR(30)
            ,@c_DispatchCasePickMethod NVARCHAR(10)
            ,@c_Priority NVARCHAR(10)'                                              --(SSA01)
         , @c_Wavekey  
         , @c_SourceType 
         , @c_DispatchCasePickMethod
         , @c_Priority                                                              --(SSA01)
               
      OPEN cur_pick    
         
      FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID
                                  , @n_Qty, @c_UOM, @n_UOMQty
                                  , @c_Route, @c_Orderkey, @c_ToLoc, @c_Priority, @dt_DeliveryDate
                                  , @c_Loadkey, @c_LPLDLoc   --WL01
                                  , @c_Areakey, @n_CubeUOM1, @n_CubeUOM3, @n_LocLevel   --WL02
                                  , @n_Casecnt   --WL03
         
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN (1,2)  
      BEGIN                       
         SET @c_LinkTaskToPick_SQL = ''   
         --WL02 S
         SET @c_Groupkey = IIF(@c_UOM = '1', '', @c_Groupkey)
         SET @c_KeyName = LEFT(TRIM(@c_Storerkey) + 'GRPKEY', 18)   --MATTELGRPKEY
         SET @c_StampGrpKey = 'N'
         SET @c_InsGrpKey = ''
         --WL02 E

         IF ISNULL(@c_DefaultLoc,'') <> ''  
           SET @c_ToLoc = @c_DefaultLoc  

         --WL01 S
         IF ISNULL(@c_LPLDLoc,'') <> ''  
            SET @c_ToLoc = @c_LPLDLoc
         --WL01 E
                                
         IF ISNULL(@c_Toloc,'') = ''  
         BEGIN           
            SET @n_continue = 3    
            SET @n_err = 83030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid To Loc setup at ROUTE. (mspRLWAV01)' 
         END    

         SET @c_TaskStatus = '0'                                                    --(Wan02) - START
         IF @c_UOM IN ('2', '6')
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.TaskDetail td (NOLOCK) 
                        WHERE td.Storerkey = @c_Storerkey
                        AND   td.Sku     = @c_Sku
                        AND   td.TaskType= 'RPF'
                        --AND   td.Lot   = @c_Lot                                   --(Wan04)
                        AND   td.ToLoc = @c_FromLoc
                        --AND   td.ToID  = @c_ID                                    --(Wan03)
                        AND   td.SourceType = @c_SourceType
                        AND   td.[Status] BETWEEN '0' AND '8'
                        )
            BEGIN
               --SET @n_QtyRelease2Pick = 0                                         --(Wan04) - START
               --SELECT @n_QtyRelease2Pick = ISNULL(SUM(td.Qty),0)
               --FROM dbo.TaskDetail td (NOLOCK) 
               --WHERE td.Storerkey = @c_Storerkey
               --AND   td.Sku     = @c_Sku
               --AND   td.TaskType='FCP'
               --AND   td.Lot     = @c_Lot
               --AND   td.FromLoc = @c_FromLoc                                        --(Wan03)
               --AND   td.ToID    = @c_ID
               --AND   td.SourceType = @c_SourceType
               --AND   td.[Status] BETWEEN '0' AND '8'
               
               --IF EXISTS ( SELECT 1 FROM dbo.LotxLocxID lli (NOLOCK)
               --            WHERE lli.Lot   = @c_Lot
               --            AND   lli.Loc = @c_FromLoc
               --            AND   lli.ID  = @c_ID
               --            AND   lli.Qty < @n_QtyRelease2Pick + @n_Qty 
               --          )
               --BEGIN
                  SET @c_TaskStatus = 'H'
               --END                                                                --(Wan04) - END
            END
         END                                                                        --(Wan02) - END     

         --WL02 S
         IF @c_UOM IN ('2', '6') AND @n_LocLevel = 0
         BEGIN
            SET @c_StampGrpKey = 'Y'
            SET @n_Volume = 0.00
            
            IF @c_UOM = '2'
               SET @n_Volume = @n_CubeUOM1 * (@n_Qty / @n_Casecnt)   --Case   --WL03
            ELSE IF @c_UOM = '6'
               SET @n_Volume = @n_CubeUOM3 * @n_Qty      --EA

            SET @n_TTLVolume = ISNULL(@n_TTLVolume, 0.00) + @n_Volume

            IF @n_TTLVolume > @n_MaxSkuVol
               SET @c_Groupkey = ''

            IF (@c_PrevOrderkey <> @c_Orderkey OR @c_Areakey <> @c_PrevAreakey OR ISNULL(@c_Groupkey, '') = '')
            BEGIN
               SET @n_TTLVolume = @n_Volume

               IF @n_TTLVolume > @n_MaxSkuVol
               BEGIN
                  --Check if need how many groups
                  SET @n_NoOfGroup = CEILING(@n_TTLVolume / @n_MaxSkuVol)
                  --WL03 S
                  SET @n_MaxQtyPerGroup = FLOOR(IIF(@c_UOM = '2', (@n_MaxSkuVol / @n_CubeUOM1) * @n_Casecnt, @n_MaxSkuVol / @n_CubeUOM3))
                  --SET @n_Casecnt = (@n_Qty / @n_UOMQty)

                  --Round up to case
                  --IF @c_UOM = '2'
                  --BEGIN
                  --   SET @n_MaxQtyPerGroup = @n_MaxQtyPerGroup * @n_Casecnt
                  --END
                  --WL03 E

                  WHILE @n_NoOfGroup > 0
                  BEGIN
                     EXEC dbo.nspg_GetKey @KeyName = @c_KeyName
                                        , @fieldlength = 10
                                        , @keystring = @c_Groupkey OUTPUT
                                        , @b_Success = @b_Success OUTPUT
                                        , @n_err = @n_err OUTPUT
                                        , @c_errmsg = @c_errmsg OUTPUT
                     
                     IF @n_continue IN (1,2) 
                     BEGIN  
                        SET @c_TaskType = 'FCP'  
                        SET @c_PickMethod = 'PP'  
        
                        IF @c_DispatchCasePickMethod = '1'
                        BEGIN
                           SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Orderkey = @c_Orderkey'
                        END
                        ELSE
                        BEGIN
                           SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Userdefine09 = @c_Wavekey'
                        END
                        
                        IF @n_Qty > @n_MaxQtyPerGroup
                        BEGIN
                           SET @n_Qty = @n_Qty - @n_MaxQtyPerGroup
                           SET @n_QtyToRelease = @n_MaxQtyPerGroup
                           SET @n_UOMQtyToRelease = @n_UOMQty   --@n_QtyToRelease / @n_Casecnt   --WL03
                        END
                        ELSE
                        BEGIN
                           SET @n_QtyToRelease = @n_Qty
                           SET @n_UOMQtyToRelease = @n_UOMQty   --@n_QtyToRelease / @n_Casecnt   --WL03
                           SET @n_Qty = 0
                        END

                        EXEC isp_InsertTaskDetail     
                            @c_TaskType              = @c_TaskType               
                           ,@c_Storerkey             = @c_Storerkey  
                           ,@c_Sku                   = @c_Sku  
                           ,@c_Lot                   = @c_Lot   
                           ,@c_UOM                   = @c_UOM        
                           ,@n_UOMQty                = @n_UOMQtyToRelease       
                           ,@n_Qty                   = @n_QtyToRelease        
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
                           ,@c_Groupkey              = @c_Groupkey
                           ,@c_WaveKey               = @c_Wavekey  
                           ,@c_Loadkey               = @c_Loadkey    
                           ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
                           ,@c_Message03             = ''  
                           ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
                           ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL    
                           ,@c_SplitTaskByCase       ='N'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.  
                           ,@c_WIP_RefNo             = @c_SourceType  
                           ,@b_Success               = @b_Success OUTPUT  
                           ,@n_Err                   = @n_err OUTPUT   
                           ,@c_ErrMsg                = @c_errmsg OUTPUT 
                           ,@c_Status                = @c_TaskStatus         
                            
                        IF @b_Success <> 1   
                        BEGIN  
                           SET @n_continue = 3  
                           SET @n_NoOfGroup = 0
                        END                           
                     END

                     SET @n_NoOfGroup = @n_NoOfGroup - 1
                  END
               END
               ELSE
               BEGIN
                  EXEC dbo.nspg_GetKey @KeyName = @c_KeyName
                                     , @fieldlength = 10
                                     , @keystring = @c_Groupkey OUTPUT
                                     , @b_Success = @b_Success OUTPUT
                                     , @n_err = @n_err OUTPUT
                                     , @c_errmsg = @c_errmsg OUTPUT
               END
            END

            SET @c_InsGrpKey = IIF(@c_StampGrpKey = 'Y', @c_Groupkey, '')
         END
         --WL02 E

         IF @c_UOM = '1' AND @n_continue IN (1,2)
         BEGIN   
            SET @c_Taskdetailkey = ''  
            SET @c_TaskType   = 'FPK'  
            SET @c_PickMethod = 'FP'  
            IF @c_DispatchCasePickMethod = '1'                                      --(Wan01) - START
            BEGIN
               SET @c_GroupKey = @c_Orderkey
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Orderkey = @c_Orderkey'
            END
            ELSE
            BEGIN
               SET @c_GroupKey = @c_Wavekey
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Userdefine09 = @c_Wavekey'    
            END                                                                     --(Wan01) - END
                
            EXEC isp_InsertTaskDetail     
                @c_Taskdetailkey         = @c_Taskdetailkey OUTPUT  
               ,@c_TaskType              = @c_TaskType               
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
               ,@c_Groupkey              = @c_Groupkey  
               ,@c_WaveKey               = @c_Wavekey        
               ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
               ,@c_Message03             = ''  
               ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL    
               ,@c_WIP_RefNo             = @c_SourceType  
               ,@b_Success               = @b_Success OUTPUT  
               ,@n_Err                   = @n_err OUTPUT   
               ,@c_ErrMsg                = @c_errmsg OUTPUT          
                
            IF @b_Success <> 1   
            BEGIN  
               SET @n_continue = 3    
            END               
            ELSE  
            BEGIN  
               UPDATE TASKDETAIL WITH (ROWLOCK)  
               SET Groupkey = @c_Taskdetailkey  
               WHERE TaskDetailKey = @c_Taskdetailkey    
            END  
         END  
         ELSE IF @c_UOM = '2' AND @n_continue IN (1,2) AND @n_Qty > 0   --WL02
         BEGIN  
            SET @c_TaskType = 'FCP'  
            SET @c_PickMethod = 'PP'  
            
            IF @c_DispatchCasePickMethod = '1'
            BEGIN
               --SET @c_GroupKey = @c_Orderkey   --WL02
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Orderkey = @c_Orderkey'
            END
            ELSE
            BEGIN
               --SET @c_GroupKey = @c_Wavekey                                                               --(Wan01)   --WL02
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Userdefine09 = @c_Wavekey'   --(Wan01) 
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
               ,@c_ToID                  = @c_ID         
               ,@c_PickMethod            = @c_PickMethod  
               ,@c_Priority              = @c_Priority       
               ,@c_SourcePriority        = '9'        
               ,@c_SourceType            = @c_SourceType        
               ,@c_SourceKey             = @c_Wavekey        
               ,@c_OrderKey              = @c_Orderkey        
               ,@c_Groupkey              = @c_InsGrpKey   --WL02  
               ,@c_WaveKey               = @c_Wavekey  
               ,@c_Loadkey               = @c_Loadkey    
               ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
               ,@c_Message03             = ''  
               ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL    
               ,@c_SplitTaskByCase       ='N'   -- N=No slip Y=Split TASK by carton. Only apply if @n_casecnt > 0. include last partial carton.  
               ,@c_WIP_RefNo             = @c_SourceType  
               ,@b_Success               = @b_Success OUTPUT  
               ,@n_Err                   = @n_err OUTPUT   
               ,@c_ErrMsg                = @c_errmsg OUTPUT 
               ,@c_Status                = @c_TaskStatus                            --(Wan02)           
                
            IF @b_Success <> 1   
            BEGIN  
               SET @n_continue = 3    
            END                           
         END  
         ELSE IF @n_continue IN (1,2) AND @n_Qty > 0   --WL02
         BEGIN  --UOM 6                       
            SET @c_TaskType = 'FCP'  
            SET @c_PickMethod = 'PP'  
            IF @c_DispatchCasePickMethod = '1'
            BEGIN
               --SET @c_GroupKey = @c_Orderkey   --WL02
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.Orderkey = @c_Orderkey'
            END
            ELSE
            BEGIN
               --SET @c_GroupKey = @c_Wavekey                                                               --(Wan01)   --WL02 
               SET @c_LinkTaskToPick_SQL = 'PICKDETAIL.UOM = @c_UOM AND ORDERS.UserDefine09 = @c_Wavekey'   --(Wan01)  
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
               ,@c_ToID                  = @c_ID         
               ,@c_PickMethod            = @c_PickMethod  
               ,@c_Priority              = @c_Priority       
               ,@c_SourcePriority        = '9'        
               ,@c_SourceType            = @c_SourceType        
               ,@c_SourceKey             = @c_Wavekey        
               ,@c_OrderKey              = @c_Orderkey        
               ,@c_Groupkey              = @c_InsGrpKey   --WL02 
               ,@c_WaveKey               = @c_Wavekey  
               ,@c_LoadKey               = @c_Loadkey       
               ,@c_AreaKey               = '?F'  -- ?F=Get from location areakey   
               ,@c_Message03             = ''  
               ,@c_LinkTaskToPick        = 'WIP' -- WIP=Update taskdetailkey to pickdetail_wip  
               ,@c_LinkTaskToPick_SQL    = @c_LinkTaskToPick_SQL    
               ,@c_WIP_RefNo             = @c_SourceType  
               ,@b_Success               = @b_Success OUTPUT  
               ,@n_Err                   = @n_err OUTPUT   
               ,@c_ErrMsg                = @c_errmsg OUTPUT 
               ,@c_Status                = @c_TaskStatus                            --(Wan01)           
                
            IF @b_Success <> 1   
            BEGIN  
               SET @n_continue = 3    
            END                              
         END  
         
         --WL02 S
         SET @c_PrevOrderkey = @c_Orderkey
         SET @c_PrevAreakey = @c_Areakey
         --WL02 E
         FETCH NEXT FROM cur_pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID
                                     , @n_Qty, @c_UOM, @n_UOMQty
                                     , @c_Route, @c_Orderkey, @c_ToLoc, @c_Priority, @dt_DeliveryDate
                                     , @c_Loadkey, @c_LPLDLoc   --WL01
                                     , @c_Areakey, @n_CubeUOM1, @n_CubeUOM3, @n_LocLevel   --WL02
                                     , @n_Casecnt   --WL03
      END  
      CLOSE cur_pick  
      DEALLOCATE cur_pick         
   END  
                       
   -----Update pickdetail_WIP work in progress staging table back to pickdetail   
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      EXEC isp_CreatePickdetail_WIP  
            @c_Loadkey               = '' --@c_Loadkey                                --(Wan02) Fix  
         ,  @c_Wavekey               = @c_wavekey    
         ,  @c_WIP_RefNo             = @c_SourceType   
         ,  @c_PickCondition_SQL     = ''  
         ,  @c_Action                = 'U'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records  
         ,  @c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization  
         ,  @b_Success               = @b_Success OUTPUT  
         ,  @n_Err                   = @n_Err     OUTPUT   
         ,  @c_ErrMsg                = @c_ErrMsg  OUTPUT  
             
      IF @b_Success <> 1  
      BEGIN  
         SET @n_continue = 3  
      END               
   END  
        
   -----Generate Pickslip No------      
   IF @n_continue = 1 or @n_continue = 2   
   BEGIN  
      IF dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AutoScanIn') = '1'   
      BEGIN              
         EXEC isp_CreatePickSlip  
             @c_Wavekey = @c_Wavekey  
            ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno   
            ,@c_ConsolidateByLoad = 'Y'  
            ,@c_AutoScanIn = 'Y'   --Y=Auto scan in the pickslip N=Not auto scan in     
            ,@c_PickslipType = '8'  
            ,@b_Success = @b_Success OUTPUT  
            ,@n_Err = @n_err OUTPUT   
            ,@c_ErrMsg = @c_errmsg OUTPUT          
            
         IF @b_Success = 0  
            SET @n_continue = 3  
  
         
         SET @cur_waveord = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT Orderkey  
            FROM WAVEDETAIL (NOLOCK)  
            WHERE Wavekey = @c_Wavekey 
            ORDER BY Wavedetailkey
           
         OPEN @cur_waveord    
         
         FETCH NEXT FROM @cur_waveord INTO @c_Orderkey  
           
         WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
         BEGIN                        
              UPDATE PICKHEADER WITH (ROWLOCK)  
              SET PICKHEADER.Wavekey = @c_Wavekey,  
                  PICKHEADER.Trafficcop = NULL  
              FROM PICKHEADER  
              JOIN ORDERS (NOLOCK) ON PICKHEADER.Orderkey = ORDERS.Orderkey  
              WHERE PICKHEADER.Orderkey = @c_Orderkey  
                                        
            FETCH NEXT FROM @cur_waveord INTO @c_Orderkey  
         END         
         CLOSE @cur_waveord  
         DEALLOCATE @cur_waveord  
      END  
   END  
     
RETURN_SP:  
  
   -----Delete pickdetail_WIP work in progress staging table  
   IF @n_continue IN (1,2)  
   BEGIN  
      EXEC isp_CreatePickdetail_WIP  
            @c_Loadkey               = '' --@c_Loadkey                                --(Wan02) Fix  
         ,  @c_Wavekey               = @c_wavekey    
         ,  @c_WIP_RefNo             = @c_SourceType   
         ,  @c_PickCondition_SQL     = ''  
         ,  @c_Action                = 'D'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records  
         ,  @c_RemoveTaskdetailkey   = 'N'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization  
         ,  @b_Success               = @b_Success OUTPUT  
         ,  @n_Err                   = @n_Err     OUTPUT   
         ,  @c_ErrMsg                = @c_ErrMsg  OUTPUT  
             
      IF @b_Success <> 1  
      BEGIN  
         SET @n_continue = 3  
      END               
   END  
      
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL  
      DROP TABLE #PICKDETAIL_WIP  
  
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_success = 0    
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
      execute nsp_logerror @n_err, @c_errmsg, "mspRLWAV01"    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
   END    
   ELSE    
   BEGIN    
      SET @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
   END        
END

GO