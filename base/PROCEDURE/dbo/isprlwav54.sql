SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/    
/* Stored Procedure: ispRLWAV54                                          */    
/* Creation Date: 07-Jun-2022                                            */    
/* Copyright: LFL                                                        */    
/* Written by: WLChooi                                                   */    
/*                                                                       */    
/* Purpose: WMS-19801 - [CN] STUSSY Release Wave                         */    
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
/* 07-Jun-2022  WLChooi  1.0  DevOps Combine Script                      */  
/*************************************************************************/     

CREATE PROCEDURE [dbo].[ispRLWAV54]        
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
     
   DECLARE  @n_continue    INT,      
            @n_starttcnt   INT,         -- Holds the current transaction count    
            @n_debug       INT,  
            @n_cnt         INT  
                    
   SELECT @n_starttcnt = @@TRANCOUNT , @n_continue = 1, @b_success = 0, @n_err = 0 ,@c_errmsg = '', @n_cnt = 0  
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
         , @c_PTLOrderkey             NVARCHAR(10)
         , @c_LoadlineNumber          NVARCHAR(5)
         , @c_Loctype                 NVARCHAR(10)
         , @c_curPickdetailkey        NVARCHAR(10)
         , @c_UserDefine02            NVARCHAR(18)
         , @c_Sourcekey               NVARCHAR(10)
         , @c_trmlogkey               NVARCHAR(10)
         , @c_DocType                 NVARCHAR(10)
         , @n_TLogGenerated           INT = 0
         , @c_Userdefine04            NVARCHAR(10)
         , @c_PrevSourcekey           NVARCHAR(10) = N''
         , @c_DPCount                 NVARCHAR(10) = N''
         , @c_FirstDP                 NVARCHAR(20) = N''
         , @c_PrevDP                  NVARCHAR(20) = N''
         , @c_SourcekeyCNT            INT          = 0
         , @c_TableName               NVARCHAR(20) = N''
         , @c_UserDefine08            NVARCHAR(50) = N''
         , @c_GetSKU                  NVARCHAR(20) = N''

   -----Check which strategy to use based on DispatchPiecePickMethood
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN        
      SELECT TOP 1 @c_Userdefine02  = MAX(WAVE.UserDefine02),   
                   @c_Userdefine03  = MAX(WAVE.UserDefine03),   
                   @c_Facility      = MAX(ORDERS.Facility),  
                   @c_DispatchPiecePickMethod = MAX(WAVE.DispatchPiecePickMethod),  
                   @c_Storerkey     = MAX(ORDERS.Storerkey),
                   @c_Userdefine04  = MAX(WAVE.UserDefine04),
                   @c_UserDefine08  = MAX(WAVE.UserDefine08),
                   @c_DocType       = MIN(ORDERS.DocType)
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
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Parameters Passed (ispRLWAV54)'    
      END    
   END      
   
   --Validate DispatchPiecePickMethood
   IF @n_continue=1 or @n_continue=2    
   BEGIN            
      IF ISNULL(@c_DispatchPiecePickMethod,'') NOT IN ('AGVB2BPTS')
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Wave.DispatchPiecePickMethod (ispRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END                  
   END  
   
   --Validate Userdefine02 and Userdefine03
   IF @n_continue=1 or @n_continue=2    
   BEGIN            
      IF (ISNULL(@c_Userdefine02,'') = '' OR ISNULL(@c_Userdefine03,'') = '')
      BEGIN           
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Must key-in location range at userdefine02 & 03 (ispRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '             
      END                  
   END  
   
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF EXISTS (SELECT 1   
                 FROM WAVEDETAIL WD(NOLOCK)  
                 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
                 WHERE O.[Status] > '2'  
                 AND WD.Wavekey = @c_Wavekey)  
      BEGIN  
         SELECT @n_continue = 3    
         SELECT @n_err = 81050    
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release is not allowed. Some orders of this Wave are started picking (ispRLWAV54)'           
      END                   
   END   

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   IF @@TRANCOUNT = 0
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
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
         END 
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN
            END
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
      , PTLOrderkey    NVARCHAR(10)
      , LogicalLoc     NVARCHAR(10)
      , Occurences     INT
   )

   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   --Generate PTS
   IF (@n_continue = 1 or @n_continue = 2)
   BEGIN
      IF (@n_continue = 1 OR @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('AGVB2BPTS')
      BEGIN
         DECLARE cur_Assgn2PTS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT DISTINCT O.OrderKey
         FROM WAVEDETAIL WD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey  
         JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
         WHERE WD.Wavekey = @c_Wavekey AND PD.UOM IN ('6','7') 
         ORDER BY O.OrderKey
        
         OPEN cur_Assgn2PTS    
         FETCH NEXT FROM cur_Assgn2PTS INTO @c_Sourcekey  
        
         WHILE @@FETCH_STATUS = 0    
         BEGIN                        
            SELECT @c_DeviceId = '', @c_IPAddress = '', @c_PortNo = '', @c_DevicePosition = '', @c_PTSLOC = '', @c_PTSStatus = '', @c_InLoc = ''  
      
            IF @b_debug = 1
               SELECT @c_Sourcekey AS Sourcekey 
            
            --Can reuse Loc since 1 Loc can be used by multiple orderkey if not enough loc
            ;WITH CTE AS (SELECT DeviceId = DP.DeviceID,   
                                 IPAddress = DP.IPAddress,   
                                 PortNo = DP.PortNo,   
                                 DevicePosition = DP.DevicePosition,   
                                 PTSLOC = LOC.Loc,  
                                 PTSStatus = '',  
                                 InLoc = PZ.InLoc,  
                                 PTLWavekey = '',  
                                 PTLOrderkey = '',
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
                         --AND (PTL.RowRef IS NULL OR PTL.Orderkey = @c_Sourcekey)  
                         --ORDER BY LOC.LogicalLocation, LOC.Loc, DP.DevicePosition
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
                PTLOrderkey,
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
                 , CTE.PTLOrderkey
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
                         @c_PTLOrderkey = ISNULL(T.PTLOrderkey,'')  
            FROM #TMP_PTSAvailableLoc T
            ORDER BY T.RowID   --T.Occurences, T.LogicalLoc, T.PTSLoc, T.DevicePosition 
      
            IF ISNULL(@c_PTSLOC,'') = ''  
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PTS Location Not Setup / Not enough PTS Location. (ispRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
               GOTO RETURN_SP  
            END   
            ELSE
            BEGIN  
               INSERT INTO RDT.rdtPTLStationLog (Station, IPAddress, Position, Loc, Wavekey, Storerkey, ShipTo, Orderkey, Sourcekey)  
               VALUES (@c_DeviceId, @c_IPAddress, @c_DevicePosition, @c_PTSLoc, @c_Wavekey, @c_Storerkey, '', @c_Sourcekey, @c_Wavekey)   
             
               SELECT @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN  
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RDT.rdtPTLStationLog Failed. (ispRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
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

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   -----Generate Conso Pickslip and Auto Scan In (Only B2B)-------  
   IF (@n_continue = 1 or @n_continue = 2) AND @c_DispatchPiecePickMethod IN ('AGVB2BPTS')
   BEGIN
      EXEC isp_CreatePickSlip
              @c_Wavekey = @c_Wavekey
             ,@c_LinkPickSlipToPick = 'Y'  --Y=Update pickslipno to pickdetail.pickslipno 
             ,@c_ConsolidateByLoad = 'N'
             ,@c_AutoScanIn = 'Y'
             ,@c_Refkeylookup = 'N'
             ,@b_Success = @b_Success OUTPUT
             ,@n_Err = @n_err OUTPUT 
             ,@c_ErrMsg = @c_errmsg OUTPUT       	
         
      IF @b_Success = 0
         SELECT @n_continue = 3   
   END  

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   -----Trigger Order Out Interface AGVB2BPTS-------  
   IF (@n_continue = 1 or @n_continue = 2) AND 
      (@c_DispatchPiecePickMethod IN ('AGVB2BPTS') AND @c_UserDefine08 <> 'Y' AND @c_DocType = 'N')
   BEGIN
      SET @c_Orderkey  = ''
      SET @c_Storerkey = ''

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OH.OrderKey,
                      OH.StorerKey
      FROM WAVEDETAIL WD (NOLOCK)  
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.Wavekey = @c_Wavekey AND OH.DocType = 'N'
      ORDER BY OH.OrderKey

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
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=83814   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain transmitlogkey2. (ispRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO RETURN_SP  
         END
         ELSE
         BEGIN
            SET @c_TableName = 'WSB2BOrderLOG'
            
            INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, @c_TableName, @c_Orderkey, '', @c_Storerkey, '0', '')
            
            SET @n_err = @@ERROR
            
            IF @n_err <> 0    
            BEGIN  
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83815   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Transmitlog2 Failed. (ispRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP  
            END
         END

         FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @c_Storerkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   -----Update Wave Status-----
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      UPDATE WAVE     
      SET TMReleaseFlag = 'Y'             
       ,  TrafficCop    = NULL               
       ,  EditWho       = SUSER_SNAME()         
       ,  EditDate      = GETDATE()             
      WHERE WAVEKEY = @c_wavekey      
   
      SELECT @n_err = @@ERROR
        
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ISPRLWAV54)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
      END  
   END 
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF @b_debug = 1
      SELECT * FROM #TMP_PTS

RETURN_SP:
   IF OBJECT_ID('tempdb..#TMP_PTS') IS NOT NULL
      DROP TABLE #TMP_PTS

   IF OBJECT_ID('tempdb..#TMP_PTSAvailableLoc') IS NOT NULL
      DROP TABLE #TMP_PTSAvailableLoc

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   WHILE @@TRANCOUNT < @n_starttcnt
      BEGIN TRAN

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispRLWAV54'    
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