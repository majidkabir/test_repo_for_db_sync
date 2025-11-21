SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMEvaluateNMVTasks                             */
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
/* 20-01-2010   1.0   Vicky      Created                                */
/* 09-03-2010   1.1   ChewKP     Avoid same user getting same task      */
/*                               (ChewKP01)                             */
/* 10-03-2010   1.2   ChewKP     Make sure task records updated status  */
/*                               to 3 (ChewKP02)                        */
/* 13-05-2013   1.3   Ung        SOS265332 Fix cursor name              */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMEvaluateNMVTasks]
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
,              @c_ptcid            NVARCHAR(5)
,              @c_fromloc          NVARCHAR(10)   OUTPUT 
,              @c_taskdetailkey    NVARCHAR(10)   OUTPUT 
,              @c_toid             NVARCHAR(18)   OUTPUT

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
          -- @c_taskdetailkey NVARCHAR(10)

   DECLARE @c_storerkey NVARCHAR(10), 
           @c_sku       NVARCHAR(20), 
           --@c_fromloc   NVARCHAR(10), 
           @c_fromid    NVARCHAR(18),
           @c_toloc     NVARCHAR(10), 
           --@c_toid      NVARCHAR(18), 
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
      DECLAREcursor_NMVTaskCandidates:
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
         SELECT @n_err = 68666
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Of Move Tasks Pick Code Failed. (nspTTMEvaluateNMVTasks)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      END
      IF @n_err = 16915
      BEGIN
         CLOSE cursor_NMVTaskCandidates
         DEALLOCATE cursor_NMVTaskCandidates
         GOTO DECLAREcursor_NMVTaskCandidates
      END
      OPEN cursor_NMVTaskCandidates
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err = 16905
      BEGIN
         CLOSE cursor_NMVTaskCandidates
         DEALLOCATE cursor_NMVTaskCandidates
         GOTO DECLAREcursor_NMVTaskCandidates
      END
      IF @n_err = 0
      BEGIN
         SELECT @b_cursor_open = 1
      END
   END

   IF (@n_continue = 1 or @n_continue = 2) and @b_cursor_open = 1
   BEGIN
      WHILE (1=1) and (@n_continue = 1 or @n_continue = 2)
      BEGIN
         SET @c_TaskDetailKey = '' -- (ChewKP02)
         
         FETCH NEXT FROM cursor_NMVTaskCandidates INTO @c_taskdetailkey
         IF @@FETCH_STATUS = -1
         BEGIN
            BREAK
         END
         ELSE
         IF ISNULL(RTRIM(@c_TaskDetailKey),'') <> '' -- (ChewKP02)
         --IF @@FETCH_STATUS = 0 AND ISNULL(RTRIM(@c_taskdetailkey),'') <> '' -- (ChewKP01)
         BEGIN
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
            WHERE TaskDetail.TaskDetailKey = @c_taskdetailkey

            IF @c_userkeyoverride <> '' and @c_userkeyoverride <> @c_userid
            BEGIN
               CONTINUE
            END

            SELECT @b_success = 0, @b_skipthetask = 0
            EXECUTE nspCheckSkipTasks
              @c_userid
            , @c_taskdetailkey
            , 'NMV'
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
            ,              @c_taskdetailkey= @c_taskdetailkey
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
             WHERE TaskDetailKey = @c_taskDetailKey
             AND STATUS = '0'
             
             
             IF @@RowCount = 0 -- (ChewKP01)
             BEGIN
               CONTINUE -- (ChewKP02)
             END
             
             -- (ChewKP02) 
             IF NOT EXISTS(SELECT 1 FROM TASKDETAIL WITH (ROWLOCK) 
                           WHERE TaskDetailKey = @c_TaskDetailKey
                           AND STATUS = '3'
                           AND UserKey = @c_userid)
             BEGIN
                CONTINUE
             END                
             ELSE -- Task assiged Sucessfully, Quit Now!!!
               BREAK 

         END -- @@FETCH_STATUS = 0
      END -- WHILE (1=1)
   END -- (@n_continue = 1 or @n_continue = 2) and @b_cursor_open = 1

   IF @b_cursor_open = 1
   BEGIN
       CLOSE cursor_NMVTaskCandidates
       DEALLOCATE cursor_NMVTaskCandidates
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
           @c_taskdetailkey       + @c_senddelimiter
         + RTRIM(@c_fromloc)      + @c_senddelimiter
         + RTRIM(@c_message01)    + @c_senddelimiter
         + RTRIM(@c_message02)    + @c_senddelimiter
         + RTRIM(@c_message03)
   END
   ELSE
   BEGIN
      SELECT @c_outstring = ''
   END

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
       execute nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluateNMVTasks'
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