SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspTTMNM01                                         */
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
/* 26-02-2010   1.1   Vicky      Fix:Should not look at PAZone (Vicky01)*/
/* 09-03-2010   1.2   ChewKP     Avoid getting same task from the aisle */
/*                               that another user is occupying         */
/*                               (ChewKP01)                             */
/* 16-03-2010  1.3    ChewKP     Remove Ailse Checking. NMV is not in   */
/*                               VNA (ChewKP02)                         */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMNM01]
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

   DECLARE @c_executestmt NVARCHAR(255)
   
   IF @n_continue=1 OR @n_continue=2  
	 BEGIN  
			DECLARE @t_Aisle_InUsed TABLE (LocAIsle NVARCHAR(10), UserKey NVARCHAR(18))
	      
	      IF EXISTS (SELECT 1 FROM TaskManagerUser TMU With (NOLOCK)
	                  INNER JOIN EquipmentProfile EP With (NOLOCK) ON (TMU.EquipmentProfileKey = EP.EquipmentProfileKey) 
	                  WHERE TMU.Userkey = @c_userid 
	                  AND TMU.EquipmentProfileKey = 'VNA' )
	      BEGIN
   			INSERT INTO @t_Aisle_InUsed (LocAisle, UserKey)
   			SELECT L.LocAisle, TD.UserKey
   			FROM TaskDetail TD WITH (NOLOCK) 
   			JOIN LOC L WITH (NOLOCK) ON (TD.FromLOC = L.Loc)
   			JOIN TaskManagerUser TMU WITH (NOLOCK) ON (TD.UserKey = TMU.UserKey)
   			JOIN EquipmentProfile EP WITH (NOLOCK) ON (TMU.EquipmentProfileKey = EP.EquipmentProfileKey)
   			WHERE TMU.EquipmentProfileKey = 'VNA' 
   				AND TD.UserKey <>  @c_userid 
   				AND TD.STatus = '3'
   	   END	
   END    

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_lastloc), '') <> ''
         SELECT @c_aisle = LOCAisle FROM LOC (NOLOCK) WHERE LOC = @c_lastloc
      ELSE
         --SET @c_aisle = 'ALL'
         SET @c_aisle = '' -- (Vicky01)
   END
   /* #INCLUDE <SPTMMV01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_areakey01), '') = ''
      BEGIN
         SET @c_MinPriority = ''
         SET @c_TaskDetailKey = ''
         
         SELECT @c_MinPriority = MIN(Priority)
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         --JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
         --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'NMV'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'NMV'
         AND TaskManagerUserDetail.Permission = '1'

         -- Get the task for Same Aisle
         SELECT TOP 1 
            @c_TaskDetailKey = TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
         --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'NMV'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'NMV'
         AND TaskManagerUserDetail.Permission = '1'
         AND Priority = @c_MinPriority
         AND Loc.LocAisle = @c_Aisle 
         --AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01) -- (ChewKP02)
         --                WHERE AIU.LocAisle = LOC.LocAisle )	

         -- If same aisle got no task then move forward to next aisle         
         IF ISNULL(RTRIM(@c_TaskDetailKey),'') = ''
         BEGIN
            SELECT TOP 1 
               @c_TaskDetailKey = TaskDetailKey
            FROM TaskDetail TaskDetail WITH (NOLOCK) 
            JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
            --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
            JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
            JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
            WHERE TaskDetail.Status = '0'
            AND TaskDetail.TaskType = 'NMV'
            AND TaskDetail.UserKey = ''
            AND TaskManagerUserDetail.UserKey = @c_userid
            AND TaskManagerUserDetail.PermissionType = 'NMV'
            AND TaskManagerUserDetail.Permission = '1'
            AND Priority = @c_MinPriority
            AND Loc.LocAisle > @c_Aisle             
            --AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01) -- (ChewKP02)
            --             WHERE AIU.LocAisle = LOC.LocAisle )	
         END 

         -- If no more task in next available aisle then move backward to get next task
         IF ISNULL(RTRIM(@c_TaskDetailKey),'') = ''
         BEGIN
            SELECT TOP 1 
               @c_TaskDetailKey = TaskDetailKey
            FROM TaskDetail TaskDetail WITH (NOLOCK) 
            JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
            --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
            JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
            JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
            WHERE TaskDetail.Status = '0'
            AND TaskDetail.TaskType = 'NMV'
            AND TaskDetail.UserKey = ''
            AND TaskManagerUserDetail.UserKey = @c_userid
            AND TaskManagerUserDetail.PermissionType = 'NMV'
            AND TaskManagerUserDetail.Permission = '1' 
            AND Priority = @c_MinPriority
            AND Loc.LocAisle < @c_Aisle         
            --AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01) -- (ChewKP02)
            --             WHERE AIU.LocAisle = LOC.LocAisle )	 
            ORDER BY Loc.LocAisle DESC              
         END 
                  
         DECLARE cursor_PATASKCANDIDATES
         CURSOR FOR
         SELECT TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @c_TaskDetailKey 
      END
      ELSE
      BEGIN
         SET @c_MinPriority = ''
         SET @c_TaskDetailKey = ''
         
         SELECT @c_MinPriority = MIN(Priority)
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
         --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'NMV'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'NMV'
         AND TaskManagerUserDetail.Permission = '1'
         AND AreaDetail.AreaKey = @c_areakey01
         --AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01) -- (ChewKP02)
         --                WHERE AIU.LocAisle = LOC.LocAisle )	

         -- Get the task for Same Aisle
         SELECT TOP 1 
            @c_TaskDetailKey = TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
         --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
         JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
         JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
         WHERE TaskDetail.Status = '0'
         AND TaskDetail.TaskType = 'NMV'
         AND TaskDetail.UserKey = ''
         AND TaskManagerUserDetail.UserKey = @c_userid
         AND TaskManagerUserDetail.PermissionType = 'NMV'
         AND TaskManagerUserDetail.Permission = '1'
         AND Priority = @c_MinPriority
         AND Loc.LocAisle = @c_Aisle 
         AND AreaDetail.AreaKey = @c_areakey01
         --AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01) -- (ChewKP02)
         --                WHERE AIU.LocAisle = LOC.LocAisle )	

         -- If same aisle got no task then move forward to next aisle         
         IF ISNULL(RTRIM(@c_TaskDetailKey),'') = ''
         BEGIN
            SELECT TOP 1 
               @c_TaskDetailKey = TaskDetailKey
            FROM TaskDetail TaskDetail WITH (NOLOCK) 
            JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
            --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
            JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
            JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
            WHERE TaskDetail.Status = '0'
            AND TaskDetail.TaskType = 'NMV'
            AND TaskDetail.UserKey = ''
            AND TaskManagerUserDetail.UserKey = @c_userid
            AND TaskManagerUserDetail.PermissionType = 'NMV'
            AND TaskManagerUserDetail.Permission = '1'
            AND Priority = @c_MinPriority
            AND Loc.LocAisle > @c_Aisle            
            AND AreaDetail.AreaKey = @c_areakey01
            --AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01) -- (ChewKP02)
            --             WHERE AIU.LocAisle = LOC.LocAisle )	
         END 

         -- If no more task in next available aisle then move backward to get next task
         IF ISNULL(RTRIM(@c_TaskDetailKey),'') = ''
         BEGIN
            SELECT TOP 1 
               @c_TaskDetailKey = TaskDetailKey
            FROM TaskDetail TaskDetail WITH (NOLOCK) 
            JOIN Loc Loc WITH (NOLOCK) ON (TaskDetail.FromLoc = Loc.Loc) --AND AreaDetail.Putawayzone = Loc.PutAwayZone)
            --JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.PutAwayZone = LOC.PutAwayZone)
            JOIN AreaDetail AreaDetail WITH (NOLOCK) ON (AreaDetail.AreaKey = TaskDetail.AreaKey) -- (Vicky01)
            JOIN TaskManagerUserDetail TaskManagerUserDetail WITH (NOLOCK) ON (TaskManagerUserDetail.AreaKey = AreaDetail.AreaKey)
            WHERE TaskDetail.Status = '0'
            AND TaskDetail.TaskType = 'NMV'
            AND TaskDetail.UserKey = ''
            AND TaskManagerUserDetail.UserKey = @c_userid
            AND TaskManagerUserDetail.PermissionType = 'NMV'
            AND TaskManagerUserDetail.Permission = '1' 
            AND Priority = @c_MinPriority
            AND Loc.LocAisle < @c_Aisle          
            AND AreaDetail.AreaKey = @c_areakey01
            --AND  NOT EXISTS (SELECT 1 FROM @t_Aisle_InUsed AIU       -- (ChewKP01) -- (ChewKP02)
            --             WHERE AIU.LocAisle = LOC.LocAisle )	
            ORDER BY Loc.LocAisle DESC              
         END 
                  
         DECLARE cursor_PATASKCANDIDATES
         CURSOR FAST_FORWARD READ_ONLY FOR -- (ChewKP01)
         SELECT TaskDetailKey
         FROM TaskDetail TaskDetail WITH (NOLOCK) 
         WHERE TaskDetailKey = @c_TaskDetailKey 
      END

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 68669   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute Of Non-Iventory Move Tasks Pick Code Failed. (nspTTMNM01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
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
        execute nsp_logerror @n_err, @c_errmsg, 'nspTTMNM01'
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