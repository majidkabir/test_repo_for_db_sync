SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrIDUpdate                                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.8                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 17-Oct-2003  YokeBeen      NIKE Regional (NSC) Project (SOS#15352)   */
/*                            - (YokeBeen01)                            */
/* 28-Dec-2004  YokeBeen      For NSC 947-InvAdj - (YokeBeen02)         */
/*                                                                      */
/* 07-Nov-2005  Vicky         SOS#42434 - Record not inserted to        */
/*                            INVHOLDTRANSLOG                           */
/* 08-Aug-2006  Vicky         Generic Configkey (INVHOLDLOG) for        */
/*                            Inventory Hold Interface                  */
/* 24-Jan-2007  Shong         Performance Tuning                        */
/* 23-Apr-2007	 Vicky         SOS#74049 - Fix interface double sending  */
/* 04-May-2007  Vicky         SOS#74919 - Insert direct to Transmitlog3 */
/*                            without checking on uniqueness of         */
/*                            Key1 + Key2  + Key3 for INVHOLDLOG        */   
/* 04-Jul-2007  Vicky         SOS#80373 - Add checking on duplicate     */
/*                            Invholdkey with both status = 0 being     */
/*                            inserted into Transmitlog3                */
/* 09-Sep-2011  TLTING01      New column update Editdate Edit Who       */
/*		                        for Datamart Extraction                   */
/* 23-May-2012  TLTING02      DM integrity - move editdate update up    */
/* 28-Oct-2013  TLTING        Review Editdate column update             */
/* 09-Aug-2016  TLTING        Change Set ROWCOUNT 1 to Top 1            */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrIDUpdate]
ON  [dbo].[ID]
FOR UPDATE
AS
BEGIN
IF @@ROWCOUNT = 0
BEGIN
	RETURN
END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


DECLARE
		@b_Success		int       -- Populated by calls to stored procedures - was the proc successful?
	,  @n_err      	int       -- Error number returned by stored procedure or this trigger
	,  @n_err2     	int       -- For Additional Error Detection
	,  @c_errmsg      NVARCHAR(250) -- Error message returned by stored procedure or this trigger
	,  @n_continue    int                 
	,  @n_starttcnt  	int       -- Holds the current transaction count
	,  @c_preprocess  NVARCHAR(250) -- preprocess
	,  @c_pstprocess  NVARCHAR(250) -- post process
	,  @n_cnt 			int                  

SELECT @b_Success		= 0 
	,  @n_err      	= 0 
	,  @n_err2     	= 0 
	,  @c_errmsg   	= '' 
	,  @n_continue    = 0 
	,  @n_starttcnt  	= 0 
	,  @c_preprocess 	= '' 
	,  @c_pstprocess 	= '' 
	,  @n_cnt 			= 0 

SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

IF UPDATE(ArchiveCop)
BEGIN
	SELECT @n_continue = 4 
END

