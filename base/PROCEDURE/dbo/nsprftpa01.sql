SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFTPA01                                         */
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
/* Date         Ver   Author     Purposes                               */
/* 24-09-2009   1.1   Vicky      To LOC is to be suggested by calling   */
/*                               nspASNPASTD                            */
/*                               RDT Compatible Error Message           */
/*                               Add Parameter   (Vicky01)              */ 
/************************************************************************/

CREATE PROC    [dbo].[nspRFTPA01]
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
,              @c_reasoncode       NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
,              @c_toloc            NVARCHAR(10)   OUTPUT -- (Vicky01)
AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 1

   DECLARE  @n_continue   int,
            @n_starttcnt  int, -- Holds the current transaction count
            @n_cnt        int, -- Holds @@ROWCOUNT after certain operations
            @n_err2       int  -- For Additional Error Detection

   DECLARE @c_retrec     NVARCHAR(2) -- Return Record '01' = Success, '09' = Failure
   DECLARE @n_cqty       int, 
           @n_returnrecs int

   SELECT @n_starttcnt = @@TRANCOUNT, 
          @n_continue = 1, 
          @b_success = 0,
          @n_err = 0,
          @c_errmsg = '',
          @n_err2 = 0

   SELECT @c_retrec = '01'
   SELECT @n_returnrecs = 1

   DECLARE @c_requestedsku     NVARCHAR(20), 
           @n_requestedqty     int, 
           @c_requestedlot     NVARCHAR(10),
           @c_requestedfromid  NVARCHAR(18), 
           @c_requestedfromloc NVARCHAR(10),
           @c_requestedtoid    NVARCHAR(18), 
           @c_requestedtoloc   NVARCHAR(10),
           @c_requestedwavekey NVARCHAR(10), 
           @c_currentstatus    NVARCHAR(10),
           @c_message01        NVARCHAR(20), 
           @c_message02        NVARCHAR(20), 
           @c_message03        NVARCHAR(20)

   DECLARE @c_toid         NVARCHAR(18), 
           --@c_toloc        NVARCHAR(10), 
           @c_logicaltoloc NVARCHAR(10)

   SELECT @c_toid = '', 
          @c_toloc = ''

   /* #INCLUDE <SPTPA01_1.SQL> */
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
     IF ISNULL(RTRIM(@c_fromid), '') <> ''
     BEGIN
         SELECT @c_taskdetailkey = taskdetailkey,
                @c_requestedtoloc = toloc,
                @c_requestedtoid = toid ,
                @c_message01 = message01,
                @c_message02 = message02,
                @c_message03 = message03
         FROM TASKDETAIL WITH (NOLOCK)
         WHERE FROMID = @c_fromid
         AND   FROMLOC = @c_fromloc
         AND   TaskDetailKey = @c_taskdetailkey -- (Vicky01)
         AND ((STATUS = '0' AND TaskType = 'PA') OR
         (STATUS = '3' AND TaskType = 'PA' and userkey = @c_userid))

         IF @@ROWCOUNT = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 67766 --81701 
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': ID Being Moved Cannot Be Found In Task Table'
         END
     END
     ELSE
     BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67767 --81702 
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Invalid ID - It is Blank!'
     END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      BEGIN TRAN
         UPDATE TASKDETAIL WITH (ROWLOCK)
           SET STATUS = '0' ,
               UserKey = '' ,
               Reasonkey = ''
         WHERE Status = '3'
         AND   Userkey = @c_userid
         AND   TaskDetailKey = @c_taskdetailkey -- (Vicky01)

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err= 67768  --81710   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table TaskDetail. (nspRFTRP01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END

         IF @n_continue = 3
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
   END -- @n_continue = 1 or @n_continue = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
       BEGIN TRAN
          UPDATE TASKDETAIL WITH (ROWLOCK)
            SET STATUS = '3' ,
                userKey = @c_userid ,
                reasonkey = '' ,
                StartTime = CURRENT_TimeStamp
          WHERE taskdetailkey = @c_taskdetailkey

          SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
          IF @n_err <> 0
          BEGIN
              SELECT @n_continue = 3
              SELECT @n_err= 67769 --81704   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table TaskDetail. (nspRFTRP01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
          END

          IF @n_continue = 3
          BEGIN
              ROLLBACK TRAN
          END
          ELSE
          BEGIN
             COMMIT TRAN
          END
   END -- @n_continue = 1 or @n_continue = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_requestedtoloc), '') <> ''
      BEGIN
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
              SELECT @b_success = 0
              EXECUTE    nspCheckEquipmentProfile
                             @c_userid        = @c_userid
              ,              @c_taskdetailkey = @c_taskdetailkey
              ,              @c_storerkey     = ''
              ,              @c_sku           = ''
              ,              @c_lot           = ''
              ,              @c_fromLoc       = @c_fromloc
              ,              @c_fromID        = @c_fromid
              ,              @c_toLoc         = @c_requestedtoloc
              ,              @c_toID          = @c_requestedtoid
              ,              @n_qty           = 0
              ,              @b_Success       = @b_success    OUTPUT
              ,              @n_err           = @n_err        OUTPUT
              ,              @c_errmsg        = @c_errmsg     OUTPUT

              IF @b_success = 0
              BEGIN
                 SELECT @n_continue = 3
              END
         END

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
              IF NOT EXISTS (SELECT 1
                             FROM AreaDetail AreaDetail WITH (NOLOCK)
                             JOIN Loc Loc WITH (NOLOCK) ON (AreaDetail.Putawayzone = Loc.PutAwayZone)
                             JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
                             WHERE Loc.Loc = @c_requestedtoloc
                             AND TaskManagerUserDetail.UserKey = @c_userid
                             AND TaskManagerUserDetail.Permissiontype = 'PA'
                             AND TaskManagerUserDetail.Permission = '1')
              BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 67770 --81709
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': User Not Allowed In Destination Location For This ID!. (nspRFTPA01)'
              END
         END
 
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
                SELECT @n_continue = 4
                SELECT @c_toloc = @c_requestedtoloc, @c_toid = @c_requestedtoid
         END
      END -- dbo.fnc_LTrim(RTRIM(@c_requestedtoloc)
   END -- @n_continue = 1 or @n_continue = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
--            EXECUTE NSPPASTD @c_userid = @c_userid,@c_storerkey = '', @c_lot ='', @c_sku = '' , @c_id = @c_fromid, @c_fromloc =@c_fromloc, @n_qty = 0, @c_uom='', @c_packkey = '', @n_putawaycapacity = 0
        EXECUTE NSPASNPASTD 
                @c_userid = @c_userid, 
                @c_storerkey = '', 
                @c_lot = '', 
                @c_sku = '', 
                @c_id = @c_fromid, 
                @c_fromloc = @c_fromloc, 
                @n_qty = 0, 
                @c_uom = '', 
                @c_packkey = '', 
                @n_putawaycapacity = 0, -- (Vicky01)
                @c_final_toloc = @c_toloc OUTPUT -- (Vicky01)
        
        IF NOT @@ERROR = 0
        BEGIN
           SELECT @n_continue = 3
           SELECT @n_err = 67771 --81705
           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Bad PutCode. (nspRFTPA01)'
        END

        -- (Vicky01) - Start
        IF @n_continue=1 OR @n_continue=2
        BEGIN
          IF ISNULL(RTRIM(@c_toloc), '') = ''
          BEGIN
             SELECT @n_continue = 3
             SELECT @n_err = 67772 --81706
             SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+' Bad Location. (nspRFTPA01)'
          END
        END
        -- (Vicky01) - End

--        IF @n_continue=1 OR @n_continue=2
--        BEGIN
--            OPEN CURSOR_TOLOC
--            IF NOT @@FETCH_STATUS = 0
--            BEGIN
--               SELECT @n_continue = 3
--               SELECT @n_err = 67772 --81706
--               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Bad Cursor. (nspRFTPA01)'
--            END
--            ELSE
--            BEGIN
--               FETCH NEXT
--               FROM CURSOR_TOLOC
--               INTO @c_toloc
--               IF NOT @@FETCH_STATUS = 0
--               BEGIN
--                  SELECT @n_continue = 3
--                  SELECT @n_err = 67773 --81707
--                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Bad Location. (nspRFTPA01)'
--               END
--               CLOSE CURSOR_TOLOC
--               DEALLOCATE CURSOR_TOLOC
--            END
--        END

        IF @n_continue = 1 or @n_continue = 2
        BEGIN
            IF ISNULL(RTRIM(@c_toloc), '') <> ''
            BEGIN
               SELECT @c_logicaltoloc = LOGICALLOCATION
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @c_toloc

               IF ISNULL(RTRIM(@c_logicaltoloc), '') = ''
               BEGIN
                  SELECT @c_logicaltoloc = @c_toloc
               END

               DECLARE @c_taskdetailsku NVARCHAR(20)
               DECLARE @b_isDiffFloor int, @c_fromoutloc NVARCHAR(10)

               SELECT  @c_taskdetailsku = sku
               FROM    Taskdetail WITH (NOLOCK)
               WHERE   Taskdetailkey = @c_taskdetailkey

               EXEC nspInsertIntoPutawayTask @c_taskdetailkey, @c_fromloc, @c_toloc, @c_fromid, @c_taskdetailsku, @c_fromoutloc output, @b_isDiffFloor output
                  /* original script
                  BEGIN TRAN
                  UPDATE TASKDETAIL
                  SET TOLOC=@c_toloc ,
                  logicaltoloc = @c_logicaltoloc,
                  userKey = @c_userid ,
                  reasonkey = '' ,
                  StartTime = CURRENT_TimeStamp
                  WHERE taskdetailkey = @c_taskdetailkey
                  */
                -- we want to change the toloc to be the drop zone (outloc) on the source destination if the putaway is on different floors
                IF @n_continue = 1 OR @n_continue = 2
                BEGIN
                   BEGIN TRAN
                      UPDATE TASKDETAIL WITH (ROWLOCK)
                        SET Toloc = @c_toloc,
                            Logicaltoloc = (CASE WHEN @b_isDiffFloor = 1 THEN @c_fromoutloc
                                                 ELSE @c_logicaltoloc
                                            END ),
                            UserKey = @c_userid ,
                            Reasonkey = '' ,
                            StartTime = CURRENT_TimeStamp
                       WHERE Taskdetailkey = @c_taskdetailkey

                       SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                       IF @n_err <> 0
                       BEGIN
                          SELECT @n_continue = 3
                          SELECT @n_err= 67774 --81708   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table TaskDetail. (nspRFTPA01)' + ' ( ' + ' SQLSvr MESSAGE=' +  RTRIM(@c_errmsg) + ' ) '
                       END

                       IF @n_continue = 3
                       BEGIN
                          ROLLBACK TRAN
                       END
                       ELSE
                       BEGIN
                          COMMIT TRAN
                       END

                       SELECT @c_toid = @c_requestedtoid
                END -- @n_continue = 1 OR @n_continue = 2
            END -- toloc <> null
            ELSE
            BEGIN
                 SELECT @n_continue = 3
                 SELECT @n_err = 67775 --81708
                 SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No Location Calculated!. (nspRFTPA01)'
            END -- ltrim (toloc) <> ''
               --   END -- @n_continue = 1 or @n_continue = 2
        END -- @n_continue = 1 or @n_continue = 2
   END -- @n_continue = 1 or @n_continue = 2

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
    
    IF @b_isDiffFloor = 1
    BEGIN
         SELECT @c_toloc = @c_fromoutloc
    END

    SELECT @c_outstring =   @c_ptcid      + @c_senddelimiter
     + RTRIM(@c_userid)           + @c_senddelimiter
     + RTRIM(@c_taskid)           + @c_senddelimiter
     + RTRIM(@c_databasename)     + @c_senddelimiter
     + RTRIM(@c_appflag)          + @c_senddelimiter
     + RTRIM(@c_retrec)           + @c_senddelimiter
     + RTRIM(@c_server)           + @c_senddelimiter
     + RTRIM(@c_errmsg)           + @c_senddelimiter
     + RTRIM(@c_taskdetailkey)    + @c_senddelimiter
     + RTRIM(@c_fromloc)          + @c_senddelimiter
     + RTRIM(@c_fromid)           + @c_senddelimiter
     + RTRIM(@c_toloc)            + @c_senddelimiter
     + RTRIM(@c_toid)             + @c_senddelimiter
     + RTRIM(@c_message01)        + @c_senddelimiter
     + RTRIM(@c_message02)        + @c_senddelimiter
     + RTRIM(@c_message03)

   IF @c_ptcid <> 'RDT'
   BEGIN
      SELECT RTRIM(@c_outstring)
   END

   /* #INCLUDE <SPTPA01_2.SQL> */
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
          execute nsp_logerror @n_err, @c_errmsg, 'nspRFTPA01'
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