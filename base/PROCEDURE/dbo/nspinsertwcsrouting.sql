SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/            
/* Store procedure: nspInsertWCSRouting                                      */            
/* Copyright      : IDS                                                      */            
/*                                                                           */            
/* Purpose: Sub-SP to insert WCSRouting records                              */            
/*                                                                           */            
/* Modifications log:                                                        */            
/*                                                                           */            
/* Date       Rev  Author   Purposes                                         */            
/* 2010-06-28 1.0  Vicky    Created                                          */            
/* 2010-07-09 1.1  ChewKP   Minor Changes on Error Msg                       */            
/*                          (ChewKP01)                                       */            
/* 2010-07-22 1.2  ChewKP   Additional Actionflag 'D' = Delete (ChewKP02)    */            
/* 2010-07-23 1.3  ChewKP   Fixes on Deletion (ChewKP03)                     */            
/* 2010-07-23 1.4  ChewKP   Update WCSRouting.Status = '5' when ActionFlag=D */            
/*                          (ChewKP04)                                       */            
/* 2010-08-04 1.5  Vicky    Bug fix (Vicky01)                                */            
/* 2010-08-11 1.6  ChewKP   Fixed Multiple QC info being create for the same */            
/*                          Tote (ChewKP05)                                  */            
/* 2010-08-12 1.7  ChewKP   Fixed issues when risidual for PA from Store Pick*/            
/*                          (ChewKP06)                                       */            
/* 2010-08-15 1.8  Shong    For Dynamic Case Pick, PTS location taking from  */          
/*                          PickDetail.Loc                                   */          
/* 2010-08-16 1.9  Vicky    Insert Error from isp_WMS2WCSRoutingValidation   */          
/*                          to TraceInfo (VIcky02)                           */          
/* 2010-08-21 2.0  James    When update WCSRouting use initial final zone &  */          
/*                          update OrderType (james01)                       */          
/* 2010-08-23 2.1  Shong    Prevent Duplicate record added                   */          
/* 2010-08-26 2.2  Shong    Include PTS to QC for short pick (Shong01)       */          
/* 2010-09-02 2.3  ChewKP   New TaskType 'END' Delete (ChewKP07)             */        
/* 2010-09-05 2.4  ChewKP   Add In ActionFlag = 'D' for PA Task (ChewKP08)   */         
/* 2010-09-05 2.5  ChewKP   Add FinalZone and InitialFinalZone to Delete     */      
/*                          Route (ChewKP09)                                 */      
/* 2010-09-14 2.6  ChewKP   Remove checking of TaskType when Insert          */    
/*                          WCSRouting (ChewKP10)                            */     
/* 2010-09-25 2.7  James    Filter out shipped pickdetail when creating DPK  */    
/*                          Routing (James02)                                */     
/* 2010-09-27 2.8  Shong    Filter QC Insertion should refer to RoutingDetail*/    
/*                          instead of WCSRouting Header. (Shong02)          */    
/* 2010-12-27 2.9  James    Shorten error message (james03)                  */    
/* 2011-05-12 3.0  ChewKP   Begin Tran and Commit Tran issues (ChewKP10)     */
/* 2012-06-18 3.1  ChewKP   SOS#247246 Delete WCS Routing when Tote          */
/*                          Consolidation (ChewKP11)                         */
/* 2014-06-23 3.2  James    SOS313463-Cater additional pickmethod (james04)  */
/* 2015-09-30 3.3  tlting   Deadlock Tune                                    */
/* 2016-10-13 3.4  James    WMS493-Enhancement on routing (james05)          */
/* 2017-04-05 3.5  James    WMS1349-Get current task type and stamp into     */
/*                          wcsrouting for TM piece picking (james06)        */
/*****************************************************************************/            
CREATE PROC [dbo].[nspInsertWCSRouting]            
@c_StorerKey     NVARCHAR(15) ,            
@c_Facility      NVARCHAR(10) ,            
@c_ToteNo        NVARCHAR(18) ,            
@c_TaskType      NVARCHAR(10) ,            
@c_ActionFlag    NVARCHAR(1)  , -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual            
@c_TaskDetailKey NVARCHAR(10) ,         
@c_Username      NVARCHAR(18) ,            
@b_debug         INT     = 0 ,        
@b_Success       INT         OUTPUT,            
@n_ErrNo         INT         OUTPUT,          @c_ErrMsg        NVARCHAR(20) OUTPUT            
AS
BEGIN          
  SET NOCOUNT ON          
              
  DECLARE @n_continue  INT,             
          @n_starttcnt INT            
            
  DECLARE @c_OrderType    NVARCHAR(10),            
          @c_FinalWCSZone NVARCHAR(10),            
          @c_PTSLOC       NVARCHAR(10),            
          @c_Consigneekey NVARCHAR(15),            
          @c_WCSKey       NVARCHAR(10),            
          @c_PrevWCSKey   NVARCHAR(10),            
          @c_PutawayZone  NVARCHAR(10),            
          @c_Orderkey     NVARCHAR(10),            
          @c_ToLOC        NVARCHAR(10),            
          @c_CurrentZone  NVARCHAR(10),            
          @c_WCSStation   NVARCHAR(20),          
          @c_LastActionFlag NVARCHAR(1), -- (shong01)           
          @c_NewActionFlag  NVARCHAR(1),  -- (shong01)          
          @cInit_Final_Zone NVARCHAR(10), -- (james01)          
          @c_curWCSkey     NVARCHAR(10),
          @c_curTaskType   NVARCHAR(10)   -- (james06)

  DECLARE @c_NextDayDelivery     NVARCHAR( 1)   -- (james05)
              
  DECLARE @n_RowRef       INT            
            
	SELECT @n_Continue = 1,           
	      @b_success = 1,           
	      @n_starttcnt=@@TRANCOUNT,           
	      @c_ErrMsg='',           
	      @n_ErrNo = 0          
                     
	SELECT @c_OrderType = ''            
           
	-- (james01)           
	IF @c_TaskType = 'PTS'          
	BEGIN          
	  	SET @c_OrderType = 'CASE'           
	END          
	ELSE          
	BEGIN          
		SELECT @c_OrderType = PickMethod            
	  	FROM TaskDetail WITH (NOLOCK)            
	  	WHERE TaskDetailKey = @c_TaskDetailKey                   
	END             
            
	IF @c_TaskType = 'PK'            
	BEGIN            
		IF @c_ActionFlag = 'N' -- New Tote/            
		BEGIN            
			-- to check whether there is another Tote with the same ToteNo in use and active            
	     	BEGIN TRAN            
	     	EXEC dbo.isp_WMS2WCSRoutingValidation             
	          @c_ToteNo,             
	          @c_StorerKey,            
	          @b_Success OUTPUT,            
	          @n_ErrNo  OUTPUT,             
	          @c_ErrMsg OUTPUT            
	         
			IF @n_ErrNo <> 0             
			BEGIN            
				SELECT @n_continue = 3            
			  	SELECT @n_ErrNo = @n_ErrNo             
			  	SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' ' + ISNULL(RTRIM(@c_ErrMsg), '') -- (ChewKP01)            
			  	GOTO Quit_SP            
			END          
			ELSE            
			BEGIN            
			  	COMMIT TRAN            
			END            
            
			IF @b_debug = 1            
			BEGIN            
				SELECT @c_OrderType '@c_OrderType'            
			END             
            
      	IF @c_OrderType LIKE 'SINGLES%'            
      	BEGIN            
      	   -- (james03)
	      	SELECT @b_success = 0
	
	      	EXECUTE nspGetRight
					NULL,  -- Facility
					@c_StorerKey,      -- Storer
					NULL,              -- No Sku in this Case
					'NextDayDelivery', -- ConfigKey
					@b_success             OUTPUT,
					@c_NextDayDelivery     OUTPUT,
					@n_ErrNo                 OUTPUT,
					@c_ErrMsg              OUTPUT
	
	      	IF @b_success <> 1
	      	BEGIN
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70397            
					SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
					GOTO Quit_SP            
				END

            SET @c_FinalWCSZone = ''
				IF @c_NextDayDelivery = '1'
				BEGIN
				   -- (james06)
				   SELECT @c_CurTaskType = TaskType
				   FROM dbo.TaskDetail WITH (NOLOCK) 
				   WHERE TaskDetailKey = @c_TaskDetailKey

				   -- If orders from taskdetail belong to the define orders.incoterm (setup in codelkup.udf01-05)
				   -- Then take the valud long as final destination
				   -- Prerequitesite task have to be group into incoterm
					SELECT TOP 1 @c_FinalWCSZone = ISNULL(RTRIM(LONG), '') 
					FROM dbo.PickDetail PD WITH (NOLOCK)
				   JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
				   JOIN dbo.CODELKUP C WITH (NOLOCK) ON ( O.UserDefine01 = C.Code)
					WHERE PD.TaskDetailKey = @c_TaskDetailKey
					AND   C.ListName = 'WCSROUTE'
					AND   C.Code = @c_OrderType
					AND   O.IncoTerm IN (C.UDF01, C.UDF02, C.UDF03, C.UDF04, C.UDF05)
					AND   O.StorerKey = @c_StorerKey
				END

            IF ISNULL( @c_FinalWCSZone, '') = ''
				   -- only send final destination            
				   SELECT @c_FinalWCSZone = ISNULL(RTRIM(SHORT), '')            
				   FROM CODELKUP WITH (NOLOCK)            
				   WHERE Listname = 'WCSROUTE'            
				   AND   Code = @c_OrderType            
            
				IF @b_debug = 1            
				BEGIN            
					SELECT @c_FinalWCSZone '@c_FinalWCSZone Singles'            
				END             
				
				IF ISNULL(RTRIM(@c_FinalWCSZone), '') = ''            
				BEGIN            
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70366             
					SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCSROUTE Not Setup'            
					GOTO Quit_SP            
				END            
          	ELSE            
          	BEGIN       
					-- Insert WCSRouting            
					-- Generate WCSKey            
               BEGIN TRAN -- (ChewKP10)       
                                        
               EXECUTE nspg_GetKey            
               	'WCSKey',            
                	10,               
                	@c_WCSKey      OUTPUT,            
                	@b_success     OUTPUT,            
                	@n_ErrNo       OUTPUT,            
                	@c_ErrMsg      OUTPUT            
               
               
					IF @n_ErrNo <> 0             
					BEGIN            
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70367             
						SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
						GOTO Quit_SP            
					END       
					ELSE            
					BEGIN            
						COMMIT TRAN            
					END            
          
					BEGIN TRAN            
					
					INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)            
					VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_FinalWCSZone,''), ISNULL(@c_FinalWCSZone,''), 'I',  @c_StorerKey, @c_Facility, @c_OrderType, @c_CurTaskType) -- Insert            
					
					SELECT @n_ErrNo = @@ERROR            
					
					IF @n_ErrNo <> 0             
					BEGIN            
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70368            
						SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
						GOTO Quit_SP            
					END            
					ELSE            
					BEGIN            
						COMMIT TRAN            
					END            
    
					BEGIN TRAN            
					
					INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
					VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_FinalWCSZone,''), 'I') -- Insert            
					
					SELECT @n_ErrNo = @@ERROR            
					
					IF @n_ErrNo <> 0             
					BEGIN            
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70369            
						SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
						GOTO Quit_SP            
					END            
					ELSE            
					BEGIN            
						COMMIT TRAN            
					END            
                         
					IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)            
					BEGIN            
						DELETE FROM WCSRouting WITH (ROWLOCK)          
						WHERE WCSKey = @c_WCSKey            
					
						GOTO Skip_WCS_Records            
					END            
					ELSE            
					BEGIN            
						GOTO Gen_WCS_Records            
					END            
         	END            
      	END -- SINGLES            
      	ELSE IF (@c_OrderType LIKE 'DOUBLES%' OR @c_OrderType LIKE 'MULTIS%')            
      	BEGIN            
      	   -- (james03)
	      	SELECT @b_success = 0
	
	      	EXECUTE nspGetRight
					NULL,  -- Facility
					@c_StorerKey,      -- Storer
					NULL,              -- No Sku in this Case
					'NextDayDelivery', -- ConfigKey
					@b_success             OUTPUT,
					@c_NextDayDelivery     OUTPUT,
					@n_ErrNo                 OUTPUT,
					@c_ErrMsg              OUTPUT
	
	      	IF @b_success <> 1
	      	BEGIN
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70397            
					SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
					GOTO Quit_SP            
				END

            SET @c_FinalWCSZone = ''
				IF @c_NextDayDelivery = '1'
				BEGIN
		         -- (james06)
				   SELECT @c_CurTaskType = TaskType
				   FROM dbo.TaskDetail WITH (NOLOCK) 
				   WHERE TaskDetailKey = @c_TaskDetailKey

				   -- If orders from taskdetail belong to the define orders.incoterm (setup in codelkup.udf01-05)
				   -- Then take the valud long as final destination
				   -- Prerequitesite task have to be group into incoterm
					SELECT TOP 1 @c_FinalWCSZone = ISNULL(RTRIM(LONG), '') 
					FROM dbo.PickDetail PD WITH (NOLOCK)
				   JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
				   JOIN dbo.CODELKUP C WITH (NOLOCK) ON ( O.UserDefine01 = C.Code)
					WHERE PD.TaskDetailKey = @c_TaskDetailKey
					AND   C.ListName = 'WCSROUTE'
					AND   C.Code = @c_OrderType
					AND   O.IncoTerm IN (C.UDF01, C.UDF02, C.UDF03, C.UDF04, C.UDF05)
					AND   O.StorerKey = @c_StorerKey
				END

            IF ISNULL( @c_FinalWCSZone, '') = ''
				   SELECT @c_FinalWCSZone = ISNULL(RTRIM(SHORT), '')            
				   FROM  CODELKUP WITH (NOLOCK)            
				   WHERE Listname = 'WCSROUTE'            
				   AND   Code = @c_OrderType            
				   
				IF @b_debug = 1            
				BEGIN            
				  SELECT @c_FinalWCSZone '@c_FinalWCSZone Doubles/Multis'            
				END             
            
				IF ISNULL(RTRIM(@c_FinalWCSZone), '') = ''            
				BEGIN            
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70370             
					SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCSROUTE Not Setup'            
					GOTO Quit_SP            
				END            
				ELSE            
				BEGIN        
					-- Insert WCSRouting            
               -- Generate WCSKey            
               BEGIN TRAN -- (ChewKP10)  
               
               EXECUTE nspg_GetKey            
               	'WCSKey',            
                	10,               
                	@c_WCSKey    OUTPUT,            
                	@b_success     OUTPUT,            
                	@n_ErrNo       OUTPUT,            
                	@c_ErrMsg      OUTPUT            

					IF @n_ErrNo <> 0             
					BEGIN            
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70371             
						SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
						GOTO Quit_SP            
					END          
					ELSE            
					BEGIN            
						COMMIT TRAN            
					END          
                          
					BEGIN TRAN            
					
					INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)            
					VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_FinalWCSZone,''), ISNULL(@c_FinalWCSZone,''), 'I',  @c_StorerKey, @c_Facility, @c_OrderType, @c_CurTaskType) -- Insert            
					
					SELECT @n_ErrNo = @@ERROR            
					
					IF @n_ErrNo <> 0             
					BEGIN            
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70372            
						SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
						GOTO Quit_SP            
					END            
					ELSE            
					BEGIN            
						COMMIT TRAN            
					END            
                                      
					SELECT TOP 1           
						@c_CurrentZone = LOC.PutawayZone
					FROM LOC LOC WITH (NOLOCK)            
					JOIN TaskDetail TD WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC )            
					WHERE LOC.Facility = @c_Facility            
					AND   TD.TaskDetailKey = @c_TaskDetailKey            
