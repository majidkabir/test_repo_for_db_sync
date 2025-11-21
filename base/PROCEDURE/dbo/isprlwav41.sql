SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: ispRLWAV41                                          */    
/* Creation Date: 08-Apr-2021                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-16622 - [CN] Mannings_WMS_ReleaseWave_CR                 */    
/*                                                                       */    
/* Called By: Wave                                                       */    
/*                                                                       */    
/* GitLab Version: 1.0                                                   */    
/*                                                                       */    
/* Version: 5.4                                                          */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/*************************************************************************/     

CREATE PROCEDURE [dbo].[ispRLWAV41]        
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
     
   DECLARE        @n_continue int,      
                  @n_starttcnt int,         -- Holds the current transaction count    
                  @n_debug int,  
                  @n_cnt int  
                    
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0  
   SELECT @n_debug = 0 
 
   DECLARE  @c_DispatchPiecePickMethod NVARCHAR(10)  
           ,@c_Userdefine03 NVARCHAR(20)  
           ,@c_ShipTo       NVARCHAR(45)  --NJOW04  
           ,@c_OmniaOrderNo NVARCHAR(20)  
           ,@c_DeviceId NVARCHAR(20)  
           ,@c_IPAddress NVARCHAR(40)  
           ,@c_PortNo NVARCHAR(5)  
           ,@c_DevicePosition NVARCHAR(10)  
           ,@c_PTSLOC NVARCHAR(10)  
           ,@c_PTSStatus NVARCHAR(10)  
           ,@c_InLoc NVARCHAR(10)  
           ,@c_DropId NVARCHAR(20)              
           ,@c_Storerkey NVARCHAR(15)  
           ,@c_Sku NVARCHAR(20)  
           ,@c_Lot NVARCHAR(10)  
           ,@c_FromLoc NVARCHAR(10)  
           ,@c_ID NVARCHAR(18)  
           ,@n_Qty INT  
           ,@c_PickMethod NVARCHAR(10)  
           ,@c_Toloc NVARCHAR(10)  
           ,@c_Taskdetailkey NVARCHAR(10)    
           ,@n_UCCQty INT  
           ,@c_Style NVARCHAR(20)  
           ,@c_Facility NVARCHAR(5)  
           ,@c_NextDynPickLoc NVARCHAR(10)  
           ,@c_UOM NVARCHAR(10)  
           ,@c_DestinationType NVARCHAR(30)  
           ,@c_SameStyleLoc NVARCHAR(10)  
           ,@c_SameStyleLogicalLoc NVARCHAR(30)  
           ,@c_SourceType NVARCHAR(30)  
           ,@c_Pickdetailkey NVARCHAR(18)  
           ,@c_NewPickdetailKey NVARCHAR(18)  
           ,@n_Pickqty INT  
           ,@n_ReplenQty INT  
           ,@n_SplitQty  INT  
           ,@c_Message03 NVARCHAR(20)  
           ,@c_TaskType NVARCHAR(10)   
           ,@c_Orderkey NVARCHAR(10)  
           ,@c_Pickslipno NVARCHAR(10)  
           ,@c_Loadkey NVARCHAR(10)  
           ,@c_InductionLoc NVARCHAR(20)       
           ,@c_PTLWavekey NVARCHAR(10)  
           ,@c_PTLLoadkey NVARCHAR(10)      
           ,@c_LoadlineNumber NVARCHAR(5)   
           ,@c_Loctype NVARCHAR(10)  
           ,@c_curPickdetailkey NVARCHAR(10)  
           ,@c_Lottable01 NVARCHAR(18)  
           ,@n_UCCToFit INT  
           ,@n_UCCCnt INT            
           ,@dt_Lottable05 DATETIME  
           ,@c_UserDefine02 NVARCHAR(18)
           ,@c_Sourcekey NVARCHAR(10)
           ,@c_trmlogkey NVARCHAR(10)
           ,@c_DocType NVARCHAR(1)
           ,@c_ECOMSingleFlag NVARCHAR(1)
           ,@n_TLogGenerated INT = 0
           ,@c_Userdefine04 NVARCHAR(10)
           ,@c_PrevSourcekey NVARCHAR(10) = ''
           ,@c_DPCount NVARCHAR(10) = ''
           ,@c_FirstDP NVARCHAR(20) = ''
           ,@c_PrevDP   NVARCHAR(20) = ''
           ,@c_SourcekeyCNT INT = 0
  
   DECLARE @cur_PICKSKU CURSOR,   
           @c_SortMode NVARCHAR(10)  

   DECLARE @c_Lottable02  NVARCHAR(18)
         , @c_Lottable03  NVARCHAR(18)
         , @dt_Lottable04 DATETIME
             
   -----Check which strategy to use based on DispatchPiecePickMethood
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT TOP 1 @c_Userdefine02 = WAVE.UserDefine02,   
                   @c_Userdefine03 = WAVE.UserDefine03,   
                   @c_Facility = ORDERS.Facility,  
                   @c_DispatchPiecePickMethod = WAVE.DispatchPiecePickMethod,  
                   @c_Storerkey = ORDERS.Storerkey,
                   @c_Userdefine04 = WAVE.UserDefine04
      FROM WAVE (NOLOCK)  
      JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey  
      JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey          
      WHERE WAVE.Wavekey = @c_Wavekey  
                          
      IF @n_debug=1  
         SELECT '@c_Userdefine02', @c_Userdefine02, '@c_Userdefine03', @c_Userdefine03, '@c_DispatchPiecePickMethod', @c_DispatchPiecePickMethod                     
   END  
   -----Wave Validation-----  
   IF @n_continue=1 or @n_continue=2    
   BEGIN    
      IF ISNULL(@c_wavekey,'') = ''    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 81010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV41)'    
      END    
   END      
   
   --Validate DispatchPiecePickMethood
   IF @n_continue=1 or @n_continue=2    
   BEGIN            
      IF ISNULL(@c_DispatchPiecePickMethod,'') NOT IN ('MANB2B','MANB2C')
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Wave.DispatchPiecePickMethod (ispRLWAV41)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END                  
   END  
   
   --Validate Userdefine02 and Userdefine03 for B2B
   IF (@n_continue=1 or @n_continue=2) AND @c_DispatchPiecePickMethod IN ('MANB2B')
   BEGIN            
      IF (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '')
      BEGIN           
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must key-in location range at userdefine02 & 03 for B2B (ispRLWAV41)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END                  
   END  
              
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                 WHERE TD.Wavekey = @c_Wavekey  
                 AND TD.Sourcetype IN('ispRLWAV41-B2B')
                 AND TD.Tasktype IN ('RPF'))   
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81040    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV41)'         
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave have started picking (ispRLWAV41)'           
      END                   
   END 
   
   --Create Temporary Tables for MANB2C 
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('MANB2C')
   BEGIN  
      --Current wave assigned dynamic pick location    
      CREATE TABLE #DYNPICK_LOCASSIGNED (
          Rowref       INT          NOT NULL IDENTITY(1, 1) PRIMARY KEY
        , STORERKEY    NVARCHAR(15) NULL
        , SKU          NVARCHAR(20) NULL
        , TOLOC        NVARCHAR(10) NULL
        , Lottable02   NVARCHAR(18) NULL
        , Lottable03   NVARCHAR(18) NULL
        , Lottable04   DATETIME     NULL
        , LocationType NVARCHAR(10) NULL
        , UCCToFit     INT          DEFAULT(0)
       )

      CREATE INDEX IDX_TOLOC ON #DYNPICK_LOCASSIGNED (TOLOC)      
       
      CREATE TABLE #DYNPICK_TASK (Rowref int not NULL identity(1,1) Primary Key  
                                 ,TOLOC NVARCHAR(10) NULL)      
  
      CREATE TABLE #DYNPICK_NON_EMPTY (Rowref int not NULL identity(1,1) Primary Key  
                                      ,LOC NVARCHAR(10) NULL)    
                                                           
      CREATE TABLE #DYNLOC (Rowref int not NULL identity(1,1) Primary KEY
                           ,Loc NVARCHAR(10) NULL
                           ,logicallocation NVARCHAR(18) NULL
                           ,MaxPallet INT NULL)
      CREATE INDEX IDX_DLOC ON #DYNLOC (LOC)   
                             
      CREATE TABLE #EXCLUDELOC (Rowref int not NULL identity(1,1) Primary Key  
                               ,LOC NVARCHAR(10) NULL)
      CREATE INDEX IDX_LOC ON #EXCLUDELOC (LOC)                         
   END 

   -----Generate MANB2C Temporary Ref Data-----  
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('MANB2C')
   BEGIN                  
      INSERT INTO #DYNLOC (Loc, LogicalLocation)
      SELECT Loc, LogicalLocation             
      FROM LOC (NOLOCK)
      WHERE Facility = @c_Facility 
      AND LocationType = 'DYNPPICK'
      AND LocationCategory = 'SHELVING' 
             
      --location have pending Replenishment tasks  
      INSERT INTO #DYNPICK_TASK (TOLOC)  
      SELECT TD.TOLOC  
      FROM   TASKDETAIL TD (NOLOCK)  
      JOIN   LOC L (NOLOCK) ON  TD.TOLOC = L.LOC  
      WHERE  L.LocationType IN('DYNPPICK')
      AND    L.LocationCategory IN ('SHELVING')   
      AND    L.Facility = @c_Facility  
      AND    TD.Status = '0'        
      AND    TD.Tasktype IN('RPF','RP1','RPT')  
      --AND    TD.Tasktype IN('RPF')  
      GROUP BY TD.TOLOC  
      HAVING SUM(TD.Qty) > 0  
                  
      --Dynamic pick loc have qty and pending move in  
      INSERT INTO #DYNPICK_NON_EMPTY (LOC)  
      SELECT LLI.LOC  
      FROM   LOTXLOCXID LLI (NOLOCK)  
      JOIN   LOC L (NOLOCK) ON LLI.LOC = L.LOC  
      WHERE  L.LocationType IN ('DYNPPICK')   
      AND    L.Facility = @c_Facility  
      GROUP BY LLI.LOC  
      HAVING SUM(LLI.Qty + LLI.PendingMoveIN) > 0
        
      INSERT INTO #EXCLUDELOC (Loc)
      SELECT E.LOC
      FROM   #DYNPICK_NON_EMPTY E 
      UNION ALL 
      SELECT ReplenLoc.TOLOC
      FROM   #DYNPICK_TASK  ReplenLoc          
   END  
   
   --BEGIN TRAN  

   --Remove taskdetailkey and add wavekey from pickdetail of the wave      
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SET @c_curPickdetailkey = ''  
      DECLARE Orders_Pickdet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT Pickdetailkey  
      FROM WAVEDETAIL WITH (NOLOCK)    
      JOIN PICKDETAIL WITH (NOLOCK)  ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey  
      WHERE WAVEDETAIL.Wavekey = @c_Wavekey   
  
      OPEN Orders_Pickdet_cur   
      FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey   
      WHILE @@FETCH_STATUS = 0   
      BEGIN   
         UPDATE PICKDETAIL WITH (ROWLOCK)   
         SET PICKDETAIL.TaskdetailKey = '',  
             PICKDETAIL.Wavekey = @c_Wavekey,   
             EditWho    = SUSER_SNAME(),  
             EditDate   = GETDATE(),     
             TrafficCop = NULL  
         WHERE PICKDETAIL.Pickdetailkey = @c_curPickdetailkey
           
         SELECT @n_err = @@ERROR  

         IF @n_err <> 0   
         BEGIN  
            CLOSE Orders_Pickdet_cur   
            DEALLOCATE Orders_Pickdet_cur                    
            SELECT @n_continue = 3    
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV41)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END    

         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
      END  
      CLOSE Orders_Pickdet_cur   
      DEALLOCATE Orders_Pickdet_cur  
   END 

   CREATE TABLE #TMP_PTS(
      Sourcekey      NVARCHAR(10)  NULL,
      LOC            NVARCHAR(50)  NULL
   )

   --Generate PTS (Only for MANB2B)
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('MANB2B')
      BEGIN
         DECLARE cur_UCCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT O.LoadKey  
         FROM WAVEDETAIL WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
         WHERE WD.Wavekey = @c_Wavekey AND PD.UOM <> '2'  
         GROUP BY O.LoadKey   
         ORDER BY O.LoadKey  
        
         OPEN cur_UCCDetail    
         FETCH NEXT FROM cur_UCCDetail INTO @c_Sourcekey  
        
         WHILE @@FETCH_STATUS = 0    
         BEGIN                        
            SELECT @c_DeviceId = '', @c_IPAddress = '', @c_PortNo = '', @c_DevicePosition = '', @c_PTSLOC = '', @c_PTSStatus = '', @c_InLoc = ''  
      
            IF @b_debug = 1
               SELECT @c_Sourcekey AS Sourcekey 
      
            SELECT TOP 1 @c_DeviceId = DP.DeviceID,   
                         @c_IPAddress = DP.IPAddress,   
                         @c_PortNo = DP.PortNo,   
                         @c_DevicePosition = DP.DevicePosition,   
                         @c_PTSLOC = LOC.Loc,  
                         @c_PTSStatus = CASE WHEN ISNULL(PTL.Sourcekey,'') <> '' THEN 'OLD' ELSE 'NEW' END,  
                         @c_InLoc = PZ.InLoc,  
                         @c_PTLWavekey = ISNULL(PTL.Wavekey,''),  
                         @c_PTLLoadkey = ISNULL(PTL.Loadkey,'')  
            FROM LOC (NOLOCK)   
            JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc   
            JOIN PUTAWAYZONE PZ (NOLOCK) ON LOC.Putawayzone = PZ.Putawayzone  
            LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc   
            WHERE LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03                    
            AND LOC.LocationCategory = 'PTS'  
            AND LOC.Facility = @c_Facility                                      
            AND (PTL.RowRef IS NULL   
                 OR (PTL.Loadkey = @c_Sourcekey)
                 )  
            --AND DP.DevicePosition >= @c_DPCount
            ORDER BY LOC.LogicalLocation, LOC.Loc, DP.DevicePosition 
      
            IF ISNULL(@c_PTSLOC,'')=''  
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAV41)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               GOTO RETURN_SP  
            END   
              
            IF @c_PTSStatus = 'NEW' OR @c_Wavekey <> @c_PTLWavekey --no PTL booking or similar booking but by different wave  
            BEGIN  
               INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, ShipTo, Loadkey, Sourcekey)  
               VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, '', @c_Sourcekey, @c_Wavekey)   
             
               SELECT @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RDT.rdtPTLStationLog Failed. (ispRLWAV41)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                  GOTO RETURN_SP  
               END     
            END  

            SELECT @c_ToLoc = @c_InLoc  
            SELECT @c_PrevSourcekey = @c_Sourcekey
            SELECT @c_PrevDP = @c_DevicePosition

            IF NOT EXISTS(SELECT 1 FROM #TMP_PTS WHERE SourceKey = @c_Sourcekey)
            BEGIN
               INSERT INTO #TMP_PTS
               SELECT @c_Sourcekey, @c_ToLoc
            END
      
            FETCH NEXT FROM cur_UCCDetail INTO @c_Sourcekey  
         END  
         CLOSE cur_UCCDetail    
         DEALLOCATE cur_UCCDetail
      END 
   END

   --select * FROM #TMP_PTS 
   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('MANB2B','MANB2C')
   BEGIN 
      SELECT @c_DocType = MAX(OH.DocType)
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = WD.Orderkey
      WHERE WD.WaveKey = @c_Wavekey

      DECLARE cur_PICKUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, PD.DropID,  
             CASE WHEN MIN(PD.PickMethod) = 'P' THEN 'FP'                            
                  ELSE 'PP' END AS PickMethod,  
             ISNULL(UCC.Qty,0) AS UCCQty,  
             CASE WHEN LOC.LocationType = 'DYNPPICK' AND LOC.LocationCategory = 'SHELVING' THEN 'DPP'
                  WHEN LOC.LocationType = 'PICK' AND LOC.LocationCategory = 'AGV' THEN 'AGV' 
                  ELSE 'BULK' END,
             '',   -- O.Loadkey
             CASE WHEN @c_DispatchPiecePickMethod = 'MANB2C' THEN ISNULL(LA.Lottable02,'') ELSE '' END,           --WL01
             CASE WHEN @c_DispatchPiecePickMethod = 'MANB2C' THEN ISNULL(LA.Lottable03,'') ELSE '' END,           --WL01
             CASE WHEN @c_DispatchPiecePickMethod = 'MANB2C' THEN ISNULL(LA.Lottable04,'19000101') ELSE NULL END  --WL01
      FROM WAVEDETAIL WD (NOLOCK)  
      JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey  
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot  
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
      JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
      JOIN SKUXLOC (NOLOCK) ON PD.Storerkey = SKUXLOC.Storerkey AND PD.Sku = SKUXLOC.Sku AND PD.Loc = SKUXLOC.Loc  
      LEFT JOIN UCC (NOLOCK) ON PD.DropId = UCC.UccNo  
      WHERE WD.Wavekey = @c_Wavekey
      GROUP BY PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, PD.UOM,
               PD.DropID, ISNULL(UCC.Qty,0),  
               CASE WHEN LOC.LocationType = 'DYNPPICK' AND LOC.LocationCategory = 'SHELVING' THEN 'DPP'
                    WHEN LOC.LocationType = 'PICK' AND LOC.LocationCategory = 'AGV' THEN 'AGV' 
                    ELSE 'BULK' END,   -- O.Loadkey  
               CASE WHEN @c_DispatchPiecePickMethod = 'MANB2C' THEN ISNULL(LA.Lottable02,'') ELSE '' END,           --WL01
               CASE WHEN @c_DispatchPiecePickMethod = 'MANB2C' THEN ISNULL(LA.Lottable03,'') ELSE '' END,           --WL01
               CASE WHEN @c_DispatchPiecePickMethod = 'MANB2C' THEN ISNULL(LA.Lottable04,'19000101') ELSE NULL END  --WL01
      ORDER BY PD.Storerkey, PD.UOM, PD.Sku, PD.Lot

      OPEN cur_PICKUCC    
      FETCH NEXT FROM cur_PICKUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_DropID, 
                                       @c_PickMethod, @n_UCCQty, @c_LocType, @c_Loadkey,
                                       @c_Lottable02, @c_Lottable03, @dt_Lottable04
         
      IF @c_DispatchPiecePickMethod = 'MANB2B'
      BEGIN
         SELECT @c_SourceType = 'ispRLWAV41-B2B'
      END
      ELSE IF @c_DispatchPiecePickMethod = 'MANB2C'  
      BEGIN
         SELECT @c_SourceType = 'ispRLWAV41-B2C' 
      END
            
      SELECT @c_TaskType = 'RPF'  
      SELECT @c_ToLoc = ''  
      SELECT @c_Message03 = ''  
         
      WHILE @@FETCH_STATUS = 0    
      BEGIN             
         IF @c_DispatchPiecePickMethod = 'MANB2B'
         BEGIN
            IF @c_uom = '2'  
            BEGIN  
                SELECT @c_DestinationType = 'DIRECT'  
            END  
            ELSE  -- uom 6 & 7  
            BEGIN                   
                SELECT @c_DestinationType = 'PTS'                             
            END
         END
         ELSE IF @c_DispatchPiecePickMethod = 'MANB2C'  
         BEGIN
            IF @c_uom = '2'  
            BEGIN  
                SELECT @c_DestinationType = 'DIRECT'  
            END  
            ELSE IF @c_uom = '6'
            BEGIN                   
                SELECT @c_DestinationType = 'DP'                             
            END
            ELSE   --UOM 7
            BEGIN                   
                SELECT @c_DestinationType = 'DPP'                             
            END
         END

         --SELECT @c_Message03 = @c_DestinationType  
           
         IF @b_debug=1  
            SELECT '@c_FromLoc', @c_FromLoc, '@c_ID', @c_ID, '@n_Qty', @n_qty, '@c_UOM', @c_UOM, '@c_Lot', @c_Lot, '@n_UCCQty', @n_UCCQty,  
                   '@c_PickMethod', @c_PickMethod, '@c_DropID', @c_DropID, 
                   '@c_DestinationType', @c_DestinationType, '@c_DispatchPiecePickMethod', @c_DispatchPiecePickMethod, '@c_Loadkey', @c_Loadkey
                                                  
         IF @c_DestinationType = 'DIRECT' --Full carton for a load  
         BEGIN  
            SELECT @c_InductionLoc = ISNULL(CL.Short,'')
            FROM CODELKUP CL (NOLOCK) 
            WHERE CL.Storerkey = @c_Storerkey AND CL.Listname = 'MANZONE' 
            AND CL.Code = (SELECT TOP 1 LOC.Putawayzone FROM LOC (NOLOCK) WHERE LOC = @c_FromLoc)
            AND Code2 = @c_DispatchPiecePickMethod
         
            SELECT @c_ToLoc = @c_InductionLoc  
             
            GOTO INSERT_TASKS  
            DIRECT:  
         END --DIRECT  

         IF @c_DestinationType = 'DP'
         BEGIN  
            SELECT @c_NextDynPickLoc = ''  
            SELECT @n_UCCToFit = 0  
            SELECT @n_UCCCnt = 0  
                                
            -- Assign loc with same sku qty already assigned in current replenishment  
            IF ISNULL(@c_NextDynPickLoc,'') = ''  
            BEGIN  
                SELECT TOP 1 @c_NextDynPickLoc = DL.ToLoc,  
                             @n_UCCToFit = DL.UCCToFit  
                FROM #DYNPICK_LOCASSIGNED DL  
                WHERE DL.Storerkey = @c_Storerkey  
                AND DL.Sku = @c_Sku  
                AND DL.Lottable02 = @c_Lottable02  
                AND DL.Lottable03 = @c_Lottable03
                AND DL.Lottable04 = @dt_Lottable04
                AND DL.LocationType = 'DP'  
                AND DL.UCCToFit > 0  
                ORDER BY DL.ToLoc                       
            END                  
                        
             -- Assign loc with same sku already assigned in other replenishment not yet start  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN                                 
                SELECT TOP 1 @c_NextDynPickLoc = L.LOC,   
                             @n_UCCToFit = L.Maxpallet - COUNT(DISTINCT TD.CaseID)  
                FROM TASKDETAIL TD (NOLOCK)  
                JOIN LOTATTRIBUTE LA (NOLOCK) ON TD.Lot = LA.Lot  
                JOIN LOC L (NOLOCK) ON TD.TOLOC = L.LOC                      
                WHERE L.LocationType IN ('DYNPICKP')   
                AND L.LocationCategory IN ('SHELVING')  
                AND L.Facility = @c_Facility  
                AND TD.Status = '0'  
                AND TD.Qty > 0   
                AND TD.Tasktype = 'RPF'   
                AND LA.Lottable02 = @c_Lottable02  
                AND LA.Lottable03 = @c_Lottable03
                AND LA.Lottable04 = @dt_Lottable04                
                --AND TD.Sourcetype = 'ispRLWAV05-TRA'  
                AND TD.Storerkey = @c_Storerkey  
                AND TD.Sku = @c_Sku  
                GROUP BY L.LogicalLocation, L.Loc, L.Maxpallet  
                HAVING COUNT(DISTINCT TD.CaseID) < L.Maxpallet  
                ORDER BY L.LogicalLocation, L.Loc  
                  
                SELECT @n_UCCCnt = CEILING(SUM(LLI.Qty) / (@n_UCCQty * 1.00))  
                FROM LOTXLOCXID LLI (NOLOCK)  
                WHERE LLI.Storerkey = @c_Storerkey  
                AND LLI.Sku = @c_Sku  
                AND LLI.Loc = @c_NextDynPickLoc  
                  
                IF @n_UCCCnt > 0  
                BEGIN  
                  SELECT @n_UCCToFit = @n_UCCToFit - @n_UCCCnt  
                END  
                  
                IF @n_UCCToFit <= 0   
                   SELECT @c_NextDynPickLoc = ''                          
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
                ORDER BY L.LogicalLocation, L.Loc  
            END
              
            -- Assign loc with same sku and qty available / pending move in  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN                
                SELECT TOP 1 @c_NextDynPickLoc = L.LOC,  
                             @n_UCCToFit = L.Maxpallet - CEILING(SUM(LLI.Qty + LLI.PendingMoveIN) / (@n_UCCQty * 1.00))  
                FROM LOTXLOCXID LLI (NOLOCK)  
                JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
                JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
                WHERE L.LocationType IN('DYNPICKP')  
                AND L.LocationCategory IN ('SHELVING')  
                AND   L.Facility = @c_Facility  
                AND  (LLI.Qty + LLI.PendingMoveIN) > 0
                AND LA.Lottable02 = @c_Lottable02 
                AND LA.Lottable03 = @c_Lottable03
                AND LA.Lottable04 = @dt_Lottable04
                --AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0   
                AND  LLI.Storerkey = @c_Storerkey  
                AND  LLI.Sku = @c_Sku  
                GROUP BY L.LogicalLocation, L.Loc, L.MaxPallet  
                HAVING CEILING(SUM(LLI.Qty + LLI.PendingMoveIN) / (@n_UCCQty * 1.00)) < L.MaxPallet  
                ORDER BY L.LogicalLocation, L.Loc  
            END  
              
            -- Assign empty loc that near to same style  
            /*  --NJOW03 Removed  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN    
                                                           
               SET @c_SameStyleLoc = ''   
               SET @c_SameStyleLogicalLoc = ''   
                SELECT @c_SameStyleLoc = ISNULL(MAX(LLI.LOC),''),  
                       @c_SameStyleLogicalLoc = ISNULL(MAX(L.LogicalLocation),'')  
                FROM LOTXLOCXID LLI (NOLOCK)  
                JOIN LOC L (NOLOCK) ON  LLI.LOC = L.LOC  
                JOIN SKU S (NOLOCK) ON  LLI.Storerkey = S.Storerkey AND LLI.Sku = S.Sku  
                WHERE L.LocationType IN ('DYNPPICK')  
                AND L.LocationCategory IN ('SHELVING')  
                AND  ((LLI.Qty + LLI.PendingMoveIN) - LLI.QtyPicked) > 0   
                AND  LLI.Storerkey = @c_Storerkey  
                AND  S.Style = @c_Style                      
            
                SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
                FROM   LOC L (NOLOCK)   
                WHERE  L.LocationType IN ('DYNPPICK')   
                AND    L.LocationCategory IN ('SHELVING')  
                AND    L.Facility = @c_Facility  
                AND    ((L.LOC >= @c_SameStyleLoc AND ISNULL(@c_SameStyleLogicalLoc,'') = '')  
                     OR (L.LogicalLocation >= @c_SameStyleLogicalLoc AND ISNULL(@c_SameStyleLogicalLoc,'') <> ''))  
                AND    NOT EXISTS(  
                           SELECT 1  
                           FROM   #DYNPICK_NON_EMPTY E  
                           WHERE  E.LOC = L.LOC  
                       ) AND  
                       NOT EXISTS(  
                           SELECT 1  
                           FROM   #DYNPICK_TASK AS ReplenLoc  
                           WHERE  ReplenLoc.TOLOC = L.LOC  
                       ) AND  
                       NOT EXISTS(  
                           SELECT 1  
                           FROM   #DYNPICK_LOCASSIGNED AS DynPick  
                           WHERE  DynPick.ToLoc = L.LOC  
                       )   
                ORDER BY L.LogicalLocation, L.Loc                      
            END  
            */  
                              
            -- If no location with same sku sytle found, then assign the empty location  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN  
               SELECT TOP 1 @c_NextDynPickLoc = L.LOC,  
                            @n_UCCToFit = L.MaxPallet  
               FROM   #DYNLOC L (NOLOCK) 
               LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.Loc
               LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
               WHERE EL.Loc IS NULL
               AND DynPick.Toloc IS NULL
               ORDER BY L.LogicalLocation, L.Loc
            
                --FROM   LOC L (NOLOCK)   
                --WHERE  L.LocationType = 'DYNPICKP'         --IN ('DYNPPICK')   
                --AND    L.LocationCategory = 'SHELVING'     --IN ('SHELVING')  
                --AND    L.Facility = @c_Facility  
                --AND    NOT EXISTS ( SELECT 1 FROM (  
                --       SELECT E.LOC  
                --       FROM   #DYNPICK_NON_EMPTY E   
                --       UNION ALL SELECT ReplenLoc.TOLOC  
                --       FROM   #DYNPICK_TASK  ReplenLoc   
                --       UNION ALL SELECT DynPick.ToLoc  
                --       FROM  #DYNPICK_LOCASSIGNED  DynPick   
                -- )  AS A WHERE A.Loc = L.LOC )  
                -- ORDER BY L.LogicalLocation, L.Loc  
                --AND    NOT EXISTS(  
                --           SELECT 1  
                --           FROM   #DYNPICK_NON_EMPTY E  
                --           WHERE  E.LOC = L.LOC  
                --       ) AND  
                --       NOT EXISTS(  
                --           SELECT 1  
                --           FROM   #DYNPICK_TASK AS ReplenLoc  
                --           WHERE  ReplenLoc.TOLOC = L.LOC  
                --       ) AND  
                --       NOT EXISTS(  
                --           SELECT 1  
                --           FROM   #DYNPICK_LOCASSIGNED AS DynPick  
                --           WHERE  DynPick.ToLoc = L.LOC  
                --       )  
                --ORDER BY L.LogicalLocation, L.Loc  
            END  
              
            IF @n_debug = 1  
               SELECT 'DP', '@c_NextDynPickLoc', @c_NextDynPickLoc  
              
            -- Terminate. Can't find any dynamic location  
            --TERMINATE:  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN  
                SELECT @n_continue = 3    
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81095   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick(DP) Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                GOTO RETURN_SP  
            END   
            
            SELECT @c_ToLoc = @c_NextDynPickLoc  
              
            SELECT @n_UCCToFit = @n_UCCToFit - 1  
                                       
            --Insert current location assigned                  
            IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED   
                           WHERE Storerkey = @c_Storerkey  
                           AND Sku = @c_Sku  
                           AND ToLoc = @c_ToLoc  
                           AND Lottable02 = @c_Lottable02
                           AND Lottable03 = @c_Lottable03
                           AND Lottable04 = @dt_Lottable04)  
            BEGIN  
               INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable02, Lottable03, Lottable04, LocationType, UCCToFit)  
               VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @c_Lottable02, @c_Lottable03, @dt_Lottable04, 'DP', @n_UCCToFit)  
            END  
            ELSE  
            BEGIN  
               UPDATE #DYNPICK_LOCASSIGNED   
               SET UCCToFit = @n_UCCToFit  
               WHERE Storerkey = @c_Storerkey  
               AND Sku = @c_Sku  
               AND ToLoc = @c_ToLoc  
               AND LocationType = 'DP'  
               AND Lottable02 = @c_Lottable02 
               AND Lottable03 = @c_Lottable03 
               AND Lottable04 = @dt_Lottable04 
            END  
            
            GOTO INSERT_TASKS  
            DP:              
         END --DP   

         IF @c_DestinationType = 'DPP'  
         BEGIN
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
               ORDER BY L.LogicalLocation, L.Loc  
            END  
            
            --Assign loc with same sku already assigned in other replenishment but in transit  
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
               ORDER BY L.LogicalLocation, L.Loc  
            END                                   
                                        
            -- If no location with same Lottable02+03+04 found, then assign the empty location  
            IF ISNULL(@c_NextDynPickLoc,'') = ''  
            BEGIN  
               SELECT TOP 1 @c_NextDynPickLoc = L.LOC  
               FROM   #DYNLOC L (NOLOCK) 
               LEFT JOIN #EXCLUDELOC EL ON L.Loc = EL.Loc
               LEFT JOIN #DYNPICK_LOCASSIGNED DynPick ON L.Loc = DynPick.TOLOC
               WHERE EL.Loc IS NULL
               AND DynPick.Toloc IS NULL
               ORDER BY L.LogicalLocation, L.Loc
            END  
              
            IF @n_debug = 1  
               SELECT 'DPP', '@c_NextDynPickLoc', @c_NextDynPickLoc  
              
            -- Terminate. Can't find any dynamic location  
