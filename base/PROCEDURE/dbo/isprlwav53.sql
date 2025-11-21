SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispRLWAV53                                         */  
/* Creation Date: 27-May-2022                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-19669 - CN - Columbia B2B Release Wave                  */ 
/*                                                                      */
/* Called By: Wave                                                      */ 
/*                                                                      */
/* GitLab Version: 1.8                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 27-May-2022  WLChooi  1.0  DevOps Combine Script                     */
/* 23-Jun-2022  WLChooi  1.1  WMS-19669 - Skip generate Pickheader(WL01)*/
/* 14-Jul-2022  WLChooi  1.2  WMS-19669 - Cater 1 Lot Multi UCC (WL02)  */
/* 15-Jul-2022  WLChooi  1.3  WMS-19669 - Fix update Pickslipno (WL03)  */
/* 16-Aug-2022  WLChooi  1.4  WMS-19669 - Enhance Logic (WL04)          */
/* 17-Oct-2022  WLChooi  1.5  WMS-19669 - Enhance Logic for CSOS (WL05) */
/* 29-Mar-2023  WLChooi  1.6  WMS-22098 - Add Logic for CSOS (WL06)     */
/* 20-Apr-2023  WLChooi  1.7  WMS-22098 - Modify Logic for CSOS (WL07)  */
/* 06-Jun-2023  WLChooi  1.8  Bug Fix for Batchno reset (WL08)          */
/* 09-Aug-2023  WLChooi  1.9  WMS-23340 - Change PK From Codelkup (WL09)*/
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispRLWAV53]      
       @c_Wavekey      NVARCHAR(10)  
     , @b_Success      INT            OUTPUT  
     , @n_err          INT            OUTPUT  
     , @c_errmsg       NVARCHAR(250)  OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue              INT
         , @b_Debug                 INT
         , @n_StartTranCnt          INT
         , @c_Storerkey             NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_DocType               NVARCHAR(10)
         , @c_OrderGroup            NVARCHAR(20)
         , @c_Orderkey              NVARCHAR(10)
         , @c_ECSingleFlag          NVARCHAR(10)
         , @c_curPickdetailkey      NVARCHAR(10)
         , @c_SourceType            NVARCHAR(20) = 'ispRLWAV53'
         , @c_Priority              NVARCHAR(10) = '9'
         , @c_SourcePriority        NVARCHAR(10) = '9'
         , @c_WaveType              NVARCHAR(20)
         , @c_PickCondition_SQL     NVARCHAR(4000)
         , @c_LinkTaskToPick_SQL    NVARCHAR(4000)
         , @c_ToLoc                 NVARCHAR(20)
         , @c_ToLoc_Strategy        NVARCHAR(30)
         , @c_TaskType              NVARCHAR(10)
         , @c_Message03             NVARCHAR(50)
         , @c_PickMethod            NVARCHAR(10)
         , @c_Sku                   NVARCHAR(20)
         , @c_Lot                   NVARCHAR(10)
         , @c_FromLoc               NVARCHAR(10)
         , @c_ID                    NVARCHAR(18)
         , @c_ToID                  NVARCHAR(18)
         , @n_Qty                   INT
         , @c_UOM                   NVARCHAR(10)
         , @n_UOMQty                INT
         , @c_UCCNo                 NVARCHAR(50)
         , @c_taskdetailkey         NVARCHAR(10)
         , @n_UCCQty                INT
         , @c_Areakey               NVARCHAR(50)
         , @n_CartonNo              INT = 1
         , @c_BatchNo               NVARCHAR(10)
         , @c_KeyName               NVARCHAR(30) = 'CaseShuttleSort'
         , @c_PickdetailKey         NVARCHAR(10)
         , @n_ReplenQty             INT
         , @n_PickQty               INT
         , @n_SplitQty              INT
         , @n_Cnt                   INT
         , @c_NewpickDetailKey      NVARCHAR(10)
         , @n_CSRMaxOrderPerBatch   INT
         , @c_UserName              NVARCHAR(250)
         , @n_PABookingKey          INT
         , @c_CallFrom              NVARCHAR(20)   
         , @c_PrevBatchNo           NVARCHAR(10)   --WL06
         , @n_TotalQty              INT   --WL07
         , @c_GetOrderkey           NVARCHAR(10)   --WL07
         , @n_GetSKUCasecnt         INT   --WL07
         , @c_ResetBatchNo          NVARCHAR(1) = 'N'   --WL08
         , @n_OldCaseCnt            INT   --WL09
         , @n_NewCasecnt            INT   --WL09
   
   DECLARE @n_CurrCnt         INT
         , @c_LocType         NVARCHAR(50)
         , @c_PrevLocType     NVARCHAR(50)
         , @c_SUSR4           NVARCHAR(50)
         , @c_ProductType     NVARCHAR(50)
         , @n_CSOSMaxCarton   INT
         , @n_Casecnt         INT
         , @n_QtyInCtn        INT 
         , @n_CSOSMaxCBM      FLOAT
         , @n_TotalCBM        FLOAT
         , @n_CBM             FLOAT
         , @c_Loc             NVARCHAR(20)
         , @n_packqty         INT
         , @c_SQL             NVARCHAR(MAX)
         , @c_SQLArgument     NVARCHAR(MAX)
         , @c_SQLWhere        NVARCHAR(250)
         , @c_CaseID          NVARCHAR(20)
         , @c_Pickslipno      NVARCHAR(10)
         , @c_PrevOrderkey    NVARCHAR(10)
         , @c_FirstSKU        NVARCHAR(20)
         , @n_RowID           INT

   DECLARE @c_Identifier      NVARCHAR(2),
           @c_Packtype        NVARCHAR(1),
           @c_VAT             NVARCHAR(18),
           @c_nCounter        NVARCHAR(25),
           @c_PackNo_Long     NVARCHAR(250),
           @n_CheckDigit      INT,
           @n_TotalCnt        INT,
           @n_TotalOddCnt     INT,
           @n_TotalEvenCnt    INT,
           @n_Add             INT,
           @n_Divide          INT,
           @n_Remain          INT,
           @n_OddCnt          INT,
           @n_EvenCnt         INT,
           @n_Odd             INT,
           @n_Even            INT,
           @c_LabelNo         NVARCHAR(20)
   
   CREATE TABLE #TMP_CZ (
           RowID              INT NOT NULL IDENTITY(1,1) PRIMARY KEY
         , CartonNo           INT
         , SKU                NVARCHAR(20)
         , SUSR4              NVARCHAR(50)   --WL04
         , LocType            NVARCHAR(10)
         , CaseCnt            INT
         , Qty                INT
         , CBM                FLOAT
         , CtnType            NVARCHAR(10)
         , BatchNo            NVARCHAR(10)
         , OrderKey           NVARCHAR(10)   --WL04
         , PickdetailKey      NVARCHAR(10) NULL   --WL04
         , ProductType        NVARCHAR(50) NULL   --WL04
   )

   CREATE TABLE #TMP_SUSR4 (
           RowID              INT NOT NULL IDENTITY(1,1) PRIMARY KEY
         , SUSR4              NVARCHAR(20)
         , SKU                NVARCHAR(20)
         , Loc                NVARCHAR(20)
         , LocType            NVARCHAR(10)
         , ProductType        NVARCHAR(50)
         , Qty                INT
         , CaseCnt            INT
         , CBM                FLOAT
         , Orderkey           NVARCHAR(10)   --WL04
   )

   --WL05 S
   CREATE TABLE #TMP_CZ_Final (
           RowID              INT NOT NULL IDENTITY(1,1) PRIMARY KEY
         , CartonNo           INT
         , SKU                NVARCHAR(20)
         , SUSR4              NVARCHAR(50)
         , LocType            NVARCHAR(10)
         , CaseCnt            INT
         , Qty                INT
         , CBM                FLOAT
         , CtnType            NVARCHAR(10)
         , BatchNo            NVARCHAR(10)
         , OrderKey           NVARCHAR(10)
         , PickdetailKey      NVARCHAR(10) NULL
   )
   --WL05 E

   --WL06 S
   DECLARE @T_Numbers TABLE (
      RowID           INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
      Dummy           NVARCHAR(1)
   )
   --WL06 E

   DECLARE @T_CtnXCaseCnt AS TABLE (CartonNo INT, Casecnt INT, BatchNo NVARCHAR(10) )   --WL07

   SET @b_Debug = @n_err
   SET @c_UserName = SUSER_SNAME()
   SET @n_PABookingKey = 0
      
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   -----Get Wave Info-----
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN      
      SELECT @c_Storerkey     = MAX(OH.Storerkey)
           , @c_Facility      = MAX(OH.Facility)
           , @c_WaveType      = MAX(W.WaveType)
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN WAVE W (NOLOCK) ON W.WaveKey = WD.WaveKey
      WHERE WD.WaveKey = @c_Wavekey                
   END

   --Validation
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                 WHERE TD.Wavekey = @c_Wavekey  
                 AND TD.Sourcetype = @c_SourceType
                 AND TD.Tasktype IN ('RPF'))   
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 63000    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV53)'         
      END      
      
      --WL05 S
      IF EXISTS (SELECT 1 FROM WAVE (NOLOCK) 
                 WHERE Wavekey = @c_Wavekey
                 AND TMReleaseFlag = 'Y')   
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 63001   
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV53)'         
      END   
      --WL05 3
   END

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN
   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN 
      IF OBJECT_ID('#PickDetail_WIP') IS NOT NULL
      BEGIN 
         DROP TABLE #PickDetail_WIP
      END

      CREATE TABLE #PickDetail_WIP
      (  
         [PickDetailKey]         [NVARCHAR](18)    NOT NULL PRIMARY KEY  
      ,  [CaseID]                [NVARCHAR](20)    NOT NULL DEFAULT (' ')  
      ,  [PickHeaderKey]         [NVARCHAR](18)    NOT NULL  
      ,  [OrderKey]              [NVARCHAR](10)    NOT NULL  
      ,  [OrderLineNumber]       [NVARCHAR](5)     NOT NULL  
      ,  [Lot]                   [NVARCHAR](10)    NOT NULL  
      ,  [Storerkey]             [NVARCHAR](15)    NOT NULL  
      ,  [Sku]                   [NVARCHAR](20)    NOT NULL  
      ,  [AltSku]                [NVARCHAR](20)    NOT NULL    DEFAULT (' ')  
      ,  [UOM]                   [NVARCHAR](10)    NOT NULL    DEFAULT (' ')  
      ,  [UOMQty]                [INT]             NOT NULL    DEFAULT ((0))  
      ,  [Qty]                   [INT]             NOT NULL    DEFAULT ((0))  
      ,  [QtyMoved]              [INT]             NOT NULL    DEFAULT ((0))  
      ,  [Status]                [NVARCHAR](10)    NOT NULL    DEFAULT ('0')  
      ,  [DropID]                [NVARCHAR](20)    NOT NULL    DEFAULT ('')  
      ,  [Loc]                   [NVARCHAR](10)    NOT NULL    DEFAULT ('UNKNOWN')  
      ,  [ID]                    [NVARCHAR](18)    NOT NULL    DEFAULT (' ')  
      ,  [PackKey]               [NVARCHAR](10)    NULL        DEFAULT (' ')  
      ,  [UpdateSource]          [NVARCHAR](10)    NULL        DEFAULT ('0')  
      ,  [CartonGroup]           [NVARCHAR](10)    NULL  
      ,  [CartonType]            [NVARCHAR](10)    NULL  
      ,  [ToLoc]                 [NVARCHAR](10)    NULL        DEFAULT (' ')  
      ,  [DoReplenish]           [NVARCHAR](1)     NULL        DEFAULT ('N')  
      ,  [ReplenishZone]         [NVARCHAR](10)    NULL        DEFAULT (' ')  
      ,  [DoCartonize]           [NVARCHAR](1)     NULL        DEFAULT ('N')  
      ,  [PickMethod]            [NVARCHAR](1)     NOT NULL    DEFAULT (' ')  
      ,  [WaveKey]               [NVARCHAR](10)    NOT NULL    DEFAULT (' ')  
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
            
      CREATE INDEX IDX_PDWIP_Orderkey ON #PickDetail_WIP (OrderKey) 
      CREATE INDEX IDX_PDWIP_SKU ON #PickDetail_WIP (Storerkey, SKU) 
      CREATE INDEX IDX_PDWIP_CaseID ON #PickDetail_WIP (Pickslipno, CaseID) 
   END

   --Initialize Pickdetail work in progress staging table
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      EXEC isp_CreatePickdetail_WIP
          @c_Loadkey               = ''
         ,@c_Wavekey               = @c_Wavekey  
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

   --Remove taskdetailkey and add wavekey from pickdetail of the wave      
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SET @c_curPickdetailkey = '' 
      
      DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT Pickdetailkey  
      FROM WAVEDETAIL WITH (NOLOCK)    
      JOIN #PickDetail_WIP PICKDETAIL WITH (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey  
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey   
  
      OPEN Orders_Pickdet_cur   
      FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey   
      WHILE @@FETCH_STATUS = 0   
      BEGIN   
         UPDATE #PickDetail_WIP WITH (ROWLOCK)   
         SET #PickDetail_WIP.TaskdetailKey   = '', 
             #PickDetail_WIP.Notes           = '',   
             #PickDetail_WIP.Wavekey         = @c_Wavekey,   
             #PickDetail_WIP.EditWho         = SUSER_SNAME(),  
             #PickDetail_WIP.EditDate        = GETDATE(),     
             #PickDetail_WIP.TrafficCop      = NULL,
             #PickDetail_WIP.CaseID          = ''   --WL06
         WHERE #PickDetail_WIP.Pickdetailkey = @c_curPickdetailkey
          
         SELECT @n_err = @@ERROR  

         IF @n_err <> 0   
         BEGIN  
            CLOSE Orders_Pickdet_cur   
            DEALLOCATE Orders_Pickdet_cur                    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END    

         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
      END  
      CLOSE Orders_Pickdet_cur   
      DEALLOCATE Orders_Pickdet_cur  
   END 

   --Main Process
   --UOM 2 -> Packstation
   --UOM 7 -> Pick Loc
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN   
      IF @@TRANCOUNT = 0
         BEGIN TRAN

      DECLARE CUR_Pick CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM
         FROM WAVEDETAIL WD (NOLOCK)  
         JOIN WAVE W (NOLOCK) ON WD.Wavekey = W.Wavekey  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         JOIN #PICKDETAIL_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
         JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku    
         JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc    
         WHERE WD.Wavekey = @c_Wavekey  
         AND PD.Status = '0'  
         AND PD.WIP_RefNo = @c_SourceType  
         AND PD.UOM IN ('2','7')          
         AND (LOC.LOC NOT IN (SELECT DISTINCT CL.Long   
                             FROM CODELKUP CL (NOLOCK)   
                             WHERE CL.LISTNAME = 'CSDEFLOC' AND CL.Storerkey = PD.Storerkey) AND PD.UOM = '2')
         GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM, LOC.LogicalLocation
         ORDER BY PD.UOM, Loc.LogicalLocation, PD.Loc   
         --WL02 E

      OPEN CUR_Pick

      FETCH NEXT FROM CUR_Pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM   --WL02

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_ToLoc = ''
         SET @c_LinkTaskToPick_SQL = 'AND PICKDETAIL.UOM = @c_UOM'
         SET @c_TaskType = 'RPF'
         SET @c_PickMethod = 'PP'
         SET @c_Priority = CASE WHEN @c_UOM = '2' THEN '9' ELSE '8' END
         SET @c_SourcePriority = '9'

         DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT UCC.UCCNo, UCC.Qty
         FROM UCC (NOLOCK)
         WHERE UCC.LOT = @c_Lot
         AND UCC.LOC = @c_FromLoc
         AND UCC.ID = @c_ID
         AND UCC.[Status] = '1'
         ORDER BY UCC.UCCNo

         OPEN CUR_UCC

         FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty

         IF @@FETCH_STATUS = -1
         BEGIN
            SELECT @n_continue = 3  
            SELECT @n_err = 63009    
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)
                             + ': Unable to find UCC for Lot: ' + TRIM(@c_Lot) + ' Loc: ' + TRIM(@c_Loc) + ' ID: ' + TRIM(@c_ID) + '. (ispRLWAV53)'
            GOTO QUIT_SP
         END 

         WHILE @@FETCH_STATUS <> -1 AND @n_Qty > 0
         BEGIN
            IF @c_UOM = '2'
            BEGIN
               SET @c_Message03 = 'PACKSTATION'
            
               SELECT @c_ToLoc = CL.Short
               FROM CODELKUP CL (NOLOCK)
               WHERE CL.LISTNAME = 'TM_TOLOC'
               AND CL.Code = @c_Facility
               AND CL.Storerkey = @c_Storerkey
            
               IF @b_Debug = 99
               BEGIN
                  SET @c_ToLoc = 'STAGE' 
               END
            
               IF ISNULL(@c_ToLoc,'') = ''
               BEGIN
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Packstation not set up. Please check Codelkup. (ispRLWAV53)' 
                                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                  GOTO QUIT_SP 
               END
            
               IF NOT EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_Toloc)
               BEGIN
                  SELECT @n_continue = 3  
                  SELECT @n_err = 63015    
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Loc not found in Loc table. (ispRLWAV53)'         
               END 
            END
            ELSE
            BEGIN
               SET @c_Message03 = 'PICK LOC'
            
               SELECT @c_ToLoc = SL.LOC
               FROM SKUxLOC SL (NOLOCK)
               JOIN LOC L (NOLOCK) ON L.LOC = SL.LOC
               WHERE SL.StorerKey = @c_Storerkey
               AND SL.Sku = @c_SKU
               AND SL.LocationType = 'PICK'
               AND L.Facility = @c_Facility
               
               IF ISNULL(@c_ToLoc,'') = ''
               BEGIN
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pick Loc not found. Please check SKUxLOC. (ispRLWAV53)' 
                                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                  GOTO QUIT_SP 
               END
            END
            
            SET @c_Areakey = ''   --WL03
            
            SELECT @c_Areakey = AD.Areakey
            FROM LOC L (NOLOCK)
            JOIN AreaDetail AD (NOLOCK) ON AD.PutawayZone = L.PutawayZone
            WHERE L.LOC = @c_FromLoc
            
            SELECT @b_success = 1    
            EXECUTE nspg_getkey    
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
                ,[Priority]    
                ,SourcePriority    
                ,[Status]    
                ,LogicalFromLoc    
                ,LogicalToLoc    
                ,PickMethod  
                ,Wavekey    
                ,Areakey  
                ,Message03 
                ,Caseid
                ,PendingMoveIn
                ,QtyReplen
               )    
               VALUES    
               (    
                 @c_taskdetailkey    
                ,@c_TaskType --Tasktype    
                ,@c_Storerkey    
                ,@c_Sku    
                ,@c_UOM -- UOM,    
                ,@n_UCCQty  -- UOMQty,    
                ,@n_UCCQty  --Qty  
                ,CASE WHEN @c_UOM = '2' THEN @n_UCCQty ELSE @n_Qty END  --systemqty  
                ,@c_Lot     
                ,@c_FromLoc     
                ,@c_ID -- from id    
                ,@c_ToLoc   
                ,@c_ID -- to id    
                ,@c_SourceType --Sourcetype    
                ,@c_Wavekey --Sourcekey    
                ,@c_Priority -- Priority    
                ,'9' -- Sourcepriority    
                ,'0' -- Status    
                ,@c_FromLoc --Logical from loc    
                ,@c_ToLoc --Logical to loc    
                ,@c_PickMethod  
                ,@c_Wavekey  
                ,@c_Areakey  
                ,@c_Message03
                ,@c_UCCNo
                ,CASE WHEN @c_UOM = '2' THEN 0 ELSE @n_UCCQty END
                ,CASE WHEN @c_UOM = '2' THEN @n_UCCQty ELSE @n_UCCQty - @n_Qty END
               )  
                 
               SELECT @n_err = @@ERROR    
            
               IF @n_err <> 0    
               BEGIN  
                   SELECT @n_continue = 3    
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                   GOTO QUIT_SP  
               END   
            END  
            
            --Update UCC Status to 3
            UPDATE UCC WITH (ROWLOCK)
            SET [Status] = '3'
            WHERE UCCNo = @c_UCCNo
            
            SELECT @n_err = @@ERROR  
            
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on UCC Failed (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            END
            
            --WL02 
            --UPDATE #PickDetail_WIP
            --SET DropID = @c_UCCNo
            --WHERE Storerkey = @c_Storerkey
            --AND SKU = @c_Sku
            --AND Lot = @c_Lot
            
            --Update taskdetailkey/wavekey to pickdetail  
            IF @n_continue = 1 OR @n_continue = 2  
            BEGIN  
                SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty  
                WHILE @n_ReplenQty > 0   
                BEGIN                          
                  SELECT TOP 1 @c_PickdetailKey = PICKDETAIL.Pickdetailkey, @n_PickQty = Qty  
                  FROM WAVEDETAIL (NOLOCK)   
                  JOIN #PickDetail_WIP PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey  
                  WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
                  AND ISNULL(PICKDETAIL.Taskdetailkey,'') = ''  
                  AND PICKDETAIL.Storerkey = @c_Storerkey  
                  AND PICKDETAIL.Sku = @c_sku  
                  AND PICKDETAIL.Lot = @c_Lot  
                  AND PICKDETAIL.Loc = @c_FromLoc  
                  AND PICKDETAIL.ID = @c_ID  
                  AND PICKDETAIL.UOM = @c_UOM  
                  --AND PICKDETAIL.DropID = @c_UCCNo   --WL02  
                  AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey  
                  ORDER BY PICKDETAIL.Pickdetailkey  
                    
                  SELECT @n_cnt = @@ROWCOUNT  
                    
                  IF @n_cnt = 0  
                      BREAK  
            
                  IF @n_PickQty <= @n_ReplenQty  
                  BEGIN  
                     UPDATE #PickDetail_WIP WITH (ROWLOCK)  
                     SET Taskdetailkey = @c_TaskdetailKey,
                         DropID = @c_UCCNo,   --WL02
                         TrafficCop = NULL  
                     WHERE Pickdetailkey = @c_PickdetailKey  
            
                     SELECT @n_err = @@ERROR  
            
                     IF @n_err <> 0   
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63035     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
                             WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, WIP_RefNo)   --WL02        
                     SELECT @c_NewpickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,         
                            Storerkey, Sku, AltSku, UOM, CASE WHEN UOM IN ('6','7') THEN @n_SplitQty ELSE 1 END , @n_SplitQty, QtyMoved, Status,   --WL02         
                            DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,         
                            ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,         
                            WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, @c_SourceType   --WL02
                     FROM #PickDetail_WIP PDW (NOLOCK)   --WL02  
                     WHERE PickdetailKey = @c_PickdetailKey  
            
                     SELECT @n_err = @@ERROR  
            
                     IF @n_err <> 0       
                     BEGIN       
                        SELECT @n_continue = 3        
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63040     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                        BREAK      
                     END  
                       
                     UPDATE #PickDetail_WIP WITH (ROWLOCK)  
                     SET Taskdetailkey   = @c_TaskdetailKey,  
                         Qty             = @n_ReplenQty,  
                         UOMQTY          = CASE WHEN UOM IN('6','7') THEN @n_ReplenQty ELSE 1 END,   --WL02 
                         DropID          = @c_UCCNo,   --WL02
                         TrafficCop      = NULL  
                     WHERE Pickdetailkey = @c_PickdetailKey  
                     SELECT @n_err = @@ERROR  
            
                     IF @n_err <> 0   
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63045     
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                        BREAK  
                     END  
                     SELECT @n_ReplenQty = 0  
                  END       
                END -- While Qty > 0  
            END
            FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty
         END
         CLOSE CUR_UCC
         DEALLOCATE CUR_UCC
         --WL02 E
         FETCH NEXT FROM CUR_Pick INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM   --WL02
      END  
      CLOSE CUR_Pick
      DEALLOCATE CUR_Pick   
      
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   --WL04 S
   --WL01 S
   --Create Pickslip
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      IF @@TRANCOUNT = 0
         BEGIN TRAN

      EXEC dbo.isp_CreatePickSlip @c_Wavekey = @c_Wavekey,       
                                  @c_PickslipType = N'3',     
                                  @b_Success = @b_Success OUTPUT,
                                  @n_Err = @n_Err OUTPUT,        
                                  @c_ErrMsg = @c_ErrMsg OUTPUT   

      IF @n_err <> 0   
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63050     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': EXEC isp_CreatePickSlip Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         GOTO QUIT_SP
      END 
      
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

      --Update Loadkey, Wavekey to Pickheader
      ;WITH CTE2 AS (SELECT DISTINCT PICKHEADER.PickHeaderKey, ORDERS.LoadKey, PDW.WaveKey
                    FROM PICKHEADER (NOLOCK)
                    JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = PICKHEADER.OrderKey
                    JOIN #PickDetail_WIP PDW (NOLOCK) ON PDW.OrderKey = PICKHEADER.OrderKey)
      UPDATE PICKHEADER
      SET PICKHEADER.ExternOrderKey = CTE2.LoadKey
        , PICKHEADER.WaveKey = CTE2.WaveKey
      FROM CTE2
      WHERE PICKHEADER.PickHeaderKey = CTE2.PickHeaderKey
   END
   --WL01 E
   --WL04 E

   IF @c_WaveType IN ('0') SET @c_WaveType = ''

   SET @n_CurrCnt = 0
   --Precartonize
   IF (@n_continue = 1 or @n_continue = 2) AND ISNULL(@c_WaveType,'') <> ''
   BEGIN
      SELECT @n_CSRMaxOrderPerBatch = CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END
           , @n_CSOSMaxCarton       = CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CAST(CL.UDF01 AS INT) ELSE 0 END
      FROM CODELKUP CL (NOLOCK) 
      WHERE CL.LISTNAME = 'CBPCMAXORD'
      AND CL.Storerkey = @c_Storerkey

      SELECT @n_CSOSMaxCBM = CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CAST(CL.UDF01 AS FLOAT) ELSE 0 END
      FROM CODELIST CL (NOLOCK) 
      WHERE CL.LISTNAME = 'CBPCMAXCBM'

      IF @b_Debug = 99
      BEGIN
         SET @n_CSRMaxOrderPerBatch = 10
         SET @n_CSOSMaxCarton = 2
         SET @n_CSOSMaxCBM = 0.096
      END
      
      --WL04 S
      IF @c_WaveType = 'CSR'
      BEGIN
         IF @n_CSRMaxOrderPerBatch = 0
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 63055   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                          + ': Max Order per Batch not set up for WaveType = CSR. (ispRLWAV53) ( SQLSvr MESSAGE='   
                          + @c_errmsg + ' ) ' 
            GOTO QUIT_SP                     
         END

         SET @c_BatchNo = ''   --WL03
         SET @n_CartonNo = 0   --WL03

         DECLARE CUR_PRECTN_CSR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PDW.OrderKey
         FROM #PickDetail_WIP PDW
         WHERE PDW.UOM IN ('6','7')
         AND PDW.Status = '0'
         AND PDW.WIP_RefNo = @c_SourceType
         ORDER BY PDW.OrderKey
         
         OPEN CUR_PRECTN_CSR

         FETCH NEXT FROM CUR_PRECTN_CSR INTO @c_Orderkey

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_CurrCnt = @n_CurrCnt + 1
            --SET @n_CartonNo = @n_CartonNo + 1   --WL03

            --WL04 S
            IF @n_CurrCnt > @n_CSRMaxOrderPerBatch --OR @n_CartonNo > 99
            BEGIN  
               --SET @n_CartonNo = 1
               SET @n_CurrCnt = 1
               SET @c_BatchNo = ''
            END
            --WL04 E

            IF @c_BatchNo = ''
            BEGIN
               EXECUTE nspg_getkey  
                   @c_KeyName
                 , 9  
                 , @c_BatchNo          OUTPUT  
                 , @b_success          OUTPUT  
                 , @n_err              OUTPUT  
                 , @c_errmsg           OUTPUT  
               
               IF NOT @b_success = 1  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err = 63056   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                  SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                                    + ': Unable to Obtain BatchNo. (ispRLWAV53) ( SQLSvr MESSAGE='   
                                      + @c_errmsg + ' ) ' 
                  GOTO QUIT_SP                     
               END
            END

            UPDATE #PickDetail_WIP
            SET PickSlipNo = 'S' + @c_BatchNo   --WL03
              --, CaseID = RIGHT('00' + CAST(@n_CartonNo AS NVARCHAR(2)), 2)
            WHERE OrderKey = @c_Orderkey AND UOM IN ('6','7')
            
            FETCH NEXT FROM CUR_PRECTN_CSR INTO @c_Orderkey
         END
         CLOSE CUR_PRECTN_CSR
         DEALLOCATE CUR_PRECTN_CSR
      END
      ELSE IF @c_WaveType = 'CSOS'   --Case Shuttle
      BEGIN
         IF @n_CSOSMaxCarton = 0
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 63060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                          + ': Max Carton per Batch not set up for WaveType = CSOS. (ispRLWAV53) ( SQLSvr MESSAGE='   
                          + @c_errmsg + ' ) ' 
            GOTO QUIT_SP                     
         END

         IF @n_CSOSMaxCBM = 0
         BEGIN  
            SET @n_continue = 3  
            SET @n_Err = 63065   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                          + ': Max CBM per carton not set up for WaveType = CSOS. (ispRLWAV53) ( SQLSvr MESSAGE='   
                          + @c_errmsg + ' ) ' 
            GOTO QUIT_SP                     
         END
         SET @c_curPickdetailkey = ''
         SET @n_CartonNo = 1
         SET @c_BatchNo = ''

         --WL07 S
         SELECT @n_Cnt = SUM(Qty)
         FROM #PickDetail_WIP PDW (NOLOCK)
         WHERE PDW.Wavekey = @c_Wavekey
         AND PDW.UOM IN ('6','7')
         AND PDW.[Status] = '0'
         AND PDW.WIP_RefNo = @c_SourceType

         WHILE @n_Cnt > 0
         BEGIN
            INSERT INTO @T_Numbers (Dummy)
            VALUES (NULL -- Dummy - nvarchar(1)
               )
            SET @n_Cnt = @n_Cnt - 1
         END
         --WL07 E

         --For SHOES - START
         --WL06 S
         --UOM 6,7, ALL Loc (Case Shuttle and Pick)
         ;WITH CTE AS (
            SELECT PDW.SKU
                 , '' AS LocType   --WL06
                 , S.SUSR4
                 , ISNULL(C1.Short,'') AS ProductType
                 , PK.CaseCnt
                 , SUM(PDW.Qty) AS Qty
                 , SUM(S.STDCUBE * PDW.Qty) AS CBM
                 , PDW.Loc
                 , PDW.OrderKey
            FROM #PickDetail_WIP PDW
            JOIN SKU S (NOLOCK) ON S.StorerKey = PDW.Storerkey
                               AND S.SKU = PDW.SKU
            LEFT JOIN CODELKUP C1 (NOLOCK) ON C1.LISTNAME = 'CBPRODUCT'
                                          AND C1.Code = S.BUSR2
                                          AND C1.Storerkey = PDW.StorerKey
            CROSS APPLY (SELECT MIN(P.Casecnt) AS Casecnt
                         FROM PACK P (NOLOCK)
                         WHERE P.PackKey = S.PACKKey) PK
            WHERE PDW.UOM IN ('6','7')
            AND C1.Short LIKE '%SHOES%'   --Shoes only
            AND PDW.Status = '0'
            AND PDW.WIP_RefNo = @c_SourceType
            AND PDW.CaseID = ''   --WL07
            GROUP BY PDW.Sku, S.SUSR4
                   , C1.Short
                   , PK.CaseCnt
                   , PDW.Loc
                   , PDW.OrderKey
         )
         INSERT INTO #TMP_SUSR4 (SUSR4, SKU, Loc, LocType, ProductType, CaseCnt, Qty, CBM, Orderkey)
         SELECT CTE.SUSR4, CTE.SKU, CTE.Loc, CTE.LocType, CTE.ProductType, CTE.CaseCnt, CTE.Qty, CTE.CBM, CTE.OrderKey
         FROM CTE
         ORDER BY CTE.LocType
                , CTE.ProductType
                , CTE.OrderKey   --WL07
                , CTE.SUSR4
                , CTE.SKU

         SET @c_BatchNo = ''
         SET @n_CartonNo = 0   --WL06
         SET @c_PrevOrderkey = ''

         --WL09 S
         --Check Casecnt and replace if necessary
         DECLARE CUR_PK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT TS.RowID, C2.Code, CASE WHEN ISNUMERIC(C2.Short) = 1 THEN C2.Short ELSE NULL END
         FROM #TMP_SUSR4 TS
         JOIN CODELKUP C2 (NOLOCK) ON C2.LISTNAME = 'CBPCPKVL'
                                  AND C2.Code = TS.CaseCnt
                                  AND C2.Storerkey = @c_Storerkey
         
         OPEN CUR_PK

         FETCH NEXT FROM CUR_PK INTO @n_RowID, @n_OldCaseCnt, @n_NewCasecnt

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF @n_NewCasecnt IS NULL 
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 63115   -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
               SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                                 + ': Codelkup.Short is not numeric value. (ispRLWAV53) ( SQLSvr MESSAGE='   
                                   + @c_errmsg + ' ) ' 
               GOTO QUIT_SP                     
            END

            IF @n_NewCasecnt > @n_OldCaseCnt
            BEGIN  
               SET @n_continue = 3  
               SET @n_Err = 63120   -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
               SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                                 + ': Codelkup.Short > PK Value. (ispRLWAV53) ( SQLSvr MESSAGE='   
                                   + @c_errmsg + ' ) ' 
               GOTO QUIT_SP                     
            END

            UPDATE #TMP_SUSR4
            SET CaseCnt = @n_NewCasecnt
            WHERE RowID = @n_RowID

            FETCH NEXT FROM CUR_PK INTO @n_RowID, @n_OldCaseCnt, @n_NewCasecnt
         END
         CLOSE CUR_PK
         DEALLOCATE CUR_PK
         --WL09 E

         --WL07 S - Add a big outer cursor, loop by orderkey
         DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PDW.Orderkey
         FROM #PickDetail_WIP PDW
         ORDER BY PDW.Orderkey

         OPEN CUR_ORD
         
         FETCH NEXT FROM CUR_ORD INTO @c_GetOrderkey
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DECLARE CUR_SUSR4 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT TS.SUSR4
            FROM #TMP_SUSR4 TS
            ORDER BY TS.SUSR4

            OPEN CUR_SUSR4
         
            FETCH NEXT FROM CUR_SUSR4 INTO @c_SUSR4
         
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               DECLARE CUR_PRECTN_CSOS_6_7 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               WITH t1 AS
               (
                  SELECT TS.LocType
                       , TS.Orderkey
                       , SUM(TS.Qty) AS QtyRequired
                       , TS.SKU
                       , TS.CaseCnt
                  FROM #TMP_SUSR4 TS
                  WHERE TS.SUSR4 = @c_SUSR4
                  AND TS.Orderkey = @c_GetOrderkey   --WL07
                  GROUP BY TS.LocType, TS.Orderkey, TS.SKU, TS.CaseCnt
               ) 
               , t2 AS ( SELECT ROW_NUMBER() OVER (ORDER BY TN.RowID) AS Val FROM @T_Numbers TN  )
               SELECT t1.LocType, t1.Orderkey, '1' AS Qty, t1.SKU, t1.Casecnt
               FROM t1, t2
               WHERE t1.QtyRequired >= t2.Val 
               ORDER BY t1.LocType, t1.Orderkey, t1.SKU
               OPTION (MAXRECURSION 0)
               --WL07 E

               OPEN CUR_PRECTN_CSOS_6_7
         
               FETCH NEXT FROM CUR_PRECTN_CSOS_6_7 INTO @c_LocType, @c_Orderkey, @n_Qty, @c_SKU, @n_GetSKUCasecnt   --WL07
         
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  --WL07 S
                  --Get Casecnt of current carton
                  IF EXISTS (SELECT 1
                             FROM @T_CtnXCaseCnt TC
                             WHERE TC.BatchNo = @c_BatchNo
                             AND TC.CartonNo = @n_CartonNo)
                  BEGIN
                     SELECT @n_Casecnt = TC.Casecnt
                     FROM @T_CtnXCaseCnt TC
                     WHERE TC.BatchNo = @c_BatchNo
                     AND TC.CartonNo = @n_CartonNo
                  END
                  ELSE
                  BEGIN
                     SET @n_Casecnt = @n_GetSKUCasecnt
                  END
                  --WL07 E

                  IF (@n_CartonNo > @n_CSOSMaxCarton) OR @c_BatchNo = '' OR (@n_TotalQty + @n_Qty > @n_Casecnt) 
                     OR @c_PrevOrderkey <> @c_Orderkey
                  BEGIN
                     IF @c_PrevOrderkey <> @c_Orderkey
                     BEGIN
                        IF @c_BatchNo <> ''
                        BEGIN
                           SET @c_BatchNo = (SELECT MAX(Batchno)
                                             FROM #TMP_CZ TC)
               
                           SELECT @n_CartonNo = MAX(CartonNo) + 1
                           FROM #TMP_CZ TC
                           WHERE BatchNo = @c_BatchNo

                           SET @n_Casecnt = @n_GetSKUCasecnt   --WL07
                        END
                        ELSE
                        BEGIN
                           SET @n_CartonNo = @n_CartonNo + 1
                           SET @n_Casecnt = @n_GetSKUCasecnt   --WL07
                        END
               
                        SET @n_TotalQty = @n_Qty
                     END
                     ELSE IF (@n_TotalQty + @n_Qty > @n_Casecnt) 
                     BEGIN
                        SET @n_TotalQty = 0
                        SET @n_CartonNo = 0
               
                        IF ISNULL(@n_TotalQty,0) = 0 AND ISNULL(@n_CartonNo,0) = 0   --New carton
                        BEGIN
                           SELECT @c_BatchNo = MAX(Batchno)
                           FROM #TMP_CZ TC
               
                           SELECT @n_CartonNo = MAX(CartonNo) + 1
                           FROM #TMP_CZ TC
                           WHERE BatchNo = @c_BatchNo
               
                           SET @n_TotalQty = @n_Qty
                           SET @n_Casecnt = @n_GetSKUCasecnt   --WL07
                        END
                        ELSE
                        BEGIN
                           SET @n_TotalQty = @n_TotalQty + @n_Qty
                        END
                     END
                  
                     --WL06 S
                     IF @c_BatchNo = ''
                     BEGIN
                        SET @c_BatchNo = IIF(ISNULL(@c_PrevBatchNo,'') = '','',@c_PrevBatchNo)
                     END
                     --WL06 E
               
                     IF (@n_CartonNo > @n_CSOSMaxCarton) OR @c_BatchNo = ''
                     BEGIN  
                        SET @c_BatchNo = ''
               
                        EXECUTE nspg_getkey  
                            @c_KeyName
                          , 9  
                          , @c_BatchNo          OUTPUT  
                          , @b_success          OUTPUT  
                          , @n_err              OUTPUT  
                          , @c_errmsg           OUTPUT  
                  
                        IF NOT @b_success = 1  
                        BEGIN  
                           SET @n_continue = 3  
                           SET @n_Err = 63085   -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                           SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                                             + ': Unable to Obtain BatchNo. (ispRLWAV53) ( SQLSvr MESSAGE='   
                                               + @c_errmsg + ' ) ' 
                           GOTO QUIT_SP                     
                        END
               
                        SET @c_BatchNo = 'S' + @c_BatchNo
                     END
               
                     IF (@n_CartonNo > @n_CSOSMaxCarton)
                     BEGIN
                        SET @n_CartonNo = 1
                        SET @n_TotalQty = @n_Qty
                        SET @n_Casecnt = @n_GetSKUCasecnt   --WL07
                     END
                  END
                  ELSE
                  BEGIN
                     SET @n_TotalQty = @n_TotalQty + @n_Qty
                  END

                  INSERT INTO #TMP_CZ (CartonNo, SKU, SUSR4, LocType, CaseCnt, Qty, CBM, CtnType, BatchNo, OrderKey, ProductType)
                  SELECT @n_CartonNo, @c_SKU, @c_SUSR4, @c_LocType, @n_Casecnt, @n_Qty, 0, 'SHOES', @c_BatchNo, @c_Orderkey, 'SHOES'   --WL07

                  SET @c_PrevOrderkey = @c_Orderkey

                  --WL07 S
                  IF NOT EXISTS (SELECT 1 FROM @T_CtnXCaseCnt TCXCC WHERE TCXCC.CartonNo = @n_CartonNo AND TCXCC.Casecnt = @n_Casecnt AND TCXCC.BatchNo = @c_BatchNo)
                  BEGIN
                     INSERT INTO @T_CtnXCaseCnt (CartonNo, Casecnt, BatchNo)
                     VALUES (@n_CartonNo -- CartonNo - int
                           , @n_Casecnt -- Casecnt - int
                           , @c_BatchNo -- BatchNo - nvarchar(10)
                        )
                  END
                  --WL07 E

                  FETCH NEXT FROM CUR_PRECTN_CSOS_6_7 INTO @c_LocType, @c_Orderkey, @n_Qty, @c_SKU, @n_GetSKUCasecnt   --WL07
               END
               CLOSE CUR_PRECTN_CSOS_6_7
               DEALLOCATE CUR_PRECTN_CSOS_6_7
            
               FETCH NEXT FROM CUR_SUSR4 INTO @c_SUSR4
            END
            CLOSE CUR_SUSR4
            DEALLOCATE CUR_SUSR4

            --SET @c_CallFrom = 'SHOES'   --WL07
            --GOTO UPD_PD
            --SHOES:   --WL07

            --WL06 E
            --For SHOES - END

            --For CLOTH - START
            SET @n_TotalCBM = 0.00
            --SET @n_CartonNo = 0   --WL06
            SET @c_CallFrom = 'CLOTH'   --WL07
            --SET @c_PrevBatchNo = @c_BatchNo   --WL06   --WL08
            --SET @c_BatchNo = ''   --WL08
            SET @c_ResetBatchNo = 'Y'   --WL08
            SET @c_Orderkey = ''
            SET @c_PrevOrderkey = ''
            SET @c_PrevLocType = ''

            --WL05 S
            DECLARE CUR_PRECTN_CSOS_LOOSE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            WITH t1 AS ( SELECT PDW.OrderKey, PDW.SKU, SUM(PDW.Qty) AS Qty, S.STDCUBE AS CBM
                              , '' AS LocType   --WL06
                              , ISNULL(C1.Short,'') AS ProductType, S.SUSR4
                         FROM #PickDetail_WIP PDW WITH (NOLOCK)
                         JOIN SKU S WITH (NOLOCK) ON PDW.SKU = S.SKU AND PDW.Storerkey = S.StorerKey
                         LEFT JOIN CODELKUP C1 (NOLOCK) ON C1.LISTNAME = 'CBPRODUCT'
                                                       AND C1.Code = S.BUSR2
                                                       AND C1.Storerkey = S.StorerKey
                         WHERE PDW.Wavekey = @c_Wavekey
                         AND PDW.UOM IN ('6','7')
                         AND PDW.[Status] = '0'
                         AND PDW.CaseID = ''   --WL07
                         AND ISNULL(C1.Short,'') LIKE '%CLOTH%'   --CLOTH only   --WL07
                         AND PDW.OrderKey = @c_GetOrderkey   --WL07
                         AND PDW.WIP_RefNo = @c_SourceType
                         GROUP BY PDW.SKU, PDW.OrderKey, PDW.PickDetailKey, S.STDCUBE
                                , ISNULL(C1.Short,'')
                                , S.SUSR4
            ),
               t2 AS ( SELECT ROW_NUMBER() OVER (ORDER BY TN.RowID) AS Val FROM @T_Numbers TN  )   --WL06
            SELECT t1.OrderKey, t1.SKU, '1' AS Qty, t1.CBM, '', t1.LocType, t1.ProductType
            FROM t1, t2
            WHERE t1.Qty >= t2.Val 
            ORDER BY t1.OrderKey, t1.LocType, t1.ProductType, t1.SUSR4, t1.SKU
            OPTION (MAXRECURSION 0)

            OPEN CUR_PRECTN_CSOS_LOOSE
         
            FETCH NEXT FROM CUR_PRECTN_CSOS_LOOSE INTO @c_Orderkey, @c_Sku, @n_Qty, @n_CBM, @c_PickdetailKey, @c_LocType, @c_ProductType
         
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               --WL08 S
               IF @c_ResetBatchNo = 'Y'
               BEGIN
                  SET @c_PrevBatchNo = @c_BatchNo
                  SET @c_BatchNo = ''
                  SET @c_ResetBatchNo = 'N'
               END
               --WL08 E

               --WL07 S
               --IF CHARINDEX('_', @c_ProductType) > 0
               --   SET @c_ProductType = SUBSTRING(@c_ProductType, CHARINDEX('_', @c_ProductType) + 1, LEN(@c_ProductType))

               --IF ISNULL(@c_ProductType,'') NOT IN ('SHOES','CLOTH') AND ISNULL(@c_ProductType,'') <> ''
               --BEGIN
               --   SET @n_continue = 3  
               --   SET @n_Err = 63070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               --   SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
               --                 + ': Product Type NOT IN (SHOES, CLOTH) for SKU ' + TRIM(@c_SKU) + '. (ispRLWAV53) ( SQLSvr MESSAGE='   
               --                 + @c_errmsg + ' ) ' 
               --   GOTO QUIT_SP 
               --END
            
               --IF ISNULL(@c_ProductType,'') = ''
               --BEGIN
               --   SET @n_continue = 3  
               --   SET @n_Err = 63075   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               --   SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
               --                     + ': Missing Product Type for SKU ' + TRIM(@c_SKU) + '. (ispRLWAV53) ( SQLSvr MESSAGE='   
               --                     + @c_errmsg + ' ) ' 
               --   GOTO QUIT_SP 
               --END
               --WL07 E

               IF (@n_CartonNo > @n_CSOSMaxCarton) OR @c_BatchNo = '' OR (@n_TotalCBM + @n_CBM > @n_CSOSMaxCBM) 
                  OR @c_PrevOrderkey <> @c_Orderkey OR @c_PrevLocType <> @c_LocType
               BEGIN
                  IF @c_PrevOrderkey <> @c_Orderkey OR @c_PrevLocType <> @c_LocType
                  BEGIN
                     IF @c_BatchNo <> ''
                     BEGIN
                        SET @c_BatchNo = (SELECT MAX(Batchno)
                                          FROM #TMP_CZ TC)

                        SELECT @n_CartonNo = MAX(CartonNo) + 1
                        FROM #TMP_CZ TC
                        WHERE BatchNo = @c_BatchNo
                     END
                     ELSE
                     BEGIN
                        SET @n_CartonNo = @n_CartonNo + 1
                     END

                     SET @n_TotalCBM = @n_CBM
                  END
                  ELSE IF (@n_TotalCBM + @n_CBM > @n_CSOSMaxCBM) 
                  BEGIN
                     SET @n_TotalCBM = 0
                     SET @n_CartonNo = 0

                     IF ISNULL(@n_TotalCBM,0) = 0 AND ISNULL(@n_CartonNo,0) = 0   --New carton
                     BEGIN
                        SELECT @c_BatchNo = MAX(Batchno)
                        FROM #TMP_CZ TC

                        SELECT @n_CartonNo = MAX(CartonNo) + 1
                        FROM #TMP_CZ TC
                        WHERE BatchNo = @c_BatchNo

                        SET @n_TotalCBM = @n_CBM
                     END
                     ELSE
                     BEGIN
                        SET @n_TotalCBM = @n_TotalCBM + @n_CBM
                     END
                  END
               
                  --WL06 S
                  IF @c_BatchNo = ''
                  BEGIN
                     SET @c_BatchNo = IIF(ISNULL(@c_PrevBatchNo,'') = '','',@c_PrevBatchNo)
                  END
                  --WL06 E

                  IF (@n_CartonNo > @n_CSOSMaxCarton) OR @c_BatchNo = ''
                  BEGIN  
                     SET @c_BatchNo = ''

                     EXECUTE nspg_getkey  
                         @c_KeyName
                       , 9  
                       , @c_BatchNo          OUTPUT  
                       , @b_success          OUTPUT  
                       , @n_err              OUTPUT  
                       , @c_errmsg           OUTPUT  
               
                     IF NOT @b_success = 1  
                     BEGIN  
                        SET @n_continue = 3  
                        SET @n_Err = 63085   -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                        SET @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err)   
                                          + ': Unable to Obtain BatchNo. (ispRLWAV53) ( SQLSvr MESSAGE='   
                                            + @c_errmsg + ' ) ' 
                        GOTO QUIT_SP                     
                     END

                     SET @c_BatchNo = 'S' + @c_BatchNo
                  END

                  IF (@n_CartonNo > @n_CSOSMaxCarton)
                  BEGIN
                     SET @n_CartonNo = 1
                     SET @n_TotalCBM = @n_CBM
                  END
               END
               ELSE
               BEGIN
                  SET @n_TotalCBM = @n_TotalCBM + @n_CBM
               END

               INSERT INTO #TMP_CZ (CartonNo, SKU, SUSR4, LocType, CaseCnt, Qty, CBM, CtnType, BatchNo, OrderKey, PickdetailKey, ProductType)
               SELECT @n_CartonNo, @c_Sku, '', @c_LocType, 0, @n_Qty, @n_CBM, 'CLOTH', @c_BatchNo, @c_Orderkey, @c_PickdetailKey, 'CLOTH'   --WL07

               SET @c_PrevOrderkey = @c_Orderkey
               SET @c_PrevLocType = @c_LocType

               FETCH NEXT FROM CUR_PRECTN_CSOS_LOOSE INTO @c_Orderkey, @c_Sku, @n_Qty, @n_CBM, @c_PickdetailKey, @c_LocType, @c_ProductType
            END
            CLOSE CUR_PRECTN_CSOS_LOOSE
            DEALLOCATE CUR_PRECTN_CSOS_LOOSE
            --For CLOTH - END

            FETCH NEXT FROM CUR_ORD INTO @c_GetOrderkey
         END
         CLOSE CUR_ORD
         DEALLOCATE CUR_ORD
         --WL07 E - Add a big outer cursor, loop by orderkey

         --Debug
         IF @b_Debug IN (2,99)
         BEGIN
            SELECT PACK.CASECNT, TC.* FROM #TMP_CZ TC
            JOIN SKU (NOLOCK) ON SKU.Sku = TC.SKU AND SKU.StorerKey = @c_Storerkey
            JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
            ORDER BY TC.RowID
         END

         --Update CaseID to Pickdetail / Split Pickdetail
         UPD_PD:
         IF (@n_Continue = 1 or @n_Continue = 2)
         BEGIN
            DECLARE CUR_UPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TC.CartonNo, TC.SKU, TC.SUSR4, SUM(TC.Qty), TC.BatchNo, TC.OrderKey, ''
            FROM #TMP_CZ TC
            GROUP BY TC.CartonNo, TC.SKU, TC.SUSR4, TC.BatchNo, TC.OrderKey
            ORDER BY TC.OrderKey, TC.CartonNo   --WL07
         
            OPEN CUR_UPD
         
            FETCH NEXT FROM CUR_UPD INTO @n_CartonNo, @c_SKU, @c_SUSR4, @n_packqty, @c_BatchNo, @c_Orderkey, @c_curPickdetailkey
         
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @c_pickdetailkey = '' 

               WHILE @n_packqty > 0  
               BEGIN
                  SET @n_cnt = 0  

                  SET @c_SQLWhere = 'AND PICKDETAIL.CaseID = '''' '

                  SET @c_SQL = N'SELECT TOP 1 @n_cnt = 1 '
                            +  '            , @n_pickqty = PICKDETAIL.Qty '
                            +  '            , @c_pickdetailkey = PICKDETAIL.Pickdetailkey '
                            +  'FROM #PickDetail_WIP Pickdetail WITH (NOLOCK) '
                            +  'JOIN ORDERS WITH (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey '
                            +  'JOIN WAVEDETAIL WITH (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey '   
                            +  'JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = PICKDETAIL.Storerkey AND SKU.SKU = PICKDETAIL.SKU '
                            +  'WHERE WAVEDETAIL.WaveKey = @c_wavekey '
                            +  'AND PICKDETAIL.Sku = CASE WHEN ISNULL(@c_SKU,'''') = '''' THEN PICKDETAIL.Sku ELSE @c_SKU END '
                            +  'AND SKU.SUSR4 = CASE WHEN ISNULL(@c_SUSR4,'''') = '''' THEN SKU.SUSR4 ELSE @c_SUSR4 END '
                            +  'AND PICKDETAIL.Pickdetailkey = CASE WHEN ISNULL(@c_curPickdetailkey,'''') = '''' THEN PICKDETAIL.Pickdetailkey ELSE @c_curPickdetailkey END '
                            +  'AND PICKDETAIL.storerkey = @c_storerkey '
                            +  'AND PICKDETAIL.Orderkey = @c_Orderkey '
                            +  'AND PICKDETAIL.UOM IN (''6'',''7'') '
                            +  @c_SQLWhere
                            --+  'AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey   '
                            +  'ORDER BY SKU.SUSR4, SKU.SKU '   --WL07

                 SET @c_SQLArgument = N' @n_cnt              INT            OUTPUT'  
                                    +  ',@n_pickqty          INT            OUTPUT'  
                                    +  ',@c_PickDetailKey    NVARCHAR(10)   OUTPUT'  
                                    +  ',@c_wavekey          NVARCHAR(10)'    
                                    +  ',@c_StorerKey        NVARCHAR(15)' 
                                    +  ',@c_SKU              NVARCHAR(20)'
                                    +  ',@c_SUSR4            NVARCHAR(50)'
                                    +  ',@c_Orderkey         NVARCHAR(10)'
                                    +  ',@c_curPickdetailkey NVARCHAR(10)'
                
                 EXEC sp_executesql @c_SQL  
                                 ,  @c_SQLArgument  
                                 ,  @n_Cnt            OUTPUT  
                                 ,  @n_pickqty        OUTPUT   
                                 ,  @c_PickDetailKey  OUTPUT  
                                 ,  @c_wavekey       
                                 ,  @c_StorerKey  
                                 ,  @c_SKU      
                                 ,  @c_SUSR4
                                 ,  @c_Orderkey
                                 ,  @c_curPickdetailkey

                  IF @n_cnt = 0  
                     BREAK
                  
                  IF @n_pickqty <= @n_packqty  
                  BEGIN  
                     UPDATE #PickDetail_WIP WITH (ROWLOCK)  
                     SET CaseID = RIGHT('000' + CAST(@n_CartonNo AS NVARCHAR), 3) 
                       , PickSlipNo = @c_BatchNo
                       , TrafficCop = NULL  
                       , EditWho = SUSER_SNAME()
                       , EditDate = GETDATE()
                     WHERE Pickdetailkey = @c_pickdetailkey  
                     SELECT @n_err = @@ERROR  
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63090  
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                        BREAK  
                     END  
                     SELECT @n_packqty = @n_packqty - @n_pickqty  
                  END  
                  ELSE  
                  BEGIN  -- pickqty > packqty  
                     SELECT @n_splitqty = @n_pickqty - @n_packqty  
                     EXECUTE nspg_GetKey  
                     'PICKDETAILKEY',  
                     10,  
                     @c_newpickdetailkey OUTPUT,  
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
                      WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Channel_ID,
                      TaskDetailKey, Notes, WIP_Refno
                     )  
                     SELECT @c_newpickdetailkey  
                          , ''  
                          , PickHeaderKey, OrderKey, OrderLineNumber, Lot
                          , Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status  
                          , ''                             
                          , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType
                          , ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod 
                          , WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Channel_ID
                          , TaskDetailKey, Notes, @c_SourceType
                     FROM #PickDetail_WIP (NOLOCK)  
                     WHERE PickdetailKey = @c_pickdetailkey  
               
                     SELECT @n_err = @@ERROR  
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63095  
                        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                        BREAK  
                     END  
               
                     UPDATE #PickDetail_WIP WITH (ROWLOCK)  
                     SET CaseID = RIGHT('000' + CAST(@n_CartonNo AS NVARCHAR), 3) 
                       , PickSlipNo = @c_BatchNo
                       , Qty = @n_packqty  
                       , UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END   
                       , TrafficCop = NULL  
                       , EditWho = SUSER_SNAME()
                       , EditDate = GETDATE()
                      WHERE Pickdetailkey = @c_pickdetailkey  
         
                      SELECT @n_err = @@ERROR  
         
                      IF @n_err <> 0  
                      BEGIN  
                         SELECT @n_continue = 3  
                         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63100  
                         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                         BREAK  
                      END  
               
                     SELECT @n_packqty = 0  
                  END  
               END -- While packqty > 0
               NEXT_LOOP_UPD:
               FETCH NEXT FROM CUR_UPD INTO @n_CartonNo, @c_SKU, @c_SUSR4, @n_packqty, @c_BatchNo, @c_Orderkey, @c_curPickdetailkey
            END
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            /*
            --WL07 S
            --WL06 S
            IF @c_CallFrom = 'SHOES'
            BEGIN
               DELETE FROM #TMP_CZ WHERE CtnType = 'SHOES'
               GOTO SHOES
            END
            --WL06 E
            --WL07 E*/
         END

         GEN_LABELNO:   --WL04 E
         IF (@n_Continue = 1 or @n_Continue = 2)
         BEGIN
            DECLARE CUR_LABELNO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PDW.PickSlipNo AS BatchNo
                          , PDW.CaseID
            FROM #PickDetail_WIP PDW
            WHERE PDW.UOM IN ('2','6','7') AND PDW.CaseID NOT IN ('')   --WL01
            ORDER BY PDW.PickSlipNo, PDW.CaseID
            
            OPEN CUR_LABELNO
            
            FETCH NEXT FROM CUR_LABELNO INTO @c_BatchNo, @c_CaseID
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
               --Copy from isp_GenUCCLabelNo_Std
               IF EXISTS ( SELECT 1 FROM StorerConfig WITH (NOLOCK)
                           WHERE StorerKey = @c_StorerKey
                           AND ConfigKey = 'GenUCCLabelNoConfig'
                           AND SValue = '1')
               BEGIN
                  SET @c_Identifier = '00'
                  SET @c_Packtype = '0'  
                  SET @c_LabelNo = ''
               
                  SELECT @c_VAT = ISNULL(Vat,'')
                  FROM Storer WITH (NOLOCK)
                  WHERE Storerkey = @c_StorerKey
            
                  IF ISNULL(@c_VAT,'') = ''
                     SET @c_VAT = '000000000'
               
                  IF LEN(@c_VAT) <> 9 
                     SET @c_VAT = RIGHT('000000000' + RTRIM(LTRIM(@c_VAT)), 9)
               
                  IF ISNUMERIC(@c_VAT) = 0 
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 63105
                     SET @c_errmsg = 'NSQL ' + CONVERT(NCHAR(5),@n_Err) + ': Vat is not a numeric value. (ispRLWAV53)'
                     GOTO QUIT_SP
                  END 
               
                  SELECT @c_PackNo_Long = Long 
                  FROM  CODELKUP (NOLOCK)
                  WHERE ListName = 'PACKNO'
                  AND Code = @c_StorerKey
                 
                  IF ISNULL(@c_PackNo_Long,'') = ''
                     SET @c_Keyname = 'TBLPackNo'
                  ELSE
                     SET @c_Keyname = 'PackNo' + LTRIM(RTRIM(@c_PackNo_Long))
                      
                  EXECUTE nspg_getkey
                     @c_Keyname ,
                     7,
                     @c_nCounter     OUTPUT ,
                     @b_success      = @b_success OUTPUT,
                     @n_err          = @n_err OUTPUT,
                     @c_errmsg       = @c_errmsg OUTPUT,
                     @b_resultset    = 0,
                     @n_batch        = 1
                     
                  SET @c_LabelNo = @c_Identifier + @c_Packtype + RTRIM(@c_VAT) + RTRIM(@c_nCounter) --+ @n_CheckDigit
               
                  SET @n_Odd = 1
                  SET @n_OddCnt = 0
                  SET @n_TotalOddCnt = 0
                  SET @n_TotalCnt = 0
               
                  WHILE @n_Odd <= 20 
                  BEGIN
                     SET @n_OddCnt = CAST(SUBSTRING(@c_LabelNo, @n_Odd, 1) AS INT)
                     SET @n_TotalOddCnt = @n_TotalOddCnt + @n_OddCnt
                     SET @n_Odd = @n_Odd + 2
                  END
               
                  SET @n_TotalCnt = (@n_TotalOddCnt * 3) 
               
                  SET @n_Even = 2
                  SET @n_EvenCnt = 0
                  SET @n_TotalEvenCnt = 0
               
                  WHILE @n_Even <= 20 
                  BEGIN
                     SET @n_EvenCnt = CAST(SUBSTRING(@c_LabelNo, @n_Even, 1) AS INT)
                     SET @n_TotalEvenCnt = @n_TotalEvenCnt + @n_EvenCnt
                     SET @n_Even = @n_Even + 2
                  END
               
                  SET @n_Add = 0
                  SET @n_Remain = 0
                  SET @n_CheckDigit = 0
               
                  SET @n_Add = @n_TotalCnt + @n_TotalEvenCnt
                  SET @n_Remain = @n_Add % 10
                  SET @n_CheckDigit = 10 - @n_Remain
               
                  IF @n_CheckDigit = 10 
                     SET @n_CheckDigit = 0
               
                  SET @c_LabelNo = ISNULL(RTRIM(@c_LabelNo), '') + CAST(@n_CheckDigit AS NVARCHAR( 1))
               END   -- GenUCCLabelNoConfig
               ELSE
               BEGIN
                  EXECUTE nspg_GetKey
                     'PACKNO', 
                     10 ,
                     @c_LabelNo  OUTPUT,
                     @b_success  OUTPUT,
                     @n_err      OUTPUT,
                     @c_errmsg   OUTPUT
               END
            
               UPDATE #PickDetail_WIP
               SET Notes = @c_LabelNo
               WHERE CaseID = @c_CaseID
               AND Pickslipno = @c_BatchNo
            
               FETCH NEXT FROM CUR_LABELNO INTO @c_BatchNo, @c_CaseID
            END
            CLOSE CUR_LABELNO
            DEALLOCATE CUR_LABELNO
            
            --WL04 S
            --UOM 2 Case Shuttle Loc - Generate Packheader and Packdetail
            IF @n_Continue IN (1,2)
            BEGIN
               DECLARE CUR_GENPACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PH.PickHeaderKey, PDW.OrderKey, PDW.Notes AS LabelNo, PDW.SKU, SUM(PDW.Qty)
               FROM #PickDetail_WIP PDW
               JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'CSDEFLOC' 
                                        AND CL.Storerkey = PDW.Storerkey 
                                        AND CL.Code = @c_Facility
                                        AND CL.Long = PDW.Loc
               JOIN PICKHEADER PH (NOLOCK) ON PH.OrderKey = PDW.OrderKey
               WHERE PDW.UOM = '2'
               AND PDW.WaveKey = @c_Wavekey
               AND PDW.WIP_RefNo = @c_SourceType
               AND NOT EXISTS (SELECT 1 FROM PACKHEADER PHDR (NOLOCK) WHERE PHDR.PickSlipNo = PH.PickHeaderKey)
               GROUP BY PH.PickHeaderKey, PDW.OrderKey, PDW.Notes, PDW.SKU
               
               OPEN CUR_GENPACK
               
               FETCH NEXT FROM CUR_GENPACK INTO @c_Pickslipno, @c_Orderkey, @c_LabelNo, @c_SKU, @n_Qty
               
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
                  BEGIN
                     INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey
                                           , StorerKey, PickSlipNo, CartonGroup)      
                     SELECT O.[Route], O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey
                          , O.Storerkey, @c_Pickslipno, ST.CartonGroup    
                     FROM PICKHEADER PH (NOLOCK)      
                     JOIN ORDERS O (NOLOCK) ON (PH.Orderkey = O.Orderkey)      
                     JOIN STORER ST (NOLOCK) ON (ST.StorerKey = O.StorerKey)
                     WHERE PH.PickHeaderKey = @c_Pickslipno
            
                     SELECT @n_err = @@ERROR  
            
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63108   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Packheader Failed (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                        GOTO QUIT_SP
                     END  
                  END
            
                  IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
                  BEGIN
                     INSERT INTO PACKDETAIL (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)  
                     VALUES (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_StorerKey, @c_SKU,  
                             @n_Qty, SUSER_SNAME(), GETDATE(), SUSER_SNAME(), GETDATE())
            
                     SELECT @n_err = @@ERROR  
            
                     IF @n_err <> 0  
                     BEGIN  
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63109   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                        SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Generate Packdetail Failed (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
                        GOTO QUIT_SP
                     END  
                  END
            
                  FETCH NEXT FROM CUR_GENPACK INTO @c_Pickslipno, @c_Orderkey, @c_LabelNo, @c_SKU, @n_Qty
               END
               CLOSE CUR_GENPACK
               DEALLOCATE CUR_GENPACK
            END
            --WL04 E
         END
      END
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

   IF @b_Debug IN (1,99)
   BEGIN
      SELECT *
      FROM #TMP_CZ
      ORDER BY BatchNo, CartonNo
   END

   -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE WITH (ROWLOCK)
      SET TMReleaseFlag = 'Y'        
       ,  TrafficCop = NULL      
       ,  EditWho = SUSER_SNAME()
       ,  EditDate= GETDATE()    
      WHERE WAVEKEY = @c_wavekey  

      SELECT @n_err = @@ERROR  

      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV53)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END 

   QUIT_SP:

   IF @n_continue = 1 or @n_continue = 2 
   BEGIN
      -----Delete pickdetail_WIP work in progress staging table
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

   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP') IS NOT NULL
       DROP TABLE #PICKDETAIL_WIP

   IF OBJECT_ID('tempdb..#TMP_CZ') IS NOT NULL
       DROP TABLE #TMP_CZ

   IF OBJECT_ID('tempdb..#TMP_SUSR4') IS NOT NULL
       DROP TABLE #TMP_SUSR4

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_Pick')) >=0 
   BEGIN
      CLOSE CUR_Pick           
      DEALLOCATE CUR_Pick      
   END  

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PRECTN_CSR')) >=0 
   BEGIN
      CLOSE CUR_PRECTN_CSR           
      DEALLOCATE CUR_PRECTN_CSR     
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PRECTN_CSOS_2')) >=0 
   BEGIN
      CLOSE CUR_PRECTN_CSOS_2           
      DEALLOCATE CUR_PRECTN_CSOS_2      
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PRECTN_CSOS_6_7')) >=0 
   BEGIN
      CLOSE CUR_PRECTN_CSOS_6_7         
      DEALLOCATE CUR_PRECTN_CSOS_6_7      
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PRECTN_CSOS_LOOSE')) >=0 
   BEGIN
      CLOSE CUR_PRECTN_CSOS_LOOSE  
      DEALLOCATE CUR_PRECTN_CSOS_LOOSE      
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_UPD')) >=0 
   BEGIN
      CLOSE CUR_UPD   
      DEALLOCATE CUR_UPD      
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_LABELNO')) >=0 
   BEGIN
      CLOSE CUR_LABELNO   
      DEALLOCATE CUR_LABELNO    
   END 

   IF (SELECT CURSOR_STATUS('LOCAL','CUR_GENPACK')) >=0 
   BEGIN
      CLOSE CUR_GENPACK   
      DEALLOCATE CUR_GENPACK    
   END 

   --WL07 S
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_ORD')) >=0 
   BEGIN
      CLOSE CUR_ORD   
      DEALLOCATE CUR_ORD    
   END 
   --WL07 E

   --WL09 S
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PK')) >=0 
   BEGIN
      CLOSE CUR_PK   
      DEALLOCATE CUR_PK    
   END 
   --WL09 E

   WHILE @@TRANCOUNT < @n_StartTranCnt
      BEGIN TRAN

   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV53'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO