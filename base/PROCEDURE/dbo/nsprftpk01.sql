SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFTPK01                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC    [dbo].[nspRFTPK01]  
 @c_sendDelimiter    NVARCHAR(1)  
 ,              @c_ptcid            NVARCHAR(5)  
 ,              @c_userid           NVARCHAR(18)  
 ,              @c_taskId           NVARCHAR(10)  
 ,              @c_databasename     NVARCHAR(30)  
 ,              @c_appflag          NVARCHAR(5)  
 ,              @c_recordType       NVARCHAR(2)  
 ,              @c_server           NVARCHAR(30)  
 ,              @c_ttm              NVARCHAR(5)  
 ,              @c_taskdetailkey    NVARCHAR(10)  
 ,              @c_storerkey        NVARCHAR(15)  
 ,              @c_sku              NVARCHAR(30)  
 ,              @c_fromloc          NVARCHAR(18)  
 ,              @c_fromid           NVARCHAR(18)  
 ,              @c_toloc            NVARCHAR(18)  
 ,              @c_dropid           NVARCHAR(18)  
 ,              @c_lot              NVARCHAR(10)  
 ,              @n_qty              int  
 ,              @c_caseid           NVARCHAR(10) -- use to display the expiry date
 ,              @c_packkey          NVARCHAR(10) -- use as converted carton and eaches qty
 ,              @c_uom              NVARCHAR(10)  
 ,              @c_reasoncode       NVARCHAR(10)  
 ,              @c_outstring        NVARCHAR(255)  OUTPUT  
 ,              @b_Success          int        OUTPUT  
 ,              @n_err              int        OUTPUT  
 ,              @c_errmsg           NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
 	  
 	DECLARE @b_debug int  
 	SELECT @b_debug = 1  
 	DECLARE        @n_continue int        ,    
 	@n_starttcnt int        , -- Holds the current transaction count  
 	@n_cnt int              , -- Holds @@ROWCOUNT after certain operations  
 	@n_err2 int               -- For Additional Error Detection  
 	DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure  
 	DECLARE @n_cqty int, @n_returnrecs int  
 	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0  
 	SELECT @c_retrec = "01"  
 	SELECT @n_returnrecs=1  
 	DECLARE @c_requestedsku NVARCHAR(20), @n_requestedqty int, @c_requestedlot NVARCHAR(10),  
 	@c_requestedfromid NVARCHAR(18), @c_requestedfromloc NVARCHAR(10),  
 	@c_requesteddropid NVARCHAR(18), @c_requestedtoloc NVARCHAR(10),  
 	@c_requestedwavekey NVARCHAR(10), @c_currentstatus NVARCHAR(10),  
 	@c_requestedcaseid NVARCHAR(10), @c_wavekey NVARCHAR(10)  
 	DECLARE @b_compareid int, @b_comparecaseid int, @b_comparelot int, @b_qtymustmatch int  
 	SELECT @b_compareid = 0, @b_comparecaseid = 0, @b_comparelot = 0, @b_qtymustmatch = 0  
 	DECLARE @c_palletpickdispatchmethod NVARCHAR(10), @c_casepickdispatchmethod NVARCHAR(10), @c_piecepickdispatchmethod NVARCHAR(10)  
 	DECLARE @n_taskdetailcount int, @n_caseidcount int, @n_lotcount int, @n_idcount int  , @c_batchind NVARCHAR(5), @c_loadkey NVARCHAR(10)
      /* #INCLUDE <SPTPK01_1.SQL> */       
 	IF @n_continue=1 OR @n_continue=2  
 	BEGIN  
 		SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )  
 	END  
 	IF @n_continue = 1 or @n_continue = 2  
 	BEGIN  
 		SELECT @c_requestedsku = TASKDETAIL.SKU,  
 		@n_requestedqty = QTY,  
 		-- @c_requestedlot = LOT,  
       @c_requestedlot = LOT, -- use lot as a lottable04
       @c_lot = LOT, --XXX assume they use the same lot
 		@c_requestedfromid  = FROMID,  
 		@c_requestedfromloc = FROMLOC,  
 		@c_requesteddropid  = TOID,  
 		@c_requestedtoloc = TOLOC,  
 		@c_requestedwavekey = WAVEKEY,  
 		@c_requestedcaseid = CASEID,  
 		@c_currentstatus = STATUS,  
 		@c_wavekey = WAVEKEY ,
 		@c_loadkey = SOURCEKEY,
       @c_caseid = CASEID, -- XXX
       @c_packkey = SKU.PackKey -- use back the same packkey
 		FROM TASKDETAIL  
       JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = TASKDETAIL.StorerKey AND SKU.SKU = TASKDETAIL.SKU)
 		WHERE TASKDETAILKEY = @c_taskdetailkey  
 		IF @@ROWCOUNT = 0  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81801, @c_errmsg = "NSQL81801:Invalid TaskDetail Key"  
 		END  
 IF @b_debug = 1
 BEGIN
 	select '@c_loadkey' = @c_loadkey, '@n_requestedqty' = @n_requestedqty, '@n_qty' = @n_qty
 END
 		--CCLAW  
 		--FBR28d  
 		IF @n_continue = 1 or @n_continue = 2  
 		BEGIN  
 			IF EXISTS (SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE NSQLVALUE = '1' AND CONFIGKEY = 'PUTAWAYTASK')  
 			BEGIN  
 		  		SELECT  @c_requestedtoloc = logicaltoloc  
 	  			FROM TaskDetail (NOLOCK)  
 	  			WHERE  TASKDETAILKEY = @c_taskdetailkey  
 	 		END  
 		END  
 		--CCLAW  
 	END  
 	IF @n_continue = 1 or @n_continue = 2  
 	BEGIN  
 		SELECT @n_taskdetailcount = COUNT(*),  
 		@n_requestedqty = SUM(QTY),  
 		@n_caseidcount = COUNT(DISTINCT CASEID),  
 		@n_lotcount = COUNT(DISTINCT LOT),  
 		@n_idcount = COUNT(DISTINCT FROMID)  
 		FROM TASKDETAIL  
 		WHERE Userkey = @c_userid  
 		AND STATUS = "3"  
 		AND TASKTYPE = "PK"  
 	END  
 	IF @n_continue=1 OR @n_continue=2  
 	BEGIN  
 		IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL  
 		BEGIN  
 			SELECT @b_success = 0  
 			EXECUTE nspg_GETSKU  @c_StorerKey   = @c_StorerKey,  
 			@c_sku         = @c_sku     OUTPUT,  
 			@b_success     = @b_success OUTPUT,  
 			@n_err         = @n_err     OUTPUT,  
 			@c_errmsg      = @c_errmsg  OUTPUT  
 			IF NOT (@b_success = 1)  
 			BEGIN  
 				SELECT @n_continue = 3  
 			END  
 		END  
 	END  
 	IF @n_continue=1 OR @n_continue=2  
 	BEGIN  
 		IF @c_currentstatus = "9"  
 		BEGIN   
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81802, @c_errmsg = "NSQL81813:" + "Item Already Processed!"  
 		END  
 	END  
 	IF @n_continue = 1 or @n_continue = 2  
 	BEGIN  
 		IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_wavekey)) IS NOT NULL  
 		BEGIN  
 			SELECT @c_palletpickdispatchmethod = dispatchpalletpickmethod,  
 			@c_casepickdispatchmethod = dispatchcasepickmethod,  
 			@c_piecepickdispatchmethod = dispatchpiecepickmethod  
 			FROM WAVE  
 			WHERE WAVEKEY = @c_wavekey  
 		END  
 		ELSE  
 		BEGIN  
 			SELECT @c_palletpickdispatchmethod = "1",  
 			@c_casepickdispatchmethod = "1",  
 			@c_piecepickdispatchmethod = "1"  
 		END  
 	END  
 	IF @n_continue = 1 or @n_continue = 2  
 	BEGIN  
 		IF @n_taskdetailcount = 1  
 		BEGIN  
 			SELECT @b_compareid = 1, @b_comparecaseid = 1, @b_qtymustmatch = 0, @b_comparelot = 1  
 		END  
 		ELSE  
 		BEGIN  
 			SELECT @b_compareid = 0, @b_comparecaseid = 0, @b_comparelot = 0,  
 			@b_qtymustmatch = 1  
 			IF @n_caseidcount = 1  
 			BEGIN  
 				SELECT @b_comparecaseid = 1  
 			END  
 			IF @n_idcount = 1  
 			BEGIN  
 				SELECT @b_compareid = 1  
 			END  
 			IF @n_lotcount = 1  
 			BEGIN  
 				SELECT @b_comparelot = 1  
 			END  
 		END  
 	END  
 	IF @n_continue=1 OR @n_continue=2  
 	BEGIN  
 		IF @c_sku <> @c_requestedsku  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81803, @c_errmsg = "NSQL81802:" + "Invalid Sku!"  
 		END  
 	END  
 	IF @n_continue=1 OR @n_continue=2  
 	BEGIN  
 		IF @c_fromloc <> @c_requestedfromloc  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81804, @c_errmsg = "NSQL81808:" + "Invalid From Loc!"  
 		END  
 	END  
 	IF @n_continue=1 OR @n_continue=2  
 	BEGIN  
 		IF @c_toloc <> @c_requestedtoloc and dbo.fnc_LTrim(dbo.fnc_RTrim(@c_requestedtoloc)) IS NOT NULL  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81805, @c_errmsg = "NSQL81810:" + "Invalid To Loc!"  
 		END  
 	END  
 	IF (@n_continue=1 OR @n_continue=2) and @b_compareid = 1  
 	BEGIN  
 		IF @c_fromid <> @c_requestedfromid  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81806, @c_errmsg = "NSQL81806:" + "Invalid From ID!"  
 		END  
 	END  
 	IF (@n_continue=1 OR @n_continue=2) and @b_comparecaseid = 1  
 	BEGIN  
 		IF @c_caseid <> @c_requestedcaseid  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81807, @c_errmsg = "NSQL81814:" + "Invalid From ID!"  
 		END  
 	END  
 	IF (@n_continue=1 OR @n_continue=2) and @b_comparelot = 1  
 	BEGIN  
 		IF @c_lot <> @c_requestedlot  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81808, @c_errmsg = "NSQL81807:" + "Invalid Lot!"  
 		END  
 	END  
 IF @b_debug = 1
 BEGIN
 	select '@n_qty'= @n_qty, '@n_requestedqty' = @n_requestedqty
 END
 	IF (@n_continue=1 OR @n_continue=2) and @b_qtymustmatch = 1  
 	BEGIN  
 		IF @n_qty <> @n_requestedqty  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81809, @c_errmsg = "NSQL81807:" + "Invalid Qty!"  
 		END  
 	END  
 	IF @n_continue = 1 or @n_continue = 2  
 	BEGIN  
 		IF (@n_qty <> @n_requestedqty) AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_reasoncode)) IS NULL  
 		BEGIN  
 			SELECT @n_continue = 3  
 			SELECT @n_err = 81810, @c_errmsg = "NSQL81807:" + "A reason code is needed for short picks!"  
 		END  
 	END  
 	IF @n_continue = 1 or @n_continue = 2  
 	BEGIN  
 		IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_reasoncode)) IS NOT NULL  
 		BEGIN  
 			IF NOT EXISTS (SELECT * FROM TaskManagerReason  
 			WHERE TaskManagerReasonKey = @c_reasoncode  
 			AND ValidInToLoc = "1"  
 			)  
 			BEGIN  
 				SELECT @n_continue = 3  
 				SELECT @n_err = 81811, @c_errmsg = "NSQL81803:" + "Invalid ReasonCode!"  
 			END  
 		END  
 	END  
 	IF @n_continue = 1 or @n_continue = 2  
 	BEGIN  
 		BEGIN TRAN  
 		IF @n_qty > 0  
 		BEGIN  
 			IF @b_qtymustmatch = 1  
 			BEGIN  
 				UPDATE TASKDETAIL  
 				SET STATUS = "9" ,  
 				FromLoc = @c_fromloc,  
 				FromId = @c_fromid,  
 				ToLoc = @c_toloc,  
 				Toid = @c_dropid,  
 				Reasonkey = @c_reasoncode,  
 				UserPosition = "1", -- This task is being performed at the FROMLOC  
 				EndTime = getdate()  
 				WHERE tasktype = "PK"  
 				and userkey = @c_userid  
 				and status = "3" 
 				AND Taskdetailkey = @c_taskdetailkey 
 			END  
 			ELSE  
 			BEGIN  
 				UPDATE TASKDETAIL  
 				SET STATUS = "9" ,  
 				Qty = @n_qty ,  
 				FromLoc = @c_fromloc,  
 				FromId = @c_fromid,  
 				ToLoc = @c_toloc,  
 				Toid = @c_dropid,  
 				Reasonkey = @c_reasoncode,  
 				UserPosition = "1", -- This task is being performed at the FROMLOC  
 				EndTime = getdate()  
 				WHERE tasktype = "PK"  
 				and userkey = @c_userid  
 				and status = "3"  
 				AND Taskdetailkey = @c_taskdetailkey
 			END  
 			SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 			IF @n_err <> 0  
 			BEGIN  
 				SELECT @n_continue = 3  
 				SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=81812   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
 				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TaskDetail. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
 			END 
 			IF @n_continue = 1 OR @n_continue = 2
 			BEGIN
 				IF EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE PICKSLIPNO = @c_taskdetailkey ) -- AND SOURCETYPE = 'BATCHPICK')
 				BEGIN
 					UPDATE PICKDETAIL
 					SET STATUS = '5'
 					WHERE PICKSLIPNO = @c_taskdetailkey
 					AND STATUS IN ('0', '1', '2', '3', '4')
 					SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
 					IF @n_err <> 0  
 					BEGIN  
 						SELECT @n_continue = 3  
 						SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=81819   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
 						SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update failed on Pickdetail table.(nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
 					END 
 				END -- IF EXISTS
 			END -- @n_continue		
 		END  -- qty > 0
 		IF @n_continue = 3  
 		BEGIN  
 			ROLLBACK TRAN  
 		END  
 		ELSE  
 		BEGIN  
 			COMMIT TRAN  
 		END  
 	END -- @n_continue = 1 or @n_continue = 2  
 	IF @n_continue=3  
 	BEGIN  
 		IF @c_retrec="01"  
 		BEGIN  
 			SELECT @c_retrec="09", @c_appflag = "TPK"  
 		END  
 	END  
 	ELSE  
 	BEGIN  
 		SELECT @c_retrec="01"  
 	END  
 SELECT @c_outstring =   @c_ptcid        + @c_senddelimiter  
 + dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter  
 + dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter  
 + dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter  
 + dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter  
 + dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter  
 + dbo.fnc_RTrim(@c_server)           + @c_senddelimiter  
 + dbo.fnc_RTrim(@c_errmsg)  
 SELECT dbo.fnc_RTrim(@c_outstring)  
      /* #INCLUDE <SPTPK01_2.SQL> */  
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
 execute nsp_logerror @n_err, @c_errmsg, "nspRFTPK01"  
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
 END  

GO