TERMINATE:  
            IF ISNULL(@c_NextDynPickLoc,'')=''  
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Dynamic Pick Location Not Setup / Not enough Dynamic Pick Location. (ispRLWAV41)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               GOTO RETURN_SP  
            END   
            
            SELECT @c_ToLoc = @c_NextDynPickLoc  
                                           
            --Insert current location assigned  
            IF NOT EXISTS (SELECT 1 FROM #DYNPICK_LOCASSIGNED   
                           WHERE Storerkey = @c_Storerkey  
                           AND Sku = @c_Sku  
                           AND ToLoc = @c_ToLoc  
                           AND Lottable02 = @c_Lottable02  
                           AND Lottable03 = @c_Lottable03
                           AND Lottable04 = @dt_Lottable04 )
            BEGIN  
               INSERT INTO #DYNPICK_LOCASSIGNED (Storerkey, Sku, ToLoc, Lottable02, Lottable03, Lottable04, LocationType)    
               VALUES (@c_Storerkey, @c_Sku, @c_Toloc, @c_Lottable02, @c_Lottable03, @dt_Lottable04, 'DPP')  
            END  
            
            IF @c_LocType = 'BULK'  
            BEGIN  
               GOTO INSERT_TASKS  
               DPP:              
            END  
         END
                            
         IF @c_DestinationType = 'PTS'
         BEGIN
            DECLARE cur_UCCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT O.LoadKey  
            FROM WAVEDETAIL WD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
            JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = PD.OrderKey 
                                        AND OD.OrderLineNumber = PD.OrderLineNumber 
                                        AND OD.SKU = PD.SKU
            WHERE WD.Wavekey = @c_Wavekey  
            AND PD.DropID = @c_DropID  
            AND PD.Storerkey = @c_Storerkey  
            AND PD.Sku = @c_Sku  
            AND PD.Loc = @c_FromLoc  
            AND PD.ID = @c_ID  
            AND PD.Lot = @c_Lot  
            GROUP BY O.LoadKey   
              
            OPEN cur_UCCDetail    
            FETCH NEXT FROM cur_UCCDetail INTO @c_Sourcekey  
              
            WHILE @@FETCH_STATUS = 0    
            BEGIN     
               SELECT @c_ToLoc = MAX(t.LOC)
               FROM #TMP_PTS t
               WHERE t.Sourcekey = @c_Sourcekey

              FETCH NEXT FROM cur_UCCDetail INTO @c_Sourcekey  
            END  
            CLOSE cur_UCCDetail    
            DEALLOCATE cur_UCCDetail                                     

            IF @c_LocType = 'BULK'  
            BEGIN  
               GOTO INSERT_TASKS  
               PTS:              
            END  
         END --PTS           
           
      PICKUCC_NEXT_REC:  
          --END --While qtyremain  
      FETCH NEXT FROM cur_PICKUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_DropID, 
                                       @c_PickMethod, @n_UCCQty, @c_LocType, @c_Loadkey,
                                       @c_Lottable02, @c_Lottable03, @dt_Lottable04
      END --Fetch  
   CLOSE cur_PICKUCC    
   DEALLOCATE cur_PICKUCC                                     
   END      

   -----Generate Conso Pickslip and Auto Scan In (Only B2B)-------  
   IF (@n_continue = 1 or @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('MANB2B')
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

   -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      /*UPDATE WAVE 
      SET STATUS = '1' -- Released  
      WHERE WAVEKEY = @c_wavekey  */

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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV33)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  