--					AND   TD.TaskType = @c_TaskType            
            
					-- Insert WCSROutingDetail            
					DECLARE PAZone_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
					SELECT DISTINCT LOC.PutawayZone            
					FROM LOC LOC WITH (NOLOCK)            
					JOIN TaskDetail TD WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC )            
					WHERE LOC.Facility = @c_Facility            
					AND   TD.UserKey = @c_Username            
					AND   TD.Status = '3'            
					AND   TD.TaskType = @c_CurTaskType            
					AND   LOC.PutawayZone <> @c_CurrentZone            
            
             	OPEN PAZone_Cur            
            
             	FETCH NEXT FROM PAZone_Cur INTO @c_PutawayZone            
            
             	WHILE (@@FETCH_STATUS <> -1)            
             	BEGIN            
                	IF @b_debug = 1            
                	BEGIN            
                   	SELECT @c_PutawayZone '@c_PutawayZone'            
                	END             

						SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')            
						FROM CODELKUP WITH (NOLOCK)            
						WHERE Listname = 'WCSSTATION'            
						AND   Code = @c_PutawayZone            

						IF @b_debug = 1            
						BEGIN            
							SELECT @c_WCSStation '@c_WCSStation'            
						END             
            
						IF ISNULL(RTRIM(@c_WCSStation), '') = ''            
						BEGIN            
							SELECT @n_continue = 3            
							SELECT @n_ErrNo = 70373             
							SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCS Not Setup'            
							CLOSE PAZone_Cur            
							DEALLOCATE PAZone_Cur            
							GOTO Quit_SP            
						END            
            
						IF @b_debug = 1          
						BEGIN          
							SELECT w.*          
							FROM WCSRoutingDetail w WITH (NOLOCK)           
							WHERE w.ToteNo = @c_ToteNo           
							AND   w.Zone   = @c_WCSStation          
							AND   w.Status < '9'           
							AND   w.WCSKey = @c_WCSKey           
							ORDER BY w.RowRef DESC           
						END          
                          
                	SET @c_LastActionFlag = ''          

						BEGIN TRAN -- (ChewKP10)  
						INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
						VALUES (@c_WCSKey, @c_ToteNo, @c_WCSStation, 'I') -- Insert            
						
						SELECT @n_ErrNo = @@ERROR            
						
						IF @n_ErrNo <> 0             
						BEGIN            
							SELECT @n_continue = 3            
							SELECT @n_ErrNo = 70374            
							SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
							CLOSE PAZone_Cur            
							DEALLOCATE PAZone_Cur            
							GOTO Quit_SP            
						END            
						ELSE            
						BEGIN            
							COMMIT TRAN            
						END            

                	FETCH NEXT FROM PAZone_Cur INTO @c_PutawayZone            
					END -- END WHILE (@@FETCH_STATUS <> -1)            

             	CLOSE PAZone_Cur            
             	DEALLOCATE PAZone_Cur            
            
             	IF NOT EXISTS (SELECT COUNT(1) FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)      
             	BEGIN            
						DELETE FROM WCSRouting WITH (ROWLOCK)            
                	WHERE WCSKey = @c_WCSKey            
          
                	GOTO Skip_WCS_Records            
             	END            
             	ELSE    
             	BEGIN            
						BEGIN TRAN          
                    
                  INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)          
                  VALUES (@c_WCSKey, @c_ToteNo, @c_FinalWCSZone, 'I') -- Insert          
        
						SELECT @n_ErrNo = @@ERROR          
        
						IF @n_ErrNo <> 0           
						BEGIN          
							SELECT @n_continue = 3          
							SELECT @n_ErrNo = 70375          
							SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'          
							GOTO Quit_SP          
						END          
						ELSE          
						BEGIN          
							COMMIT TRAN          
						END          
                   
						GOTO Gen_WCS_Records            
             	END      
				END -- Insert WCSRouting            
      	END --Doubles / Multis            
      	IF @c_OrderType LIKE 'PIECE%'            
      	BEGIN            
	         -- only send final destination            
	         SELECT @c_ToLOC = ISNULL(RTRIM(ToLOC), '')            
	         FROM TaskDetail WITH (NOLOCK)            
	         WHERE TaskDetailKey = @c_TaskDetailKey            
	         AND   PickMethod = @c_OrderType            
          
	         IF ISNULL(RTRIM(@c_ToLOC), '') = ''            
	         BEGIN            
	            BEGIN TRAN -- (ChewKP10)  
	              
	            -- (Vicky01) - Start            
	            SELECT @c_Consigneekey = RTRIM(Message01)            
	            FROM TaskDetail WITH (NOLOCK)            
	            WHERE TaskDetailKey = @c_TaskDetailKey            
	            AND   PickMethod = @c_OrderType            
            	-- (Vicky01) - End            
            
	            IF ISNULL(RTRIM(@c_Consigneekey), '') = ''            
	            BEGIN            
	               SELECT @n_continue = 3            
	               SELECT @n_ErrNo = 70376            
	               SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' No Store Info'            
	               GOTO Quit_SP            
	            END            
	            ELSE             
	            BEGIN            
						SELECT @c_ToLOC = LOC            
						FROM StoreToLOCDetail WITH (NOLOCK)            
						WHERE Consigneekey = @c_Consigneekey            
	            END            
         	END            

	         SELECT @c_PutawayZone = PutawayZone            
	         FROM LOC WITH (NOLOCK)            
	         WHERE LOC = @c_ToLOC            

	         SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')            
	         FROM CODELKUP WITH (NOLOCK)            
	         WHERE Listname = 'WCSSTATION'            
	         AND   Code = @c_PutawayZone            

	         IF ISNULL(RTRIM(@c_WCSStation), '') = ''            
	         BEGIN            
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70377            
					SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCSSTATION Not Setup'            
					GOTO Quit_SP            
	         END            
	         ELSE            
				BEGIN            
					-- Insert WCSRouting            
					-- Generate WCSKey            
					BEGIN TRAN -- (ChewKP10)  

					EXECUTE nspg_GetKey            
						'WCSKey',                         
						10,               
						@c_WCSKey       OUTPUT,            
						@b_success     OUTPUT,            
						@n_ErrNo       OUTPUT,            
						@c_ErrMsg      OUTPUT            

					IF @n_ErrNo <> 0         
					BEGIN            
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70378             
						SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
						GOTO Quit_SP            
					END            
					BEGIN            
						COMMIT TRAN            
					END            

					BEGIN TRAN            
             
             	INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)            
             	VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), ISNULL(@c_WCSStation,''), 'I',  @c_StorerKey, @c_Facility, @c_OrderType, @c_TaskType) -- Insert            
            
             	SELECT @n_ErrNo = @@ERROR            
            
					IF @n_ErrNo <> 0             
					BEGIN            
               	SELECT @n_continue = 3            
               	SELECT @n_ErrNo = 70379            
               	SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
						GOTO Quit_SP            
             	END          
             	ELSE            
             	BEGIN            
						COMMIT TRAN            
             	END            
            
					BEGIN TRAN            
					
					INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
					VALUES (@c_WCSKey, @c_ToteNo, @c_WCSStation, 'I') -- Insert            
					
					SELECT @n_ErrNo = @@ERROR            
					
					IF @n_ErrNo <> 0             
					BEGIN            
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70380            
						SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
						GOTO Quit_SP            
					END            
					ELSE            
					BEGIN            
						COMMIT TRAN            
					END            
            
					IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)            
					BEGIN            
						DELETE FROM WCSRouting  WITH (ROWLOCK)           
						WHERE WCSKey = @c_WCSKey            
					
						GOTO Skip_WCS_Records            
					END            
					ELSE            
					BEGIN            
						GOTO Gen_WCS_Records            
					END            
				END            
			END -- Piece (Store)            
      	ELSE           
      	IF @c_OrderType LIKE 'CASE%'          
      	BEGIN          
				-- Insert WCSRouting          
				-- Generate WCSKey            
				BEGIN TRAN           
				
				EXECUTE nspg_GetKey           
					'WCSKey',           
					10,           
					@c_WCSKey OUTPUT,           
					@b_success OUTPUT,           
					@n_ErrNo OUTPUT,           
					@c_ErrMsg OUTPUT            

				IF @n_ErrNo<>0          
				BEGIN          
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70381             
					SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Gen WCSKey Failed'           
					GOTO Quit_SP          
				END          
				ELSE          
				BEGIN          
					COMMIT TRAN          
				END           
                    
          	BEGIN TRAN            
                    
          	INSERT INTO WCSRouting          
     			(          
              WCSKey          
             ,ToteNo          
             ,Initial_Final_Zone          
             ,Final_Zone          
             ,ActionFlag          
             ,StorerKey          
             ,Facility          
             ,OrderType      
           	 ,TaskType          
            )          
				VALUES          
            (          
              @c_WCSKey          
             ,@c_ToteNo          
             ,''          
             ,''          
             ,'I'          
             ,@c_StorerKey          
             ,@c_Facility          
             ,@c_OrderType          
             ,@c_TaskType          
            ) -- Insert            
                    
          	SELECT @n_ErrNo = @@ERROR            
                    
				IF @n_ErrNo<>0          
				BEGIN          
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70382            
					SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Insert WCSRouting Failed'           
					GOTO Quit_SP          
				END          
				ELSE          
				BEGIN          
					COMMIT TRAN          
				END            
                    
				DECLARE Store_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY           
				FOR          
				SELECT DISTINCT L.PutawayZone          
				FROM   PickDetail PD WITH (NOLOCK)           
				JOIN   LOC l WITH (NOLOCK) ON PD.LOC = L.Loc          
				JOIN   Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey    
				WHERE  PD.Storerkey = @c_Storerkey          
				AND    PD.CaseID = @c_ToteNo           
				AND  O.Status NOT IN ('9', 'CANC') -- (james02)    
    
          	OPEN Store_Cur           
                    
				FETCH NEXT FROM Store_Cur INTO @c_PutawayZone            
				
				WHILE (@@FETCH_STATUS<>-1)          
				BEGIN          
					SELECT @c_WCSStation = ISNULL(RTRIM(SHORT) ,'')          
					FROM   CODELKUP WITH (NOLOCK)          
					WHERE  Listname = 'WCSSTATION'          
					AND    Code = @c_PutawayZone            
				
					IF ISNULL(RTRIM(@c_WCSStation) ,'')=''          
					BEGIN          
						SELECT @n_continue = 3            
						SELECT @n_ErrNo = 70383             
						SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+          
					   	' WCSSTATION Not Setup'          
					       
						CLOSE Store_Cur           
						DEALLOCATE Store_Cur           
						GOTO Quit_SP          
					END        
            	-- (ChewKP10)    

	            IF NOT EXISTS (SELECT 1 FROM  WCSRoutingDetail WITH (NOLOCK)          
	                           WHERE  WCSKey = @c_WCSKey          
	                           AND    ToteNo = @c_ToteNo          
	                           AND    Zone = @c_WCSStation          
	                 )          
	            BEGIN          
						BEGIN TRAN           
	
	               INSERT INTO WCSRoutingDetail          
	                   ( WCSKey      ,ToteNo     ,Zone          
	                    ,ActionFlag)          
	                  VALUES          
	                   (          
	                     @c_WCSKey     ,@c_ToteNo  ,@c_WCSStation          
	                    ,'I'          
	                   ) -- Insert -- (Vicky01)            
	
	               SELECT @n_ErrNo = @@ERROR            
	
	               IF @n_ErrNo<>0          
	               BEGIN          
							SELECT @n_continue = 3            
							SELECT @n_ErrNo = 70384            
							SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+          
								' Insert WCSRoutingDetail Failed'          
							
							CLOSE Store_Cur           
							DEALLOCATE Store_Cur           
							GOTO Quit_SP          
	               END          
	               ELSE          
	               BEGIN          
							COMMIT TRAN          
	               END          
	            END           

           		FETCH NEXT FROM Store_Cur INTO @c_PutawayZone          
        		END -- END WHILE (@@FETCH_STATUS <> -1)            

        		CLOSE Store_Cur           
        		DEALLOCATE Store_Cur            

        		IF NOT EXISTS (          
                 SELECT 1          
                 FROM   WCSRoutingDetail WITH (NOLOCK)          
                 WHERE  WCSKey = @c_WCSKey          
             					)          
        		BEGIN          
           		DELETE           
           		FROM   WCSRouting  WITH (ROWLOCK)        
           		WHERE  WCSKey = @c_WCSKey           
                        
           		GOTO Skip_WCS_Records          
        		END          
        		ELSE          
        		BEGIN          
           		GOTO Gen_WCS_Records          
				END          
			END-- Case (Store)            
		END -- N             
  		ELSE IF @c_ActionFlag = 'F'            
  		BEGIN            
			SELECT @c_FinalWCSZone = Final_Zone,            
			     @c_PrevWCSKey = WCSKey,          
			     @cInit_Final_Zone = Initial_Final_Zone,    -- (james01)          
			     @c_CurTaskType = TaskType
			FROM WCSRouting WITH (NOLOCK)            
			WHERE ToteNo = @c_ToteNo            
			AND   ActionFlag = 'I'            
			AND   Status < '9'            
            
       	SET @cInit_Final_Zone = ISNULL(@cInit_Final_Zone,'')          
                  
			SELECT @n_RowRef = RowRef           
			FROM WCSRoutingDetail WITH (NOLOCK)            
			WHERE WCSKey = @c_PrevWCSKey            
			AND   Zone = @c_FinalWCSZone            
            
			-- Insert WCSRouting            
			-- Generate WCSKey            
			BEGIN TRAN            
			
			EXECUTE nspg_GetKey            
				'WCSKey',            
				10,               
				@c_WCSKey       OUTPUT,            
				@b_success     OUTPUT,            
				@n_ErrNo       OUTPUT,            
				@c_ErrMsg      OUTPUT        

			IF @n_ErrNo <> 0             
			BEGIN            
				SELECT @n_continue = 3            
				SELECT @n_ErrNo = 70385            
				SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
				GOTO Quit_SP            
			END            
			ELSE          
			BEGIN            
				COMMIT TRAN            
			END            
            
       	BEGIN TRAN            
            
       	INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)            
