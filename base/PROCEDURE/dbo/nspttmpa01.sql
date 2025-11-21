SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMPA01                                         */
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
/*                               Must only get Task within the RDT User */
/*                               Area Setup  (Vicky01)                  */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMPA01]
               @c_userid           NVARCHAR(18)
,              @c_areakey01        NVARCHAR(10)
,              @c_areakey02        NVARCHAR(10)
,              @c_areakey03        NVARCHAR(10)
,              @c_areakey04        NVARCHAR(10)
,              @c_areakey05        NVARCHAR(10)
,              @c_lastloc          NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0
   
   DECLARE @n_continue  int,
           @n_starttcnt int, -- Holds the current transaction count
           @n_cnt       int, -- Holds @@ROWCOUNT after certain operations
           @n_err2      int, -- For Additional Error Detection
           @b_Success   int,
           @n_err       int,
           @c_errmsg    NVARCHAR(250)

   SELECT @n_starttcnt = @@TRANCOUNT, 
          @n_continue = 1, 
          @b_success = 0,
          @n_err = 0, 
          @c_errmsg = '',
          @n_err2 = 0

   DECLARE @c_executestmt NVARCHAR(255)

   /* #INCLUDE <SPTMMV01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_areakey01), '') = ''
      BEGIN
         DECLARE cursor_PATASKCANDIDATES
         CURSOR FOR
         SELECT TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'PA'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'PA'
         AND TaskManagerUserDetail.Permission = '1'
         ORDER BY Priority, SourcePriority,TaskDetailKey
      END
      ELSE
      BEGIN
         DECLARE cursor_PATASKCANDIDATES
         CURSOR FOR
--         SELECT TaskDetailKey
--         FROM TaskDetail TaskDetail WITH (NOLOCK)
--         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc)
--         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.Putawayzone = Loc.PutAwayZone)
--         WHERE TaskDetail.Status = '0'
--         AND TaskDetail.TaskType = 'PA'
--         AND TaskDetail.UserKey = ''
--         AND AreaDetail.AreaKey = @c_areakey01
--         ORDER BY Priority, SourcePriority,TaskDetailKey
         SELECT TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'PA'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'PA'
         AND TaskManagerUserDetail.Permission = '1'
         AND AreaDetail.AreaKey = @c_areakey01 -- (Vicky01)
         ORDER BY Priority, SourcePriority,TaskDetailKey
      END

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67808--79201   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Execute Of Putaway Tasks Pick Code Failed. (nspTTMPA01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
      END
   END

   /* #INCLUDE <SPTMMV01_2.SQL> */
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMPA01'
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