SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFTPA03                                         */
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
/* Date         Ver.  Author     Purposes                               */
/* 28-09-2009   1.1   Vicky      RDT Compatible Error Message           */
/*                               Add Parameter (Vicky01)                */
/* 08-01-2010   1.2   James      Remove checking putawaytask table      */
/*                               (james01)                              */
/* 12-01-2010   1.3   James      Cater for PrePack (james02)            */
/* 25-03-2010   1.4   Vicky      Insert to Alert (Vicky02)              */
/************************************************************************/

CREATE PROC    [dbo].[nspRFTPA03]
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
,              @c_fromloc          NVARCHAR(18)
,              @c_fromid           NVARCHAR(18)
,              @c_toloc            NVARCHAR(18)
,              @c_toid             NVARCHAR(18)
,              @n_qty              int
,              @c_packkey          NVARCHAR(10)
,              @c_uom              NVARCHAR(10)
,              @c_reasoncode       NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
,              @c_userposition     NVARCHAR(10) = '' -- (Vicky01)
AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 1
   
   DECLARE @n_continue  int,
           @n_starttcnt int, -- Holds the current transaction count
           @n_cnt       int, -- Holds @@ROWCOUNT after certain operations
           @n_err2      int  -- For Additional Error Detection

   DECLARE @c_retrec NVARCHAR(2) -- Return Record '01' = Success, '09' = Failure

   DECLARE @n_cqty       int, 
           @n_returnrecs int

   -- (Vicky02) - Start
   DECLARE @c_AlertMessage NVARCHAR( 255),
           @c_TaskType     NVARCHAR(10),
           @c_ModuleName   NVARCHAR(30) 
   -- (Vicky02) - End

   SELECT @n_starttcnt = @@TRANCOUNT, 
          @n_continue = 1, 
          @b_success = 0,
          @n_err = 0,
          @c_errmsg = '',
          @n_err2 = 0, 
          @n_cnt=0,
          @c_AlertMessage = '' -- (Vicky02)

   SELECT @c_retrec = '01'
   SELECT @n_returnrecs=1

   DECLARE @c_requestedsku     NVARCHAR(20), 
           @n_requestedqty     int, 
           @c_requestedlot     NVARCHAR(10),
           @c_requestedfromid  NVARCHAR(18), 
           @c_requestedfromloc NVARCHAR(10),
           @c_requestedtoid    NVARCHAR(18), 
           @c_requestedtoloc   NVARCHAR(10),
           @c_requestedwavekey NVARCHAR(10), 
           @c_currentstatus    NVARCHAR(10),
           @c_StorerKey        NVARCHAR(15)

   /* #INCLUDE <SPTPA02_1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF ISNULL(RTRIM(@c_toid), '') = ''
      BEGIN
         SELECT @c_toid = @c_fromid
      END

      IF ISNULL(RTRIM(@c_packkey), '') = ''
      BEGIN
         SELECT @c_packkey = ID.Packkey,
                @c_uom= PACK.Packuom3
         FROM ID ID WITH (NOLOCK)
         JOIN PACK PACK WITH (NOLOCK) ON (ID.PACKKEY = PACK.PACKKEY)
         WHERE ID = @c_fromid
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @c_requestedfromid  = FROMID,
             @c_requestedfromloc = FROMLOC,
             @c_requestedtoid  = TOID,
             @c_requestedtoloc = Logicaltoloc, -- fbr028a - to retrieve from logicaltoloc
             @c_requestedwavekey = WAVEKEY,
             @c_currentstatus = Status,
             @c_StorerKey = StorerKey,
             @c_TaskType = TaskType -- (VIcky02) 
      FROM  TASKDETAIL WITH (NOLOCK)
      WHERE TASKDETAILKEY = @c_taskdetailkey
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67787--84001 
         SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),@n_err)+ ' :Invalid TaskDetail Key'
      END
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
     IF @c_userposition = '2' -- (Vicky01)
     BEGIN
          IF @c_fromid <> @c_requestedfromid
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 67788--84006, 
             SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+ ' :Invalid From ID!'
          END
      END -- (Vicky01)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_userposition = '2' -- (Vicky01)
      BEGIN
           IF @c_fromloc <> @c_requestedfromloc
           BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 67789--84008, 
               SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+ ' :Invalid From Loc!'
           END
       END -- (Vicky01)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
     IF @c_userposition = '2' -- (Vicky01)
      BEGIN
          IF ISNULL(RTRIM(@c_requestedtoid), '') <> ''
          BEGIN
              IF @c_toid <> @c_requestedtoid AND ISNULL(RTRIM(@c_requestedtoid), '') <> ''
              BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 67790 --84009, 
                  SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),@n_err)+ ' :Invalid To ID!'
              END
           END
       END -- (Vicky01)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
     IF @c_userposition = '2' -- (Vicky01)
     BEGIN
          IF @c_toloc <> @c_requestedtoloc
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 67791--84010, 
             SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),@n_err)+ ' :Invalid To Loc!'
          END
     END -- (Vicky01)
   END

   IF @n_continue=1 OR @n_continue=2
   BEGIN
      IF @c_currentstatus = '9'
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67792--84013, 
         SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),@n_err)+ ' :Item Already Processed!'
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 1
      EXECUTE nspUOMConv
      @n_fromqty = @n_qty,
      @c_fromuom = @c_uom,
      @c_touom  = NULL,
      @c_packkey = @c_packkey,
      @n_toqty   = @n_qty OUTPUT,
      @b_success = @b_success OUTPUT,
      @n_err     = @n_err OUTPUT,
      @c_errmsg  = @c_errmsg OUTPUT
      IF NOT @b_success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_fromid), '') <> '' AND @n_qty > 0
      BEGIN
         DECLARE @n_inv_qty  INT
         SELECT @n_inv_qty = SUM(Qty) -- (james02)
         FROM LOTxLOCxID WITH (NOLOCK)
         WHERE ID = @c_fromid 
         AND LOC = @c_fromloc 
         AND QTY > 0

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0      -- Trap database error
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 67793--84000
            SELECT @c_errmsg = 'NSQL' + Convert(CHAR(5),@n_err) + ': Select Error On LOTxLOCxID.' + ' (nspRFTPA03) (SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ')'
         END
         ELSE IF @n_cnt = 0  -- For some reason there's no match (maybe qty = 0)
         BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 67794--84002
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No Match For ID At Loc (nspRFTPA03)'
         END
         ELSE IF @n_cnt > 1  -- ID belongs to a multi-lot pallet
               -- If prepackbom not turned on   (james02)
               AND EXISTS (SELECT 1 FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'PREPACKBYBOM' AND Svalue = '0')
         BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 67795--84004
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': You Cannot Specify A QTY To Move When Moving A Multi-Lot Pallet (nspRFTPA03)'
         END
         ELSE
         BEGIN
            IF @n_qty > @n_inv_qty        -- Qty to putaway is overstated
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 67796--84011
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Qty Specified Exceeds Qty On Pallet (nspRFTPA03)'
            END
            ELSE IF @n_qty < @n_inv_qty   -- Partial pallet
            BEGIN
              -- Allow to process Partial Pallet
                 SELECT @n_qty = @n_qty 

--               SELECT @n_continue = 3 
--               SELECT @n_err = 67797--84012
--               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cannot PutAway Partial Pallet (nspRFTPA03)'
            END
            ELSE                          -- Qty stated equal qty as recorded in inventory
            BEGIN
               SELECT @n_qty = 0
            END
         END  -- @n_cnt = 1
      END  -- FromId specified with qty > 0
   END  -- @n_continue = 1 or @n_continue = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_reasoncode), '') <> ''
      BEGIN
         -- (Vicky01) - Start
         IF @c_userposition <> ''
         BEGIN
           IF @c_userposition = '1'
           BEGIN
             IF NOT EXISTS (SELECT 1 FROM TaskManagerReason WITH (NOLOCK)
                            WHERE TaskManagerReasonKey = @c_reasoncode
                            AND ValidInFromLoc = '1')
             BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 67816--84003, 
               SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),@n_err)+ ':Invalid ReasonCode!'
             END
           END
           ELSE IF @c_userposition = '2'
           BEGIN
             IF NOT EXISTS (SELECT 1 FROM TaskManagerReason WITH (NOLOCK)
                            WHERE TaskManagerReasonKey = @c_reasoncode
                            AND ValidInToLoc = '1')
             BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 67817--84003, 
               SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),@n_err)+ ':Invalid ReasonCode!'
             END
           END
         END
         ELSE  
         -- (Vicky01) - End
         BEGIN
             IF NOT EXISTS (SELECT 1 FROM TaskManagerReason WITH (NOLOCK)
                            WHERE TaskManagerReasonKey = @c_reasoncode
                            AND ValidInToLoc = '1')
             BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 67798--84003, 
               SELECT @c_errmsg = 'NSQL' +CONVERT(char(5),@n_err)+ ':Invalid ReasonCode!'
             END
         END
     END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
--      (james01)
--      Putaway task only generated when tasktype = 'MV' (nspInsertIntoPutawayTask), we will use tasktype = 'PA' instead
--      IF EXISTS (SELECT 1 FROM Putawaytask WITH (NOLOCK) WHERE taskdetailkey = @c_taskdetailkey)
--      BEGIN
--         BEGIN TRAN
--          IF @c_userposition = '2'
--          BEGIN
--             UPDATE TASKDETAIL WITH (ROWLOCK)
--              SET STATUS = '9' ,
--                  Qty = @n_qty ,
--                  FromLoc = @c_fromloc,
--                  FromId = @c_fromid,
--                  logicaltoloc = @c_toloc,
--                  Toid = @c_toid,
--                  Reasonkey = CASE WHEN ISNULL(@c_reasoncode, '') = '' THEN Reasonkey ELSE @c_reasoncode END,
--                  --UserPosition = '2', -- This task is being performed at the TOLOC
--                  UserPosition = CASE WHEN @c_userposition <> '' THEN @c_userposition ELSE '2' END, -- (Vicky01)
--                  EndTime = getdate()
--             WHERE taskdetailkey = @c_taskdetailkey
--           END
--           ELSE
--           BEGIN
--             UPDATE TASKDETAIL WITH (ROWLOCK)
--              SET STATUS = '9' ,
--                  Qty = @n_qty ,
                  --FromLoc = @c_fromloc,
                  --FromId = @c_fromid,
                  --logicaltoloc = @c_toloc,
                  --Toid = @c_toid,
--                  Reasonkey = CASE WHEN ISNULL(@c_reasoncode, '') = '' THEN Reasonkey ELSE @c_reasoncode END,
                  --UserPosition = '2', -- This task is being performed at the TOLOC
--                  UserPosition = CASE WHEN @c_userposition <> '' THEN @c_userposition ELSE '2' END, -- (Vicky01)
--                  EndTime = getdate()
--             WHERE taskdetailkey = @c_taskdetailkey
--           END

--            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--            IF @n_err <> 0
--            BEGIN
--               SELECT @n_continue = 3
--               SELECT @n_err = 67799--84005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table TaskDetail. (nspRFTPA03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
--            END
--            
--            IF @n_continue = 3
--            BEGIN
--               ROLLBACK TRAN
--            END
--            ELSE
--            BEGIN
--               COMMIT TRAN
--            END
--      END -- If Exists
--      ELSE
--      BEGIN
         BEGIN TRAN

--         IF @c_userposition = '2'
--          BEGIN
--            UPDATE TASKDETAIL WITH (ROWLOCK)
--              SET STATUS = '9' ,
--                  Qty = @n_qty ,
--                  FromLoc = @c_fromloc,
--                  FromId = @c_fromid,
--                  ToLoc = @c_toloc,
--                  Toid = @c_toid,
--                  Reasonkey = @c_reasoncode,
--                  --UserPosition = '2', -- This task is being performed at the TOLOC
--                  UserPosition = CASE WHEN @c_userposition <> '' THEN @c_userposition ELSE '2' END, -- (Vicky01)
--                  EndTime = getdate()
--             WHERE taskdetailkey = @c_taskdetailkey
--           END
--           ELSE
--           BEGIN
            UPDATE TASKDETAIL WITH (ROWLOCK)
              SET STATUS = '9' ,
--                  Qty = @n_qty ,
                  --FromLoc = @c_fromloc,
                 -- FromId = @c_fromid,
                 -- ToLoc = @c_toloc,
                --  Toid = @c_toid,
                  Reasonkey = CASE WHEN ISNULL(@c_reasoncode, '') = '' THEN Reasonkey ELSE @c_reasoncode END,
                  --UserPosition = '2', -- This task is being performed at the TOLOC
                  UserPosition = CASE WHEN @c_userposition <> '' THEN @c_userposition ELSE '2' END, -- (Vicky01)
                  EndTime = getdate(),
                  EditDate = getdate(),
                  EditWho = suser_sname()
             WHERE taskdetailkey = @c_taskdetailkey
--            END

             SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
             IF @n_err <> 0
             BEGIN
                 SELECT @n_continue = 3
                 SELECT @n_err = 67800--84005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table TaskDetail. (nspRFTPA03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
             END
             
             IF @n_continue = 3
             BEGIN
                 ROLLBACK TRAN
             END
             ELSE
             BEGIN
                 COMMIT TRAN
             END
--       END
   END -- @n_continue = 1 or @n_continue = 2

   -- (Vicky02) - Start
   IF (@n_continue = 1 or @n_continue = 2) AND ISNULL(RTRIM(@c_reasoncode), '') <> ''
   BEGIN
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' TaskDetailKey: ' + @c_taskdetailkey
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' TaskType: ' + @c_TaskType
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ReasonCode: ' + @c_reasoncode
      --SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' QTY: ' + CAST(@n_qty AS NVARCHAR( 5))
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DateTime: ' + CONVERT(CHAR,GETDATE(), 121)

      SELECT @c_ModuleName = CASE WHEN @c_TaskType = 'PA' THEN 'TMPA' 
                             ELSE 'nspRFRSN01' END

      -- Insert LOG Alert
      SELECT @b_Success = 1
      EXECUTE dbo.nspLogAlert
         @c_ModuleName   = @c_ModuleName,
         @c_AlertMessage = @c_AlertMessage,
         @n_Severity     = 0,
         @b_success      = @b_Success OUTPUT,
         @n_err          = @n_Err OUTPUT,
         @c_errmsg       = @c_Errmsg OUTPUT
      	
      IF NOT @b_Success = 1
      BEGIN
         SELECT @n_continue = 3
      END
   END
   -- (Vicky02) - End

   IF @n_continue=3
   BEGIN
     IF @c_retrec='01'
     BEGIN
        SELECT @c_retrec='09', @c_appflag = 'TPA'
     END
   END
   ELSE
   BEGIN
     SELECT @c_retrec='01'
   END

  SELECT @c_outstring =  @c_ptcid      + @c_senddelimiter
  + RTRIM(@c_userid)           + @c_senddelimiter
  + RTRIM(@c_taskid)           + @c_senddelimiter
  + RTRIM(@c_databasename)     + @c_senddelimiter
  + RTRIM(@c_appflag)          + @c_senddelimiter
  + RTRIM(@c_retrec)           + @c_senddelimiter
  + RTRIM(@c_server)           + @c_senddelimiter
  + RTRIM(@c_errmsg)

  IF @c_ptcid <> 'RDT'
  BEGIN
    SELECT RTRIM(@c_outstring)
  END

  /* #INCLUDE <SPTPA02_2.SQL> */
  IF @n_continue=3  -- Error Occured - Process And Return
  BEGIN
      SELECT @b_success = 0
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspRFTPA03'
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN 
     END
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