--       VALUES (@c_WCSKey, @c_ToteNo, '', '', 'U',  @c_StorerKey, @c_Facility, @c_OrderType, @c_TaskType) -- Update            
       	VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@cInit_Final_Zone,''), ISNULL(@c_FinalWCSZone,''), 'U',  @c_StorerKey, @c_Facility, @c_OrderType, @c_CurTaskType) -- Update  (james01)          
            
			SELECT @n_ErrNo = @@ERROR            
			
			IF @n_ErrNo <> 0             
			BEGIN            
				SELECT @n_continue = 3            
				SELECT @n_ErrNo = 70386            
				SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
				GOTO Quit_SP            
			END            
			ELSE            
			BEGIN            
				COMMIT TRAN            
			END            

			-- Insert WCSROutingDetail            
			DECLARE PAZone_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
			SELECT Zone            
			FROM WCSRoutingDetail WITH (NOLOCK)            
			WHERE WCSKey = @c_PrevWCSKey          
			AND   Status = '0'            
			AND   RowRef <> @n_RowRef            

			OPEN PAZone_Cur            

       	FETCH NEXT FROM PAZone_Cur INTO @c_PutawayZone            

       	WHILE (@@FETCH_STATUS <> -1)            
       	BEGIN            
         	BEGIN TRAN            

          	INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
          	VALUES (@c_WCSKey, @c_ToteNo, @c_PutawayZone, 'D') -- Delete            
          
          	SELECT @n_ErrNo = @@ERROR            
          
          	IF @n_ErrNo <> 0             
          	BEGIN            
					SELECT @n_continue = 3            
					SELECT @n_ErrNo = 70387            
					SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
					CLOSE PAZone_Cur            
					DEALLOCATE PAZone_Cur            
					GOTO Quit_SP            
				END            
				ELSE            
				BEGIN            
					COMMIT TRAN            
				END            
            
				FETCH NEXT FROM PAZone_Cur INTO @c_PutawayZone            
       	END -- END WHILE (@@FETCH_STATUS <> -1)            
            
       	CLOSE PAZone_Cur            
       	DEALLOCATE PAZone_Cur            
            
       	IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)            
       	BEGIN            
				DELETE FROM WCSRouting WITH (ROWLOCK)            
				WHERE WCSKey = @c_WCSKey            
            
          	GOTO Skip_WCS_Records            
			END            
			ELSE            
			BEGIN            
				GOTO Gen_WCS_Records            
			END            
		END -- F            
		ELSE IF @c_ActionFlag = 'S'            
		BEGIN            

			-- only send final destination            
			SELECT @c_FinalWCSZone = ISNULL(RTRIM(SHORT), '')            
			FROM CODELKUP WITH (NOLOCK)            
			WHERE Listname = 'WCSROUTE'            
			AND   Code = 'QC'            
                        
			IF ISNULL(RTRIM(@c_FinalWCSZone), '') = ''            
			BEGIN            
				SELECT @n_continue = 3            
				SELECT @n_ErrNo = 70388             
				SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCSROUTE Not Setup'            
				GOTO Quit_SP            
			END            

			-- (Shong02)     
			IF NOT EXISTS ( SELECT 1 FROM dbo.WCSROUTINGDETAIL WITH (NOLOCK)           
			               WHERE ToteNo = @c_ToteNo           
			               AND Zone = @c_FinalWCSZone           
			               AND Status <> '9')                         
			BEGIN            
            -- Insert WCSRouting            
            -- Generate WCSKey            
            BEGIN TRAN --(ChewKP10)  
            EXECUTE nspg_GetKey            
               'WCSKey',            
               10,               
               @c_WCSKey      OUTPUT,            
               @b_success     OUTPUT,            
               @n_ErrNo       OUTPUT,            
               @c_ErrMsg      OUTPUT            
            
            IF @n_ErrNo <> 0             
            BEGIN            
               SELECT @n_continue = 3            
               SELECT @n_ErrNo = 70389             
               SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
               GOTO Quit_SP            
            END            
            BEGIN            
               COMMIT TRAN            
            END            
            
            -- Have to check the last action, if last action is Delete then shouldn't use update   
            SET @c_LastActionFlag = ''          
            SELECT TOP 1           
               @c_LastActionFlag = w.ActionFlag  
            FROM WCSRouting w WITH (NOLOCK)           
            WHERE w.ToteNo = @c_ToteNo          
            ORDER BY w.WCSKey DESC          
          
            -- Get the initial final zone for ActionFlag = 'U' (james01)          
            SELECT TOP 1 @cInit_Final_Zone = Initial_Final_Zone,          
                         @c_CurTaskType = TaskType        
            FROM WCSRouting WITH (NOLOCK)           
            WHERE ToteNo = @c_ToteNo          
               AND Status < '9'          
               AND ActionFlag = 'I'            
            ORDER BY WCSKey          
            
            SET @c_NewActionFlag = 'U'          
            
            IF @c_LastActionFlag = 'D'          
            SET @c_NewActionFlag = 'I'          
                       
            BEGIN TRAN            
            
            INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag, StorerKey, Facility, OrderType, TaskType)            
            --             VALUES (@c_WCSKey, @c_ToteNo, @c_FinalWCSZone, @c_FinalWCSZone, @c_NewActionFlag,           
            VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@cInit_Final_Zone,''), ISNULL(@c_FinalWCSZone,''),     
                    @c_NewActionFlag, --(james01)          
                    @c_StorerKey, @c_Facility, @c_OrderType, @c_CurTaskType) -- Update            
            
            SELECT @n_ErrNo = @@ERROR            
            
            IF @n_ErrNo <> 0             
            BEGIN            
               SELECT @n_continue = 3            
               SELECT @n_ErrNo = 70390            
               SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
               GOTO Quit_SP            
            END            
            ELSE            
            BEGIN            
               COMMIT TRAN            
            END            
            
            BEGIN TRAN            
        
            INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
            VALUES (@c_WCSKey, @c_ToteNo, @c_FinalWCSZone, 'I') -- Insert            
            
            SELECT @n_ErrNo = @@ERROR            
            
            IF @n_ErrNo <> 0             
            BEGIN            
               SELECT @n_continue = 3            
               SELECT @n_ErrNo = 70391            
               SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
               GOTO Quit_SP            
            END            
            ELSE            
            BEGIN            
               COMMIT TRAN            
            END            
            
             IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)            
             BEGIN            
                DELETE FROM WCSRouting WITH (ROWLOCK)            
                WHERE WCSKey = @c_WCSKey            
            
                GOTO Skip_WCS_Records            
             END            
             ELSE            
             BEGIN            
                GOTO Gen_WCS_Records            
             END            
        END           
        ELSE            
        BEGIN            
           GOTO Skip_WCS_Records            
        END            
                    
        -- Avoid Multiple QC Record Being Created - End (ChewKP05 )            
    END -- S            
   ELSE           
   IF @c_ActionFlag='D' -- (ChewKP02) Start          
   BEGIN          
       --BEGIN TRAN (ChewKP10)  
                 
       -- (ChewKP03) Start            
       SELECT @c_OrderType = PickMethod,
              @c_CurTaskType = TaskType      
       FROM   TaskDetail WITH (NOLOCK)          
       WHERE  TaskDetailKey = @c_TaskDetailKey           
       -- (ChewKP03) End            
                 
       IF @b_debug=1          
       BEGIN          
           SELECT @c_OrderType '@c_OrderType'      
       END           
         
       BEGIN TRAN -- (ChewKP10)          
       -- Generate WCSKey            
       EXECUTE nspg_GetKey           
       'WCSKey',           
       10,           
       @c_WCSKey OUTPUT,           
       @b_success OUTPUT,           
       @n_ErrNo OUTPUT,           
       @c_ErrMsg OUTPUT            
                 
       IF @n_ErrNo<>0          
       BEGIN          
           SELECT @n_continue = 3            
           SELECT @n_ErrNo = 70411             
           SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Gen WCSKey Failed'           
           GOTO Quit_SP          
       END            
    
                 
       INSERT INTO WCSRouting          
         (          
           WCSKey          ,ToteNo          ,Initial_Final_Zone          ,Final_Zone          
          ,ActionFlag      ,StorerKey       ,Facility                    ,OrderType          
          ,TaskType         )          
       VALUES          
         ( @c_WCSKey       ,@c_ToteNo          ,''                ,''          
          ,'D'             ,@c_StorerKey       ,@c_Facility       ,@c_OrderType          
          ,@c_CurTaskType          
         ) -- Delete            
                 
       SELECT @n_ErrNo = @@ERROR            
                 
       IF @n_ErrNo<>0          
       BEGIN          
           SELECT @n_continue = 3            
           SELECT @n_ErrNo = 70412            
           SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Insert WCSRouting Failed'           
           GOTO Quit_SP          
       END           

      -- tlting01
	   DECLARE Item_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   Select  WCSKey 
         FROM WCSRouting WITH (NOLOCK)      
         WHERE  ToteNo = @c_ToteNo   

	   OPEN Item_cur 
	   FETCH NEXT FROM Item_cur INTO @c_curWCSkey  
	   WHILE @@FETCH_STATUS = 0 
	   BEGIN 

         -- Update WCSRouting.Status = '5' When Delete          
         UPDATE WCSRouting WITH (ROWLOCK)        
         SET    STATUS = '5', 
         EditDate = GETDATE(), 
         EditWho =SUSER_SNAME()        
         WHERE  WCSkey = @c_curWCSkey          

          SELECT @n_ErrNo = @@ERROR            
          IF @n_ErrNo<>0          
          BEGIN     
              DEALLOCATE Item_cur      
              SELECT @n_continue = 3            
              SELECT @n_ErrNo = 70413            
              SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Upd WCS Fail'           
              GOTO Quit_SP          
          END             
   		
		   FETCH NEXT FROM Item_cur INTO @c_curWCSkey 
	   END
	   CLOSE Item_cur 
	   DEALLOCATE Item_cur  
	                    
       COMMIT TRAN           
