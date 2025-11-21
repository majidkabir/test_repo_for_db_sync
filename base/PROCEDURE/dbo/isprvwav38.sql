SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: ispRVWAV38                                          */
/* Creation Date: 2021-01-22                                             */
/* Copyright: LFL                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-15653 - HK - Lululemon Relocation Project-Release Wave CR*/      
/*        : Copy and develop from ispRVWAV04                             */   
/*                                                                       */
/* Called By: wave                                                       */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-01-22  Wan      1.0   Created                                    */
/*************************************************************************/
CREATE PROCEDURE [dbo].[ispRVWAV38]
       @c_Wavekey      NVARCHAR(10)
      ,@c_Orderkey     NVARCHAR(10) = ''
      ,@b_Success      int          = 0  OUTPUT
      ,@n_err          int          = 0  OUTPUT
      ,@c_errmsg       NVARCHAR(250)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT            = 1
         , @n_starttcnt       INT            = @@TRANCOUNT    -- Holds the current transaction count
         , @n_debug           INT            = 0
         , @n_cnt             INT            = 0
         , @n_Started         INT            = 0
         , @n_Released        INT            = 0
         , @n_DelPSLP         BIT            = 0

         , @c_Storerkey       NVARCHAR(15)   = ''
         , @c_Pickdetailkey   NVARCHAR(10)   = ''
         , @c_Taskdetailkey   NVARCHAR(10)   = ''
         , @c_TaskStatus      NVARCHAR(10)   = ''    
         , @c_Loadkey         NVARCHAR(10)   = ''
         , @c_LoadLineNumber  NVARCHAR(5)    = ''
         , @c_PickSlipNo      NVARCHAR(10)   = ''
         , @c_Transmitflag    NVARCHAR(10)   = ''
         , @c_Transmitlogkey  NVARCHAR(10)   = ''
         , @c_WavedetailKey   NVARCHAR(10)   = ''
         , @c_ReleasedFlag    NVARCHAR(10)   = 'N'
         
         , @c_PTLStationLogQueue   NVARCHAR(30) = ''          --v1.6 2021-03-26    
         
   DECLARE @CUR_TASKDEL       CURSOR 
         , @CUR_PSLIP         CURSOR
         , @CUR_RFKDEL        CURSOR 
         , @CUR_ORDRMV        CURSOR
         
   DECLARE @TORD  TABLE 
      (
      	  Orderkey           NVARCHAR(10) NOT NULL DEFAULT('')   PRIMARY KEY
      ,    Loadkey            NVARCHAR(10) NOT NULL DEFAULT('')    
      ,    Wavekey            NVARCHAR(10) NOT NULL DEFAULT('')       
   	)        

   SET @b_success=0
   SET @n_err=0
   SET @c_errmsg=''
   SET @n_cnt=0
   SET @n_debug = 0

   -- 1) Task Released but Sort & pack RDT module to Pick Confirm, 2) Manual Pick Confirm
   SET @c_Orderkey = ISNULL(RTRIM(@c_Orderkey),'')
   
   IF @c_Orderkey = '' --v1.6 confirm to reverse By Wavekey only
   BEGIN
      INSERT INTO @TORD
   	(
   		Orderkey
   	,  Loadkey
   	,  Wavekey	
   	)
   	SELECT DISTINCT w.OrderKey
   	   , lpd.LoadKey
   	   , w.WaveKey
   	FROM WAVEDETAIL AS w WITH (NOLOCK)
   	JOIN LoadPlanDetail AS lpd WITH (NOLOCK) ON lpd.OrderKey = w.OrderKey
   	WHERE w.Wavekey = @c_Wavekey
   	
   	SELECT @n_Released= ISNULL(SUM(CASE WHEN td.TaskDetailKey IS NULL THEN 0 ELSE 1 END),0)
            ,@n_Started = ISNULL(SUM(CASE WHEN td.TaskDetailKey IS NULL THEN 0 WHEN Td.[Status] IN ('N') THEN 0 ELSE 1 END),0)   --2021-06-25 CR2.1
      FROM @tORD TORD
      LEFT OUTER JOIN TaskDetail AS td WITH  (NOLOCK) ON td.Wavekey = TORD.Wavekey
                                                      AND td.Sourcetype IN ('ispRLWAV38-RETAIL','ispRLWAV38-ECOM', 'ispRLWAV38-RPF')
                                                      AND td.Tasktype IN ('SPK', 'PK', 'RPF')
      WHERE  TORD.Wavekey = @c_Wavekey   
      IF @n_Released = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81010
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': This Wave/SO has not been released. (ispRVWAV38)'
         GOTO RETURN_SP
      END  
      
      IF @n_Started > 0 
      BEGIN
      	SET @n_continue = 3
         SET @n_err = 81020
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)
                      +': Some Tasks have been started. Not allow to Reverse Wave/SO Released (ispRVWAV38)' 
         GOTO RETURN_SP
      END  
      
      SET @c_StorerKey = ''
      SELECT TOP 1 @c_StorerKey = OH.StorerKey 
      FROM @TORD t
      JOIN ORDERS OH WITH (NOLOCK) ON t.orderkey = oh.OrderKey
   END
   ELSE
   BEGIN
      SET @c_Loadkey = ''
      SELECT @c_Loadkey = Loadkey FROM LOADPLANDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey
      
   	INSERT INTO @TORD
   	(
   		Orderkey
   	, 	Loadkey	
   	,  Wavekey
   	)
   	VALUES
   	(  @c_Orderkey
   	,  @c_Loadkey
   	,  @c_Wavekey
   	)
   	
      SET @c_Transmitflag = '0'
      SELECT @c_Transmitflag =  ISNULL(MAX(TL3.Transmitflag),'0')
      FROM TRANSMITLOG3 TL3  WITH (NOLOCK)
      JOIN ORDERS       OH   WITH (NOLOCK) ON (TL3.Key1 = OH.Orderkey)
                                           AND(TL3.Key3 = OH.Storerkey)
      WHERE TL3.TABLENAME = 'PICKCFMLOG'
      AND   OH.Orderkey = @c_Orderkey

      IF @c_Transmitflag <> '0'
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81030
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PICKCFGLOG is being / had processed. (ispRVWAV38)' 
         GOTO RETURN_SP
      END

      IF EXISTS ( SELECT 1
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND [Status] > 0 )
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81040
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders is picked/ pick in progress. (ispRVWAV38)'
         GOTO RETURN_SP
      END

      SET @c_StorerKey = ''
      SELECT TOP 1 @c_StorerKey = StorerKey FROM ORDERS WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      SET @n_Cnt = 0
      IF @c_Orderkey <> ''
      BEGIN
      	SELECT @n_Cnt = 1
      	FROM PACKHEADER WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey 
         AND OrderKey = @c_Orderkey
      END
      
      IF @n_Cnt = 0 AND @c_Loadkey <> ''
      BEGIN
      	SELECT @n_Cnt = 1
      	FROM PACKHEADER WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey 
         AND Loadkey = @c_Loadkey
         AND Orderkey  =''
      END

      IF @n_Cnt = 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 81050
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Orders is packing/packed. (ispRVWAV38)'
         GOTO RETURN_SP
      END
   END
   
   --BEGIN TRAN

    --Delete RefKeyLookup, PickingInfo, PICKHEADER
   IF @n_continue IN (1,2)
   BEGIN
   	DECLARE @TPSLP TABLE
   	(
   		   PickSlipNo  NVARCHAR(10) NOT NULL DEFAULT('') PRIMARY KEY
   	,     Discrete    INT          NOT NULL DEFAULT(0)
   	)
   	   	
      INSERT INTO @TPSLP
   	   (
   		   PickSlipNo
   	   ,  Discrete	
   	   )
   	SELECT DISTINCT 
   	       p.PickSlipNo
   	      ,Discrete = CASE WHEN PH.OrderKey = '' THEN 0 ELSE 1 END
   	FROM @TORD AS t 
      JOIN PICKDETAIL AS p  WITH (NOLOCK) ON p.OrderKey = t.OrderKey
      JOIN PICKHEADER AS PH WITH (NOLOCK) ON p.PickSlipNo = PH.PickHeaderKey
      
      SET @CUR_PSLIP = CURSOR FAST_FORWARD READ_ONLY FOR
   	SELECT TPS.PickSlipNo
   	FROM @tPSLP TPS

      OPEN @CUR_PSLIP
      
      FETCH NEXT FROM @CUR_PSLIP INTO @c_PickSlipNo  
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
   	BEGIN
   		DEL_REFKEYLOOKUP:

         IF @c_Orderkey = ''
         BEGIN
   	      SET @CUR_RFKDEL = CURSOR FAST_FORWARD READ_ONLY FOR
   	      SELECT RFLK.PickDetailKey
   	      FROM REFKEYLOOKUP RFLK WITH (NOLOCK)
   	      WHERE RFLK.PickSlipNo = @c_PickSlipNo
         END
         ELSE
         BEGIN
       	   ;WITH PICK ( PickDetailkey )
             AS ( SELECT p.PickDetailkey
   	            FROM @TORD AS t 
                  JOIN PICKDETAIL AS p  WITH (NOLOCK) ON p.OrderKey = t.OrderKey
               )
             
            UPDATE pd
                  SET  pd.PickSlipNo = ''
   		            , pd.EditWho  = SUSER_SNAME()
   		            , pd.EditDate = GETDATE()
   		            , pd.TrafficCop = NULL
            FROM PICK p
            JOIN PICKDETAIL pd ON pd.PickDetailkey = p.PickDetailkey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Failed (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
      
         	SET @CUR_RFKDEL = CURSOR FAST_FORWARD READ_ONLY FOR
   	      SELECT RFLK.PickDetailKey
   	      FROM REFKEYLOOKUP RFLK WITH (NOLOCK)
   	      WHERE RFLK.PickSlipNo = @c_PickSlipNo
   	      AND RFLK.PickSlipNo = @c_Orderkey
         END

         OPEN @CUR_RFKDEL
      
         FETCH NEXT FROM @CUR_RFKDEL INTO @c_PickDetailKey
      
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
   	   BEGIN
            DELETE RFLK 
            FROM REFKEYLOOKUP RFLK
            WHERE RFLK.PickDetailKey = @c_PickDetailKey
               
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete RefKeyLookUp Table Failed. (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END 
            FETCH NEXT FROM @CUR_RFKDEL INTO @c_PickDetailKey
         END -- END WHILE
         CLOSE @CUR_RFKDEL
         DEALLOCATE @CUR_RFKDEL
         
         SET @n_DelPSLP = 1 
         IF @c_Orderkey <> ''
         BEGIN
            IF EXISTS (SELECT 1 
                       FROM PICKDETAIL AS p WITH (NOLOCK) 
                       WHERE p.Storerkey = @c_Storerkey
                       AND p.PickSlipNo = @c_PickSlipNo
                        )
            BEGIN
               SET @n_DelPSLP = 0 
            END
         END
         
         IF @n_DelPSLP = 1
         BEGIN
            IF EXISTS (SELECT 1 FROM PICKINGINFO PCKIF WITH (NOLOCK) WHERE PCKIF.PickSlipNo = @c_PickSlipNo)
   		   BEGIN
   		      DELETE PCKIF
   		      FROM PICKINGINFO PCKIF
   		      WHERE PCKIF.PickSlipNo = @c_PickSlipNo

               SET @n_err = @@ERROR

               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PickingInfo Table Failed. (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                  GOTO RETURN_SP
               END
   		   END
         
            DELETE PH
            FROM PICKHEADER PH
            WHERE PH.PickHeaderkey = @c_PickSlipNo

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Pickheader Table Failed. (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
         END   
         FETCH NEXT FROM @CUR_PSLIP INTO @c_PickSlipNo 
   	END
   	CLOSE @CUR_PSLIP
   	DEALLOCATE @CUR_PSLIP
   END
   
   ----delete replenishment pick tasks
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	IF @c_Orderkey = ''
   	BEGIN         
   	   SET @CUR_TASKDEL = CURSOR FAST_FORWARD READ_ONLY FOR
   	   SELECT p.PickDetailKey
   	         ,td.TaskDetailKey
   	         ,td.[Status] 
   	   FROM TaskDetail AS td WITH (NOLOCK)
   	   LEFT OUTER JOIN PICKDETAIL AS p WITH (NOLOCK) ON p.TaskDetailKey = td.TaskDetailKey 
         WHERE td.Sourcetype IN ('ispRLWAV38-RETAIL','ispRLWAV38-ECOM', 'ispRLWAV38-RPF')
         AND td.Tasktype IN ('SPK', 'PK', 'RPF')
         AND td.WaveKey  = @c_Wavekey
   	END
   	ELSE
   	BEGIN
   		SELECT p.PickDetailKey
   	         ,p.TaskDetailKey
   	         ,td.[Status] 
   	   FROM @tORD TORD
         JOIN PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = TORD.OrderKey
         JOIN TaskDetail AS td WITH  (NOLOCK) ON p.TaskDetailKey = td.TaskDetailKey
         WHERE td.Sourcetype IN ('ispRLWAV38-RETAIL','ispRLWAV38-ECOM', 'ispRLWAV38-RPF')
         AND td.Tasktype IN ('SPK', 'PK', 'RPF')	
         AND EXISTS (SELECT 1 FROM PICKDETAIL AS p2 WITH (NOLOCK) 
                     WHERE  p2.TaskDetailKey = td.TaskDetailKey
                     AND p2.OrderKey <> p.OrderKey
                     GROUP BY p2.TaskDetailKey 
                     HAVING COUNT(DISTINCT p2.Orderkey) = 1
                     AND MIN(p2.Orderkey) = @c_Orderkey
         )
         
   		
   		SET @CUR_TASKDEL = CURSOR FAST_FORWARD READ_ONLY FOR
   	   SELECT p.PickDetailKey
   	         ,p.TaskDetailKey
   	         ,td.[Status] 
   	   FROM @tORD TORD
         JOIN PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = TORD.OrderKey
         JOIN TaskDetail AS td WITH  (NOLOCK) ON p.TaskDetailKey = td.TaskDetailKey
         WHERE td.Sourcetype IN ('ispRLWAV38-RETAIL','ispRLWAV38-ECOM', 'ispRLWAV38-RPF')
         AND td.Tasktype IN ('SPK', 'PK', 'RPF')	
         AND EXISTS (SELECT 1 FROM PICKDETAIL AS p2 WITH (NOLOCK) 
                     WHERE  p2.TaskDetailKey = td.TaskDetailKey
                     AND p2.OrderKey <> p.OrderKey
                     GROUP BY p2.TaskDetailKey 
                     HAVING COUNT(DISTINCT p2.Orderkey) = 1
                     AND MIN(p2.Orderkey) = @c_Orderkey
         )
         
         
   	END

      OPEN @CUR_TASKDEL
      
      FETCH NEXT FROM @CUR_TASKDEL INTO @c_PickDetailKey, @c_TaskDetailKey, @c_TaskStatus  
      
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
   	BEGIN
   		--Delete Task
   		
    		IF @c_TaskStatus NOT IN ('9', 'X')
   		BEGIN
   						
            DELETE td
            FROM TASKDETAIL td
            WHERE td.TaskDetailKey = @c_TaskDetailKey
            AND td.[Status] NOT IN ('9', 'X')

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Taskdetail Table Failed. (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
   		END
   		
   		FETCH NEXT FROM @CUR_TASKDEL INTO @c_PickDetailKey, @c_TaskDetailKey, @c_TaskStatus 
   	END
   	CLOSE @CUR_TASKDEL
   	DEALLOCATE @CUR_TASKDEL
   END
   
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Bulk Remove TaskDetail from Pickdetail as trafficcop = null for Wave
      IF @c_Orderkey = ''
      BEGIN
         ;WITH PICK ( PickDetailkey )
            AS (  SELECT p.PickDetailkey
    	            FROM @TORD AS t 
                  JOIN PICKDETAIL AS p  WITH (NOLOCK) ON p.OrderKey = t.OrderKey
            )
             
         UPDATE pd
               SET  pd.TaskDetailKey = ''
   		         , pd.EditWho  = SUSER_SNAME()
   		         , pd.EditDate = GETDATE()
   		         , pd.TrafficCop = NULL
         FROM PICK p
         JOIN PICKDETAIL pd ON pd.PickDetailkey = p.PickDetailkey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unallocate Orders Failed (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END
      END
   END
   -----Reverse wave status------
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_Orderkey <> ''
      BEGIN
         --Unallocation  
         DEL_ORDERS:

         SET @c_TransmitLogKey = ''
         SELECT @c_TransmitLogKey = TL3.transmitlogkey
         FROM TRANSMITLOG3 TL3 WITH (NOLOCK) 
         WHERE TL3.TABLENAME = 'PICKCFMLOG'
         AND   TL3.TransmitFlag = '0'
         AND   TL3.Key3 = @c_Storerkey
         
         IF @c_TransmitLogKey <> ''
         BEGIN
            DELETE TL3 
            FROM TRANSMITLOG3 TL3
            WHERE TL3.transmitlogkey = @c_TransmitLogKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete TRANSMITLOG3 Failed (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
         END

         SET @CUR_ORDRMV = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT p.PickDetailkey
   	   FROM @TORD AS t 
         JOIN PICKDETAIL AS p  WITH (NOLOCK) ON p.OrderKey = t.OrderKey
         
         OPEN @CUR_ORDRMV
      
         FETCH NEXT FROM @CUR_ORDRMV INTO @c_PickDetailKey 
      
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)
         BEGIN
            DELETE pd
            FROM PICKDETAIL pd WHERE pd.PickDetailkey = @c_PickDetailKey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Unallocate Orders Failed (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
            
            FETCH NEXT FROM @CUR_ORDRMV INTO @c_PickDetailKey 
         END 
         CLOSE @CUR_ORDRMV
         DEALLOCATE @CUR_ORDRMV

         ; WITH LPO ( Loadkey, LoadLineNumber )
         AS (  SELECT lpd.Loadkey
                     ,lpd.LoadLineNumber
               FROM @TORD AS t 
               JOIN LOADPLANDETAIL AS lpd WITH (NOLOCK) ON lpd.OrderKey = t.OrderKey
            ) 
         
         DELETE lpd
         FROM LOADPLANDETAIL lpd 
         WHERE lpd.Loadkey = @c_Loadkey
         AND lpd.LoadLineNumber = @c_LoadLineNumber
            
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Remove Orders from LOADPLANDETAIL Failed (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END
         
         ;WITH WV ( WaveDetailKey )
         AS (
               SELECT wd.wavedetailkey
               FROM @TORD AS t 
               JOIN WAVEDETAIL AS wd  WITH (NOLOCK) ON wd.OrderKey = t.OrderKey
             )
         
         DELETE WD
         FROM WV
         JOIN WAVEDETAIL WD ON WD.WaveDetailKey = WV.WaveDetailKey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Remove Orders from WAVEDETAIL Failed (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO RETURN_SP
         END
          
         SET @c_ReleasedFlag = 'N'
         SELECT TOP 1 @c_ReleasedFlag = 'Y'
         FROM WAVEDETAIL AS w WITH (NOLOCK)
         WHERE w.WaveKey = @c_Wavekey
      END

      IF @n_continue IN (1,2)
      BEGIN
         IF @c_ReleasedFlag = 'N' 
         BEGIN
            UPDATE WAVE
                SET TMReleaseFlag = 'N'               
                 ,  TrafficCop = NULL                 
                 ,  EditWho = SUSER_SNAME()           
                 ,  EditDate= GETDATE()               
            WHERE WAVEKEY = @c_Wavekey

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_continue = 3
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
               SET @n_err = 81160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update on wave Failed (ispRVWAV38)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
               GOTO RETURN_SP
            END
         END
      END
   END

   -----Remove 'PTLStation Record------
   --v1.6 2021-03-06
   IF @n_continue IN ( 1,2 ) AND @c_Orderkey = ''
   BEGIN
      SELECT @c_PTLStationLogQueue = ISNULL(sc.SValue,'0')
      FROM RDT.StorerConfig AS sc WITH (NOLOCK) 
      WHERE sc.Function_ID = 805
      AND sc.Storerkey = @c_StorerKey
      AND sc.Configkey = 'PTLStationLogQueue'
      
      IF @c_PTLStationLogQueue = 1
      BEGIN
      	; WITH PLTS (RowRef) AS
      	(
      	   SELECT p.RowRef
   	      FROM rdt.rdtPTLStationLogQueue p (NOLOCK)
   	      WHERE p.WaveKey = @c_wavekey
            AND   p.Storerkey = @c_Storerkey
         )

         DELETE PS
      	FROM PLTS PS
      	JOIN rdt.rdtPTLStationLogQueue p ON PS.Rowref = p.RowRef
      END
      ELSE
      BEGIN
      	; WITH PLTS (RowRef) AS
      	(
      	   SELECT p.RowRef
   	      FROM rdt.rdtPTLStationLog p (NOLOCK)
   	      WHERE p.WaveKey = @c_wavekey
            AND   p.Storerkey = @c_Storerkey
      	)
      	
      	DELETE PS
      	FROM PLTS PS
      	JOIN rdt.rdtPTLStationLog AS rpsl ON PS.Rowref = rpsl.RowRef
      END	
   END
RETURN_SP:
   WHILE @@TRANCOUNT < @n_starttcnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3 AND @@TRANCOUNT > @n_starttcnt -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, "ispRVWAV38"
--      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END --sp end

GO