-- TLTING01
IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
BEGIN
	UPDATE ID with (ROWLOCK)
	SET EditDate = GETDATE(),
	    EditWho = SUSER_SNAME(),
	    TrafficCop = NULL
	FROM ID , INSERTED (NOLOCK)
	WHERE ID.ID = INSERTED.ID
	SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

	IF @n_err <> 0
	BEGIN
		SELECT @n_continue = 3
		SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74565   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ID. (ntrIDUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
	END
END

IF UPDATE(TrafficCop)
BEGIN
	SELECT @n_continue = 4 
END

      /* #INCLUDE <TRRDU1.SQL> */     
DECLARE @c_CurrentID  NVARCHAR(18),
        @c_InvHoldKey NVARCHAR(10),
       @c_HoldReason NVARCHAR(10),
        @c_InStatus   NVARCHAR(10),
        @c_DelStatus  NVARCHAR(10)
DECLARE @c_transmitlogkey NVARCHAR(10),
        @c_authority NVARCHAR(1),
        @b_interface NVARCHAR(1) 

-- (YokeBeen01) - Start
DECLARE @c_Sku		 NVARCHAR(20),
		  @c_StorerKey NVARCHAR(18),
		  @c_Facility NVARCHAR(5)		-- (YokeBeen02) 

DECLARE @c_PrevInvHoldKey NVARCHAR(10),
        @c_PrevInStatus   NVARCHAR(10)

-- SOS#74049 (Start)
DECLARE @n_LocCnt int,
        @n_LotCnt int

SELECT @n_LocCnt = 0,
       @n_LotCnt = 0
-- SOS#74049 (End)

SELECT  @c_CurrentID			= '' ,
        @c_InvHoldKey		= '' ,
        @c_HoldReason		= '' ,
        @c_InStatus			= '' ,
        @c_DelStatus			= '' ,
		  @c_transmitlogkey	= '' ,
        @c_authority			= '' ,
        @b_interface			= '' ,
		  @c_Sku					= '' ,
		  @c_StorerKey			= '' ,
		  @c_Facility			= '' 
-- (YokeBeen01) - End

-- Generic Configkey (Start)
DECLARE @c_invholditf NVARCHAR(1)
SELECT @c_invholditf  = ''
-- Generic Configkey (End)

IF @n_continue=1 OR @n_continue=2
BEGIN
   IF UPDATE(Status) 
   BEGIN 
   	IF EXISTS (SELECT IH.ID FROM INVENTORYHOLD IH (NOLOCK), INSERTED INS, DELETED DEL
                  WHERE INS.ID = DEL.ID
                    AND INS.ID = IH.ID
                    AND INS.STATUS <> DEL.STATUS)
   	BEGIN
   		SELECT @c_CurrentID = SPACE(18)
   
         WHILE (1=1)
   		BEGIN
         	 
            SELECT TOP 1 @c_CurrentID = INS.ID,
                   @c_InStatus  = INS.Status,
                   @c_DelStatus = DEL.Status,
                   @c_InvHoldKey = IH.InventoryHoldKey,
                   @c_HoldReason = IH.Status
              FROM INVENTORYHOLD IH (NOLOCK), INSERTED INS, DELETED DEL
             WHERE INS.ID = DEL.ID
               AND INS.ID = IH.ID
               AND INS.STATUS <> DEL.STATUS
               AND INS.ID > @c_CurrentID
   
   			IF @@ROWCOUNT = 0
            BEGIN
            	BREAK
            END
   
            -- When HOLD
   			--Added By Vicky 27 Dec 2002 SOS #9084
            EXECUTE nspGetRight NULL,  -- Facility
                          NULL,  -- Storer
                          NULL,  -- Sku
                          'INVENTORY ID HOLD - INTERFACE',      -- ConfigKey
                          @b_success    output, 
                          @c_authority  output, 
                          @n_err        output, 
                          @c_errmsg     output
   
            IF @b_success <> 1
            BEGIN
               SELECT @c_errmsg = 'ntrIDUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
               BREAK
            END
            ELSE 
            BEGIN
               IF @c_authority = '1'
               	SELECT @b_interface = '1'
               ELSE
               	SELECT @b_interface = '0'
            END
   
   			IF @b_interface = '1'
   			BEGIN
            	IF @c_InStatus = "HOLD" AND @c_DelStatus = "OK" AND UPPER(dbo.fnc_RTrim(@c_HoldReason)) <> "IMPORT"
             	BEGIN
   	            SELECT @c_transmitlogkey=''
   	            SELECT @b_success=1
   					EXECUTE nspg_getkey
                      'TransmitlogKey'
    		             ,10
    	 	             , @c_transmitlogkey OUTPUT
    		             , @b_success OUTPUT
    		             , @n_err OUTPUT
    		             , @c_errmsg OUTPUT
   
   					IF NOT @b_success=1
   					BEGIN
   						SELECT @n_continue=3
   					END
   
   					IF ( @n_continue = 1 or @n_continue = 2 ) 
   					BEGIN
   						INSERT TRANSMITLOG  (Transmitlogkey, tablename, key1, key2, key3,  transmitflag)
   						VALUES  (@c_transmitlogkey, "InventoryHold", @c_CurrentID, '', 'HOLD','0')
   						SELECT @n_err= @@Error
   
   						IF NOT @n_err=0
   						BEGIN
   							SELECT @n_continue=3 
   							/* Trap SQL Server Error */
   							Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=99701
   							Select @c_errmsg= "NSQL"+CONVERT(char(5), @n_err)+":Insert failed on TransmitLog. (ntrIDUpdate)"+"("+"SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+")" 
   							/* End Trap SQL Server Error */
   						END 
   					END               
   				END         
   				-- When Release from Hold
   				IF @c_InStatus = "OK" AND @c_DelStatus = "HOLD"
   				BEGIN
   					SELECT @c_transmitlogkey=''
   					SELECT @b_success=1
   					EXECUTE nspg_getkey
                      'TransmitlogKey'
    		             ,10
    	 	             , @c_transmitlogkey OUTPUT
    		             , @b_success OUTPUT
    		             , @n_err OUTPUT
    		             , @c_errmsg OUTPUT
   
   					IF NOT @b_success=1
   					BEGIN
   						SELECT @n_continue=3
   					END
   
   					IF ( @n_continue = 1 OR @n_continue = 2 ) 
   					BEGIN
   						INSERT TRANSMITLOG  (Transmitlogkey, tablename, key1, key2, key3,  transmitflag)
   						VALUES  (@c_transmitlogkey, "InventoryHold", @c_CurrentID, '', 'RELEASE','0')
   	
   						SELECT @n_err= @@Error
   	
   						IF NOT @n_err=0
   						BEGIN
   							SELECT @n_continue=3 
   							/* Trap SQL Server Error */
   							Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=99701
   							Select @c_errmsg= "NSQL"+CONVERT(char(5), @n_err)+":Insert failed on TransmitLog. (ntrIDUpdate)"+"("+"SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+")" 
   							/* End Trap SQL Server Error */
   						END 
   					END
   				END
   			END -- Added By Vicky 27 Dec 2002 SOS #9084
   		END -- While 1=1      
   	END -- If record exists
   END -- if update(status)
