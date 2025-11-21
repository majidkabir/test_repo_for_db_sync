SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrLotUpdate                                                */
/* Creation Date:  17-Oct-2003                                          */
/* Copyright: IDS                                                       */
/* Written by:  YokeBeen                                                */
/*                                                                      */
/* Purpose:  (SOS#15352) - NIKE Regional (NSC) Project                  */
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
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 28-Dec-2004  YokeBeen      For NSC 947-InvAdj - (YokeBeen01)         */
/* 09-May-2006  MaryVong      Add in RDT compatible error message       */
/* 08-Aug-2006  Vicky         Generic Configkey (INVHOLDLOG) for        */
/*                            Inventory Hold Interface                  */
/* 23-Apr-2007	 Vicky         SOS#74049 - Fix interface double sending */
/* 04-May-2007  Vicky         SOS#74919 - Insert direct to Transmitlog3 */
/*                            without checking on uniqueness of         */
/*                            Key1 + Key2  + Key3 for INVHOLDLOG        */  
/* 04-Jul-2007  Vicky         SOS#80373 - Add checking on duplicate     */
/*                            Invholdkey with both status = 0 being     */
/*                            inserted into Transmitlog3                */  
/* 09-Sep-2011  TLTING01      New column update Editdate Edit Who       */
/*	                           for Datamart Extraction                   */
/* 23 May 2012  TLTING02      DM integrity - add update editdate B4     */
/*                            TrafficCop                                */
/* 28-Oct-2013  TLTING        Review Editdate column update             */ 
/* 20-Sep-2016  TLTING        Change SetROWCOUNT 1 to Top 1             */
/* 28-Sep-2018  TLTING        Remove row lock                           */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrLotUpdate]
ON  [dbo].[LOT]
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
   	,  @c_errmsg    NVARCHAR(250) -- Error message returned by stored procedure or this trigger
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
   
   -- TLTING02
	IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
	BEGIN
		UPDATE LOT  
		SET EditDate = GETDATE(),
		    EditWho = SUSER_SNAME(),
		    TrafficCop = NULL	
		FROM LOT , INSERTED (NOLOCK)
		WHERE LOT.LOT = INSERTED.LOT

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=74565   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOT. (ntrLOTUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
		END
	END

   IF UPDATE(TrafficCop)
   BEGIN
   	SELECT @n_continue = 4 
   END   

   /* #INCLUDE <TRRDU1.SQL> */     
   DECLARE @c_CurrentLOT  NVARCHAR(18),
           @c_InvHoldKey NVARCHAR(10),
           @c_HoldReason NVARCHAR(10),
           @c_InStatus   NVARCHAR(10),
           @c_DelStatus	 NVARCHAR(10),
           @c_authority NVARCHAR(1),
   		  @c_Sku		 NVARCHAR(20),
   		  @c_StorerKey NVARCHAR(18),
   		  @c_TranStatus NVARCHAR(10),
   -- (YokeBeen01) - Start
   		  @c_Facility NVARCHAR(5)

	-- SOS#74049 (Start)
	DECLARE @n_IDCnt  int,
	        @n_LocCnt int

   DECLARE @c_transmitlogkey NVARCHAR(10)
	
	SELECT @n_IDCnt = 0,
	       @n_LocCnt = 0
	-- SOS#74049 (End)

   SELECT  @c_CurrentLOT	= '' ,
           @c_InvHoldKey	= '' ,
           @c_HoldReason	= '' ,
           @c_InStatus		= '' ,
           @c_DelStatus		= '' ,
           @c_authority		= '' ,
   		  @c_Sku				= '' ,
   		  @c_StorerKey		= '' ,
   		  @c_TranStatus	= '' ,
   		  @c_Facility		= '' 
   -- (YokeBeen01) - End

	-- Generic Configkey (Start)
	DECLARE @c_invholditf NVARCHAR(1)
	SELECT @c_invholditf  = '0'
	-- Generic Configkey (End)

   IF ( @n_continue=1 OR @n_continue=2)  AND UPDATE(STATUS)
   BEGIN
   	IF EXISTS (SELECT INVENTORYHOLD.LOT 
   					 FROM INVENTORYHOLD (NOLOCK), INSERTED, DELETED 
                  WHERE INSERTED.LOT = DELETED.LOT
                    AND INSERTED.LOT = INVENTORYHOLD.LOT
                    AND INSERTED.STATUS <> DELETED.STATUS)
   	BEGIN
   		SELECT TOP 1 @c_Storerkey = Storerkey FROM INSERTED (NOLOCK)
   
   		SELECT @b_success = 0
   		SELECT @c_authority = '0'

         EXECUTE nspGetRight 
			NULL,				-- Facility
			@c_StorerKey,	-- Storer
			NULL,				-- Sku
			'INVHOLDLOG',	-- ConfigKey
			@b_success		OUTPUT, 
			@c_invholditf	OUTPUT, 
			@n_err			OUTPUT, 
			@c_errmsg		OUTPUT
   
   	   IF @b_success <> 1
   	   BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 60981
   	      SELECT @c_errmsg = 'ntrLotUpdate :' + RTrim(@c_errmsg) 
   	   END
   
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
            SELECT @n_continue = 3
            SELECT @n_err = 60981
   	      SELECT @c_errmsg = 'ntrLotUpdate :' + RTrim(@c_errmsg) 
   	   END

    IF (@n_continue = 1 or @n_continue = 2)
   	   BEGIN
   			IF (@c_authority = '1') or (@c_invholditf = '1')
   			BEGIN
   	         SELECT @c_CurrentLOT = SPACE(10)
   
   		      WHILE (1=1)	-- LOT Level
   				BEGIN
   		      	
   		         SELECT TOP 1 @c_CurrentLOT = INSERTED.LOT,
   		                @c_InStatus  = INSERTED.Status,
   		                @c_DelStatus = DELETED.Status,
                         @c_InvHoldKey = INVENTORYHOLD.InventoryHoldKey
   		           FROM INVENTORYHOLD (NOLOCK), INSERTED, DELETED 
   		          WHERE INSERTED.LOT = DELETED.LOT
   		            AND INSERTED.LOT = INVENTORYHOLD.LOT
   		            AND INSERTED.STATUS <> DELETED.STATUS
   		            AND INSERTED.LOT > @c_CurrentLOT
   		          ORDER BY INSERTED.LOT  
   
   					IF @@ROWCOUNT = 0
   		         BEGIN
   		         	BREAK
   		         END
   
   		         SELECT DISTINCT TOP 1 
   							 @c_Sku = INSERTED.Sku,
   							 @c_StorerKey = INSERTED.StorerKey
   		           FROM INVENTORYHOLD (NOLOCK), INSERTED, DELETED
   		          WHERE INSERTED.LOT = DELETED.LOT
   		            AND INSERTED.LOT = INVENTORYHOLD.LOT
   		            AND INSERTED.STATUS <> DELETED.STATUS
   		            AND INSERTED.LOT = @c_CurrentLOT
   
   					-- When HOLD or Release
   					IF (@c_InStatus = 'HOLD' AND @c_DelStatus = 'OK') OR (@c_InStatus = 'OK' AND @c_DelStatus = 'HOLD')
   					BEGIN
   						IF ( @n_continue = 1 OR @n_continue = 2 ) 
   						BEGIN
   						-- (YokeBeen01) - Start
   						-- Inventory to OnHold/Release should based on Facility level
   							SELECT @c_Facility = SPACE(5)
   
   					      WHILE (1=1)	-- Facility Level
   							BEGIN
   					      	
   								SELECT DISTINCT TOP 1 @c_Facility = LOC.Facility 
   								  FROM LOTXLOCXID L (NOLOCK) 
   								  JOIN LOT LOT (NOLOCK) ON (L.Lot = LOT.Lot AND L.Storerkey = LOT.Storerkey AND L.Sku = LOT.Sku)
   								  JOIN LOC LOC (NOLOCK) ON (L.Loc = LOC.Loc)
   								 WHERE LOT.Lot = dbo.fnc_RTrim(@c_CurrentLOT)
   									AND LOT.Sku = @c_Sku
   									AND LOT.Storerkey = @c_StorerKey
   									AND LOC.Facility > @c_Facility
   								ORDER BY LOC.Facility	
   
   								IF @@ROWCOUNT = 0
   					         BEGIN
   					         	BREAK
   					         END
                           
                           IF @c_authority = '1'
                           BEGIN
	   								BEGIN TRAN
	   									INSERT INTO INVHOLDTRANSLOG 
	   											(StorerKey, Sku, Facility, SourceKey, SourceType, UserID)
	   									VALUES (@c_StorerKey, @c_Sku, @c_Facility, @c_CurrentLOT, 'LOT', SUSER_SNAME())
	   								COMMIT TRAN
              					-- (YokeBeen01) - End
                             
   								SELECT @n_err = @@Error
   
   								IF NOT @n_err = 0
   								BEGIN
   									SELECT @n_continue = 3 
   									Select @c_errmsg = CONVERT(CHAR(250), @n_err), @n_err= 60982 --99702
   									Select @c_errmsg = 'NSQL' + CONVERT(CHAR(5), @n_err) + ':Insert failed on INVHOLDTRANSLOG. (ntrLotUpdate)' + '(' + 'SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ')' 
   								END 
                          END --  @c_authority = '1'
                          ELSE
                          IF @c_invholditf = '1'
                          BEGIN
                            BEGIN TRAN
					               -- SOS#74049 - To fix double sending of records (Start)
										SELECT @n_IDCnt = 0,  @n_LocCnt = 0
					
					               SELECT @n_IDCnt = COUNT(*)
					               FROM TRANSMITLOG3 T3 (NOLOCK)
					               JOIN INVENTORYHOLD IH (NOLOCK) ON (IH.InventoryHoldKey = T3.Key1)
					               JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.ID = IH.ID AND 
					                                                LLI.Storerkey = @c_StorerKey AND 
					                                                LLI.LOT = @c_CurrentLOT)
					               WHERE T3.Tablename = 'INVHOLDLOG-ID'
					               AND   T3.Transmitflag = '0'
					               AND   T3.Key2 = @c_InStatus
					
					               IF @n_IDCnt = 0
					               BEGIN
					                  SELECT @n_LocCnt = COUNT(*)
					                  FROM TRANSMITLOG3 T3 (NOLOCK)
					                  JOIN INVENTORYHOLD IH (NOLOCK) ON (IH.InventoryHoldKey = T3.Key1)
					                  JOIN LOTxLOCxID LLI (NOLOCK) ON (LLI.LOC = IH.LOC AND 
					                                                   LLI.Storerkey = @c_StorerKey AND 
					                                                   LLI.LOT = @c_CurrentLOT)
					                  WHERE T3.Tablename = 'INVHOLDLOG-LOC'
					                  AND   T3.Transmitflag = '0'
					                  AND   T3.Key2 = @c_InStatus
					               END

                              IF (@n_IDCnt = 0) AND (@n_LocCnt = 0)
                              BEGIN
                                -- SOS#80373 (Start)
                                IF NOT EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'INVHOLDLOG-LOT'
                                                AND Key1 = @c_InvHoldKey AND Key2 = @c_InStatus 
                                                AND Key3 = @c_StorerKey AND Transmitflag = '0')
                                BEGIN
           	                    --  Added By Vicky for SOS#74919 (Start)
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
						   						INSERT INTO TRANSMITLOG3  (Transmitlogkey, Tablename, Key1, Key2, Key3, Transmitflag)
						   						VALUES  (@c_transmitlogkey, 'INVHOLDLOG-LOT', @c_InvHoldKey, @c_InStatus, @c_StorerKey,'0')
						   	
						   						SELECT @n_err= @@Error
						   	
						   						IF NOT @n_err=0
						   						BEGIN
						   							SELECT @n_continue=3 
						   							Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=74562
						   							Select @c_errmsg= 'NSQL' + CONVERT(char(5), @n_err)+ ':Insert failed on TransmitLog3. (ntrLotUpdate)' +'(' + 'SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ')'
						   						END 
						                 END
                               END -- SOS#80373 (End)
--                    Added By Vicky for SOS#74919 (End)
	                           END
                              -- SOS#74049 - To fix double sending of records (End)
								      COMMIT TRAN
                          END -- @c_invholditf = '1'
   					      END -- WHILE (1=1) - Facility Level
   						END -- if @n_continue = 1 OR @n_continue = 2
   					END -- When HOLD or Release
   				END -- While 1=1 - LOT Level 
   			END -- @c_authority = '1' or @c_invholditf = '1'
   		END -- IF (@n_continue = 1 or @n_continue = 2)
   	END -- if record exists
   END -- IF @n_continue=1

   /* #INCLUDE <TRRDU2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide
   
         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN
   
         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR 
   
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrLotUpdate'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
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