RETURN_SP:
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRLWAV41"    
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
   "TaskDetailKey"    
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
       ,@c_UOM -- UOM,    
       ,@n_UCCQty  -- UOMQty,    
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
       ,@c_DestinationType  
       ,''  
       ,@c_Message03  
       ,@c_DropID  
       ,@c_Loadkey  
       ,(@n_UCCQty - @n_Qty)
      )  
        
      SELECT @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN  
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV41)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
          GOTO RETURN_SP  
      END     
   END  

   --Update taskdetailkey/wavekey to pickdetail  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
       SELECT @c_Pickdetailkey = '', @n_ReplenQty = @n_Qty  
       WHILE @n_ReplenQty > 0   
       BEGIN                          
           
         SELECT TOP 1 @c_PickdetailKey = PICKDETAIL.Pickdetailkey, @n_PickQty = Qty  
         FROM WAVEDETAIL (NOLOCK)   
         JOIN PICKDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey  
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey  
         AND ISNULL(PICKDETAIL.Taskdetailkey,'') = ''  
         AND PICKDETAIL.Storerkey = @c_Storerkey  
         AND PICKDETAIL.Sku = @c_sku  
         AND PICKDETAIL.Lot = @c_Lot  
         AND PICKDETAIL.Loc = @c_FromLoc  
         AND PICKDETAIL.ID = @c_ID  
         AND PICKDETAIL.UOM = @c_UOM  
         AND PICKDETAIL.DropID = @c_DropID  
         AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey  
         ORDER BY PICKDETAIL.Pickdetailkey  
           
         SELECT @n_cnt = @@ROWCOUNT  
           
         IF @n_cnt = 0  
             BREAK  
           
         IF @n_PickQty <= @n_ReplenQty  
         BEGIN  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET Taskdetailkey = @c_TaskdetailKey,  
                TrafficCop = NULL  
            WHERE Pickdetailkey = @c_PickdetailKey  
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0   
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81150     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
                    
            INSERT PICKDETAIL        
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
            FROM PICKDETAIL (NOLOCK)  
            WHERE PickdetailKey = @c_PickdetailKey  
                                 
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0       
            BEGIN       
               SELECT @n_continue = 3        
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81160     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
               BREAK      
            END  
              
            UPDATE PICKDETAIL WITH (ROWLOCK)  
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
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV05)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
   IF @c_DestinationType = 'DP'  
      GOTO DP  
   IF @c_DestinationType = 'DPP'  
      GOTO DPP  

QUIT_SP:
   IF OBJECT_ID('tempdb..#DYNPICK_LOCASSIGNED') IS NOT NULL
      DROP TABLE #DYNPICK_LOCASSIGNED

   IF OBJECT_ID('tempdb..#DYNPICK_TASK') IS NOT NULL
      DROP TABLE #DYNPICK_TASK

   IF OBJECT_ID('tempdb..#DYNPICK_NON_EMPTY') IS NOT NULL
      DROP TABLE #DYNPICK_NON_EMPTY

   IF OBJECT_ID('tempdb..#DYNLOC') IS NOT NULL
      DROP TABLE #DYNLOC

   IF OBJECT_ID('tempdb..#EXCLUDELOC') IS NOT NULL
      DROP TABLE #EXCLUDELOC

END --sp end  

GO