END

-- (YokeBeen01) - Start
IF @n_continue=1 OR @n_continue=2
BEGIN
   IF UPDATE(STATUS)
   BEGIN 
   	IF EXISTS (SELECT INVENTORYHOLD.ID 
   					 FROM INVENTORYHOLD (NOLOCK), INSERTED, DELETED 
                  WHERE INSERTED.ID = DELETED.ID
                    AND INSERTED.ID = INVENTORYHOLD.ID
                    AND INSERTED.STATUS <> DELETED.STATUS)
   	BEGIN
   		SELECT @c_CurrentID = SPACE(18)
   
         WHILE (1=1)	-- ID Level
   		BEGIN
         	--SET ROWCOUNT 1
            SELECT TOP 1 @c_CurrentID = INSERTED.ID,
                   @c_InStatus  = INSERTED.Status,
                   @c_DelStatus = DELETED.Status
              FROM INVENTORYHOLD (NOLOCK), INSERTED, DELETED 
             WHERE INSERTED.ID = DELETED.ID
               AND INSERTED.ID = INVENTORYHOLD.ID
               AND INSERTED.STATUS <> DELETED.STATUS
               AND INSERTED.ID > @c_CurrentID
   
   			IF @@ROWCOUNT = 0
            BEGIN
            	BREAK
            END
   
   			-- (YokeBeen02) - Start
   			-- Inventory to OnHold/Release should based on Facility level
   	      WHILE (1=1)	-- Sku Level
   			BEGIN
   	      	-- SET ROWCOUNT 1
   				SELECT TOP 1  @c_Sku = Min(LOTxLOCxID.Sku) -- modified for SOS#42434
   -- 						  @c_StorerKey = LOTxLOCxID.StorerKey, -- Commented for SOS#42434
   -- 						  @c_Facility = LOC.Facility -- Commented for SOS#42434
   	           FROM INVENTORYHOLD INVENTORYHOLD (NOLOCK) 
   				  JOIN ID ID (NOLOCK) ON (INVENTORYHOLD.ID = ID.ID) 
   				  JOIN LOTxLOCxID LOTxLOCxID (NOLOCK) ON (ID.ID = LOTxLOCxID.ID)
   				  JOIN LOC LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
   				 WHERE INVENTORYHOLD.InventoryHoldKey = @c_InvHoldKey
   					AND ID.ID = @c_CurrentID 
   					AND LOTxLOCxID.Sku > @c_Sku  -- SOS#42434
   
                -- Added for SOS#42434
                SELECT TOP 1 @c_StorerKey = LOTxLOCxID.StorerKey, 
    						  @c_Facility = LOC.Facility 
   	           FROM INVENTORYHOLD INVENTORYHOLD (NOLOCK) 
   				  JOIN ID ID (NOLOCK) ON (INVENTORYHOLD.ID = ID.ID) 
   				  JOIN LOTxLOCxID LOTxLOCxID (NOLOCK) ON (ID.ID = LOTxLOCxID.ID)
   				  JOIN LOC LOC (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
   				 WHERE INVENTORYHOLD.InventoryHoldKey = @c_InvHoldKey
   					AND ID.ID = @c_CurrentID 
   					AND LOTxLOCxID.Sku = @c_Sku  -- SOS#42434
   
   				IF @@ROWCOUNT = 0
   	         BEGIN
   	         	BREAK
   	         END
   
   	         -- When HOLD
   				SELECT @b_success = 0
   
   	         EXECUTE nspGetRight 
   								NULL,				-- Facility
   								@c_StorerKey,	-- Storer
   								NULL,				-- Sku
   								'NIKEREGITF',	-- ConfigKey
   								@b_success		OUTPUT, 
   								@c_authority	OUTPUT, 
   								@n_err			OUTPUT, 
   								@c_errmsg		OUTPUT
   
   	         IF @b_success <> 1
   	         BEGIN
   	            SELECT @c_errmsg = 'ntrIDUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
   	            BREAK
   	         END
   	         ELSE 
   	         BEGIN
   	            IF @c_authority = '1'
   					BEGIN
   						IF (@c_InStatus = 'HOLD' AND @c_DelStatus = 'OK') OR (@c_InStatus = 'OK' AND @c_DelStatus = 'HOLD') 
   						BEGIN
   							IF ( @n_continue = 1 OR @n_continue = 2 ) 
   							BEGIN
   								BEGIN TRAN
   									INSERT INTO INVHOLDTRANSLOG 
   											(StorerKey, Sku, Facility, SourceKey, SourceType, UserID)
   									VALUES (@c_StorerKey, @c_Sku, @c_Facility, @c_CurrentID, 'ID', SUSER_SNAME())
   								COMMIT TRAN
   			-- (YokeBeen02) - End
   
   								SELECT @n_err = @@Error
   
   								IF NOT @n_err = 0
   								BEGIN
   									SELECT @n_continue = 3 
   									Select @c_errmsg = CONVERT(CHAR(250), @n_err), @n_err=99702
   									Select @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ':Insert failed on INVHOLDTRANSLOG. (ntrIDUpdate)' + '(' + 'SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ')' 
   								END 
   							END -- if @n_continue = 1 OR @n_continue = 2
   						END -- When Hold or Release
   					END -- IF @c_authority = '1'
   				END -- IF @b_success <> 1
   
   	         -- Generic Inventory Hold Configkey (Start)
   				SELECT @b_success = 0
   
   	         EXECUTE nspGetRight 
   								NULL,				-- Facility
   								@c_StorerKey,	-- Storer
   								NULL,				-- Sku
   								'INVHOLDLOG',	-- ConfigKey
   								@b_success		OUTPUT, 
   								@c_invholditf  OUTPUT, 
   								@n_err			OUTPUT, 
   								@c_errmsg		OUTPUT
   
   	         IF @b_success <> 1
   	         BEGIN
   	            SELECT @c_errmsg = 'ntrIDUpdate :' + dbo.fnc_RTrim(@c_errmsg), @n_continue = 3
   	            BREAK
   	         END
   	         ELSE 
   	         BEGIN
   	            IF @c_invholditf = '1'
   					BEGIN
   						IF (@c_InStatus = 'HOLD' AND @c_DelStatus = 'OK') OR (@c_InStatus = 'OK' AND @c_DelStatus = 'HOLD') 
   						BEGIN
   							IF ( @n_continue = 1 OR @n_continue = 2 ) 
   							BEGIN
   								BEGIN TRAN
                              -- SOS#74049 - To fix double sending of records (Start)
											SELECT @n_LocCnt = 0, @n_LotCnt = 0

                                 SELECT @n_LocCnt = COUNT(*)
                                 FROM TRANSMITLOG3 T3 (NOLOCK)
                                 JOIN INVENTORYHOLD IH (NOLOCK) ON (IH.InventoryHoldKey = T3.Key1)
                                 JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOC = IH.LOC AND 
                                                                  LLI.Storerkey = @c_StorerKey AND 
                                                                  LLI.ID = @c_CurrentID)
                                 WHERE T3.Tablename = 'INVHOLDLOG-LOC'
                                 AND   T3.Transmitflag = '0'
                                 AND   T3.Key2 = @c_InStatus

                                 IF @n_LocCnt = 0
                                 BEGIN
	                                 SELECT @n_LotCnt = COUNT(*)
	                                 FROM TRANSMITLOG3 T3 (NOLOCK)
	                                 JOIN INVENTORYHOLD IH (NOLOCK) ON (IH.InventoryHoldKey = T3.Key1)
	                                 JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOT = IH.LOT AND 
	                                                                  LLI.Storerkey = @c_StorerKey AND 
	                                                                  LLI.ID = @c_CurrentID)
	                                 WHERE T3.Tablename = 'INVHOLDLOG-LOT'
	                                 AND   T3.Transmitflag = '0'
	                                 AND   T3.Key2 = @c_InStatus
                                 END
                                  
                                 IF (@n_LocCnt = 0) AND (@n_LotCnt = 0)
                                 BEGIN
