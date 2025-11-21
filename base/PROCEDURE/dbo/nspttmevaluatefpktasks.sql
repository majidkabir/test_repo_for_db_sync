SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMEvaluateFPKTasks                             */
/* Purpose:                                                             */
/*                                                                      */
/* Modification log:                                                    */
/* Date        Ver.  Author     Purposes                                */
/* 2014-07-02  1.0   Ung        Created. SOS311415                      */
/* 2014-10-17  1.0   TLTING     SQL2012 Bug fix                         */
/************************************************************************/

CREATE PROC [dbo].[nspTTMEvaluateFPKTasks]
    @c_sendDelimiter    NVARCHAR(1)
   ,@c_UserID           NVARCHAR(18)
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
   ,@b_Success          INT            OUTPUT
   ,@n_err              INT            OUTPUT
   ,@c_errmsg           NVARCHAR(250)  OUTPUT
   ,@c_ptcid            NVARCHAR(5)
   ,@c_FromLOC          NVARCHAR(10)   OUTPUT
   ,@c_TaskDetailKey    NVARCHAR(10)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
       @n_TranCount   INT
      ,@n_Continue    INT
      ,@cSQL          NVARCHAR(1000)
      ,@cSQLParam     NVARCHAR(1000)

   SELECT 
       @n_TranCount = @@TRANCOUNT
      ,@n_Continue = 1
      ,@b_success = 0
      ,@n_err = 0
      ,@c_errmsg = ''


   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @c_TTMPickCode AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC ' + RTRIM( @c_TTMPickCode) +
         ' @c_UserID, @c_AreaKey01, @c_AreaKey02, @c_AreaKey03, @c_AreaKey04, @c_AreaKey05, @c_LastLOC, ' + 
         ' @n_err OUTPUT, @c_errmsg OUTPUT, @c_FromLOC OUTPUT, @c_TaskDetailKey OUTPUT'
      SET @cSQLParam =
         '@c_UserID        NVARCHAR(18), ' + 
         '@c_AreaKey01     NVARCHAR(10), ' + 
         '@c_AreaKey02     NVARCHAR(10), ' + 
         '@c_AreaKey03     NVARCHAR(10), ' + 
         '@c_AreaKey04     NVARCHAR(10), ' + 
         '@c_AreaKey05     NVARCHAR(10), ' + 
         '@c_LastLOC       NVARCHAR(10), ' + 
         '@n_err           INT            OUTPUT, ' + 
         '@c_errmsg        NVARCHAR(250)  OUTPUT, ' + 
         '@c_FromLOC       NVARCHAR(10)   OUTPUT, ' + 
         '@c_TaskDetailKey NVARCHAR(10)   OUTPUT'

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @c_UserID, @c_AreaKey01, @c_AreaKey02, @c_AreaKey03, @c_AreaKey04, @c_AreaKey05, @c_LastLOC, 
         @n_err OUTPUT, @c_errmsg OUTPUT, @c_FromLOC OUTPUT, @c_TaskDetailKey OUTPUT

      IF @n_err <> 0
         SET @n_Continue = 3
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
         WHILE @@TRANCOUNT>@n_TranCount
               COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err ,10 ,1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT=1
            AND @@TRANCOUNT>@n_TranCount
         BEGIN
             ROLLBACK TRAN
         END
         ELSE
         BEGIN
             WHILE @@TRANCOUNT>@n_TranCount
             BEGIN
                 COMMIT TRAN
             END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspTTMEvaluateFPKTasks'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT>@n_TranCount
         COMMIT TRAN
      RETURN
   END
END

GO