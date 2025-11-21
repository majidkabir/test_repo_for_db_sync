SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMEvaluateVRPLTasks                            */
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
/* Date         Ver Author     Purposes                                 */
/* 23-Feb-2011  1.0 ChewKP     Created                                  */
/************************************************************************/

CREATE PROC [dbo].[nspTTMEvaluateVRPLTasks]
    @c_sendDelimiter    NVARCHAR(1)
   ,@c_userid           NVARCHAR(18)
   ,@c_StrategyKey      NVARCHAR(10)
   ,@c_TTMStrategyKey   NVARCHAR(10)
   ,@c_TTMPickCode      NVARCHAR(10)
   ,@c_TTMOverride      NVARCHAR(10)
   ,@c_AreaKey01        NVARCHAR(10)
   ,@c_AreaKey02        NVARCHAR(10)
   ,@c_AreaKey03        NVARCHAR(10)
   ,@c_AreaKey04        NVARCHAR(10)
   ,@c_AreaKey05        NVARCHAR(10)
   ,@c_LastLoc          NVARCHAR(10)
   ,@c_OutString        NVARCHAR(255)  OUTPUT
   ,@b_Success          INT        OUTPUT
   ,@n_err              INT        OUTPUT
   ,@c_errmsg           NVARCHAR(250)  OUTPUT
   ,@c_ptcid            NVARCHAR(5)
   ,@c_FromLoc          NVARCHAR(10)   OUTPUT
   ,@c_TaskDetailKey    NVARCHAR(10)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug INT
   SELECT @b_debug = 0
   DECLARE @n_Continue    INT
          ,@n_StartTCnt   INT -- Holds the current transaction count

   SELECT @n_StartTCnt = @@TRANCOUNT
         ,@n_Continue = 1
         ,@b_success = 0
         ,@n_err = 0
         ,@c_errmsg = ''

   DECLARE @c_executestmt      NVARCHAR(255)
          ,@b_gotarow          INT
          ,@b_SkipTheTask      INT -- (Vicky01)

   DECLARE @b_cursor_open      INT
   --           ,@c_TaskDetailKey    NVARCHAR(10)

   DECLARE @c_StorerKey        NVARCHAR(15)
          ,@c_sku              NVARCHAR(20)
           --           ,@c_FromLoc          NVARCHAR(10)
          ,@c_fromid           NVARCHAR(18)
          ,@c_droploc          NVARCHAR(10)
          ,@c_dropid           NVARCHAR(18)
          ,@c_lot              NVARCHAR(10)
          ,@n_qty              INT
          ,@c_PackKey          NVARCHAR(15)
          ,@c_UOM              NVARCHAR(10)
          ,@c_Message01        NVARCHAR(20)
          ,@c_Message02        NVARCHAR(20)
          ,@c_Message03        NVARCHAR(20)
          ,@c_CaseId           NVARCHAR(10)
          ,@c_orderkey         NVARCHAR(10)
          ,@c_OrderLineNumber  NVARCHAR(5)
          ,@c_WaveKey          NVARCHAR(10)

   DECLARE @b_RecordOK         INT -- used when figuring out whether or not enough inventory exists at the source location for a move to occur.
   SELECT @b_gotarow = 0
         ,@b_RecordOK = 0

   IF @n_Continue=1 OR @n_Continue=2
   BEGIN
      DeclareCursor_PKTaskCandidates:
      SELECT @b_cursor_open = 0
      SELECT @n_Continue = 1 -- Reset just in case the GOTO statements below get executed
      SELECT @c_executestmt = "EXECUTE "+RTRIM(@c_TTMPickCode)
            +" "
            +"'"+RTRIM(@c_userid)+"'"+","
            +"'"+RTRIM(@c_AreaKey01)+"'"+","
            +"'"+RTRIM(@c_AreaKey02)+"'"+","
            +"'"+RTRIM(@c_AreaKey03)+"'"+","
            +"'"+RTRIM(@c_AreaKey04)+"'"+","
            +"'"+RTRIM(@c_AreaKey05)+"'"+","
            +"'"+RTRIM(@c_LastLoc)+"'"
      EXECUTE (@c_executestmt)
      SET @n_err = @@ERROR

      -- A cursor with the name '%.*ls' already exists.
      IF @n_err = 16915
      BEGIN
          CLOSE Cursor_PKTaskCandidates
          DEALLOCATE Cursor_PKTaskCandidates
          GOTO DeclareCursor_PKTaskCandidates
      END
      
      IF @n_err<>0
         AND @n_err<>16915
         AND @n_err<>16905 -- Error #s 16915 and 16905 handled separately below
      BEGIN
         SELECT @n_Continue = 3
         --SET @nErrNo = 72285
         --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --
         
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
               ,@n_err = 81101 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                ": Execute Of Move Tasks Pick Code Failed. (nspTTMEvaluateVRPLTasks)"
               +" ( "+" SQLSvr MESSAGE="+RTRIM(@c_errmsg)
               +" ) "
      END
      


      OPEN Cursor_PKTaskCandidates
      SELECT @n_err = @@ERROR

      -- The cursor is already open.
      IF @n_err = 16905
      BEGIN
          CLOSE Cursor_PKTaskCandidates
          DEALLOCATE Cursor_PKTaskCandidates
          GOTO DeclareCursor_PKTaskCandidates
      END

      IF @n_err=0
      BEGIN
          SELECT @b_cursor_open = 1
      END
   END

   IF (@n_Continue=1 OR @n_Continue=2)
      AND @b_cursor_open=1
   BEGIN
       WHILE (1=1)
             AND (@n_Continue=1 OR @n_Continue=2)
       BEGIN
           SELECT @b_RecordOK = 0
           SET @c_TaskDetailKey = ''

           FETCH NEXT FROM Cursor_PKTaskCandidates
           INTO @c_TaskDetailKey,
           @c_CaseId,
           @c_OrderKey,
           @c_OrderLineNumber,
           @c_WaveKey,
           @c_StorerKey,
           @c_sku,
           @c_lot,
           @c_FromLoc,
           @c_FromId,
           @c_PackKey,
           @c_UOM,
           @n_Qty,
           @c_Message01,
           @c_Message02,
           @c_Message03
           IF @@FETCH_STATUS=-1
           BEGIN
               BREAK
           END
           ELSE
           IF ISNULL(RTRIM(@c_TaskDetailKey) ,'')<>'' -- (Shong01)
           BEGIN
               SELECT @b_RecordOK = 1

               SELECT @b_success = 0
                     ,@b_SkipTheTask = 0

               EXECUTE nspCheckSkipTasks
               @c_userid
               , @c_TaskDetailKey
               , 'VRPL'
               , ''
               , ''
               , ''
               , ''
               , ''
               , ''
               , @b_SkipTheTask OUTPUT
               , @b_Success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

               IF @b_success<>1
               BEGIN
                   SELECT @n_Continue = 3
               END

               IF @b_SkipTheTask=1
               BEGIN
                   CONTINUE
               END

               SELECT @b_success = 0
               EXECUTE nspCheckEquipmentProfile
               @c_Userid=@c_Userid
               , @c_TaskDetailKey=@c_TaskDetailKey
               , @c_StorerKey=@c_StorerKey
               , @c_sku=@c_sku
               , @c_lot=@c_lot
               , @c_FromLoc=@c_FromLoc
               , @c_fromID=@c_fromid
               , @c_toLoc=''--@c_toloc
               , @c_toID=''--@c_toid
               , @n_qty=@n_qty
               , @b_Success=@b_success OUTPUT
               , @n_err=@n_err OUTPUT
               , @c_errmsg=@c_errmsg OUTPUT

               IF @b_success=0
               BEGIN
                   CONTINUE
               END
               -- (Vicky01) - End

               IF NOT EXISTS(
                      SELECT 1
                      FROM   TASKDETAIL WITH (ROWLOCK)
                      WHERE  TaskDetailKey = @c_TaskDetailKey
                             AND STATUS = '3'
                             AND UserKey = @c_userid
                  )
               BEGIN
                   UPDATE TASKDETAIL WITH (ROWLOCK)
                   SET    STATUS = '3'
                         ,UserKey = @c_userid
                         ,Reasonkey = ''
                         ,StartTime = CURRENT_TIMESTAMP
                         ,EditDate = CURRENT_TIMESTAMP     --(Kc01)
                         ,EditWho = @c_userid              --(Kc01)
                   WHERE  TaskDetailKey = @c_TaskDetailKey
                          AND STATUS IN ('0') -- (ChewKP01)

                   IF @@RowCount=0 -- (ChewKP01)
                   BEGIN
                       CONTINUE
                   END
               END
               -- (Shong01)
               IF NOT EXISTS(
                      SELECT 1
                      FROM   TASKDETAIL WITH (ROWLOCK)
                      WHERE  TaskDetailKey = @c_TaskDetailKey
                             AND STATUS = '3'
                             AND UserKey = @c_userid
                  )
               BEGIN
                   CONTINUE
               END
               ELSE
                   -- Task assiged Sucessfully, Quit Now!!!
                   BREAK
           END


           IF ISNULL(RTRIM(@c_TaskDetailKey) ,'')='' -- The record in the cursor is blank!
           BEGIN
               SELECT @b_RecordOK = 0
               CONTINUE
           END

           SELECT @b_gotarow = 1
           BREAK
       END -- WHILE (1=1)
   END

   IF @b_cursor_open=1
   BEGIN
      CLOSE Cursor_PKTaskCandidates
      DEALLOCATE Cursor_PKTaskCandidates
   END

   IF @n_Continue=3 -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT=1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT>@n_StartTCnt
               COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err ,10 ,1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT=1
            AND @@TRANCOUNT>@n_StartTCnt
         BEGIN
             ROLLBACK TRAN
         END
         ELSE
         BEGIN
             WHILE @@TRANCOUNT>@n_StartTCnt
             BEGIN
                 COMMIT TRAN
             END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluateVRPLTasks'
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012 
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT>@n_StartTCnt
         COMMIT TRAN
      RETURN
   END
END

GO