--                               Commented By Vicky for SOS#74919 (Start)                                    
-- 	      							      SELECT @b_success = 1                                                             
-- 	    							         EXEC ispGenTransmitLog3 'INVHOLDLOG-ID', @c_InvHoldKey, @c_InStatus, @c_StorerKey, ''
-- 	   							         , @b_success OUTPUT
-- 	   							         , @n_err OUTPUT
-- 	   							         , @c_errmsg OUTPUT
-- 	   
-- 	                                 IF @b_success <> 1
-- 	   							         BEGIN
-- 	   							            SELECT @n_continue = 3
-- 	   							            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810
-- 	   							            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to obtain transmitlogkey (ntrIDUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
-- 	   							         END
--                               Commented By Vicky for SOS#74919 (End)
--                               Added By Vicky for SOS#74919 (Start)
                                      IF NOT EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'INVHOLDLOG-ID'
                                                      AND Key1 = @c_InvHoldKey AND Key2 = @c_InStatus 
                                                      AND Key3 = @c_StorerKey AND Transmitflag = '0')
                                      BEGIN
													SELECT @c_transmitlogkey = ''
													SELECT @b_success = 1
													EXECUTE nspg_getkey
								                   'TransmitlogKey3'
								 		             ,10
								 	 	             , @c_transmitlogkey OUTPUT
								 		             , @b_success OUTPUT
								 		             , @n_err OUTPUT
								 		             , @c_errmsg OUTPUT
								
													IF @b_success <> 1
													BEGIN
														SELECT @n_continue=3
													END
                                       ELSE
                                       BEGIN
