SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMPA03                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Retrieve Task by Searching Matching Tote No / Case ID       */
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
/* 28-06-2010   1.0   ChewKP     Created                                */
/* 17-10-2010   1.1   Shong      Changing Sorting Order                 */
/* 19-05-2015   1.2   ChewKP     Comment V_StationResponse for ANF      */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMPA03]
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
           @c_errmsg    NVARCHAR(250),
           @c_aisle     NVARCHAR(10),
           @c_MinPriority  NVARCHAR(10), 
           @c_TaskDetailKey NVARCHAR(10) 

   SELECT @n_starttcnt = @@TRANCOUNT, 
          @n_continue = 1, 
          @b_success = 0,
          @n_err = 0, 
          @c_errmsg = '',
          @n_err2 = 0 
         

   DECLARE @c_executestmt NVARCHAR(255), 
           @c_CursorSelect NVARCHAR(Max), -- (shong01)
           @c_Storerkey   NVARCHAR(15)
   
   -- Create a table to store all the taskdetailkey (shong01)
   DECLARE @t_TaskDetailKey TABLE (TaskDetailKey NVARCHAR(10)) 
   
   SELECT @c_Storerkey = DefaultStorer FROM RDT.RDTUSER (NOLOCK)
   WHERE Username = @c_userid
   

   /* #INCLUDE <SPTMMV01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_areakey01), '') = ''
      BEGIN
         SET @c_MinPriority = ''
         SET @c_TaskDetailKey = ''

         DECLARE CURSOR_PATASKCANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TaskDetail.TaskDetailKey    
         FROM TaskDetail WITH (NOLOCK) 
         JOIN Loc WITH (NOLOCK) ON (TaskDetail.ToLoc = Loc.Loc) 
         JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN TaskManagerUserDetail WITH (NOLOCK) 
                  ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey) 
--         LEFT OUTER JOIN V_StationResponse VR ON VR.AreaKey = AREADETAIL.AreaKey   
--               AND VR.BoxNumber = CASE WHEN ISNUMERIC(ISNULL(TaskDetail.DropID,'X')) = 1   
--                                       THEN CAST(TaskDetail.DropID AS BIGINT) ELSE '0'   
--                                  END   
--               AND VR.Reading_Time >= TaskDetail.AddDate                                                                                           
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'PA'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'PA'
         AND TaskManagerUserDetail.Permission = '1'
         AND TaskDetail.Storerkey = @c_Storerkey 
         ORDER BY TaskDetail.Priority, 
                  --CASE WHEN VR.BoxNumber IS NULL THEN 1 ELSE 0 END, 
                  LOC.LogicalLocation 
			
      END
      ELSE
      BEGIN
         SET @c_MinPriority = ''
         SET @c_TaskDetailKey = ''
         
         DECLARE CURSOR_PATASKCANDIDATES CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TaskDetail.TaskDetailKey    
         FROM TaskDetail WITH (NOLOCK) 
         JOIN Loc WITH (NOLOCK) ON (TaskDetail.ToLoc = Loc.Loc) 
         JOIN AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN TaskManagerUserDetail WITH (NOLOCK) 
                  ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey) 
--         LEFT OUTER JOIN V_StationResponse VR ON VR.AreaKey = AREADETAIL.AreaKey   
--               AND VR.BoxNumber = CASE WHEN ISNUMERIC(ISNULL(TaskDetail.DropID,'X')) = 1   
--                                       THEN CAST(TaskDetail.DropID AS BIGINT) ELSE '0'   
--                                  END   
--               AND VR.Reading_Time >= TaskDetail.AddDate                                                                                           
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'PA'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'PA'
         AND TaskManagerUserDetail.Permission = '1'
         AND TaskDetail.Storerkey = @c_Storerkey 
         AND AreaDetail.AreaKey = @c_areakey01 -- (Vicky01)
         ORDER BY TaskDetail.Priority, 
                  --CASE WHEN VR.BoxNumber IS NULL THEN 1 ELSE 0 END, 
                  LOC.LogicalLocation 

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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMPA03'
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