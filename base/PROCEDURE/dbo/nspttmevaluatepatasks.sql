SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMEvaluatePATasks                              */
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
/* 28-09-2009   1.1   Vicky      Add Parameter                          */
/*                               RDT Compatible Error Message (Vicky01) */
/* 09-03-2010   1.2   Shong      Avoid same user getting same task      */
/*                               (Shong01)                              */
/* 10-03-2010   1.4   Shong      Make sure task records updated status  */
/*                               to 3 (Shong02)                         */
/* 17-04-2024                    UWP-18215 Add TRY CATCH                */
/*                               around OPEN CURSOR                     */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMEvaluatePATasks]
               @c_sendDelimiter    NVARCHAR(1)
,              @c_userid           NVARCHAR(18)
,              @c_strategykey      NVARCHAR(10)
,              @c_ttmstrategykey   NVARCHAR(10)
,              @c_ttmpickcode      NVARCHAR(10)
,              @c_ttmoverride      NVARCHAR(10)
,              @c_areakey01        NVARCHAR(10)
,              @c_areakey02        NVARCHAR(10)
,              @c_areakey03        NVARCHAR(10)
,              @c_areakey04        NVARCHAR(10)
,              @c_areakey05        NVARCHAR(10)
,              @c_lastloc          NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
,              @c_ptcid            NVARCHAR(5) -- (Vicky01)
,              @c_fromloc          NVARCHAR(10)   OUTPUT -- (Vicky01)
,              @c_TaskDetailKey    NVARCHAR(10)   OUTPUT -- (Vicky01)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0
   
   DECLARE  @n_continue  int,
            @n_starttcnt int, -- Holds the current transaction count
            @n_cnt       int, -- Holds @@ROWCOUNT after certain operations
            @n_err2      int  -- For Additional Error Detection

   DECLARE @c_retrec NVARCHAR(2) -- Return Record '01' = Success, '09' = Failure
   DECLARE @n_cqty       int, 
           @n_returnrecs int

   SELECT @n_starttcnt = @@TRANCOUNT, 
          @n_continue = 1, 
          @b_success = 0,
          @n_err = 0,
          @c_errmsg = '',
          @n_err2 = 0

   SELECT @c_retrec = '01'
   SELECT @n_returnrecs=1

   DECLARE @c_executestmt  NVARCHAR(255), 
           @c_AlertMessage NVARCHAR(255), 
           @b_gotarow      int

   DECLARE @b_cursor_open   int--, 
          -- @c_TaskDetailKey NVARCHAR(10)

   DECLARE @c_storerkey NVARCHAR(10), 
           @c_sku       NVARCHAR(20), 
           --@c_fromloc   NVARCHAR(10), 
           @c_fromid    NVARCHAR(18),
           @c_toloc     NVARCHAR(10), 
           @c_toid      NVARCHAR(18), 
           @c_lot       NVARCHAR(10), 
           @n_qty       int, 
           @c_packkey   NVARCHAR(10), 
           @c_uom       NVARCHAR(5),
           @c_message01 NVARCHAR(20), 
           @c_message02 NVARCHAR(20), 
           @c_message03 NVARCHAR(20),
           @c_userkeyoverride NVARCHAR(18),
           @b_skipthetask int

   SELECT @b_gotarow = 0

   /* #INCLUDE <SPEVPA_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARECURSOR_PATASKCANDIDATES: 
      SELECT @b_cursor_open = 0
      SELECT @n_continue = 1 -- Reset just in case the GOTO statements below get executed
      SELECT @c_executestmt = 'Execute ' + ISNULL(RTRIM(@c_ttmpickcode), '') + ' '
      + 'N''' + ISNULL(RTRIM(@c_userid), '') + '''' + ','
      + 'N''' + ISNULL(RTRIM(@c_areakey01), '') + '''' + ','
      + 'N''' + ISNULL(RTRIM(@c_areakey02), '') + '''' + ','
      + 'N''' + ISNULL(RTRIM(@c_areakey03), '') + '''' + ','
      + 'N''' + ISNULL(RTRIM(@c_areakey04), '') + '''' + ','
      + 'N''' + ISNULL(RTRIM(@c_areakey05), '') + ''''+ ','
      + 'N''' + ISNULL(RTRIM(@c_lastloc), '') + ''''
      EXECUTE (@c_executestmt)

      SELECT @n_err = @@ERROR
      IF @n_err <> 0 and @n_err <> 16915 and @n_err <> 16905 -- Error #s 16915 and 16905 handled separately below
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67805--79101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Of Move Tasks Pick Code Failed. (nspTTMEvaluatePATasks)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      END
      IF @n_err = 16915
      BEGIN
         CLOSE CURSOR_PATASKCANDIDATES
         
         DEALLOCATE CURSOR_PATASKCANDIDATES
         GOTO DECLARECURSOR_PATASKCANDIDATES
      END

      BEGIN TRY
         OPEN CURSOR_PATASKCANDIDATES
      END TRY
      BEGIN CATCH
         SELECT @n_err = @@ERROR
         IF @n_err = 16905
         BEGIN
            CLOSE CURSOR_PATASKCANDIDATES
            DEALLOCATE CURSOR_PATASKCANDIDATES
            GOTO DECLARECURSOR_PATASKCANDIDATES
         END
         ELSE
         BEGIN
            IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
            BEGIN
               ROLLBACK TRAN
            END

            SET @b_success = 0
            SELECT @n_err = 63061 --set error number to get message
            RETURN
         END
      END CATCH

      IF @n_err = 0
      BEGIN
         SELECT @b_cursor_open = 1
      END
      
   END

   IF (@n_continue = 1 or @n_continue = 2) and @b_cursor_open = 1
   BEGIN
      WHILE (1=1) and (@n_continue = 1 or @n_continue = 2)
      BEGIN
         SET @c_TaskDetailKey = '' --(Shong02)  

         FETCH NEXT FROM CURSOR_PATASKCANDIDATES INTO @c_TaskDetailKey
         IF @@FETCH_STATUS = -1
         BEGIN
            BREAK
         END
         ELSE 
         IF ISNULL(RTRIM(@c_TaskDetailKey),'') <> '' -- (Shong01)
         BEGIN
            SET @c_userkeyoverride=''
            SELECT @c_storerkey = taskdetail.storerkey,
                   @c_sku = taskdetail.sku,
                   @c_fromloc = taskdetail.fromloc ,
                   @c_fromid = taskdetail.fromid ,
                   @c_toloc = taskdetail.toloc ,
                   @c_toid = taskdetail.toid,
                   @c_lot = taskdetail.lot ,
                   @n_qty = taskdetail.qty,
                   @c_userkeyoverride = userkeyoverride,
                   @c_message01 = message01,
                   @c_message02 = message02,
                   @c_message03 = message03
            FROM TaskDetail WITH (NOLOCK) 
            WHERE TaskDetail.TaskDetailKey = @c_TaskDetailKey

            IF @c_userkeyoverride <> '' and @c_userkeyoverride <> @c_userid
            BEGIN
               CONTINUE
            END

            SELECT @b_success = 0, @b_skipthetask = 0
            EXECUTE nspCheckSkipTasks
              @c_userid
            , @c_TaskDetailKey
            , 'PA'
            , ''
            , ''
            , ''
            , ''
            , ''
            , ''
            , @b_skipthetask OUTPUT
            , @b_Success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue=3
            END

            IF @b_skipthetask = 1
            BEGIN
               CONTINUE
            END

            SELECT @b_success = 0
            EXECUTE    nspCheckEquipmentProfile
                           @c_userid       = @c_userid
            ,              @c_TaskDetailKey= @c_TaskDetailKey
            ,              @c_storerkey    = @c_storerkey
            ,              @c_sku          = @c_sku
            ,              @c_lot          = @c_lot
            ,              @c_fromLoc      = @c_fromloc
            ,              @c_fromID       = @c_fromid
            ,              @c_toLoc        = @c_toloc
            ,              @c_toID         = @c_toid
            ,              @n_qty          = @n_qty
            ,              @b_Success      = @b_success    OUTPUT
            ,              @n_err          = @n_err        OUTPUT
            ,              @c_errmsg       = @c_errmsg     OUTPUT
            
            IF @b_success = 0
            BEGIN
               CONTINUE
            END
                        
            UPDATE TASKDETAIL WITH (ROWLOCK)
               SET Status = '3' ,
                   UserKey = @c_userid ,
                   Reasonkey = '' ,
                   StartTime = CURRENT_TimeStamp
             WHERE TaskDetailKey = @c_TaskDetailKey
             AND STATUS = '0' 
             
             IF @@RowCount = 0  -- (Shong01)
             BEGIN
               CONTINUE
             END

             -- (Shong02) 
             IF NOT EXISTS(SELECT 1 FROM TASKDETAIL WITH (ROWLOCK) 
                           WHERE TaskDetailKey = @c_TaskDetailKey
                           AND STATUS = '3'
                           AND UserKey = @c_userid)
             BEGIN
                CONTINUE
             END                
             ELSE -- Task assiged Sucessfully, Quit Now!!!
               BREAK 
             
--            IF EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) 
--                      WHERE ID  = @c_fromid
--                      AND QTY >= @n_qty)
--            BEGIN
--               IF ISNULL(RTRIM(@c_fromid), '') <> ''
--               BEGIN
--                  SELECT @c_packkey = ID.Packkey,
--                         @c_uom = PACK.Packuom3
--                  FROM PACK PACK WITH (NOLOCK)
--                  JOIN ID ID WITH (NOLOCK) ON (ID.Packkey = PACK.Packkey)
--                  WHERE ID.ID = @c_fromid
--               END
--               ELSE
--               BEGIN
--                  SELECT @c_packkey = '', @c_uom = ''
--               END
--                  BEGIN TRANSACTION
--                  UPDATE TASKDETAIL WITH (ROWLOCK)
--                    SET Status = '0' ,
--                        UserKey = ''
--                  WHERE Status = '3'
--                  AND Userkey = @c_userid
--
--                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--                  IF @n_err <> 0
--                  BEGIN
--                     SELECT @n_continue = 3
--                     SELECT @n_err = 67806--79102   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Occurred While Attempting To Update TaskDetail. (nspTTMEvaluatePATasks)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
--                  END
--                 
--                  IF @n_continue = 1 or @n_continue = 2
--                  BEGIN
--                     UPDATE TASKDETAIL WITH (ROWLOCK)
--                       SET Status = '3' ,
--                           UserKey = @c_userid ,
--                           Reasonkey = '' ,
--                           StartTime = CURRENT_TimeStamp
--                     WHERE TaskDetailKey = @c_TaskDetailKey
--                     AND STATUS = '0'
--
--                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--                     IF @n_err <> 0
--                     BEGIN
--                        SELECT @n_continue = 3
--                        SELECT @n_err = 67807--79103   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--                        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Occurred While Attempting To Update TaskDetail. (nspTTMEvaluatePATasks)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
--                     END
--                     
--                     IF @n_continue = 1 or @n_continue = 2
--                     BEGIN
--                        IF @n_cnt = 1
--                        BEGIN
--                           SELECT @b_gotarow = 1
--                        END
--                     END
--                  END -- @n_continue = 1 or @n_continue = 2
--
--                  IF @n_continue = 3
--                  BEGIN
--                     ROLLBACK TRANSACTION
--                  END
--                  ELSE
--                  BEGIN
--                     COMMIT TRANSACTION
--                     BREAK -- We're done.
--                  END
--            END -- IF Exists
--            ELSE
--            BEGIN
--                  SELECT @c_AlertMessage =
--                  'TASK MANAGER ALERT:' +
--                  '  The Amount Of Inventory That The System Expected Is Not At The Location!' +
--                  ', TaskDetailKey=' + RTRIM(@c_TaskDetailKey) +
--                  ', StorerKey=' + RTRIM(@c_StorerKey) +
--                  ', Sku=' + RTRIM(@c_Sku) +
--                  ', Lot=' + RTRIM(@c_Lot) +
--                  ', FromId=' + RTRIM(@c_FromId) +
--                  ', FromLoc=' + RTRIM(@c_FromLoc) +
--                  ', Qty=' + RTRIM(CONVERT(char(10), @n_Qty))
--                  SELECT @b_success = 1
--                  
--                  EXECUTE nspLogAlert
--                          @c_ModuleName   = 'nspTTMEvaluatePATasks',
--                          @c_AlertMessage = @c_AlertMessage,
--                          @n_Severity     = NULL,
--                          @b_success      = @b_success OUTPUT,
--                          @n_err          = @n_err OUTPUT,
--                          @c_errmsg       = @c_errmsg OUTPUT
--
--                  IF NOT @b_success = 1
--                  BEGIN
--                     SELECT @n_continue = 3
--                  END
--
--                  IF @n_continue = 1 or @n_continue = 2
--                  BEGIN
--                     UPDATE TASKDETAIL WITH (ROWLOCK)
--                       SET Status = 'S',
--                           StatusMsg = 'The Amount Of Inventory That The System Expected Is Not At The Location - Task Not Dispatched!'
--                     WHERE TaskDetailKey = @c_TaskDetailKey
--                  END
--            END -- Alert
         END -- @@FETCH_STATUS = 0
      END -- WHILE (1=1)
   END -- (@n_continue = 1 or @n_continue = 2) and @b_cursor_open = 1

   IF @b_cursor_open = 1
   BEGIN
       CLOSE CURSOR_PATASKCANDIDATES
       DEALLOCATE CURSOR_PATASKCANDIDATES
   END

   IF @n_continue=3
   BEGIN
      IF @c_retrec='01'
      BEGIN
         SELECT @c_retrec='09'
      END
   END
   ELSE
   BEGIN
      SELECT @c_retrec='01'
   END

   IF (@n_continue = 1 or @n_continue = 2) AND @b_gotarow = 1
   BEGIN
         SELECT @c_outstring = 
           @c_TaskDetailKey       + @c_senddelimiter
         + RTRIM(@c_fromloc)      + @c_senddelimiter
         + RTRIM(@c_message01)    + @c_senddelimiter
         + RTRIM(@c_message02)    + @c_senddelimiter
         + RTRIM(@c_message03)
   END
   ELSE
   BEGIN
      SELECT @c_outstring = ''
   END

--   IF @c_ptcid <> 'RDT'
--   BEGIN
--     SELECT RTRIM(@c_outstring)
--   END

   /* #INCLUDE <SPEVPA_2.SQL> */
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
       execute nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluatePATasks'
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