--                                          IF @c_InvHoldKey <> @c_PrevInvHoldKey AND @c_InStatus <> @c_PrevInStatus
--                                          BEGIN

								   						INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
								   						VALUES  (@c_transmitlogkey, 'INVHOLDLOG-ID', @c_InvHoldKey, @c_InStatus, @c_StorerKey,'0')
	
-- 	                                          SELECT @c_PrevInvHoldKey = '', @c_PrevInStatus = ''
-- 	                                          SELECT @c_PrevInvHoldKey = @c_InvHoldKey
-- 	                                          SELECT @c_PrevInStatus = @c_InStatus                                          
								   	
								   						SELECT @n_err= @@Error
								   	
								   						IF NOT @n_err=0
								   						BEGIN
								   							SELECT @n_continue=3 
								   							Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=74562
								   							Select @c_errmsg= 'NSQL' + CONVERT(char(5), @n_err)+ ':Insert failed on TransmitLog3. (ntrIDUpdate)' +'(' + 'SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ')'
								   						END 
                                       END -- Insert
--                                        END
                                     END -- not exists
--                               Added By Vicky for SOS#74919 (End)
                                 END -- Cnt
                                 -- SOS#74049 - To fix double sending of records (End)
   								COMMIT TRAN
   							END -- if @n_continue = 1 OR @n_continue = 2
   						END -- When Hold or Release
   					END -- IF @c_invholditf = '1'
   				END -- IF @b_success <> 1 INVHOLDLOG
     	         -- Generic Inventory Hold Configkey (End)
   			END -- While 1=1 - Sku Level
   		END -- While 1=1 - ID Level     
   	END -- If record exists
   END -- If Update(status) 
END
-- (YokeBeen01) - End

      /* #INCLUDE <TRRDU2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
	IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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

	EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrIDUpdate" 
	RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	RETURN
END
ELSE
BEGIN
	WHILE @@TRANCOUNT > @n_starttcnt
	BEGIN
		COMMIT TRAN
	END
	RETURN
END
END


GO