END-- D (ChewKP02) End        
  END -- PK            
  ELSE      
  IF @c_TaskType = 'PA'            
  BEGIN            
      -- Handling Residual for PA Task from Store Picks Start (ChewKP06)             
      IF @c_ActionFlag = 'R'            
      BEGIN            
         BEGIN TRAN            
                  
            -- only send final destination            
            SELECT @c_ToLOC = ISNULL(RTRIM(ToLOC), '')            
            FROM TaskDetail WITH (NOLOCK)            
            WHERE TaskDetailKey = @c_TaskDetailKey            
            AND   TaskType = @c_TaskType            
                  
                  
            IF @b_debug = 1            
            BEGIN            
               SELECT @c_ToLOC '@c_ToLOC'            
            END             
                  
            IF ISNULL(RTRIM(@c_ToLOC), '') = ''            
            BEGIN            
                SELECT @n_continue = 3            
                SELECT @n_ErrNo = 70414             
                SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' No ToLOC'            
                GOTO Quit_SP            
            END            
            ELSE            
            BEGIN            
                  
                SELECT @c_Putawayzone = PutawayZone            
                FROM LOC WITH (NOLOCK)            
                WHERE LOC = @c_ToLOC            
                       
                IF @b_debug = 1            
                BEGIN            
                  SELECT @c_Putawayzone '@c_Putawayzone PA'            
                END             
                  
                SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')            
                FROM CODELKUP WITH (NOLOCK)            
                WHERE Listname = 'WCSSTATION'            
               AND   Code = @c_Putawayzone            
                  
                IF ISNULL(RTRIM(@c_WCSStation), '') = ''            
                BEGIN            
                   SELECT @n_continue = 3            
                   SELECT @n_ErrNo = 70415             
                   SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCSSTATION Not Setup'            
                   GOTO Quit_SP            
                END            
                  
                -- Insert WCSRouting            
                -- Generate WCSKey            
                --BEGIN TRAN            
                  
                EXECUTE nspg_GetKey            
                'WCSKey',            
                10,               
                  @c_WCSKey       OUTPUT,            
                  @b_success     OUTPUT,            
                  @n_ErrNo       OUTPUT,            
                  @c_ErrMsg      OUTPUT            
                IF @n_ErrNo <> 0             
                BEGIN            
                    SELECT @n_continue = 3            
                    SELECT @n_ErrNo = 70866             
                    SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
                    GOTO Quit_SP            
                END            
                BEGIN            
                    COMMIT TRAN            
                END            
                  
                BEGIN TRAN            
                
                INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone,     
                                        ActionFlag, StorerKey, Facility, OrderType, TaskType)            
                VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''), ISNULL(@c_WCSStation,''), 'U',      
                        @c_StorerKey, @c_Facility, @c_OrderType, @c_TaskType) -- Update            
                  
                SELECT @n_ErrNo = @@ERROR            
                  
                IF @n_ErrNo <> 0             
                BEGIN            
                    SELECT @n_continue = 3            
                    SELECT @n_ErrNo = 70867            
                    SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
                    GOTO Quit_SP            
                END            
                ELSE            
                BEGIN            
                   COMMIT TRAN            
                END            
                  
                BEGIN TRAN            
                  
                INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
                VALUES (@c_WCSKey, @c_ToteNo, @c_WCSStation, 'I') -- Insert            
                  
                SELECT @n_ErrNo = @@ERROR            
                  
                IF @n_ErrNo <> 0             
                BEGIN            
                    SELECT @n_continue = 3            
                    SELECT @n_ErrNo = 70868            
                    SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
                    GOTO Quit_SP            
                END            
                ELSE            
                BEGIN            
                COMMIT TRAN            
                END            
                  
                IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)            
                BEGIN            
                   DELETE FROM WCSRouting WITH (ROWLOCK)            
                   WHERE WCSKey = @c_WCSKey            
        
                   GOTO Skip_WCS_Records            
                END            
                ELSE            
                BEGIN            
                  GOTO Gen_WCS_Records            
          END            
            END             
      END -- -- Handling Residual for PA Task from Store Picks End (ChewKP06)           
      ELSE IF @c_ActionFlag='D' -- (ChewKP08) Start          
      BEGIN          
       BEGIN TRAN           
               
       SET @c_OrderType = ''           
               
       IF @b_debug=1          
       BEGIN          
           SELECT @c_OrderType '@c_OrderType'          
       END           
             
       -- (ChewKP09) Start       
       SET @cInit_Final_Zone = ''      
       SET @c_FinalWCSZone = ''      
       SELECT TOP 1 @c_FinalWCSZone = Final_Zone ,      
              @cInit_Final_Zone = Initial_Final_Zone      
       FROM dbo.WCSRouting WITH (NOLOCK)      
       WHERE ToteNo = @c_ToteNo      
            AND ActionFlag = 'I'      
       ORDER BY WCSKey Desc      
       -- (ChewKP09) End       
                 
       -- Generate WCSKey            
       EXECUTE nspg_GetKey           
       'WCSKey',           
       10,           
       @c_WCSKey OUTPUT,           
       @b_success OUTPUT,           
       @n_ErrNo OUTPUT,           
       @c_ErrMsg OUTPUT            
                 
       IF @n_ErrNo<>0          
       BEGIN          
           SELECT @n_continue = 3            
           SELECT @n_ErrNo = 71066             
           SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Gen WCSKey Failed'           
           GOTO Quit_SP          
       END            
                 
       INSERT INTO WCSRouting          
         (          
           WCSKey          ,ToteNo          ,Initial_Final_Zone          ,Final_Zone          
          ,ActionFlag      ,StorerKey       ,Facility                    ,OrderType          
          ,TaskType         )          
       VALUES          
         ( @c_WCSKey       ,@c_ToteNo          ,ISNULL(@cInit_Final_Zone,'')                    
          ,ISNULL(@c_FinalWCSZone,'')          ,'D'                 
          ,@c_StorerKey    ,@c_Facility        ,@c_OrderType          
          ,@c_TaskType          
         ) -- Delete            
                 
       SELECT @n_ErrNo = @@ERROR            
                 
       IF @n_ErrNo<>0          
       BEGIN          
           SELECT @n_continue = 3            
           SELECT @n_ErrNo = 71067            
           SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Insert WCSRouting Failed'           
           GOTO Quit_SP          
       END           
                 
	    DECLARE Item_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   Select  WCSKey 
         FROM WCSRouting WITH (NOLOCK)      
         WHERE  ToteNo = @c_ToteNo   

	    OPEN Item_cur 
	    FETCH NEXT FROM Item_cur INTO @c_curWCSkey  
	    WHILE @@FETCH_STATUS = 0 
	    BEGIN 

         -- Update WCSRouting.Status = '5' When Delete          
         UPDATE WCSRouting WITH (ROWLOCK)        
         SET    STATUS = '5', 
         EditDate = GETDATE(), 
         EditWho =SUSER_SNAME()        
         WHERE  WCSkey = @c_curWCSkey          

          SELECT @n_ErrNo = @@ERROR           
          IF @n_ErrNo<>0          
          BEGIN     
              DEALLOCATE Item_cur      
              SELECT @n_continue = 3            
              SELECT @n_ErrNo = 71068            
              SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Upd WCS Fail'           
              GOTO Quit_SP          
          END              
   		
		   FETCH NEXT FROM Item_cur INTO @c_curWCSkey 
	    END
	    CLOSE Item_cur 
	    DEALLOCATE Item_cur  
          
                 
       COMMIT TRAN           
      END-- D (ChewKP08) End                   
      ELSE -- @c_ActionFlag <> 'R'            
         BEGIN            
              -- to check whether there is another Tote with the same ToteNo in use and active            
              BEGIN TRAN            
              EXEC dbo.isp_WMS2WCSRoutingValidation             
                 @c_ToteNo,             
                   @c_StorerKey,            
                   @b_Success OUTPUT,            
                   @n_ErrNo  OUTPUT,             
                   @c_ErrMsg OUTPUT            
                  
             IF @n_ErrNo <> 0             
             BEGIN            
                 SELECT @n_continue = 3            
             SELECT @n_ErrNo = @n_ErrNo             
                 SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' ' + ISNULL(RTRIM(@c_ErrMsg), '') -- (ChewKP01)            
                 GOTO Quit_SP            
             END          
             ELSE            
             BEGIN            
                 COMMIT TRAN            
             END            
          
          
            BEGIN TRAN            
                
        -- only send final destination            
            SELECT @c_ToLOC = ISNULL(RTRIM(ToLOC), '')            
            FROM TaskDetail WITH (NOLOCK)            
            WHERE TaskDetailKey = @c_TaskDetailKey            
            AND   TaskType = @c_TaskType            
                  
                  
            IF @b_debug = 1            
            BEGIN            
               SELECT @c_ToLOC '@c_ToLOC'            
            END             
                  
            IF ISNULL(RTRIM(@c_ToLOC), '') = ''            
            BEGIN            
                SELECT @n_continue = 3            
                SELECT @n_ErrNo = 70392             
                SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' No ToLOC'            
                GOTO Quit_SP            
            END            
            ELSE            
            BEGIN            
                  
                SELECT @c_Putawayzone = PutawayZone            
                FROM LOC WITH (NOLOCK)            
                WHERE LOC = @c_ToLOC            
                       
                IF @b_debug = 1            
                BEGIN            
                  SELECT @c_Putawayzone '@c_Putawayzone PA'            
                END             
                  
                SELECT @c_WCSStation = ISNULL(RTRIM(SHORT), '')            
                FROM CODELKUP WITH (NOLOCK)            
                WHERE Listname = 'WCSSTATION'            
                AND   Code = @c_Putawayzone            
                  
                IF ISNULL(RTRIM(@c_WCSStation), '') = ''            
                BEGIN            
                   SELECT @n_continue = 3            
                   SELECT @n_ErrNo = 70393             
                   SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCSSTATION Not Setup'            
                   GOTO Quit_SP            
                END            
                  
                -- Insert WCSRouting            
                -- Generate WCSKey            
                --BEGIN TRAN            
                  
                EXECUTE nspg_GetKey            
                'WCSKey',            
                10,               
                  @c_WCSKey       OUTPUT,            
                  @b_success     OUTPUT,            
                  @n_ErrNo       OUTPUT,            
                  @c_ErrMsg      OUTPUT            
            
                  
                IF @n_ErrNo <> 0             
                BEGIN            
                    SELECT @n_continue = 3            
                    SELECT @n_ErrNo = 70394             
                    SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
                    GOTO Quit_SP            
                END            
                BEGIN            
                    COMMIT TRAN            
                END            
                  
                BEGIN TRAN            
                  
                INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone,     
                                   ActionFlag, StorerKey, Facility, OrderType, TaskType)            
                VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@c_WCSStation,''),     
                        ISNULL(@c_WCSStation,''), 'I',  @c_StorerKey, @c_Facility,     
                        @c_OrderType, @c_TaskType) -- Update            
                  
                SELECT @n_ErrNo = @@ERROR            
                  
                IF @n_ErrNo <> 0             
                BEGIN            
                    SELECT @n_continue = 3            
                    SELECT @n_ErrNo = 70395            
                    SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
                    GOTO Quit_SP            
                END   
                ELSE            
                BEGIN            
                    COMMIT TRAN            
                END            
                  
                BEGIN TRAN            
                  
                INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
                VALUES (@c_WCSKey, @c_ToteNo, @c_WCSStation, 'I') -- Insert            
                  
                SELECT @n_ErrNo = @@ERROR            
                  
                IF @n_ErrNo <> 0             
                BEGIN            
                    SELECT @n_continue = 3            
                    SELECT @n_ErrNo = 70396            
                    SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
                    GOTO Quit_SP            
                END            
                ELSE            
                BEGIN            
                    COMMIT TRAN            
                END            
                  
                IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)            
                BEGIN            
                   DELETE FROM WCSRouting WITH (ROWLOCK)            
                   WHERE WCSKey = @c_WCSKey            
                  
                   GOTO Skip_WCS_Records            
                END            
                ELSE            
                BEGIN            
                  GOTO Gen_WCS_Records            
                END            
           END            
      END -- @c_ActionFlag <> 'R'            
  END            
  IF @c_TaskType = 'PTS'  -- (Shong01)          
  BEGIN          
     IF @c_ActionFlag = 'S'            
     BEGIN            
        BEGIN TRAN            
          
        -- only send final destination            
        SELECT @c_FinalWCSZone = ISNULL(RTRIM(SHORT), '')            
        FROM CODELKUP WITH (NOLOCK)            
        WHERE Listname = 'WCSROUTE'            
        AND   Code = 'QC'            
                     
        IF ISNULL(RTRIM(@c_FinalWCSZone), '') = ''            
        BEGIN            
           SELECT @n_continue = 3            
           SELECT @n_ErrNo = 70388             
           SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' WCSROUTE Not Setup'            
           GOTO Quit_SP            
        END            
                  
        -- Avoid Multiple QC Record Being Created - Start (ChewKP05 )              
        IF NOT EXISTS ( SELECT 1 FROM dbo.WCSROUTING WITH (NOLOCK)           
                        WHERE ToteNo = @c_ToteNo           
                        AND Final_Zone = @c_FinalWCSZone           
                        AND Status <> '9')            
        BEGIN            
           -- Insert WCSRouting            
           -- Generate WCSKey            
          
           EXECUTE nspg_GetKey            
            'WCSKey',            
            10,     
            @c_WCSKey       OUTPUT,            
            @b_success     OUTPUT,            
            @n_ErrNo       OUTPUT,            
            @c_ErrMsg      OUTPUT            
          
          
           IF @n_ErrNo <> 0             
           BEGIN            
              SELECT @n_continue = 3            
              SELECT @n_ErrNo = 70389             
              SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Gen WCSKey Failed'            
              GOTO Quit_SP            
           END            
           BEGIN            
               COMMIT TRAN            
           END            
          
           -- Have to check the last action, if last action is Delete then shouldn't use update           
           SET @c_LastActionFlag = ''          
           SELECT TOP 1           
                  @c_LastActionFlag = w.ActionFlag          
           FROM WCSRouting w WITH (NOLOCK)           
           WHERE w.ToteNo = @c_ToteNo          
           ORDER BY w.WCSKey DESC          
          
       -- Get the initial final zone for ActionFlag = 'U' (james01)          
           SELECT @cInit_Final_Zone = MAX(Zone)          
           FROM WCSRoutingDetail WITH (NOLOCK)           
           WHERE ToteNo = @c_ToteNo          
             AND ActionFlag = 'I'            
                     
           SET @cInit_Final_Zone = ISNULL(@cInit_Final_Zone, '')          
          
           SET @c_NewActionFlag = 'U'          
                    
           IF @c_LastActionFlag = 'D'          
              SET @c_NewActionFlag = 'I'          
                    
           BEGIN TRAN            
          
           INSERT INTO WCSRouting (WCSKey, ToteNo, Initial_Final_Zone, Final_Zone, ActionFlag,     
                  StorerKey, Facility, OrderType, TaskType)            
           VALUES (@c_WCSKey, @c_ToteNo, ISNULL(@cInit_Final_Zone,''),     
                  ISNULL(@c_FinalWCSZone,''), @c_NewActionFlag, --(james01)          
                   @c_StorerKey, @c_Facility, @c_OrderType, @c_TaskType) -- Update            
          
           SELECT @n_ErrNo = @@ERROR            
          
           IF @n_ErrNo <> 0             
           BEGIN            
              SELECT @n_continue = 3            
              SELECT @n_ErrNo = 70390            
              SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRouting Failed'            
              GOTO Quit_SP            
           END            
           ELSE            
           BEGIN            
              COMMIT TRAN            
           END            
          
           BEGIN TRAN            
          
           INSERT INTO WCSRoutingDetail (WCSKey, ToteNo, Zone, ActionFlag)            
           VALUES (@c_WCSKey, @c_ToteNo, @c_FinalWCSZone, 'I') -- Insert            
          
           SELECT @n_ErrNo = @@ERROR            
          
           IF @n_ErrNo <> 0             
           BEGIN            
              SELECT @n_continue = 3            
              SELECT @n_ErrNo = 70391            
            SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' Insert WCSRoutingDetail Failed'            
              GOTO Quit_SP            
           END            
           ELSE            
           BEGIN            
              COMMIT TRAN            
           END            
          
           IF NOT EXISTS (SELECT 1 FROM WCSRoutingDetail WITH (NOLOCK) WHERE WCSKey = @c_WCSKey)            
           BEGIN            
              DELETE FROM WCSRouting WITH (ROWLOCK)            
              WHERE WCSKey = @c_WCSKey            
          
              GOTO Skip_WCS_Records            
           END            
           ELSE            
           BEGIN            
              GOTO Gen_WCS_Records            
           END            
        END -- If QC Sort Station not exists              
     END -- ActionFlag = 'S'          
  END -- TaskType = 'PTS'           
  IF @c_TaskType IN ('Scan2Van', 'ECOMM_DSPT', 'TOTE_CONSO') -- (ChewKP07) -- (ChewKP11)
  BEGIN          
  IF @c_ActionFlag='D' -- (ChewKP07) Start          
  BEGIN          
       BEGIN TRAN           
                 
       -- (ChewKP03) Start            
       SELECT @c_OrderType = ''       
             
       -- (ChewKP09) Start       
       SET @cInit_Final_Zone = ''      
       SET @c_FinalWCSZone = ''      
       SELECT TOP 1 @c_FinalWCSZone = Final_Zone ,      
              @cInit_Final_Zone = Initial_Final_Zone      
       FROM dbo.WCSRouting WITH (NOLOCK)      
       WHERE ToteNo = @c_ToteNo      
            AND ActionFlag = 'I'      
       ORDER BY WCSKey Desc      
       -- (ChewKP09) End       
                 
       EXECUTE nspg_GetKey           
       'WCSKey',      
       10,           
       @c_WCSKey OUTPUT,           
       @b_success OUTPUT,           
       @n_ErrNo OUTPUT,           
       @c_ErrMsg OUTPUT            
                 
       IF @n_ErrNo<>0          
       BEGIN          
           SELECT @n_continue = 3            
           SELECT @n_ErrNo = 70411             
           SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Gen WCSKey Failed'           
           GOTO Quit_SP          
       END            
                 
       INSERT INTO WCSRouting          
         (          
           WCSKey          ,ToteNo          ,Initial_Final_Zone          ,Final_Zone          
          ,ActionFlag      ,StorerKey       ,Facility                    ,OrderType          
          ,TaskType         )          
       VALUES          
         ( @c_WCSKey       ,@c_ToteNo          ,ISNULL(@cInit_Final_Zone,'')            
          ,ISNULL(@c_FinalWCSZone,'')        
          ,'D'             ,@c_StorerKey       ,@c_Facility       ,@c_OrderType          
          ,@c_TaskType          
         ) -- Delete            
                 
       SELECT @n_ErrNo = @@ERROR            
                 
       IF @n_ErrNo<>0          
       BEGIN          
           SELECT @n_continue = 3            
           SELECT @n_ErrNo = 70412            
           SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Insert WCSRouting Failed'           
           GOTO Quit_SP          
       END           
                 
	    DECLARE Item_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   Select  WCSKey 
         FROM WCSRouting WITH (NOLOCK)      
         WHERE  ToteNo = @c_ToteNo   

	    OPEN Item_cur 
	    FETCH NEXT FROM Item_cur INTO @c_curWCSkey  
	    WHILE @@FETCH_STATUS = 0 
	    BEGIN 

         -- Update WCSRouting.Status = '5' When Delete          
         UPDATE WCSRouting WITH (ROWLOCK)        
         SET    STATUS = '5', 
         EditDate = GETDATE(), 
         EditWho =SUSER_SNAME()        
         WHERE  WCSkey = @c_curWCSkey          

         SELECT @n_ErrNo = @@ERROR            
                 
         IF @n_ErrNo<>0          
         BEGIN        
            DEALLOCATE Item_cur   
            SELECT @n_continue = 3            
            SELECT @n_ErrNo = 70413            
            SELECT @c_ErrMsg = CONVERT(CHAR(5) ,ISNULL(@n_ErrNo ,0))+' Upd WCS Fail'           
            GOTO Quit_SP          
         END               
   		
		   FETCH NEXT FROM Item_cur INTO @c_curWCSkey 
	    END
	    CLOSE Item_cur 
	    DEALLOCATE Item_cur  
         
                 
      COMMIT TRAN           
   END-- D (ChewKP07) End            
  END          
              
  Gen_WCS_Records:            
  BEGIN TRAN            
  EXEC dbo.isp_WMS2WCSRouting            
        @c_WCSKey,            
        @c_StorerKey,            
        @b_Success OUTPUT,            
        @n_ErrNo  OUTPUT,             
        @c_ErrMsg OUTPUT            
            
  IF @n_ErrNo <> 0             
  BEGIN            
     SELECT @n_continue = 3            
     SELECT @n_ErrNo = @n_ErrNo             
     SELECT @c_ErrMsg = CONVERT(CHAR(5),ISNULL(@n_ErrNo,0)) + ' ' + ISNULL(RTRIM(@c_ErrMsg), '') -- (ChewKP01)            
     GOTO Quit_SP            
  END            
  ELSE            
  BEGIN            
     COMMIT TRAN            
  END            
            
  Skip_WCS_Records:            
            
  Quit_SP:            
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
          
      -- (Vicky02)          
--      INSERT INTO dbo.TRACEINFO ( TraceName , TimeIn , Step1 , Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4)          
--      VALUES ('nspInsertWCSRouting', GetDate(), @c_StorerKey, @c_Facility, @c_ToteNo, @c_TaskType,  @c_ActionFlag, @c_TaskDetailKey, @c_Username, @n_ErrNo, LEFT(@c_ErrMsg, 20))          
          
      EXECUTE nsp_logerror @n_ErrNo, @c_ErrMsg, 'nspInsertWCSRouting'            
      --RAISERROR @n_ErrNo @c_ErrMsg           
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
END


GO