SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: ispRLWAV62                                          */    
/* Creation Date: 31-May-2023                                            */    
/* Copyright: MAERSK                                                     */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-22628 - [CN] Desigual_WMS_ReleaseWave                    */    
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
/* 31-May-2023  WLChooi  1.0  DevOps Combine Script                      */  
/*************************************************************************/     
CREATE   PROCEDURE [dbo].[ispRLWAV62]        
   @c_wavekey      NVARCHAR(10)    
 , @b_Success      INT            OUTPUT    
 , @n_err          INT            OUTPUT    
 , @c_errmsg       NVARCHAR(250)  OUTPUT    
 , @b_debug        INT = 0
 AS    
 BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @n_continue int,      
           @n_starttcnt INT,  -- Holds the current transaction count    
           @n_debug INT,  
           @n_cnt INT  
   
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_cnt=0  
   SELECT @n_debug = @b_debug 
 
   DECLARE @c_DispatchPiecePickMethod NVARCHAR(10)
         , @c_Userdefine03            NVARCHAR(20)
         , @c_ShipTo                  NVARCHAR(45)
         , @c_OmniaOrderNo            NVARCHAR(20)
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
         , @c_SameStyleLoc            NVARCHAR(10)
         , @c_SameStyleLogicalLoc     NVARCHAR(30)
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
         , @c_UserDefine02            NVARCHAR(18)
         , @c_UserDefine08            NVARCHAR(30)
         , @c_Sourcekey               NVARCHAR(10)
         , @c_trmlogkey               NVARCHAR(10)
         , @c_DocType                 NVARCHAR(10)
         , @n_TLogGenerated           INT = 0
         , @c_PrevSourcekey           NVARCHAR(10) = N''
         , @c_DPCount                 NVARCHAR(10) = N''
         , @c_FirstDP                 NVARCHAR(20) = N''
         , @c_PrevDP                  NVARCHAR(20) = N''
         , @c_SourcekeyCNT            INT          = 0
         , @c_TableName               NVARCHAR(20) = N''
         , @c_GetSKU                  NVARCHAR(20) = N''
         
   DECLARE @cur_PICKSKU CURSOR,   
           @c_SortMode NVARCHAR(10)  
       
    CREATE TABLE #TMP_PTSAvailableLoc (
        RowID          INT NOT NULL IDENTITY(1,1) PRIMARY KEY
      , DeviceID       NVARCHAR(20)
      , IPAddress      NVARCHAR(40)
      , PortNo         NVARCHAR(5)
      , DevicePosition NVARCHAR(10)
      , PTSLOC         NVARCHAR(10)
      , PTSStatus      NVARCHAR(10)
      , InLoc          NVARCHAR(10)
      , PTLWavekey     NVARCHAR(10)
      , PTLLoadkey     NVARCHAR(10)
      , LogicalLoc     NVARCHAR(10)
      , Occurences     INT
   )

   -----Check which strategy to use based on DispatchPiecePickMethood
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT TOP 1 @c_Userdefine02 = WAVE.UserDefine02,   
                   @c_Userdefine03 = WAVE.UserDefine03,  
                   @c_UserDefine08 = WAVE.UserDefine08, 
                   @c_Facility = ORDERS.Facility,  
                   @c_DispatchPiecePickMethod = WAVE.DispatchPiecePickMethod,  
                   @c_Storerkey = ORDERS.Storerkey
      FROM WAVE (NOLOCK)  
      JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey  
      JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey          
      WHERE WAVE.Wavekey = @c_Wavekey  
                          
      IF @n_debug=1  
         SELECT '@c_Userdefine02', @c_Userdefine02, '@c_Userdefine03', @c_Userdefine03, '@c_UserDefine08', @c_UserDefine08, '@c_DispatchPiecePickMethod', @c_DispatchPiecePickMethod                     
   END  
   -----Wave Validation-----  
   IF @n_continue=1 or @n_continue=2    
   BEGIN    
      IF ISNULL(@c_wavekey,'') = ''    
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @n_err = 81010    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV62)'    
      END    
   END      
   
   --Validate DispatchPiecePickMethood
   IF @n_continue=1 or @n_continue=2    
   BEGIN            
      IF ISNULL(@c_DispatchPiecePickMethod,'') NOT IN ('DESB2BPTS','DESB2BZINI','DESB2CAGV')
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Wave.DispatchPiecePickMethod (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END                  
   END  
   
   --Validate Userdefine02 and Userdefine03 (Do not validate for DESB2CAGV)
   IF @n_continue=1 or @n_continue=2    
   BEGIN            
      IF (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '') AND ISNULL(@c_DispatchPiecePickMethod,'') NOT IN ('DESB2CAGV')
      BEGIN           
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must key-in location range at userdefine02 & 03 (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END                  
   END  
              
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1 FROM TASKDETAIL TD (NOLOCK)   
                 WHERE TD.Wavekey = @c_Wavekey  
                 AND TD.Sourcetype IN('ispRLWAV62')
                 AND TD.Tasktype IN ('RPF'))   
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81040    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave has been released. (ispRLWAV62)'         
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV62)'           
      END                   
   END   

   BEGIN TRAN  

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
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END    

         FETCH NEXT FROM Orders_Pickdet_cur INTO @c_curPickdetailkey  
      END  
      CLOSE Orders_Pickdet_cur   
      DEALLOCATE Orders_Pickdet_cur  
   END 

   CREATE TABLE #TMP_PTS(
      Sourcekey      NVARCHAR(10)  NULL,
      LOC            NVARCHAR(50)  NULL,
      SKU            NVARCHAR(20)  NULL 
   )

   --Generate PTS
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('DESB2BPTS', 'DESB2BZINI')
      BEGIN
         DECLARE cur_Assgn2PTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT O.LoadKey
         FROM WAVEDETAIL WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         --JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
         WHERE WD.Wavekey = @c_Wavekey --AND PD.UOM <> '2'  
         GROUP BY O.LoadKey
         ORDER BY O.LoadKey
        
         OPEN cur_Assgn2PTS    
         FETCH NEXT FROM cur_Assgn2PTS INTO @c_Sourcekey  
        
         WHILE @@FETCH_STATUS = 0    
         BEGIN                        
            SELECT @c_DeviceId = '', @c_IPAddress = '', @c_PortNo = '', @c_DevicePosition = '', @c_PTSLOC = '', @c_PTSStatus = '', @c_InLoc = ''  
      
            IF @b_debug = 1
               SELECT @c_Sourcekey AS Sourcekey, @c_Userdefine02 AS Userdefine02, @c_Userdefine03 AS Userdefine03, @c_Facility AS Facility
            
            --Can reuse Loc since 1 Loc can be used by multiple loadkey if not enough loc
            ;WITH CTE AS (SELECT DeviceId = DP.DeviceID,   
                                 IPAddress = DP.IPAddress,   
                                 PortNo = DP.PortNo,   
                                 DevicePosition = DP.DevicePosition,   
                                 PTSLOC = LOC.Loc,  
                                 PTSStatus = '',  
                                 InLoc = PZ.InLoc,  
                                 PTLWavekey = '',  
                                 PTLLoadkey = '',
                                 LogicalLocation = LOC.LogicalLocation,
                                 Occurences = (SELECT COUNT(DISTINCT Orderkey)
                                               FROM RDT.rdtPTLStationLog P (NOLOCK)
                                               WHERE P.Loc = DP.Loc)
                         FROM LOC (NOLOCK)   
                         JOIN DEVICEPROFILE DP (NOLOCK) ON LOC.Loc = DP.Loc   
                         JOIN PUTAWAYZONE PZ (NOLOCK) ON LOC.Putawayzone = PZ.Putawayzone  
                         LEFT JOIN RDT.rdtPTLStationLog PTL (NOLOCK) ON LOC.Loc = PTL.Loc   
                         WHERE LOC.Loc BETWEEN @c_Userdefine02 AND @c_Userdefine03                    
                         AND LOC.LocationCategory = 'PTS'  
                         AND LOC.Facility = @c_Facility                                      
            )
            INSERT INTO #TMP_PTSAvailableLoc
            (
                DeviceID,
                IPAddress,
                PortNo,
                DevicePosition,
                PTSLOC,
                PTSStatus,
                InLoc,
                PTLWavekey,
                PTLLoadkey,
                Occurences,
                LogicalLoc
            )
            SELECT CTE.DeviceId
                 , CTE.IPAddress  
                 , CTE.PortNo
                 , CTE.DevicePosition 
                 , CTE.PTSLOC
                 , CTE.PTSStatus 
                 , CTE.InLoc
                 , CTE.PTLWavekey  
                 , CTE.PTLLoadkey
                 , ISNULL(CTE.Occurences,0)
                 , CTE.LogicalLocation
            FROM CTE   
            ORDER BY ISNULL(CTE.Occurences,0), CTE.LogicalLocation, CTE.PTSLOC, CTE.DevicePosition 

            SELECT TOP 1 @c_DeviceId = T.DeviceID,   
                         @c_IPAddress = T.IPAddress,   
                         @c_PortNo = T.PortNo,   
                         @c_DevicePosition = T.DevicePosition,   
                         @c_PTSLOC = T.PTSLOC,  
                         @c_PTSStatus = T.PTSStatus,  
                         @c_InLoc = T.InLoc,  
                         @c_PTLWavekey = ISNULL(T.PTLWavekey,''),  
                         @c_PTLLoadkey = ISNULL(T.PTLLoadkey,'')  
            FROM #TMP_PTSAvailableLoc T
            ORDER BY T.Occurences, T.LogicalLoc, T.PTSLoc, T.DevicePosition 

            IF ISNULL(@c_PTSLOC,'') = ''  
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               GOTO RETURN_SP  
            END   
            ELSE
            BEGIN  
               INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, ShipTo, Loadkey, Sourcekey)  
               VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, '', @c_Sourcekey, @c_Wavekey)   

               SELECT @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RDT.rdtPTLStationLog Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
                  GOTO RETURN_SP  
               END 
               
               UPDATE #TMP_PTSAvailableLoc
               SET Occurences = Occurences + 1
               WHERE PTSLOC = @c_PTSLOC
            END  
              
            SELECT @c_ToLoc = @c_InLoc  
            SELECT @c_PrevSourcekey = @c_Sourcekey
            SELECT @c_PrevDP = @c_DevicePosition

            IF NOT EXISTS(SELECT 1 FROM #TMP_PTS WHERE SourceKey = @c_Sourcekey)
            BEGIN
               INSERT INTO #TMP_PTS (Sourcekey, LOC)
               SELECT @c_Sourcekey, @c_ToLoc
            END
      
            FETCH NEXT FROM cur_Assgn2PTS INTO @c_Sourcekey  
         END  
         CLOSE cur_Assgn2PTS    
         DEALLOCATE cur_Assgn2PTS
      END 
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('DESB2BPTS','DESB2BZINI')
   BEGIN 
      DECLARE cur_PICKUCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT PD.Storerkey, PD.Sku, PD.Lot, PD.Loc, PD.ID, SUM(PD.Qty) AS Qty, PD.UOM, PD.DropID,  
             CASE WHEN MIN(PD.PickMethod) = 'P' THEN 'FP'                            
                  ELSE 'PP' END AS PickMethod,  
             ISNULL(UCC.Qty,0) AS UCCQty,  
             CASE WHEN LOC.LocationType = 'DYNPPICK' AND LOC.LocationCategory = 'DPP' THEN 'DPP'
                  WHEN LOC.LocationType = 'PICK' AND LOC.LocationCategory = 'AGV' THEN 'AGV' 
                  ELSE 'BULK' END,
             ''-- O.Loadkey
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
               CASE WHEN LOC.LocationType = 'DYNPPICK' AND LOC.LocationCategory = 'DPP' THEN 'DPP'
                    WHEN LOC.LocationType = 'PICK' AND LOC.LocationCategory = 'AGV' THEN 'AGV' 
                    ELSE 'BULK' END--, O.Loadkey  
      ORDER BY PD.Storerkey, PD.UOM, PD.Sku, PD.Lot

      OPEN cur_PICKUCC    
      FETCH NEXT FROM cur_PICKUCC INTO @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_Qty, @c_UOM, @c_DropID, 
                                       @c_PickMethod, @n_UCCQty, @c_LocType, @c_Loadkey
         

      SELECT @c_SourceType = 'ispRLWAV62'  
      SELECT @c_TaskType = 'RPF'  
      SELECT @c_ToLoc = ''  
      SELECT @c_Message03 = ''  
         
      WHILE @@FETCH_STATUS = 0    
      BEGIN     
         SELECT @c_DestinationType = 'PTS'   

         IF @b_debug=1  
            SELECT '@c_FromLoc', @c_FromLoc, '@c_ID', @c_ID, '@n_Qty', @n_qty, '@c_UOM', @c_UOM, '@c_Lot', @c_Lot, '@n_UCCQty', @n_UCCQty,  
                   '@c_PickMethod', @c_PickMethod, '@c_DropID', @c_DropID, 
                   '@c_DestinationType', @c_DestinationType, @c_Loadkey
                                                       
         IF @c_DestinationType = 'PTS' --IFC Put To Light(store)  
         BEGIN  
            DECLARE cur_UCCDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT O.LoadKey  
            FROM WAVEDETAIL WD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
            JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
            WHERE WD.Wavekey = @c_Wavekey  
            AND PD.DropID = @c_DropID  
            AND PD.Storerkey = @c_Storerkey  
            AND PD.Sku = @c_Sku  
            AND PD.Loc = @c_FromLoc  
            AND PD.ID = @c_ID  
            AND PD.Lot = @c_Lot  
            GROUP BY O.LoadKey   
            ORDER BY O.LoadKey 
              
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
                                       @c_PickMethod, @n_UCCQty, @c_LocType, @c_Loadkey
      END --Fetch  
   CLOSE cur_PICKUCC    
   DEALLOCATE cur_PICKUCC                                     
   END      

   -----Generate Conso Pickslip and Auto Scan In (Only B2B)-------  
   IF (@n_continue = 1 or @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('DESB2BPTS','DESB2BZINI')
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
   
   -----Trigger Order Out Interface DESB2CAGV-------  
   IF (@n_continue = 1 or @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('DESB2CAGV') AND @c_UserDefine08 <> 'Y'
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OH.OrderKey, OH.Storerkey
      FROM WAVEDETAIL WD (NOLOCK) 
      JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      WHERE WD.WaveKey = @c_wavekey AND OH.DocType = 'E'
      GROUP BY OH.OrderKey, OH.Storerkey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @b_success = 1   
         EXECUTE nspg_getkey
         'TransmitlogKey2'
         , 10
         , @c_trmlogkey OUTPUT
         , @b_success   OUTPUT
         , @n_err       OUTPUT
         , @c_errmsg    OUTPUT
         
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=83812   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain transmitlogkey2. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO RETURN_SP  
         END
         ELSE
         BEGIN
            SET @c_TableName = 'WSB2COrderLOG'
            
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, @c_TableName, @c_Orderkey, '', @c_StorerKey, '0', '')
            
            SET @n_err = @@ERROR
            IF @n_err <> 0    
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83813   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Transmitlog2 Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP  
            END  
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_Storerkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   -----Trigger Order Out Interface DESB2BPTS & DESB2BZINI-------  
   --DPP/AGV TO PTS no need generate taskdetail, need to trigger interface 
   IF (@n_continue = 1 or @n_continue = 2) AND (@c_DispatchPiecePickMethod IN ('DESB2BPTS','DESB2BZINI') AND @c_UserDefine08 <> 'Y') 
   BEGIN
      SET @c_Loadkey  = ''
      SET @c_Storerkey = ''

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OH.LoadKey,
                      OH.StorerKey
      FROM WAVEDETAIL WD (NOLOCK)  
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
      WHERE WD.Wavekey = @c_Wavekey AND OH.DocType = 'N'
      ORDER BY OH.LoadKey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SELECT @b_success = 1   
         EXECUTE nspg_getkey
         'TransmitlogKey2'
         , 10
         , @c_trmlogkey OUTPUT
         , @b_success   OUTPUT
         , @n_err       OUTPUT
         , @c_errmsg    OUTPUT
         
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=83814   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain transmitlogkey2. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO RETURN_SP  
         END
         ELSE
         BEGIN
            SET @c_TableName = 'WSB2BOrderLOG'
            
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, @c_TableName, @c_Loadkey, @c_Wavekey, @c_StorerKey, '0', '')
            
            SET @n_err = @@ERROR
            
            IF @n_err <> 0    
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83815   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Transmitlog2 Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP  
            END
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey, @c_Storerkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
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
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRLWAV33)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END  

