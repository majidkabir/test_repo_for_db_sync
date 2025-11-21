SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_GetTMLPStatusCartons                           */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: Loadplan Task Release Strategy for IDSUS TITAN Project      */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetTMLPStatusCartons]   
   @c_LoadKey     NVARCHAR(10),  
   @n_err         INT OUTPUT,  
   @c_ErrMsg      NVARCHAR(250) OUTPUT  
AS    
BEGIN
    SET NOCOUNT ON     
    SET ANSI_NULLS OFF     
    SET QUOTED_IDENTIFIER OFF     
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_continue       INT
           ,@c_PickDetailKey  NVARCHAR(10)
           ,@c_taskdetailkey  NVARCHAR(10)
           ,@c_pickloc        NVARCHAR(10)
           ,@b_success        INT
           ,@n_ShipTo         INT
           ,@c_PickMethod     NVARCHAR(10)
           ,@c_RefTaskKey     NVARCHAR(10)  
    
    DECLARE @n_cnt            INT   
    
    DECLARE @c_sku            NVARCHAR(20)
           ,@c_id             NVARCHAR(18)
           ,@c_fromloc        NVARCHAR(10)
           ,@c_toloc          NVARCHAR(10)
           ,@c_PnDLocation    NVARCHAR(10)
           ,@n_InWaitingList  INT
           ,@n_SKUCnt         INT
           ,@n_PickQty        INT
           ,@c_Status         NVARCHAR(10)
           ,@c_StorerKey      NVARCHAR(15)
           ,@n_PalletQty      INT
           ,@n_StartTranCnt   INT
           ,@c_LaneType       NVARCHAR(20)  
           ,@c_Priority       NVARCHAR(10)
    
    
    SELECT @n_continue = 1
          ,@n_err = 0
          ,@c_ErrMsg = ''  
    
    SET @n_StartTranCnt = @@TRANCOUNT 
    
    BEGIN TRAN  
    
    
    IF @n_continue=1 OR
       @n_continue=2
    BEGIN
        SELECT @c_PickDetailKey = ''    
        SELECT @c_pickloc = ''    
        
        DECLARE C_PickTask  CURSOR LOCAL FAST_FORWARD READ_ONLY 
        FOR
            SELECT p.LOC
                  ,p.ID
                  ,COUNT    (DISTINCT o.ConsigneeKey) AS ShipTo
                  ,SUM      (p.Qty) AS AllocatedQty
                  ,lp.Priority 
            FROM   PickDetail p WITH (NOLOCK)
                   JOIN LoadPlanDetail lpd WITH (NOLOCK)
                        ON  lpd.OrderKey = p.OrderKey 
                   JOIN ORDERS o WITH (NOLOCK)
                        ON  o.OrderKey = p.OrderKey
                   JOIN LoadPlan lp WITH (NOLOCK) 
                        ON lp.LoadKey = lpd.LoadKey 
            WHERE  lpd.LoadKey = @c_LoadKey
            GROUP BY
                   p.LOC
                  ,p.ID 
                  ,lp.Priority 
        
        OPEN C_PickTask 
        
        FETCH NEXT FROM C_PickTask INTO @c_FromLoc, @c_ID, @n_ShipTo, @n_PickQty, @c_Priority                                
        
        WHILE (@@FETCH_STATUS<>-1)
        BEGIN
            SET @c_ToLoc = ''  
            
            SELECT TOP 1 
                   @c_StorerKey = StorerKey
                  ,@n_SKUCnt = COUNT(DISTINCT SKU)
                  ,@c_SKU = MAX(SKU)
                  ,@n_PalletQty = SUM(Qty- QtyPicked)
            FROM   LOTxLOCxID LLI(NOLOCK)
            WHERE  LLI.ID = @c_ID
            GROUP BY
                   LLI.StorerKey  
            
            IF @n_SKUCnt>1
            BEGIN
                SET @n_SKUCnt = 1
            END
            ELSE
                SET @c_sku = ''  
            
            IF @n_PalletQty=@n_PickQty
                SET @c_PickMethod = 'FP' -- Full Pallet
            ELSE
                SET @c_PickMethod = 'PP' -- Partial Pallet  
            
            -- Is Loadplan.UserDefine08 = 'Y' (Work Order)
            -- Then go to VAS Location  
            IF EXISTS(
                   SELECT 1
                   FROM   Loadplan WITH (NOLOCK)
                   WHERE  LoadKey = @c_LoadKey AND
                          ISNUMERIC(UserDefine10) = 1
               )
            BEGIN
                SET @c_LaneType = 'VAS'
                
                SELECT TOP 1 
                       @c_ToLoc = LOC
                FROM   LoadPlanLaneDetail LPLD WITH (NOLOCK)
                WHERE  LPLD.LoadKey = @c_LoadKey AND
                       LPLD.LocationCategory = 'VAS'
            END
            ELSE 
            IF @n_ShipTo=1 -- 1 Ship to then go to processing area
            BEGIN
                SET @c_LaneType = 'Processing Area'
                
                SELECT TOP 1 
                       @c_ToLoc = LPLD.LOC
                FROM   LoadPlanLaneDetail LPLD WITH (NOLOCK)
                       LEFT OUTER JOIN (
                                SELECT LoadKey
                                      ,TOLOC
                                      ,COUNT(DISTINCT TOID) AS Pallets
                                FROM   TaskDetail TD WITH (NOLOCK)
                                WHERE  TD.LoadKey = @c_LoadKey AND
                                       TD.SourceType = 'isp_GetTMLPStatusCartons'
                                GROUP BY
                                       LoadKey
                                      ,TOLOC
                            ) AS TDL
                            ON  TDL.LoadKey = LPLD.LoadKey
                       LEFT OUTER JOIN LOC l WITH (NOLOCK)
                            ON  l.Loc = TDL.TOLOC
                WHERE  LPLD.LoadKey = @c_LoadKey AND
                       LPLD.LocationCategory = 'PROC' AND
                       (TDL.Pallets<L.MaxPallet OR TDL.Pallets IS NULL)
            END
            ELSE
            BEGIN
                SET @c_LaneType = 'HVCP'
                
                SELECT TOP 1 
                       @c_ToLoc = LPLD.LOC
                FROM   LoadPlanLaneDetail LPLD WITH (NOLOCK)
                       LEFT OUTER JOIN (
                                SELECT LoadKey 
                                      ,TOLOC
                                      ,COUNT(DISTINCT TOID) AS Pallets
                                FROM   TaskDetail TD WITH (NOLOCK)
                                WHERE  TD.LoadKey = @c_LoadKey AND
                                       TD.SourceType = 'isp_GetTMLPStatusCartons'
                                GROUP BY
                                       LoadKey
                                      ,TOLOC
                            ) AS TDL
                            ON  TDL.LoadKey = LPLD.LoadKey
                       LEFT OUTER JOIN LOC l WITH (NOLOCK)
                            ON  l.Loc = TDL.TOLOC
                WHERE  LPLD.LoadKey = @c_LoadKey AND
                       LPLD.LocationCategory = 'HVCP' AND
                       (TDL.Pallets<L.MaxPallet OR TDL.Pallets IS NULL)
            END   
            
            IF @c_ToLoc=''
            BEGIN
                SELECT @n_continue = 3    
                SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                      ,@n_err = 81004 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
                SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                       ': No ('+@c_LaneType+
                       ') Lanes Assigned to Load, Generate Task Failed (isp_GetTMLPStatusCartons)'
            END 
            -- INSERT Task from VNA to Pick & Drop Location  
            IF @n_continue=1 OR
               @n_continue=2
            BEGIN
                SET @c_PnDLocation = ''  
                
                SELECT TOP 1 
                       @c_PnDLocation = L.LOC
                FROM   LOC L WITH (NOLOCK)
                       JOIN LOC FromLOC WITH (NOLOCK)
                            ON  FromLOC.LocAisle = L.LocAisle
                       LEFT OUTER JOIN LOTxLOCxID LLI WITH (NOLOCK)
                            ON  LLI.Loc = L.Loc
                WHERE  L.LocationCategory IN ('PnD_Ctr' ,'PnD_Out') AND
                       FromLOC.LOC = @c_fromloc
                GROUP BY
                       CASE 
                            WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1
                            WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1
                            WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1
                            ELSE 2
                       END
                      ,L.LOC
                      ,L.LogicalLocation
                      ,L.LocAisle
                HAVING SUM(ISNULL(LLI.Qty ,0)+ISNULL(LLI.PendingMoveIN ,0))=0
                ORDER BY
                       L.LocAisle
                      ,CASE 
                         WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1
                         WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1
                         WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1
                         ELSE 2
                       END
                      ,L.LogicalLocation
                      ,L.LOC 
                
                -- If No more Empty P&D Location, then just get 1st P&D Location         
                IF @c_PnDLocation='' OR
                   @c_PnDLocation IS NULL
                BEGIN
                    SELECT TOP 1 
                           @c_PnDLocation = L.LOC
                    FROM   LOC L WITH (NOLOCK)
                           JOIN LOC FromLOC WITH (NOLOCK)
                                ON  FromLOC.LocAisle = L.LocAisle
                    WHERE  L.LocationCategory IN ('PnD_Ctr' ,'PnD_Out') AND
                           FromLOC.LOC = @c_fromloc
                    GROUP BY
                           CASE 
                               WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1
                               WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1
                               WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1
                               ELSE 2
                           END
                          ,L.LOC
                          ,L.LogicalLocation
                          ,L.LocAisle
                    ORDER BY
                           L.LocAisle
                          ,CASE 
                               WHEN @c_LaneType = 'HVCP' AND L.LocationCategory='PnD_Ctr' THEN 1
                               WHEN @c_LaneType = 'VAS'  AND L.LocationCategory='PnD_Ctr' THEN 1
                               WHEN @c_LaneType = 'PROC' AND L.LocationCategory='PnD_Out' THEN 1
                               ELSE 2
                           END
                          ,L.LogicalLocation
                          ,L.LOC                    
                    
                    IF ISNULL(RTRIM(@c_PnDLocation) ,'')<>''
                    BEGIN
                        SET @n_InWaitingList = 1  
                        SET @c_Status = 'Q'
                    END
                END
                ELSE
                BEGIN
                    SET @n_InWaitingList = 0  
                    SET @c_Status = '0'
                END
            END  
            
            IF @n_continue=1 OR
               @n_continue=2
            BEGIN
                -- Create 2 Tasks. 1 to PnD location, another from PnD Location to the Final Destination
                -- Insert into taskdetail Main    
                EXECUTE nspg_getkey 
                'TaskDetailKey', 
                10, 
                @c_taskdetailkey OUTPUT, 
                @b_success OUTPUT, 
                @n_err OUTPUT, 
                @c_ErrMsg OUTPUT    
                IF NOT @b_success=1
                BEGIN
                    SELECT @n_continue = 3    
                    SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                          ,@n_err = 81005 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
                    SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                           ': Unable to Get TaskDetailKey (isp_GetTMLPStatusCartons)' 
                          +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg 
                          +' ) '
                END
                ELSE
                BEGIN
                    INSERT TASKDETAIL
                      (
                        TaskDetailKey
                       ,TaskType
                       ,Storerkey
                       ,Sku
                       ,Lot
                       ,UOM
                       ,UOMQty
                       ,Qty
                       ,FromLoc
                       ,FromID
                       ,ToLoc
                       ,ToId
                       ,SourceType
                       ,SourceKey
                       ,Caseid
                       ,Priority
                       ,SourcePriority
                       ,OrderKey
                       ,OrderLineNumber
                       ,PickDetailKey
                       ,PickMethod
                       ,STATUS
                       ,LoadKey 
                      )
                    VALUES
                      (
                        @c_taskdetailkey
                       ,'PK'
                       ,@c_Storerkey
                       ,@c_sku
                       ,''	-- Lot,
                       ,''	-- UOM,
                       ,0	-- UOMQty,
                       ,@n_PickQty
                       ,@c_fromloc
                       ,@c_id
                       ,@c_PnDLocation
                       ,@c_id
                       ,'isp_GetTMLPStatusCartons'
                       ,@c_LoadKey
                       ,''	-- Caseid
                       ,@c_Priority -- Priority
                       ,'9'
                       ,''	-- Orderkey,
                       ,''	-- OrderLineNumber
                       ,''	-- PickDetailKey
                       ,@c_PickMethod
                       ,@c_Status
                       ,@c_LoadKey 
                      )  
                    
                    SELECT @n_err = @@ERROR    
                    IF @n_err<>0
                    BEGIN
                        SELECT @n_continue = 3    
                        SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                              ,@n_err = 81006 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
                        SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                               ': Insert Into TaskDetail Failed (isp_GetTMLPStatusCartons)' 
                              +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg 
                              +' ) '
                        
                        GOTO QUIT_SP
                    END
                    
                    SET @c_RefTaskKey = @c_taskdetailkey  
                    
                    IF @n_continue=1 OR
                       @n_continue=2
                    BEGIN
                        EXECUTE nspg_getkey 
                        'TaskDetailKey', 
                        10, 
                        @c_taskdetailkey OUTPUT, 
                        @b_success OUTPUT, 
                        @n_err OUTPUT, 
                        @c_ErrMsg OUTPUT    
                        IF NOT @b_success=1
                        BEGIN
                            SELECT @n_continue = 3    
                            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                                  ,@n_err = 81007 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
                            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                                   ': Unable to Get TaskDetailKey (isp_GetTMLPStatusCartons)' 
                                  +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg 
                                  +' ) '
                        END
                        ELSE
                        BEGIN
                            INSERT TASKDETAIL
                              (
                                TaskDetailKey
                               ,TaskType
                               ,Storerkey
                               ,Sku
                               ,Lot
                               ,UOM
                               ,UOMQty
                               ,Qty
                               ,FromLoc
                               ,FromID
                               ,ToLoc
                               ,ToId
                               ,SourceType
                               ,SourceKey
                               ,--WaveKey,    
                                Caseid
                               ,Priority
                               ,SourcePriority
                               ,OrderKey
                               ,OrderLineNumber
                               ,PickDetailKey
                               ,PickMethod
                               ,RefTaskKey
                               ,[Status]
                               ,LoadKey 
                              )
                            VALUES
                              (
                                @c_taskdetailkey
                               ,'NMV'
                               ,@c_Storerkey
                               ,@c_sku
                               ,''	-- Lot,
                               ,''	-- UOM,
                               ,0	-- UOMQty,
                               ,@n_PickQty
                               ,@c_PnDLocation
                               ,@c_id
                               ,@c_toloc
                               ,@c_id
                               ,'isp_GetTMLPStatusCartons'
                               ,@c_LoadKey
                               ,''	-- Caseid,
                               ,@c_Priority
                               ,'9'
                               ,''	-- Orderkey,
                               ,''	-- OrderLineNumber
                               ,''	-- PickDetailKey
                               ,@c_PickMethod
                               ,@c_RefTaskKey
                               ,'W'
                               ,@c_LoadKey
                              )  
                            
                            
                            SELECT @n_err = @@ERROR    
                            IF @n_err<>0
                            BEGIN
                                SELECT @n_continue = 3    
                                SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                                      ,@n_err = 81008 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
                                SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err) 
                                      +
                                       ': Insert Into TaskDetail Failed (isp_GetTMLPStatusCartons)' 
                                      +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg 
                                      +' ) '
                                
                                GOTO QUIT_SP
                            END
                        END -- If continue
                    END
                END -- insert into taskdetail
            END-- Insert into taskdetail Main  
            
            FETCH NEXT FROM C_PickTask INTO @c_FromLoc, @c_ID, @n_ShipTo, @n_PickQty, @c_Priority 
        END -- WHILE 1=1  
        CLOSE C_PickTask 
        DEALLOCATE C_PickTask
    END--**    
    
    -- Release Lane if No Task required to move to the Lane
    DECLARE CUR_RELEASE_LANE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT LPLD.LOC
       FROM   LoadPlanLaneDetail LPLD WITH (NOLOCK)
       WHERE  LPLD.LoadKey = @c_LoadKey
       AND    LPLD.[Status] < '9'
       
    OPEN CUR_RELEASE_LANE
    
    FETCH NEXT FROM CUR_RELEASE_LANE INTO @c_toloc 
    
    WHILE @@FETCH_STATUS <> -1
    BEGIN
       
       IF NOT EXISTS(SELECT 1  
                    FROM   TaskDetail TD WITH (NOLOCK)
                    WHERE  TD.LoadKey = @c_LoadKey AND 
                           TD.SourceType = 'isp_GetTMLPStatusCartons' AND 
                           TD.[Status] NOT IN ('9' ,'S' ,'R') AND
                           TD.ToLoc = @c_toloc)
       BEGIN
          UPDATE LoadPlanLaneDetail   
            SET [Status] = '9' 
          WHERE  LoadKey = @c_LoadKey
          AND    [Status] < '9' 
          AND    LOC = @c_toloc 
       END                    
                
       FETCH NEXT FROM CUR_RELEASE_LANE INTO @c_toloc
    END
    CLOSE CUR_RELEASE_LANE
    DEALLOCATE CUR_RELEASE_LANE 
       
                    
    
    -- Trigger outbound IML for WCS 
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
	   SELECT @b_success = 0  
      
      DECLARE @c_Facility  NVARCHAR(5), 
              @c_authority NVARCHAR(10)
              
      SELECT TOP 1 @c_Facility = O.Facility, 
                   @c_StorerKey = O.StorerKey 
      FROM LoadPlanDetail lpd WITH (NOLOCK)
      JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey 
      WHERE lpd.LoadKey = @c_LoadKey
      ORDER BY lpd.LoadLineNumber
      
	   EXECUTE nspGetRight 
	            @c_Facility,  -- facility
				   @c_StorerKey, -- Storerkey
				   null,         -- Sku
				   'WMSWCSLP',   -- Configkey
				   @b_success    output,
				   @c_authority  output, 
				   @n_err        output,
				   @c_errmsg     output

      IF @c_authority = '1' AND @b_success = 1
      BEGIN
		    EXEC dbo.ispGenTransmitLog3 'WMSWCSLP', @c_LoadKey, '' , '', ''
		       , @b_success OUTPUT
		       , @n_err OUTPUT
		       , @c_errmsg OUTPUT
		    IF @b_success <> 1
		    BEGIN
			    SELECT @n_continue = 3
			    GOTO Quit_SP
		    END
		END       
    END
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
      DECLARE @c_OrderKey NVARCHAR(10), 
              @c_OrderPickHeaderKey NVARCHAR(10),
              @c_LoadPickHeaderKey NVARCHAR(10)

      IF NOT EXISTS(SELECT 1 FROM PICKHEADER p WITH (NOLOCK) WHERE p.ExternOrderKey = @c_LoadKey
                    AND p.OrderKey = '')
      BEGIN
         SELECT @b_success = 0
         
		   EXECUTE nspg_GetKey
			   'PICKSLIP',
			   9,
			   @c_LoadPickHeaderKey OUTPUT,
			   @b_success OUTPUT,
			   @n_err OUTPUT,
			   @c_errmsg OUTPUT
   			         
		   SELECT @c_LoadPickHeaderKey = 'P' + @c_LoadPickHeaderKey
   		
		   INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderkey, OrderKey, PickType, Zone, TrafficCop)
		   VALUES (@c_LoadPickHeaderKey, @c_LoadKey, '', '0', 'C', '')

			SELECT @n_err = @@ERROR
			IF @n_err <> 0
			BEGIN
				SELECT @n_continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 81009 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err) 
                 +
                  ': Insert Into PickHeader Failed (isp_GetTMLPStatusCartons)' 
                 +' ( '+' SQLSvr MESSAGE='+@c_ErrMsg 
                 +' ) '
				GOTO Quit_SP
			END		   
      END
	   
      DECLARE Cur_OrderKey CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT O.OrderKey
         FROM LoadPlanDetail lpd WITH (NOLOCK)
         JOIN ORDERS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey 
         WHERE lpd.LoadKey = @c_LoadKey
         ORDER BY lpd.LoadLineNumber
      
      OPEN Cur_OrderKey 
      
      FETCH NEXT FROM Cur_OrderKey INTO @c_OrderKey 
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM PICKHEADER p WITH (NOLOCK) WHERE p.ExternOrderKey = @c_LoadKey
                       AND p.OrderKey = @c_OrderKey)
         BEGIN
			   EXECUTE nspg_GetKey
				   'PICKSLIP',
				   9,
				   @c_OrderPickHeaderKey OUTPUT,
				   @b_success OUTPUT,
				   @n_err OUTPUT,
				   @c_errmsg OUTPUT
   				         
			   SELECT @c_OrderPickHeaderKey = 'P' + @c_OrderPickHeaderKey

			   INSERT INTO PICKHEADER
			   (PickHeaderKey, ExternOrderkey, Orderkey, PickType, Zone, TrafficCop)
			   VALUES
			   (@c_OrderPickHeaderKey, @c_Loadkey, @c_OrderKey, '0', 'D', '')
   					
			   SELECT @n_err = @@ERROR
			   IF @n_err <> 0
			   BEGIN
				   SELECT @n_continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                     ,@n_err = 81010 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                      ': Insert Into PickHeader Failed (isp_GetTMLPStatusCartons)'+' ( ' 
                     +' SQLSvr MESSAGE='+@c_ErrMsg 
                     +' ) '					   
				   GOTO Quit_SP
			   END

			   
			   IF NOT EXISTS (SELECT 1 FROM PACKHEADER p WITH (NOLOCK) 
			                  WHERE p.LoadKey = @c_LoadKey
			                    AND p.OrderKey = @c_OrderKey
			                    AND p.PickSlipNo = @c_OrderPickHeaderKey)
			   BEGIN
		         INSERT INTO PackHeader
		         (
		            PickSlipNo,
		            StorerKey,
		            [Route],
		            OrderKey,
		            OrderRefNo,
		            LoadKey,
		            ConsigneeKey,
		            [Status]
		         )
		         VALUES
		         (
		            @c_OrderPickHeaderKey,
		            @c_StorerKey,
		            '',  -- Route
		            @c_OrderKey,
		            '',  -- OrderRefNo
		            @c_LoadKey,
		            '',  -- ConsigneeKey,
		            '0'
		         )
		         SELECT @n_err = @@ERROR
		         IF @n_err <> 0
		         BEGIN
			         SELECT @n_continue = 3
                  SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                        ,@n_err = 81011 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                         ': Insert Into PackHeader Failed (isp_GetTMLPStatusCartons)'+' ( ' 
                        +' SQLSvr MESSAGE='+@c_ErrMsg 
                        +' ) '			      
			         GOTO Quit_SP
		         END
			   END
			   
			   UPDATE PICKDETAIL 
			      SET PickSlipNo = @c_OrderPickHeaderKey, TrafficCop = NULL 
			   WHERE OrderKey = @c_OrderKey 
	         IF @n_err <> 0
	         BEGIN
		         SELECT @n_continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                     ,@n_err = 81012 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                      ': Update PickDetail Failed (isp_GetTMLPStatusCartons)'+' ( ' 
                     +' SQLSvr MESSAGE='+@c_ErrMsg 
                     +' ) '			      
		         GOTO Quit_SP
	         END
			      					         
         END

         FETCH NEXT FROM Cur_OrderKey INTO @c_OrderKey
      END
      CLOSE Cur_OrderKey
      DEALLOCATE Cur_OrderKey     
    END
           
    Quit_SP:
    
    IF @n_continue=3
    BEGIN
        IF @@TRANCOUNT>@n_StartTranCnt
            ROLLBACK TRAN 
        
        EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetTMLPStatusCartons' 
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
    END
    ELSE
    BEGIN
        UPDATE LoadPlan WITH (ROWLOCK)
        SET    PROCESSFLAG = 'Y'
        WHERE  LoadKey = @c_LoadKey  
        
        SELECT @n_err = @@ERROR    
        IF @n_err<>0
        BEGIN
            SELECT @n_continue = 3    
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 81013 -- Should Be Set To The SQL Errmessage but I do't know how to do so.    
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': Update of LoadPlan Failed (isp_GetTMLPStatusCartons)'+' ( ' 
                  +' SQLSvr MESSAGE='+@c_ErrMsg 
                  +' ) '
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT>@n_StartTranCnt 
                  COMMIT TRAN
        END
    END
END

GO