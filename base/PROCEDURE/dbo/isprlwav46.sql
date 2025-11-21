SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: ispRLWAV46                                          */    
/* Creation Date: 20-Aug-2021                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-17722 - [CN] Sephora Chengdu Release Wave                */    
/*                                                                       */    
/* Called By: Wave                                                       */    
/*                                                                       */    
/* GitLab Version: 1.3                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */ 
/* 2021-08-20   WLChooi  1.0  DevOps Combine Script                      */ 
/* 2021-12-16   WLChooi  1.1  WMS-17722 Change Message02 & Message03 and */
/*                            bug fix (WL01)                             */
/* 2022-02-07   WLChooi  1.2  WMS-18856 Change DPP Loc Assign Logic(WL02)*/
/* 04-Sep-2023  WLChooi  1.3  WMS-23555 - Add validation (WL03)          */
/*************************************************************************/     

CREATE   PROCEDURE [dbo].[ispRLWAV46]        
  @c_wavekey      NVARCHAR(10)    
 ,@b_Success      INT            OUTPUT    
 ,@n_err          INT            OUTPUT    
 ,@c_errmsg       NVARCHAR(250)  OUTPUT    
 ,@b_debug        INT = 0
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
      SET @b_debug = @n_err

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0  
   SELECT @n_debug = 0 
 
   DECLARE @c_DispatchPiecePickMethod NVARCHAR(10)
         , @c_DeviceId                NVARCHAR(20)
         , @c_IPAddress               NVARCHAR(40)
         , @c_PortNo                  NVARCHAR(5)
         , @c_DevicePosition          NVARCHAR(10)
         , @c_PTSLOC                  NVARCHAR(10)
         , @c_PTSStatus               NVARCHAR(10)
         , @c_InLoc                   NVARCHAR(10)
         , @c_DropId                  NVARCHAR(20)
         , @c_Storerkey               NVARCHAR(15)
         , @c_Sku                     NVARCHAR(20)
         , @c_Lot                     NVARCHAR(10)
         , @c_FromLoc                 NVARCHAR(10)
         , @c_ID                      NVARCHAR(18)
         , @n_Qty                     INT
         , @c_PickMethod              NVARCHAR(10)
         , @c_Toloc                   NVARCHAR(10)
         , @c_Taskdetailkey           NVARCHAR(10)
         , @n_UCCQty                  INT
         , @c_Style                   NVARCHAR(20)
         , @c_Facility                NVARCHAR(5)
         , @c_NextDynPickLoc          NVARCHAR(10)
         , @c_UOM                     NVARCHAR(10)
         , @c_DestinationType         NVARCHAR(30)
         , @c_SourceType              NVARCHAR(30)
         , @c_Pickdetailkey           NVARCHAR(18)
         , @c_NewPickdetailKey        NVARCHAR(18)
         , @n_Pickqty                 INT
         , @n_ReplenQty               INT
         , @n_SplitQty                INT
         , @c_Message03               NVARCHAR(20)
         , @c_TaskType                NVARCHAR(10)
         , @c_Orderkey                NVARCHAR(10)
         , @c_Pickslipno              NVARCHAR(10)
         , @c_Loadkey                 NVARCHAR(10)
         , @c_InductionLoc            NVARCHAR(20)
         , @c_PTLWavekey              NVARCHAR(10)
         , @c_PTLLoadkey              NVARCHAR(10)
         , @c_LoadlineNumber          NVARCHAR(5)
         , @c_Loctype                 NVARCHAR(10)
         , @c_curPickdetailkey        NVARCHAR(10)
         , @c_Lottable01              NVARCHAR(18)
         , @n_UCCToFit                INT
         , @n_UCCCnt                  INT
         , @dt_Lottable05             DATETIME
         , @c_Userdefine02            NVARCHAR(50)
         , @c_Userdefine03            NVARCHAR(50)
         , @c_DocType                 NVARCHAR(10)
         , @c_PrevSourcekey           NVARCHAR(10) = N''
         , @c_DPCount                 NVARCHAR(10) = N''
         , @c_FirstDP                 NVARCHAR(20) = N''
         , @c_PrevDP                  NVARCHAR(20) = N''
         , @n_CountBUSR4              INT          = 0
         , @c_DispatchCasePickMethod  NVARCHAR(10)
         , @c_Lottable02              NVARCHAR(18)
         , @c_Lottable03              NVARCHAR(18)
         , @dt_Lottable04             DATETIME
         , @c_SKUBUSR4                NVARCHAR(50)
         , @n_CountSKU                INT
         , @n_CountLoad               INT
         , @n_PTSNumber               INT
         , @c_MinPos                  NVARCHAR(20)
         , @c_PTSCode                 NVARCHAR(50)
         , @c_Notes                   NVARCHAR(500)
         , @c_PalletPicker            NVARCHAR(50)
         , @c_CasePicker              NVARCHAR(50) 
         , @c_PickWorkBalance         NVARCHAR(10)
         , @n_RowID                   INT   --WL01
         , @c_PAZone                  NVARCHAR(50)   --WL02
         , @c_PZDPPLOC                NVARCHAR(20)   --WL02

   DECLARE @n_SKUPerPTS               INT
         , @n_CurrentSplitNumber      INT
         , @n_RemainSKUCount          INT
         , @n_SplitCountSKU           INT
         , @n_TopSplitCategory        INT
         , @n_SplitNumber             INT
   
   --Pick Work Balance
   DECLARE @c_GetLocationHandling     NVARCHAR(10)
         , @c_GetPDNotes              NVARCHAR(50)
         , @c_GetSKU                  NVARCHAR(20)
         , @c_GetFromLoc              NVARCHAR(20)
         , @n_CountSKULoc             INT
         , @n_TaskPerLH               INT
         , @c_PrevLocationHandling    NVARCHAR(20)
         , @c_PrevPDNotes             NVARCHAR(50)
         , @c_PrevSKU                 NVARCHAR(50)
         , @c_PrevFromLoc             NVARCHAR(50)
         , @n_CurrentTaskCount        INT = 1
         , @c_GroupKey                NVARCHAR(10)
         , @c_GetTaskdetailkey        NVARCHAR(10)
         , @c_FirstGroupKey           NVARCHAR(1) = 'Y'
         
   -----Check which strategy to use based on DispatchPiecePickMethood
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT TOP 1 @c_Userdefine02 = WAVE.UserDefine02   
                 , @c_Userdefine03 = WAVE.UserDefine03 
                 , @c_PalletPicker = WAVE.UserDefine04
                 , @c_CasePicker   = WAVE.UserDefine05 
                 , @c_Facility     = ORDERS.Facility 
                 , @c_Storerkey    = ORDERS.Storerkey
                 , @c_DispatchPiecePickMethod = WAVE.DispatchPiecePickMethod  
                 , @c_DispatchCasePickMethod  = WAVE.DispatchCasePickMethod
      FROM WAVE (NOLOCK)  
      JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey  
      JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey          
      WHERE WAVE.Wavekey = @c_Wavekey  
                          
      IF @n_debug=1  
         SELECT '@c_TopSplitCategory', @c_Userdefine02, '@c_SplitNumber', @c_Userdefine03, '@c_DispatchPiecePickMethod', @c_DispatchPiecePickMethod      
         
      SELECT @c_PickWorkBalance = ISNULL(SC.sValue,'')
      FROM StorerConfig SC (NOLOCK)
      WHERE SC.StorerKey = @c_Storerkey
      AND SC.ConfigKey = 'SEPWORKBAL'             
   END  

   -----Wave Validation-----  
   IF @n_continue=1 or @n_continue=2    
   BEGIN    
      IF ISNULL(@c_wavekey,'') = ''    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 81010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV46)'    
      END    
   END      
   
   --Validate DispatchPiecePickMethood
   IF @n_continue=1 or @n_continue=2    
   BEGIN
      IF ISNULL(@c_DispatchPiecePickMethod,'') NOT IN ('SEPB2BPTS','SEPB2BNOR','SEPB2CALL')
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Wave.DispatchPiecePickMethod (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END                  
   END  
   
   --Validate Userdefine02 and Userdefine03
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_DispatchPiecePickMethod,'') IN ('SEPB2BPTS')    
   BEGIN            
      IF (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '') 
      BEGIN           
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must key-in Userdefine01 & 02. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END    
      
      IF (ISNUMERIC(@c_Userdefine02) = 0 OR ISNUMERIC(@c_Userdefine03) = 0) 
      BEGIN           
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Userdefine01 & 02 must be a number. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END
      ELSE
      BEGIN
         SET @n_TopSplitCategory = @c_Userdefine02
         SET @n_SplitNumber      = @c_Userdefine03
      END  
   END  
        
   --Check if the wave has been released      
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                 WHERE TD.Wavekey = @c_Wavekey  
                 AND TD.Sourcetype IN('ispRLWAV46-B2B','ispRLWAV46-B2C')
                 AND TD.Tasktype IN ('RPF'))   
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81040    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV46)'         
      END                   
   END  

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1   
                 FROM WAVEDETAIL WD(NOLOCK)  
                 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                 WHERE O.Status > '2'  
                 AND WD.Wavekey = @c_Wavekey)  
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81050    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV46)'           
      END  
      
      --WL03 S
      IF EXISTS ( SELECT 1 
                  FROM WAVEDETAIL WD(NOLOCK)  
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                  WHERE WD.Wavekey = @c_Wavekey
                  AND O.DocType = 'E'
                  HAVING MIN(O.[Status]) < '2')
      BEGIN
         SELECT @n_continue = 3    
         SELECT @n_err = 81095  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Found B2C Orders with Status < 2 (ispRLWAV46)' 
      END

      IF EXISTS ( SELECT 1 
                  FROM WAVEDETAIL WD(NOLOCK)  
                  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                  WHERE WD.Wavekey = @c_Wavekey
                  AND O.DocType = 'N'
                  HAVING MIN(O.[Status]) = '0')
      BEGIN
         SELECT @n_continue = 3    
         SELECT @n_err = 81100    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Found B2B Orders with Status = 0 (ispRLWAV46)' 
      END
      --WL03 E
   END   
   
   --Create Temporary Tables  
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR')
   BEGIN  
      --Current wave assigned dynamic pick location    
      CREATE TABLE #DYNPICK_LOCASSIGNED ( Rowref         INT NOT NULL IDENTITY(1,1) PRIMARY KEY  
                                         ,STORERKEY      NVARCHAR(15) NULL  
                                         ,SKU            NVARCHAR(20) NULL  
                                         ,TOLOC          NVARCHAR(10) NULL  
                                         ,Lottable02     NVARCHAR(18) NULL 
                                         ,Lottable03     NVARCHAR(18) NULL    
                                         ,Lottable04     DATETIME NULL    
                                         ,LocationType   NVARCHAR(10) NULL   
                                         ,UCCToFit       INT DEFAULT(0)
                                         ,Putawayzone    NVARCHAR(50) NULL   --WL02
      )  
      CREATE INDEX IDX_TOLOC ON #DYNPICK_LOCASSIGNED (TOLOC)      
       
      CREATE TABLE #DYNPICK_TASK (Rowref        INT NOT NULL IDENTITY(1,1) PRIMARY Key  
                                 ,TOLOC         NVARCHAR(10) NULL
                                 ,Putawayzone   NVARCHAR(50) NULL   --WL02
      )      
  
      CREATE TABLE #DYNPICK_NON_EMPTY (Rowref         INT NOT NULL IDENTITY(1,1) PRIMARY Key  
                                      ,LOC            NVARCHAR(10) NULL
                                      ,Putawayzone    NVARCHAR(50) NULL   --WL02
      )    
                                                           
      CREATE TABLE #DYNLOC (Rowref           INT NOT NULL IDENTITY(1,1) PRIMARY KEY
                           ,Loc              NVARCHAR(10) NULL
                           ,logicallocation  NVARCHAR(18) NULL
                           ,MaxPallet        INT NULL
                           ,Putawayzone      NVARCHAR(50) NULL   --WL02
      )
      CREATE INDEX IDX_DLOC ON #DYNLOC (LOC)   
                             
      CREATE TABLE #EXCLUDELOC (Rowref       INT NOT NULL IDENTITY(1,1) PRIMARY Key  
                               ,LOC          NVARCHAR(10) NULL
                               ,Putawayzone  NVARCHAR(50) NULL   --WL02
      )
      CREATE INDEX IDX_LOC ON #EXCLUDELOC (LOC) 
                       
   END   
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_DispatchPiecePickMethod IN ('SEPB2BPTS','SEPB2BNOR') 
         SELECT @c_SourceType = 'ispRLWAV46-B2B'  
      ELSE IF @c_DispatchPiecePickMethod IN ('SEPB2CALL')
         SELECT @c_SourceType = 'ispRLWAV46-B2C'  

      IF OBJECT_ID('#PickDetail_WIP') IS NOT NULL
      BEGIN 
         DROP TABLE #PickDetail_WIP;
      END
      
      CREATE TABLE #PickDetail_WIP
      (  
         [PickDetailKey]         [nvarchar](18)    NOT NULL PRIMARY KEY  
      ,  [CaseID]                [nvarchar](20)    NOT NULL DEFAULT (' ')  
      ,  [PickHeaderKey]         [nvarchar](18)    NOT NULL  
      ,  [OrderKey]              [nvarchar](10)    NOT NULL  
      ,  [OrderLineNumber]       [nvarchar](5)     NOT NULL  
      ,  [Lot]                   [nvarchar](10)    NOT NULL  
      ,  [Storerkey]             [nvarchar](15)    NOT NULL  
      ,  [Sku]                   [nvarchar](20)    NOT NULL  
      ,  [AltSku]                [nvarchar](20)    NOT NULL    DEFAULT (' ')  
      ,  [UOM]                   [nvarchar](10)    NOT NULL    DEFAULT (' ')  
      ,  [UOMQty]                [int]             NOT NULL    DEFAULT ((0))  
      ,  [Qty]                   [int]             NOT NULL    DEFAULT ((0))  
      ,  [QtyMoved]              [int]             NOT NULL    DEFAULT ((0))  
      ,  [Status]                [nvarchar](10)    NOT NULL    DEFAULT ('0')  
      ,  [DropID]                [nvarchar](20)    NOT NULL    DEFAULT ('')  
      ,  [Loc]                   [nvarchar](10)    NOT NULL    DEFAULT ('UNKNOWN')  
      ,  [ID]                    [nvarchar](18)    NOT NULL    DEFAULT (' ')  
      ,  [PackKey]               [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [UpdateSource]          [nvarchar](10)    NULL        DEFAULT ('0')  
      ,  [CartonGroup]           [nvarchar](10)    NULL  
      ,  [CartonType]            [nvarchar](10)    NULL  
      ,  [ToLoc]                 [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [DoReplenish]           [nvarchar](1)     NULL        DEFAULT ('N')  
      ,  [ReplenishZone]         [nvarchar](10)    NULL        DEFAULT (' ')  
      ,  [DoCartonize]           [nvarchar](1)     NULL        DEFAULT ('N')  
      ,  [PickMethod]            [nvarchar](1)     NOT NULL    DEFAULT (' ')  
      ,  [WaveKey]               [nvarchar](10)    NOT NULL    DEFAULT (' ')  
      ,  [EffectiveDate]         [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [AddDate]               [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [AddWho]                [nvarchar](128)   NOT NULL    DEFAULT (suser_sname())  
      ,  [EditDate]              [datetime]        NOT NULL    DEFAULT (getdate())  
      ,  [EditWho]               [nvarchar](128)   NOT NULL    DEFAULT (suser_sname())  
      ,  [TrafficCop]            [nvarchar](1)     NULL  
      ,  [ArchiveCop]            [nvarchar](1)     NULL  
      ,  [OptimizeCop]           [nvarchar](1)     NULL  
      ,  [ShipFlag]              [nvarchar](1)     NULL        DEFAULT ('0')  
      ,  [PickSlipNo]            [nvarchar](10)    NULL  
      ,  [TaskDetailKey]         [nvarchar](10)    NULL  
      ,  [TaskManagerReasonKey]  [nvarchar](10)    NULL  
      ,  [Notes]                 [nvarchar](4000)  NULL  
      ,  [MoveRefKey]            [nvarchar](10)    NULL        DEFAULT ('')  
      ,  [WIP_Refno]             [nvarchar](30)    NOT NULL    DEFAULT ('')  
      ,  [Channel_ID]            [bigint]          NULL        DEFAULT ((0))
      )      
            
      CREATE INDEX PDWIP_Wave ON #PickDetail_WIP (Wavekey, WIP_RefNo, UOM, [Status])                     
   END          
            
   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Wavekey               = @c_Wavekey  
         ,@c_WIP_RefNo             = @c_SourceType 
         ,@c_PickCondition_SQL     = ''
         ,@c_Action                = 'I'    --I=Initialize pickdetail_wip table. U=Update pickdetail_WIP to pickdetail table and delete. D=Only delete pickdetail_WIP records
         ,@c_RemoveTaskdetailkey   = 'Y'    --N=No remove Y=Remove taskdetailkey from pickdetail record when initialization
         ,@b_Success               = @b_Success OUTPUT
         ,@n_Err                   = @n_Err     OUTPUT 
         ,@c_ErrMsg                = @c_ErrMsg  OUTPUT
           
      IF @b_Success <> 1
      BEGIN
         SET @n_continue = 3
      END          
   END 

   -----Generate SEPB2CALL Temporary Ref Data-----  
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR')
   BEGIN                  
      INSERT INTO #DYNLOC (Loc, LogicalLocation, Putawayzone)   --WL02  
      SELECT Loc, LogicalLocation, PutawayZone   --WL02               
      FROM LOC (NOLOCK)
      WHERE Facility = @c_Facility 
      AND LocationType = 'DYNPPICK'
      AND LocationCategory = 'SHELVING' 
             
      --location have pending Replenishment tasks  
      INSERT INTO #DYNPICK_TASK (TOLOC, Putawayzone)   --WL02    
      SELECT TD.TOLOC, L.PutawayZone   --WL02  
      FROM   TASKDETAIL TD (NOLOCK)  
      JOIN   LOC L (NOLOCK) ON  TD.TOLOC = L.LOC  
      WHERE  L.LocationType IN('DYNPPICK')
      AND    L.LocationCategory IN ('SHELVING')   
      AND    L.Facility = @c_Facility  
      AND    TD.Status = '0'          
      AND    TD.Tasktype IN('RPF')  
      GROUP BY TD.TOLOC, L.PutawayZone   --WL02    
      HAVING SUM(TD.Qty) > 0  
                  
      --Dynamic pick loc have qty and pending move in  
      INSERT INTO #DYNPICK_NON_EMPTY (LOC, Putawayzone)   --WL02    
      SELECT LLI.LOC, L.PutawayZone   --WL02    
      FROM   LOTXLOCXID LLI (NOLOCK)  
      JOIN   LOC L (NOLOCK) ON LLI.LOC = L.LOC  
      WHERE  L.LocationType IN ('DYNPPICK')   
      AND    L.Facility = @c_Facility  
      GROUP BY LLI.LOC, L.PutawayZone   --WL02  
      HAVING SUM(LLI.Qty + LLI.PendingMoveIN) > 0
        
      INSERT INTO #EXCLUDELOC (Loc, Putawayzone)   --WL02
      SELECT E.LOC, E.Putawayzone  --WL02
      FROM   #DYNPICK_NON_EMPTY E 
      UNION ALL 
      SELECT ReplenLoc.TOLOC, ReplenLoc.Putawayzone   --WL02
      FROM   #DYNPICK_TASK  ReplenLoc 
   END 
   
   --Remove Notes and add wavekey from #PickDetail_WIP of the wave      
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SET @c_curPickdetailkey = ''  
      DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT Pickdetailkey  
      FROM WAVEDETAIL WITH (NOLOCK)    
      JOIN #PickDetail_WIP WITH (NOLOCK)  ON WAVEDETAIL.Orderkey = #PickDetail_WIP.Orderkey  
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey   
  
      OPEN Orders_Pickdet_cur   
      FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey   
      WHILE @@FETCH_STATUS = 0   
      BEGIN   
         UPDATE #PickDetail_WIP WITH (ROWLOCK)   
         SET #PickDetail_WIP.Notes = '',  
             #PickDetail_WIP.Wavekey = @c_Wavekey,   
             EditWho    = SUSER_SNAME(),  
             EditDate   = GETDATE(),     
             TrafficCop = NULL  
         WHERE #PickDetail_WIP.Pickdetailkey = @c_curPickdetailkey
           
         SELECT @n_err = @@ERROR  

         IF @n_err <> 0   
         BEGIN  
            CLOSE Orders_Pickdet_cur   
            DEALLOCATE Orders_Pickdet_cur                    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #PickDetail_WIP Table Failed. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END    

         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
      END  
      CLOSE Orders_Pickdet_cur   
      DEALLOCATE Orders_Pickdet_cur  
   END 
    
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1   
                 FROM WAVEDETAIL WD(NOLOCK)  
                 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                 WHERE O.Status < '2' AND O.DocType = 'E'
                 AND WD.Wavekey = @c_Wavekey)  
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81055    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Not all ECOM orders are fully allocated  (ispRLWAV46)'           
      END                   
   END  

   --Get PTS Info
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT @n_PTSNumber = COUNT(CL.Code)
           , @c_MinPos    = MIN(CL.Short)
      FROM CODELKUP CL (NOLOCK)  
      WHERE CL.LISTNAME = 'WSPTSCODE' AND CL.Storerkey = @c_Storerkey  
   END  

   --BEGIN TRAN  

   CREATE TABLE #TMP_PTS(
      RowID       INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      BUSR4       NVARCHAR(200) NULL,
      CountSKU    INT NULL,
      LOC         NVARCHAR(50)  NULL
   )

   CREATE TABLE #TMP_PTSSplitResult (
      RowID       INT,   --WL01
      BUSR4       NVARCHAR(200),
      CountSKU    INT
   )

   CREATE TABLE #TMP_PTSCodelkup (
      RowID       INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      PTSCode     NVARCHAR(50)
   )

   CREATE TABLE #TMP_PickWorkBalance (
      LocationHandling   NVARCHAR(10),
      CountSKULOC        INT,
      TasksPerLH         INT NULL )

   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      --Generate PTS
      IF @c_DispatchPiecePickMethod = 'SEPB2BPTS'
      BEGIN
         SELECT @n_CountBUSR4 = COUNT(DISTINCT S.BUSR4)
         FROM WAVEDETAIL WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN SKU S (NOLOCK) ON PD.SKU = S.SKU AND PD.Storerkey = S.Storerkey
         WHERE WD.Wavekey = @c_Wavekey AND PD.UOM <> '2' 

         SELECT @n_CountLoad = COUNT(DISTINCT LPD.Loadkey)
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN #PICKDETAIL_WIP PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey  
         JOIN WAVEDETAIL WD (NOLOCK) ON WD.OrderKey = PD.OrderKey
         WHERE WD.Wavekey = @c_Wavekey AND PD.UOM <> '2' 

         --IF @n_PTSNumber < @n_CountBUSR4
         --BEGIN
         --   SELECT @n_continue = 3    
         --   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81069   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         --   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': @n_PTSNumber < COUNT(DISTINCT SKU.BUSR4) . (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         --   GOTO RETURN_SP 
         --END

         IF (@n_TopSplitCategory * @n_SplitNumber) > @n_PTSNumber
         BEGIN
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81069   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not Enough Station. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
            GOTO RETURN_SP 
         END

         IF @n_CountLoad > CAST(@c_MinPos AS INT)
         BEGIN
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81069   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Not Enough Position. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
            GOTO RETURN_SP 
         END

         INSERT INTO #TMP_PTS (BUSR4, CountSKU)
         SELECT TOP (@n_PTSNumber) S.BUSR4
                                 , COUNT(DISTINCT S.SKU)
         FROM WAVEDETAIL WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN SKU S (NOLOCK) ON PD.SKU = S.SKU AND PD.Storerkey = S.Storerkey
         WHERE WD.Wavekey = @c_Wavekey AND PD.UOM <> '2'  
         GROUP BY S.BUSR4
         ORDER BY 2 DESC

         INSERT INTO #TMP_PTSCodelkup (PTSCode)
         SELECT DISTINCT ISNULL(CL.Code,'')
         FROM CODELKUP CL (NOLOCK)
         WHERE CL.LISTNAME = 'WSPTSCODE' AND CL.Storerkey = @c_Storerkey
         ORDER BY 1
      END

      IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('SEPB2BPTS')
      BEGIN
         --Check if need to split SKU Count
         DECLARE cur_SplitSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT TP.RowID, TP.BUSR4, TP.CountSKU   --WL01
         FROM #TMP_PTS TP
         ORDER BY TP.RowID
        
         OPEN cur_SplitSKU    
         FETCH NEXT FROM cur_SplitSKU INTO @n_RowID, @c_SKUBUSR4, @n_CountSKU   --WL01  
        
         WHILE @@FETCH_STATUS = 0    
         BEGIN                        
            IF @b_debug = 1
               SELECT @c_SKUBUSR4 AS SKUBUSR4, @n_CountSKU AS CountSKU, @n_TopSplitCategory AS TopSplitCategory, @n_SplitNumber AS SplitNumber

            IF @n_TopSplitCategory >= 1 AND @n_SplitNumber >= 1   --WL01
            BEGIN
               SELECT @n_SKUPerPTS = ROUND(@n_CountSKU / @n_SplitNumber, 0)

               SET @n_CurrentSplitNumber = @n_SplitNumber
               SET @n_RemainSKUCount     = @n_CountSKU

               WHILE @n_CurrentSplitNumber > 0 
               BEGIN
                  IF @n_CurrentSplitNumber = 1
                     SELECT @n_SplitCountSKU = @n_RemainSKUCount
                  ELSE
                     SELECT @n_SplitCountSKU = @n_SKUPerPTS
                  
                  SET @n_RemainSKUCount = @n_RemainSKUCount - @n_SKUPerPTS
                  SET @n_CurrentSplitNumber = @n_CurrentSplitNumber - 1
                  --SET @n_TopSplitCategory = @n_TopSplitCategory - 1   --WL01

                  INSERT INTO #TMP_PTSSplitResult(RowID, BUSR4, CountSKU)
                  VALUES(@n_RowID, @c_SKUBUSR4 , @n_SplitCountSKU)
               END

               SET @n_TopSplitCategory = @n_TopSplitCategory - 1   --WL01
            END
            ELSE 
            BEGIN
               INSERT INTO #TMP_PTSSplitResult(RowID, BUSR4, CountSKU)
               VALUES(@n_RowID, @c_SKUBUSR4 , @n_CountSKU)
            END

            FETCH NEXT FROM cur_SplitSKU INTO @n_RowID, @c_SKUBUSR4, @n_CountSKU   --WL01   
         END  
         CLOSE cur_SplitSKU    
         DEALLOCATE cur_SplitSKU

         --Update Pickdetail.Notes = Codelkup.Code
         SET @n_cnt = 1

         DECLARE CUR_PDNotes CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TSR.BUSR4, TSR.CountSKU
         FROM #TMP_PTSSplitResult TSR
         ORDER BY TSR.RowID   --WL01
         --ORDER BY TSR.BUSR4    ASC    --WL01
         --       , TSR.CountSKU DESC   --WL01

         OPEN CUR_PDNotes    

         FETCH NEXT FROM CUR_PDNotes INTO @c_SKUBUSR4, @n_CountSKU  
        
         WHILE @@FETCH_STATUS = 0    
         BEGIN        
            SELECT @c_PTSCode = TPC.PTSCode
            FROM #TMP_PTSCodelkup TPC      
            WHERE TPC.RowID = @n_cnt

            UPDATE #PickDetail_WIP
            SET Notes = @c_PTSCode
            WHERE SKU IN ( SELECT DISTINCT TOP (@n_CountSKU) PD.SKU
                           FROM #PickDetail_WIP PD
                           JOIN SKU S (NOLOCK) ON S.StorerKey = PD.Storerkey AND S.Sku = PD.Sku
                           WHERE S.BUSR4 = @c_SKUBUSR4 AND S.StorerKey = @c_Storerkey
                           AND ISNULL(PD.Notes,'') = '' AND PD.UOM <> '2'   --WL01
                           ORDER BY PD.SKU)
            AND Storerkey = @c_Storerkey
            AND UOM <> '2'   --WL01

            SET @n_cnt = @n_cnt + 1

            FETCH NEXT FROM CUR_PDNotes INTO @c_SKUBUSR4, @n_CountSKU  
         END  
         CLOSE CUR_PDNotes    
         DEALLOCATE CUR_PDNotes
      END 
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('SEPB2BPTS','SEPB2BNOR','SEPB2CALL')
   BEGIN 
      DECLARE cur_PICKUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, PD.DropID,  
             CASE WHEN MIN(PD.PickMethod) = 'P' THEN 'FP'                            
                  ELSE 'PP' END AS PickMethod,  
             ISNULL(UCC.Qty,0) AS UCCQty,  
             CASE WHEN LOC.LocationType = 'DYNPPICK' AND LOC.LocationCategory = 'SHELVING' THEN 'DPP'
                  ELSE 'BULK' END,
             '',-- O.Loadkey
             CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(LA.Lottable02,'') ELSE '' END,         
             CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(LA.Lottable03,'') ELSE '' END,         
             CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(LA.Lottable04,'19000101') ELSE NULL END,
             CASE WHEN @c_DispatchPiecePickMethod = 'SEPB2BPTS' THEN PD.Notes ELSE '' END,
             CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(SKU.BUSR4,'') ELSE '' END   --WL02
      FROM WAVEDETAIL WD (NOLOCK)  
      JOIN #PICKDETAIL_WIP PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot  
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
      JOIN SKUXLOC (NOLOCK) ON PD.Storerkey = SKUXLOC.Storerkey AND PD.Sku = SKUXLOC.Sku AND PD.Loc = SKUXLOC.Loc  
      LEFT JOIN UCC (NOLOCK) ON PD.DropId = UCC.UccNo AND PD.Storerkey = UCC.Storerkey
      WHERE WD.Wavekey = @c_Wavekey
      GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM,
               PD.DropID, ISNULL(UCC.Qty,0),  
               CASE WHEN LOC.LocationType = 'DYNPPICK' AND LOC.LocationCategory = 'SHELVING' THEN 'DPP'
                    ELSE 'BULK' END,--, O.Loadkey 
                    CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(LA.Lottable02,'') ELSE '' END,         
                    CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(LA.Lottable03,'') ELSE '' END,         
                    CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(LA.Lottable04,'19000101') ELSE NULL END,
                    CASE WHEN @c_DispatchPiecePickMethod = 'SEPB2BPTS' THEN PD.Notes ELSE '' END,
                    CASE WHEN @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') THEN ISNULL(SKU.BUSR4,'') ELSE '' END   --WL02
      ORDER BY PD.Storerkey, PD.UOM, PD.Sku, PD.Lot

      OPEN cur_PICKUCC    
      FETCH NEXT FROM cur_PICKUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_DropID, 
                                       @c_PickMethod, @n_UCCQty, @c_LocType, @c_Loadkey,
                                       @c_Lottable02, @c_Lottable03, @dt_Lottable04, @c_Notes, @c_SKUBUSR4   --WL02

      SELECT @c_TaskType = 'RPF'  
      SELECT @c_ToLoc = ''  
      SELECT @c_Message03 = @c_Notes   --Save PD.Notes into TaskDetail.Message03  
         
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         IF @c_DispatchPiecePickMethod = 'SEPB2BPTS'
         BEGIN
            IF @c_uom = '2'  
            BEGIN                 
                SELECT @c_DestinationType = 'DIRECT'  
            END   
            ELSE   --UOM in ('6','7')
            BEGIN
               SELECT @c_DestinationType = 'PTS'            
            END
         END
         ELSE IF @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR')
         BEGIN
            IF @c_uom = '2'  
            BEGIN  
               SELECT @c_DestinationType = 'DIRECT'  
            END  
            ELSE IF @c_UOM = '7'
            BEGIN                   
               SELECT @c_DestinationType = 'DPP'                             
            END        
         END
         
         IF @b_debug = 2  
            SELECT '@c_FromLoc', @c_FromLoc, '@c_ID', @c_ID, '@n_Qty', @n_qty, '@c_UOM', @c_UOM, '@c_Lot', @c_Lot, '@n_UCCQty', @n_UCCQty,  
                   '@c_PickMethod', @c_PickMethod, '@c_DropID', @c_DropID, 
                   '@c_DestinationType', @c_DestinationType, @c_Loadkey

         --SEPB2CALL - Full Case for Multi Orders - UOM = '6'
         --DPP LOC -> loc.putawayzone -> putawayzone.InLoc (induction)
         IF @c_DispatchPiecePickMethod IN ('SEPB2CALL') AND @c_UOM IN ('6')
         BEGIN
         	SELECT @c_DestinationType = 'DIRECT_M'  

            SELECT @c_ToLoc = ISNULL(PZ.InLoc,'')
            FROM LOC (NOLOCK)
            JOIN PUTAWAYZONE PZ (NOLOCK) ON LOC.Putawayzone = PZ.Putawayzone  
            WHERE LOC.LOC = @c_FromLoc

            GOTO INSERT_TASKS  
            DIRECT_M: 
            
            GOTO PICKUCC_NEXT_REC
         END
         
         IF @c_DestinationType = 'DPP' --AND @c_DispatchPiecePickMethod IN ('SEPB2CALL','SEPB2BNOR') AND @c_UOM IN ('7')
         BEGIN
            --WL02 S
            SELECT @c_PAZone   = ISNULL(CL.Short,'')
                 , @c_PZDPPLOC = ISNULL(CL.Long,'')
            FROM CODELKUP CL (NOLOCK)
            WHERE CL.LISTNAME = 'SEPPAZONE'
            AND CL.Code = @c_SKUBUSR4
            AND CL.Storerkey = @c_Storerkey
            AND CL.Code2 = 'RL'
            --WL02 E

            SELECT @c_NextDynPickLoc = ''  
                                                                
             -- Assign loc with same sku qty already assigned in current replenishment  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN  
               SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc  
               FROM #DYNPICK_LOCASSIGNED DL  
               WHERE DL.Storerkey = @c_Storerkey  
               AND DL.Sku = @c_Sku  
               AND DL.Lottable02 = @c_Lottable02  
               AND DL.Lottable03 = @c_Lottable03
               AND DL.Lottable04 = @dt_Lottable04
               AND DL.LocationType = 'DPP'  
               AND DL.Putawayzone = @c_PAZone   --WL02  
               ORDER BY DL.ToLoc                       
            END                  
                        
            -- Assign pick loc of the sku if setup skuxloc.locationtype = 'PICK'
            --IF ISNULL(@c_NextDynPickLoc,'')=''  
            --BEGIN  
            --   SELECT TOP 1 @c_NextDynPickLoc = SL.Loc
            --   FROM SKUXLOC SL (NOLOCK)
            --   WHERE SL.Storerkey = @c_Storerkey
            --   AND SL.Sku = @c_Sku
            --   AND SL.LocationType = 'PICK'
            --   ORDER BY SL.Loc
            --END                
                        
            -- Assign loc with same sku already assigned in other replenishment not yet start  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN              
               SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
               FROM TASKDETAIL TD (NOLOCK)  
               JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot  
               JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC    
               WHERE L.LocationType IN ('DYNPPICK')   
               AND L.LocationCategory IN ('SHELVING')  
               AND L.Facility = @c_Facility  
               AND TD.Status = '0'  
               AND TD.Qty > 0   
               AND TD.Tasktype = 'RPF'  
               AND LA.Lottable02 = @c_Lottable02  
               AND LA.Lottable03 = @c_Lottable03
               AND LA.Lottable04 = @dt_Lottable04
               AND TD.Storerkey = @c_Storerkey  
               AND TD.Sku = @c_Sku  
               AND L.PutawayZone = @c_PAZone   --WL02
               ORDER BY L.LogicalLocation, L.Loc  
            END  
            
            -- Assign loc with same sku already assigned in other replenishment but in transit  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN              
               SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
               FROM TASKDETAIL TD (NOLOCK)  
               JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
               JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot  
               WHERE L.LocationType IN ('DYNPPICK')   
               AND L.LocationCategory IN ('SHELVING')  
               AND L.Facility = @c_Facility  
               AND TD.Status = '0'  
               AND TD.Qty > 0   
               AND TD.Tasktype IN('RP1','RPT')  
               AND LA.Lottable02 = @c_Lottable02  
               AND LA.Lottable03 = @c_Lottable03
               AND LA.Lottable04 = @dt_Lottable04
               AND TD.Storerkey = @c_Storerkey  
               AND TD.Sku = @c_Sku  
               AND L.PutawayZone = @c_PAZone   --WL02
               ORDER BY L.LogicalLocation, L.Loc  
            END  
              
            -- Assign loc with same sku and qty available / pending move in  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN                
               SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
               FROM LOTXLOCXID LLI (NOLOCK)  
               JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot  
               JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
               WHERE L.LocationType IN('DYNPPICK')  
               AND L.LocationCategory IN ('SHELVING')  
               AND   L.Facility = @c_Facility  
               AND  (LLI.Qty + LLI.PendingMoveIN) > 0  
               AND LA.Lottable02 = @c_Lottable02  
               AND LA.Lottable03 = @c_Lottable03
               AND LA.Lottable04 = @dt_Lottable04 
               AND  LLI.Storerkey = @c_Storerkey  
               AND  LLI.Sku = @c_Sku  
               AND L.PutawayZone = @c_PAZone   --WL02
               ORDER BY L.LogicalLocation, L.Loc  
            END                                   
                                        
            -- If no location with same Lottable02+03+04 found, then assign the empty location  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN  
               SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
               FROM   #DYNLOC L (NOLOCK) 
               LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.Loc
               LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
               WHERE EL.Loc IS NULL
               AND DynPick.Toloc IS NULL
               AND L.Putawayzone = @c_PAZone         --WL02  
               ORDER BY L.LogicalLocation, L.Loc
            END  
            
            --WL02 S
            --IF @n_debug = 1  
            --   SELECT 'DPP', '@c_NextDynPickLoc', @c_NextDynPickLoc  
            --WL02 E

            -- Terminate. Can't find any dynamic location  
            TERMINATE:  
            --WL02 S
            IF ISNULL(@c_NextDynPickLoc,'') = '' 
            BEGIN
               SET @c_NextDynPickLoc = @c_PZDPPLOC
            END
            --WL02 E

            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               GOTO RETURN_SP  
            END 
            
            --WL02 S
            IF @n_debug = 1  
               SELECT 'DPP', '@c_NextDynPickLoc', @c_NextDynPickLoc  
            --WL02 E
            
            SELECT @c_ToLoc = @c_NextDynPickLoc  
                                           
            --Insert current location assigned  
            IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED   
                           WHERE Storerkey = @c_Storerkey  
                           AND Sku = @c_Sku  
                           AND ToLoc = @c_ToLoc  
                           AND Lottable02 = @c_Lottable02  
                           AND Lottable03 = @c_Lottable03
                           AND Lottable04 = @dt_Lottable04
                           AND Putawayzone = @c_PAZone)   --WL02
            BEGIN  
               INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable02, Lottable03, Lottable04, LocationType, Putawayzone)   --WL02    
               VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @c_Lottable02, @c_Lottable03, @dt_Lottable04, 'DPP', @c_PAZone)   --WL02  
            END  

            IF @c_LocType IN ('BULK')  
            BEGIN  
               GOTO INSERT_TASKS  
               DPP:              
            END  
         END
                                     
         IF @c_DestinationType = 'DIRECT' --Full carton for a load  
         BEGIN  
            SELECT @c_InductionLoc = ISNULL(CL.Short,'')
            FROM CODELKUP CL (NOLOCK) 
            WHERE CL.Storerkey = @c_Storerkey AND CL.Listname = 'SEPZONE' 
            AND CL.Code = (SELECT TOP 1 LOC.Putawayzone FROM LOC (NOLOCK) WHERE LOC = @c_FromLoc)
            AND Code2 = @c_DispatchPiecePickMethod

            SELECT @c_ToLoc = @c_InductionLoc  
             
            GOTO INSERT_TASKS  
            DIRECT:  
         END --DIRECT  

         IF @c_DestinationType = 'PTS'
         BEGIN
            SELECT @c_InductionLoc = ISNULL(CL.Short,'')
            FROM CODELKUP CL (NOLOCK) 
            WHERE CL.Storerkey = @c_Storerkey AND CL.Listname = 'SEPZONE' 
            AND CL.Code = @c_DestinationType
            AND Code2 = @c_DispatchPiecePickMethod
            
            SELECT @c_ToLoc = @c_InductionLoc  

            IF @c_LocType = 'BULK'  
            BEGIN  
               GOTO INSERT_TASKS  
               PTS:              
            END                                    
         END --PTS     

         PICKUCC_NEXT_REC:  
         FETCH NEXT FROM cur_PICKUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_DropID, 
                                       @c_PickMethod, @n_UCCQty, @c_LocType, @c_Loadkey,
                                       @c_Lottable02, @c_Lottable03, @dt_Lottable04, @c_Notes, @c_SKUBUSR4   --WL02
      END --Fetch  
      CLOSE cur_PICKUCC    
      DEALLOCATE cur_PICKUCC                                     
   END      

   -----Update pickdetail_WIP work in progress staging table back to pickdetail 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Wavekey               = @c_wavekey  
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

   -----Generate Conso Pickslip and Auto Scan In (Only B2B)-------  
   IF (@n_continue = 1 or @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('SEPB2BPTS','SEPB2BNOR')
   BEGIN
      EXEC isp_CreatePickSlip
              @c_Wavekey = @c_Wavekey
             ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
             ,@c_ConsolidateByLoad = 'Y'
             ,@c_AutoScanIn = 'Y'
             ,@c_Refkeylookup = 'Y'
             ,@b_Success = @b_Success OUTPUT
             ,@n_Err = @n_err OUTPUT 
             ,@c_ErrMsg = @c_errmsg OUTPUT       	
         
      IF @b_Success = 0
         SELECT @n_continue = 3   
   END  

   -------Generate Discrete Pickslip and Auto Scan In (Only B2C)-------  
   --IF (@n_continue = 1 or @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('SEPB2CALL')
   --BEGIN
   --   EXEC isp_CreatePickSlip
   --           @c_Wavekey = @c_Wavekey
   --          ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
   --          ,@c_ConsolidateByLoad = 'N'
   --          ,@c_AutoScanIn = 'Y'
   --          ,@b_Success = @b_Success OUTPUT
   --          ,@n_Err = @n_err OUTPUT 
   --          ,@c_ErrMsg = @c_errmsg OUTPUT       	
         
   --   IF @b_Success = 0
   --      SELECT @n_continue = 3   
   --END 

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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_PickWorkBalance = '1'
   BEGIN
      INSERT INTO #TMP_PickWorkBalance (LocationHandling, CountSKULOC)
      SELECT L.LocationHandling
           , COUNT(DISTINCT TD.SKU + TD.FromLoc)
      FROM TASKDETAIL TD (NOLOCK)
      JOIN LOC L (NOLOCK) ON L.LOC = TD.FromLoc
      WHERE TD.WaveKey = @c_wavekey
      GROUP BY L.LocationHandling
      ORDER BY L.LocationHandling
      
      -----LocationHandling = 1 (Pallet Picker)-----
      ;WITH PWB_1 AS
      (
         SELECT T1.LocationHandling, T1.CountSKULOC AS CountSKULOC, T1.TasksPerLH
         FROM #TMP_PickWorkBalance T1
         WHERE T1.LocationHandling = '1'
      )
      UPDATE PWB_1
      SET TasksPerLH = CASE WHEN ISNUMERIC(@c_PalletPicker) = 1 
                            THEN CountSKULOC / @c_PalletPicker
                            ELSE CountSKULOC END

      -----LocationHandling = 2 (Case Picker)-----
      ;WITH PWB_2 AS
      (
         SELECT T1.LocationHandling, T1.CountSKULOC AS CountSKULOC, T1.TasksPerLH
         FROM #TMP_PickWorkBalance T1
         WHERE T1.LocationHandling = '2'
      )
      UPDATE PWB_2
      SET TasksPerLH = CASE WHEN ISNUMERIC(@c_CasePicker) = 1 
                            THEN CountSKULOC / @c_CasePicker
                            ELSE CountSKULOC END

      DECLARE CUR_PWB CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT   L.LocationHandling
             , CASE WHEN ISNULL(TD.Message03,'') = '' THEN 'ZZZZZZZZZZ' ELSE TD.Message03 END
             , TD.Sku
             , TD.FromLoc
             , TPWB.CountSKULOC
             , TPWB.TasksPerLH
             , TD.TaskDetailKey
      FROM TASKDETAIL TD (NOLOCK)
      JOIN LOC L (NOLOCK) ON L.LOC = TD.FromLoc
      JOIN #TMP_PickWorkBalance TPWB ON TPWB.LocationHandling = L.LocationHandling
      WHERE TD.WaveKey = @c_wavekey AND TD.TaskType = 'RPF'
      GROUP BY L.LocationHandling
             , CASE WHEN ISNULL(TD.Message03,'') = '' THEN 'ZZZZZZZZZZ' ELSE TD.Message03 END
             , TD.Sku
             , TD.FromLoc
             , TPWB.CountSKULOC
             , TPWB.TasksPerLH
             , TD.TaskDetailKey
      ORDER BY L.LocationHandling
             , CASE WHEN ISNULL(TD.Message03,'') = '' THEN 'ZZZZZZZZZZ' ELSE TD.Message03 END
             , TD.Sku
             , TD.FromLoc
             , TD.TaskDetailKey

      OPEN CUR_PWB

      FETCH NEXT FROM CUR_PWB INTO @c_GetLocationHandling, @c_GetPDNotes, @c_GetSKU, @c_GetFromLoc, @n_CountSKULoc, @n_TaskPerLH, @c_GetTaskdetailkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @b_success = 1   
         
         --SELECT @c_PrevLocationHandling, @c_GetLocationHandling, @c_PrevPDNotes, @c_GetPDNotes, @n_CurrentTaskCount, @n_TaskPerLH, @c_GroupKey, @c_GetTaskdetailkey
         IF (@c_PrevLocationHandling <> @c_GetLocationHandling) OR (@c_PrevPDNotes <> @c_GetPDNotes) OR (@c_PrevSKU <> @c_GetSKU) OR (@c_PrevFromLoc <> @c_GetFromLoc) OR (@c_FirstGroupKey = 'Y')
         BEGIN 
            IF (@n_CurrentTaskCount > @n_TaskPerLH) OR (@c_PrevLocationHandling <> @c_GetLocationHandling) OR (@c_PrevPDNotes <> @c_GetPDNotes) OR (@c_FirstGroupKey = 'Y')
            BEGIN 
               SET @n_CurrentTaskCount = 1
               SET @c_FirstGroupKey = 'N'

               --Get New GroupKey
               EXECUTE   nspg_getkey    
               'SEPCDGrKey'    
               , 10    
               , @c_GroupKey OUTPUT    
               , @b_success OUTPUT    
               , @n_err OUTPUT    
               , @c_errmsg OUTPUT    
               
               IF NOT @b_success = 1    
               BEGIN    
                  SELECT @n_continue = 3    
               END 
            END

            SET @n_CurrentTaskCount = @n_CurrentTaskCount + 1   
         END

         UPDATE dbo.TaskDetail
         SET Groupkey   = @c_GroupKey
           , TrafficCop = NULL
           , Editwho    = SUSER_SNAME()
           , EditDate   = GETDATE()
         WHERE TaskDetailKey = @c_GetTaskdetailkey  
   
         SET @c_PrevLocationHandling = @c_GetLocationHandling
         SET @c_PrevPDNotes = @c_GetPDNotes
         SET @c_PrevSKU = @c_GetSKU
         SET @c_PrevFromLoc = @c_GetFromLoc

         FETCH NEXT FROM CUR_PWB INTO @c_GetLocationHandling, @c_GetPDNotes, @c_GetSKU, @c_GetFromLoc, @n_CountSKULoc, @n_TaskPerLH, @c_GetTaskdetailkey
      END
      CLOSE CUR_PWB
      DEALLOCATE CUR_PWB
   END

RETURN_SP:
   -----Delete pickdetail_WIP work in progress staging table
   IF @n_continue IN (1,2)
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Wavekey               = @c_wavekey  
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

   IF OBJECT_ID('tempdb..#DYNPICK_LOCASSIGNED','u') IS NOT NULL  
      DROP TABLE #DYNPICK_LOCASSIGNED 
  
   IF OBJECT_ID('tempdb..#DYNPICK_TASK','u') IS NOT NULL  
      DROP TABLE #DYNPICK_TASK
  
   IF OBJECT_ID('tempdb..#DYNPICK_NON_EMPTY','u') IS NOT NULL  
      DROP TABLE #DYNPICK_NON_EMPTY  
           
   IF OBJECT_ID('tempdb..#DYNLOC','u') IS NOT NULL  
      DROP TABLE #DYNLOC  
       
   IF OBJECT_ID('tempdb..#EXCLUDELOC','u') IS NOT NULL  
      DROP TABLE #EXCLUDELOC

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV46'  
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

INSERT_TASKS:  
   --function to insert taskdetail  
   SELECT @b_success = 1    
   EXECUTE   nspg_getkey    
   'TaskDetailKey'    
   , 10    
   , @c_taskdetailkey OUTPUT    
   , @b_success OUTPUT    
   , @n_err OUTPUT    
   , @c_errmsg OUTPUT    

   IF NOT @b_success = 1    
   BEGIN    
      SELECT @n_continue = 3    
   END    
    
   IF @b_success = 1    
   BEGIN        
     INSERT TASKDETAIL    
      (    
        TaskDetailKey    
       ,TaskType    
       ,Storerkey    
       ,Sku    
       ,UOM    
       ,UOMQty    
       ,Qty    
       ,SystemQty  
       ,Lot    
       ,FromLoc    
       ,FromID    
       ,ToLoc    
       ,ToID    
       ,SourceType    
       ,SourceKey    
       ,Priority    
       ,SourcePriority    
       ,Status    
       ,LogicalFromLoc    
       ,LogicalToLoc    
       ,PickMethod  
       ,Wavekey  
       ,Message02   
       ,Areakey  
       ,Message03  
       ,Caseid  
       ,Loadkey  
       ,QtyReplen
      )    
      VALUES    
      (    
        @c_taskdetailkey    
       ,@c_TaskType --Tasktype    
       ,@c_Storerkey    
       ,@c_Sku    
       ,@c_UOM -- UOM   
       ,@n_UCCQty  --UOMQty
       ,@n_UCCQty  --Qty   
       ,@n_Qty  --systemqty  
       ,@c_Lot     
       ,@c_fromloc     
       ,@c_ID -- from id    
       ,@c_toloc   
       ,@c_ID -- to id    
       ,@c_SourceType --Sourcetype    
       ,@c_Wavekey --Sourcekey    
       ,'9' -- Priority    
       ,'9' -- Sourcepriority    
       ,'0' -- Status    
       ,@c_FromLoc --Logical from loc    
       ,@c_ToLoc --Logical to loc    
       ,@c_PickMethod  
       ,@c_Wavekey  
       ,@c_Message03   --@c_DestinationType   --WL01  
       ,''  
       ,@c_DestinationType   --@c_Message03   --WL01   
       ,@c_DropID  
       ,@c_Loadkey  
       ,@n_UCCQty - @n_Qty
      )  
        
      SELECT @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN  
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
          GOTO RETURN_SP  
      END     
   END  

   --Update taskdetailkey/wavekey to PICKDETAIL_WIP  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
       SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty  
       WHILE @n_ReplenQty > 0   
       BEGIN                          
         SELECT TOP 1 @c_PickdetailKey = PD.Pickdetailkey, @n_PickQty = Qty  
         FROM WAVEDETAIL (NOLOCK)   
         JOIN #PICKDETAIL_WIP PD (NOLOCK) ON WAVEDETAIL.Orderkey = PD.Orderkey  
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
         AND ISNULL(PD.Taskdetailkey,'') = ''  
         AND PD.Storerkey = @c_Storerkey  
         AND PD.Sku = @c_sku  
         AND PD.Lot = @c_Lot  
         AND PD.Loc = @c_FromLoc  
         AND PD.ID = @c_ID  
         AND PD.UOM = @c_UOM  
         AND PD.DropID = @c_DropID  
         AND PD.Pickdetailkey > @c_pickdetailkey  
         ORDER BY PD.Pickdetailkey  
           
         SELECT @n_cnt = @@ROWCOUNT  
           
         IF @n_cnt = 0  
             BREAK  
           
         IF @n_PickQty <= @n_ReplenQty  
         BEGIN  
            UPDATE #PICKDETAIL_WIP WITH (ROWLOCK)  
            SET Taskdetailkey = @c_TaskdetailKey,  
                TrafficCop = NULL  
            WHERE Pickdetailkey = @c_PickdetailKey  
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81150     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #PICKDETAIL_WIP Table Failed. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
               BREAK  
           END   
           SELECT @n_ReplenQty = @n_ReplenQty - @n_PickQty  
         END  
         ELSE  
         BEGIN  -- pickqty > replenqty     
            SELECT @n_SplitQty = @n_PickQty - @n_ReplenQty  
            EXECUTE nspg_GetKey        
            'PICKDETAILKEY',        
            10,        
            @c_NewPickdetailKey OUTPUT,           
            @b_success OUTPUT,        
            @n_err OUTPUT,        
            @c_errmsg OUTPUT        
            IF NOT @b_success = 1        
            BEGIN  
               SELECT @n_continue = 3        
               BREAK        
            END        
                    
            INSERT #PickDetail_WIP        
                   (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,         
                    Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,         
                    DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,         
                    ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,         
                    WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo)        
            SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,         
                   Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN ('6','7') THEN @n_SplitQty ELSE UOMQty END , @n_SplitQty, QtyMoved, Status,         
                   DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,         
                   ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,         
                   WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo  
            FROM #PickDetail_WIP (NOLOCK)  
            WHERE PickdetailKey = @c_PickdetailKey  
                                 
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0       
            BEGIN       
               SELECT @n_continue = 3        
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81160     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert #PICKDETAIL_WIP Table Failed. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
               BREAK      
            END  
              
            UPDATE #PickDetail_WIP WITH (ROWLOCK)  
            SET Taskdetailkey = @c_TaskdetailKey,  
                Qty = @n_ReplenQty,  
                UOMQTY = CASE WHEN UOM IN('6','7') THEN @n_ReplenQty ELSE UOMQty END,              
                TrafficCop = NULL  
            WHERE Pickdetailkey = @c_PickdetailKey  
            SELECT @n_err = @@ERROR  

            IF @n_err <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81170     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update #PICKDETAIL_WIP Table Failed. (ispRLWAV46)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
               BREAK  
            END  
            SELECT @n_ReplenQty = 0  
         END       
       END -- While Qty > 0  
   END   

   --Return back to calling point  
   IF @c_DestinationType = 'DIRECT'  
      GOTO DIRECT  
   IF @c_DestinationType = 'PTS'  
      GOTO PTS  
   IF @c_DestinationType = 'DPP'
      GOTO DPP
   
END --sp end  

GO