RETURN_SP:
   IF OBJECT_ID('tempdb..#TMP_PTS') IS NOT NULL
      DROP TABLE #TMP_PTS

   IF OBJECT_ID('tempdb..#TMP_PTSAvailableLoc') IS NOT NULL
      DROP TABLE #TMP_PTSAvailableLoc

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV62'    
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
       ,@c_UOM -- UOM,    
       ,CASE WHEN ISNULL(@n_UCCQty,0) = 0 THEN @n_Qty ELSE @n_UCCQty END  -- UOMQty,    
       ,CASE WHEN ISNULL(@n_UCCQty,0) = 0 THEN @n_Qty ELSE @n_UCCQty END  --Qty  
       ,@n_Qty  --systemqty  
       ,@c_Lot     
       ,@c_FromLOC  
       ,@c_ID -- from id    
       ,@c_ToLOC   
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
       ,''--@c_DestinationType  
       ,''  
       ,''--@c_Message03  
       ,@c_DropID  
       ,@c_Loadkey  
       ,(CASE WHEN ISNULL(@n_UCCQty,0) = 0 THEN @n_Qty ELSE @n_UCCQty END - @n_Qty)
      )  
        
      SELECT @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN  
          SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
          SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Taskdetail Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
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
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV62)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
               BREAK  
            END  
            SELECT @n_ReplenQty = 0  
         END       
       END -- While Qty > 0  
   END   

   --Return back to calling point  
   IF @c_DestinationType = 'PTS'  
      GOTO PTS  

END --sp end  

GO