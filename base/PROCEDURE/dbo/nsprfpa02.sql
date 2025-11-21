SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFPA02                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 31-Mar-2006  MaryVong   Add in RDT compatible error messages         */
/*                         Modification excluded TaskType = 'PK'        */
/* 18-Sep-2006  MaryVong   Bug Fix - Raise Error to support RDT         */
/* 2007-07-16   TLTING     SQL2005, Status = 9 put '9'                  */
/* 2012-08-27   Ung        Performance tuning (ung01)                   */
/************************************************************************/

CREATE PROC [dbo].[nspRFPA02]    
                @c_sendDelimiter    NVARCHAR(1)        
 ,              @c_ptcid            NVARCHAR(5)     
 ,              @c_userid           NVARCHAR(10)        
 ,              @c_taskId           NVARCHAR(10)       
 ,              @c_databasename     NVARCHAR(5)        
 ,              @c_appflag          NVARCHAR(2)        
 ,              @c_recordType       NVARCHAR(2)        
 ,              @c_server           NVARCHAR(30)    
 ,              @c_storerkey        NVARCHAR(30)    
 ,              @c_lot              NVARCHAR(10)    
 ,              @c_sku              NVARCHAR(30)    
 ,              @c_fromloc          NVARCHAR(18)    
 ,              @c_fromid           NVARCHAR(18)    
 ,              @c_toloc            NVARCHAR(18)    
 ,              @c_toid             NVARCHAR(18)    
 ,              @n_qty              int    
 ,              @c_uom              NVARCHAR(10)    
 ,              @c_packkey          NVARCHAR(10)    
 ,              @c_reference        NVARCHAR(10)    
 ,              @c_outstring        NVARCHAR(255)  OUTPUT    
 ,              @b_Success          int        OUTPUT    
 ,              @n_err              int        OUTPUT    
 ,              @c_errmsg           NVARCHAR(250)  OUTPUT    
AS    
BEGIN -- MAIN    
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue int        ,  /* continuation flag     
                                      1=Continue    
                                      2=failed but continue processsing     
                                      3=failed do not continue processing     
                                      4=successful but skip furthur processing */
            @n_starttcnt int        , -- Holds the current transaction count                                                                                               
            @c_preprocess NVARCHAR(250) , -- preprocess    
            @c_pstprocess NVARCHAR(250) , -- post process    
            @n_err2 int,               -- For Additional Error Detection    
            @c_SuggestedLoc NVARCHAR(10), -- Loc Suggested by the PA process  
            @n_checkqty     Int       -- Qty from RFPUTAWAY table  
   /* Declare RF Specific Variables */    
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure    
   DECLARE @c_dbnamestring NVARCHAR(255)
   DECLARE @n_cqty int, @n_returnrecs int,@n_cnt int    
   /* Set default values for variables */    
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0    
   SELECT @c_retrec = "01"  
   SELECT @n_returnrecs=1    
   DECLARE @b_debug int    
   SELECT @b_debug = 0    
   IF @b_debug = 1    
   BEGIN     
      SELECT @c_storerkey "@c_storerkey", @c_lot "@c_lot", @c_sku "@c_sku", @c_fromloc "@c_fromloc", @c_fromid "@c_fromid", @c_toloc "@c_toloc", @c_toid "@c_toid", @n_qty "@n_qty", @c_uom "@c_uom", @c_packkey "@c_packkey"    
   END
   /* Execute Preprocess */    
   /* #INCLUDE <SPRFPA02_1.SQL> */
   /* End Execute Preprocess */    
   /* Start Main Processing */    
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_packkey= PACKKEY
      FROM SKU (NOLOCK)
      WHERE SKU = @c_sku
      AND   STORERKEY = @c_storerkey
      IF @b_debug = 1 SELECT 'packkey' = @c_packkey
   END
   /* Calculate Sku Supercession */    
   DECLARE @c_putawayFlag NVARCHAR(1), @c_tasktype NVARCHAR(10), @c_originaltoloc NVARCHAR(10)    
   SELECT @c_putawayflag = '1'    
   SELECT @c_tasktype = ''    
   IF EXISTS (SELECT 1 FROM PUTAWAYTASK (NOLOCK) WHERE ID = @c_fromid and FROMLOC = @c_fromloc and status = '0') AND    
      EXISTS(SELECT 1 FROM NSQLCONFIG (NOLOCK) WHERE NSQLVALUE = '1' AND CONFIGKEY = 'PUTAWAYTASK' )    
   BEGIN
      SELECT @c_putawayflag = '0'
      SELECT  @c_tasktype = TASKDETAIL.TaskType, @c_originaltoloc = PUTAWAYTASK.ToLoc    
      FROM PUTAWAYTASK (NOLOCK), TASKDETAIL (NOLOCK)    
      WHERE PUTAWAYTASK.TaskDetailKey = TASKDETAIL.TaskDetailKey    
      AND PUTAWAYTASK.Status = '0'    
      AND PUTAWAYTASK.ID = @c_fromid    
      AND PUTAWAYTASK.FromLoc = @c_fromloc      
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(UPPER(@c_originaltoloc))) <> dbo.fnc_LTrim(dbo.fnc_RTrim(UPPER(@c_toloc)))    
      BEGIN    
         SELECT @n_continue = 3
         SELECT @n_err = 60951 --66255  
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Toloc. (nspRFPA02)"    
      END
      IF @n_continue = 1 OR @n_continue = 2    
      BEGIN    
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_tasktype)) = 'PK'
         BEGIN    
            -- For PK task, we have done everything,
            SELECT @n_continue = 5 --Don't process anything unless it has been notify.    
         END    
         ELSE    
         BEGIN    
            SELECT @c_storerkey = STORERKEY    
            FROM LOTXLOCXID (NOLOCK)    
            WHERE ID = @c_fromid    
            AND   LOC = @c_fromloc    
            AND   Qty > 0    
         END
      END
   END    
   IF @n_continue=1 OR @n_continue=2    
   BEGIN    
      IF @c_putawayflag = '1'    
      BEGIN 
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
         BEGIN
            SELECT @b_success = 0    
            EXECUTE nspg_GETSKU    
               @c_StorerKey   = @c_StorerKey,    
               @c_sku         = @c_sku     OUTPUT,    
               @b_success     = @b_success OUTPUT,    
               @n_err         = @n_err     OUTPUT,    
               @c_errmsg      = @c_errmsg  OUTPUT    
            IF NOT @b_success = 1    
            BEGIN    
               SELECT @n_continue = 3
               SELECT @n_err = 60952
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Error On Execute nspg_GETSKU. (nspRFPA02)"    
            END    
            ELSE IF @b_debug = 1    
            BEGIN    
               SELECT @c_sku "@c_sku"    
            END
         END             
      END-- if @c_putawayflag    
   END         
   /* Calculate next Task ID */    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )    
   END         
   /* End Calculate Next Task ID */    
   --** retreive Qty by Storekey x Sku x FromLoc if n_qty is blank (ZY)    
   -- we want to obtain the qty from the lotxlocxid table, as putawaytask table does not contain the qty.    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN    
      IF (@n_qty IS NULL) OR (@c_putawayflag  = '0')    
      BEGIN
         SELECT @n_qty = qty 
         FROM LOTxLOCxID (NOLOCK) 
         WHERE id = @c_fromid 
         AND   qty - qtypicked > 0    
         SELECT @n_cnt = @@ROWCOUNT
         IF NOT @n_cnt = 1    
         BEGIN
            IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NULL
            BEGIN
               SELECT @n_qty = qty
               FROM LOTxLOCxID (NOLOCK)
               WHERE storerkey = @c_storerkey
               AND   sku = @c_sku
               AND   qty - qtypicked > 0
               SELECT @n_cnt = @@ROWCOUNT
               IF NOT @n_cnt = 1    
               BEGIN    
                  -- retrieve using sku & loc & storer-- 
                  IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) IS NULL
                  BEGIN    
                     SELECT @n_qty = qty    
                     FROM LOTxLOCxID (NOLOCK)   
                     WHERE storerkey = @c_storerkey    
                     AND   sku = @c_sku    
                     AND   loc = @c_fromloc    
                     -- AND id = @c_id    
                     AND   qty - qtypicked > 0    
                     SELECT @n_cnt = @@ROWCOUNT
                     IF @n_cnt = 0
                     BEGIN
                        SELECT @n_continue = 3 
                        SELECT @n_err = 60953 --66205
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Data Not Found - by STORER, SKU & LOC. (nspRFPA02)"
                     END
                     ELSE IF @n_cnt > 1
                     BEGIN
                        SELECT @n_continue = 3 
                        SELECT @n_err = 60954 --66205
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Get More Than 1 Qty - by STORER, SKU & LOC. (nspRFPA02)"
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @n_continue = 3     
                     SELECT @n_err = 60955 --66206
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": FromLoc Is Blank - by STORER, SKU & LOC. (nspRFPA02)"
                  END
               END    
            END  -- IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NULL       
            ELSE    
            -- error: bad input parameter(s)     
            BEGIN    
               SELECT @n_continue = 3     
               SELECT @n_err = 60956 --66200    
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input - STORER Or SKU. (nspRFPA02)"    
            END    
         END -- IF NOT @n_cnt = 1    
      END -- IF  ( @n_qty IS NULL ) OR (@c_putawayflag  = '0')     
   END -- IF @n_continue = 1 or @n_continue = 2    
   --** Retrieve fromid by storerkey, sku, loc if user not key in ID ()    
   IF @n_continue = 1 OR @n_continue = 2    
   BEGIN
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NULL
      BEGIN    
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) IS NULL
         BEGIN  
            SELECT @c_fromid = id, @c_lot = lot 
            FROM   LOTxLOCxID (NOLOCK)
            WHERE  STORERKEY = @c_storerkey 
            AND    SKU = @c_sku 
            AND    lot = @c_lot
         END
         ELSE
         BEGIN
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NULL
            BEGIN
               SELECT @c_fromid = id, @c_lot = lot 
               FROM  LOTxLOCxID (NOLOCK)
               WHERE STORERKEY = @c_storerkey 
               AND   SKU  = @c_sku 
               AND   LOC = @c_fromloc 
            END
            ELSE	
            BEGIN 
               SELECT @c_fromid = id, @c_lot = lot 
               FROM  LOTxLOCxID (NOLOCK)
               WHERE STORERKEY = @c_storerkey 
               AND   SKU  = @c_sku 
               AND   LOC = @c_fromloc 
               AND   lot = @c_lot
            END
         END                  
      END    
      ELSE
      BEGIN
         IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NULL
         BEGIN
            SELECT @c_lot = lot 
            FROM LOTxLOCxID (NOLOCK)
            WHERE ID = @c_fromid 
            AND   LOC = @c_fromloc    
            AND   Qty > 0
         END
      END
   END
         
   -- Check Qty to Move before too late
   IF @b_debug = 1  SELECT @c_lot 'lot', @c_fromloc 'loc', @c_fromid 'id', convert(char(10),@n_qty) 'Qty'
   IF NOT EXISTS( SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOT = @c_Lot AND LOC = @c_FromLoc AND ID = @c_fromid
                  AND Qty >= @n_qty)
   BEGIN
      SELECT @n_continue = 3     
      SELECT @n_err = 60957 --66201    
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Quantity Not Available. (nspRFPA02)"    
   END
   /* Execute nspAddItrnMove */    
   IF @n_continue=1 or @n_continue=2    
   BEGIN    
      IF @b_debug = 1    
      BEGIN     
         SELECT @n_qty "@n_qty"    
      END         
      BEGIN TRAN    
      SELECT @b_success = 1    
      EXECUTE nspItrnAddMove    
            @n_ItrnSysId    = NULL,      
            @c_itrnkey      = NULL,    
            @c_StorerKey    = @c_storerkey,    
            @c_Sku          = @c_sku,    
            @c_Lot          = @c_lot,    
            @c_FromLoc      = @c_fromloc,    
            @c_FromID       = @c_fromid,     
            @c_ToLoc        = @c_toloc,     
            @c_ToID         = @c_toid,      
            @c_Status       = "",    
            @c_lottable01   = "",    
            @c_lottable02   = "",    
            @c_lottable03   = "",    
            @d_lottable04   = NULL,    
            @d_lottable05   = NULL,    
            @n_casecnt      = 0,    
            @n_innerpack    = 0,          
            @n_qty          = @n_qty,    
            @n_pallet       = 0,    
            @f_cube         = 0,    
            @f_grosswgt     = 0,    
            @f_netwgt       = 0,    
            @f_otherunit1   = 0,    
            @f_otherunit2   = 0,    
            @c_SourceKey    = @c_reference,    
            @c_SourceType   = "nspRFPA02",    
            @c_PackKey      = @c_packkey,    
            @c_UOM          = @c_uom,    
            @b_UOMCalc      = 1,    
            @d_EffectiveDate = NULL,    
            @b_Success      = @b_Success  OUTPUT,    
            @n_err          = @n_err      OUTPUT,    
            @c_errmsg       = @c_errmsg   OUTPUT    
      IF NOT @b_success=1    
      BEGIN    
         SELECT @n_continue = 3             
      END    
   END -- IF @n_continue=1 or @n_continue=2    
   /* End Execute nspAddItrnMove */
   
   /* Start of RFPUTAWAY Delete */       
   IF @n_continue=1 OR @n_continue=2  
   BEGIN  
      SET ROWCOUNT 1  
      SELECT @c_SuggestedLoc = SuggestedLoc,  
            @n_checkqty      = qty  
      FROM RFPUTAWAY WITH  (NOLOCK) 
      WHERE LOT     = @c_lot  
      AND FromLoc = @c_fromloc  
      AND ID      = @c_fromid  
      AND PTCID   = @c_ptcid  
      AND ADDWHO  = @c_userid  
      IF @@ROWCOUNT = 1  
      BEGIN  
         DELETE FROM RFPUTAWAY  
         WHERE LOT   = @c_lot  
         AND FromLoc = @c_fromloc  
         AND ID      = @c_fromid  
         AND PTCID   = @c_ptcid  
         AND ADDWHO  = @c_userid  
         IF NOT @@ROWCOUNT = 1  
         BEGIN  
            SELECT @n_continue = 3   
            SELECT @n_err = 60958 --66301  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed To Delete RFPutaway. (nspRFPA02)"  
            --SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete RFPutaway Task FROM - TOID:"+@c_fromid+" - "+@c_toid+". (nspRFPA01)"  
         END  
         SET ROWCOUNT 0   
      END  
      /* If the Loc suggested by the PA process (c_SuggestedLoc) Does Not match the  
      current toloc, it means the user entered a new location to putaway. */  
      IF @c_SuggestedLoc <> @c_toloc  
      BEGIN  
         UPDATE LotxLocxId  WITH (ROWLOCK)
         SET PendingMoveIn = PendingMoveIn - @n_checkqty  
         WHERE LOT         = @c_lot  
         AND LOC           = @c_SuggestedLoc  
         AND ID            = @c_fromid 
         AND PendingMoveIn > 0
         SELECT @n_err = @@ERROR
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 60959 --66302  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed To Update LOTxLOCxID. (nspRFPA02)"  
         END  
      END                      
   END  
   /* End of RFPUTAWAY Delete*/  
   /* Set RF Return Record */    
   IF @n_continue=3     
   BEGIN    
      IF @c_retrec="01"    
      BEGIN    
         SELECT @c_retrec="09"    
      END     
   END     
   ELSE    
   BEGIN    
      SELECT @c_retrec="01"         
   END    
   /* End Set RF Return Record */    
   IF @n_continue = 5     
   BEGIN  -- Reset to normal status.    
      SELECT @n_continue = 1    
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_tasktype)) <> 'PK'
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err= 81799   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         --SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Should Not be Pick Task. (nspRFPA02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) " 
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Should be Pick Task but it is not. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
      END        
   END --IF @n_continue=5     
   IF @n_continue=1 OR @n_continue=2    
   BEGIN    
      -- The move is successful, check to see if it exists in PutawayTask table. If yes, update the status = '9'    
      IF EXISTS (SELECT 1 FROM PUTAWAYTASK (NOLOCK)     
                  WHERE ID = @c_fromid AND FromLoc = @c_fromloc AND Status = '0') AND @c_putawayflag = '0'    
      BEGIN    
         IF @n_continue=1 OR @n_continue=2    
         BEGIN
            UPDATE PutawayTask WITH (ROWLOCK)   
            SET Status = '9',    
               Editdate = getdate(),    
               EditWho = Suser_Sname()    
            WHERE ID = @c_fromid     
            AND   FromLoc = @c_fromloc     
            AND   Toloc = @c_toloc    
            AND   Status = '0'    
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
            IF @n_err <> 0    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err= 60711 --81708   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Failed To Update PutawayTask. (nspRFPA02)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
               --SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table TaskDetail. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
            END
         END    
         IF @n_continue=1 OR @n_continue=2    
         BEGIN    
            IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_tasktype)) = 'PK'    
            BEGIN    
               DECLARE @c_pickdetailkey NVARCHAR(10), @c_taskdetailkey NVARCHAR(10)    
               SELECT @c_pickdetailkey = ''  
               SELECT @c_pickdetailkey = TASKDETAIL.PickdetailKey, @c_taskdetailkey = TASKDETAIL.Taskdetailkey    
               FROM TASKDETAIL(NOLOCK), PUTAWAYTASK(NOLOCK)    
               WHERE PUTAWAYTASK.TaskDetailKey = TASKDETAIL.TaskDetailKey    
               AND   TASKDETAIL.TaskType = 'PK'    
               AND   PUTAWAYTASK.Status = '0'    
               AND   PUTAWAYTASK.FromLoc = @c_fromloc    
               AND   PUTAWAYTASK.Id = @c_fromid    
               IF @c_pickdetailkey = ''
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=81709   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to obtain pickdetailkey. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
               END    
               IF @n_continue = 1 OR @n_continue = 2  
               BEGIN  
                  IF EXISTS ( SELECT 1 FROM PUTAWAYTASK(NOLOCK)     
                              WHERE taskdetailkey = @c_taskdetailkey   
                              AND   status = '0' )       -- TLTING SQL2005 put ' in status check
                  BEGIN    
                     --Still got outstanding task in putawaytask.    
                     UPDATE PICKDETAIL WITH (ROWLOCK)   
                     SET TOLOC  = @c_toloc,    
                        DROPID = @c_fromid,    
                        Editdate = getdate(),    
                        EditWho = Suser_Sname(),    
                        TrafficCop = Null    
                     WHERE pickdetailkey = @c_pickdetailkey    
                  END    
                  ELSE    
                  BEGIN    
                     --Picktask is completed.    
                     UPDATE  PICKDETAIL WITH (ROWLOCK)    
                     SET Status = '5',    
                        TOLOC  = @c_toloc,    
                        DROPID = @c_fromid,    
                        Editdate = getdate(),    
                        EditWho = Suser_Sname()    
                     WHERE pickdetailkey = @c_pickdetailkey    
                  END    
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT    
                  IF @n_err <> 0
                  BEGIN    
                     SELECT @n_continue = 3    
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=81709   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table PickDetail. (nspRFTRP01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "    
                  END    
               END  
            END -- IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_tasktype)) = 'PK'    
         END    
      END--IF EXISTS (SELECT 1 FROM PUTAWAYTASK (NOLOCK)     
   END -- IF @n_continue=1 OR @n_continue=2    
   /* End Main Processing */   
   -- Added By SHONG
   -- To Update the ReceiptDetail if unique row was found 
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      DECLARE @c_ReceiptKey NVARCHAR(10),
            @c_ReeiptLineNo NVARCHAR(5), 
            @n_ReceiptLinecnt int  

      SELECT @n_ReceiptLinecnt = COUNT(*) FROM RECEIPTDETAIL (NOLOCK) 
      WHERE ToID = @c_fromid 
      AND   ToLoc = @c_fromloc
      AND   (PutawayLoc = '' OR PutawayLoc IS NULL)
      AND   STORERKEY = @c_storerkey   --(ung01)
      AND   SKU = @c_sku               --(ung01)

      IF @n_ReceiptLinecnt = 1
      BEGIN
         SELECT @c_ReceiptKey = ReceiptKey,
               @c_ReeiptLineNo = ReceiptLineNumber
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE ToID = @c_fromid 
         AND   ToLoc = @c_fromloc
         AND   (PutawayLoc = '' OR PutawayLoc IS NULL)
         AND   STORERKEY = @c_storerkey   --(ung01)
         AND   SKU = @c_sku               --(ung01)

         -- Modify by SHONG, to include trafficcop when updating
         UPDATE RECEIPTDETAIL
         SET PutawayLoc = @c_toloc, trafficcop = null
         WHERE RECEIPTKEY = @c_ReceiptKey
         AND   ReceiptLineNumber = @c_ReeiptLineNo
      END
      ELSE
      BEGIN  
         IF @n_ReceiptLinecnt > 1 
         BEGIN
            SELECT @c_ReceiptKey = ReceiptKey 
            FROM RECEIPTDETAIL (NOLOCK)
            WHERE ToID = @c_fromid 
            AND   ToLoc = @c_fromloc
            AND   (PutawayLoc = '' OR PutawayLoc IS NULL)
            AND   STORERKEY = @c_storerkey   --(ung01)
            AND   SKU = @c_sku               --(ung01)

            -- Modify by SHONG, to include trafficcop when updating
            UPDATE RECEIPTDETAIL
            SET PutawayLoc = @c_toloc, trafficcop = null
            WHERE RECEIPTKEY = @c_ReceiptKey
            AND   ToID = @c_fromid 
            AND   ToLoc = @c_fromloc 
            AND   QtyReceived > 0 
         END
      END
   END -- @n_continue=1 OR @n_continue=2
   /* Post Process Starts */    
   /* #INCLUDE <SPRFPA02_2.SQL> */    
   /* Post Process Ends */    
   /* Construct Return Message */    
   SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter    
         + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter     
         + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter    
         + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter    
         + dbo.fnc_RTrim(@c_appflag)  + @c_senddelimiter    
         + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter    
         + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter    
         + dbo.fnc_RTrim(@c_errmsg)      

   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
   IF @n_IsRDT <> 1
   SELECT dbo.fnc_RTrim(@c_outstring)

   /* Return Statement */    
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0       
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide
   
         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN
   
         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this stor proc

         -- Trigger need to RAISERROR, as a way to pass error back to caller. 
         -- Stor proc pass error back directly so RAISERROR is not required
         RAISERROR (@n_err, 10, 1) WITH SETERROR
   
         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN 
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
         EXECUTE nsp_logerror @n_err, @c_errmsg, "nspRFPA02"    
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
         RETURN    
      END
   END    
   ELSE    
   BEGIN    
      /* Error Did Not Occur , Return Normally */    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt     
      BEGIN    
         COMMIT TRAN    
      END              
      RETURN    
   END    
   /* End Return Statement */         
END -- MAIN

GO