SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspCheckEquipmentProfile                           */
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
/* 28-09-2009   1.1   Vicky      RDT Compatible Error Message (Vicky01) */
/* 27-01-2010   1.2   Vicky      SOS#158756 - Add in MaxLevel &         */
/*                               MaxHeight Checking (Vicky02)           */
/* 17-07-2020   1.3   James      WMS14152 - Check MaxPallet (james01)   */
/************************************************************************/

CREATE PROC    [dbo].[nspCheckEquipmentProfile]
                @c_userid       NVARCHAR(18)
 ,              @c_taskdetailkey NVARCHAR(10)
 ,              @c_storerkey    NVARCHAR(15)
 ,              @c_sku          NVARCHAR(20)
 ,              @c_lot          NVARCHAR(10)
 ,              @c_FromLoc      NVARCHAR(10)
 ,              @c_FromID       NVARCHAR(18)
 ,              @c_ToLoc        NVARCHAR(10)
 ,              @c_ToId         NVARCHAR(18)
 ,              @n_qty          int
 ,              @b_Success      int        OUTPUT
 ,              @n_err          int        OUTPUT
 ,              @c_errmsg       NVARCHAR(250)  OUTPUT
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
 DECLARE  @n_continue    int,  
          @n_starttcnt   int, -- Holds the current transaction count
          @c_preprocess NVARCHAR(250), -- preprocess
          @c_pstprocess NVARCHAR(250), -- post process
          @n_cnt        int,    
          @n_err2       int        -- For Additional Error Detection

 SELECT @n_starttcnt = @@TRANCOUNT, 
        @n_continue = 1, 
        @b_success = 0,
        @n_err = 0,
        @c_errmsg = '',
        @n_err2 = 0

 DECLARE @c_userequipmentprofilekey NVARCHAR(10), 
         @c_loc_zone   NVARCHAR(10),
         @c_loc_level  int,  -- (Vicky02)
         @c_loc_height float -- (Vicky02)

DECLARE @c_MaximumPallet      INT
DECLARE @c_FromAisle          NVARCHAR( 10)

      /* #INCLUDE <SPCEQ1.SQL> */     
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
   IF ISNULL(RTRIM(@c_toloc), '') <> ''
   BEGIN
      SELECT @c_userequipmentprofilekey = TASKMANAGERUSER.Equipmentprofilekey
      FROM TASKMANAGERUSER WITH (NOLOCK)
      WHERE USERKEY = @c_userid

      SELECT @c_loc_zone = PUTAWAYZONE,
             @c_loc_level = LocLevel, -- (Vicky02)
             @c_loc_height = Height   -- (Vicky02)
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @c_toloc

      SELECT @c_FromAisle = LOC.LocAisle
      FROM dbo.TaskDetail TD WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON td.FromLoc = loc.Loc
      WHERE TD.TaskDetailKey = @c_taskdetailkey
      
      SELECT @c_MaximumPallet = MaximumPallet
      FROM dbo.EquipmentProfile WITH (NOLOCK)
      WHERE EquipmentProfileKey = @c_userequipmentprofilekey

      IF EXISTS(SELECT 1 FROM PAZoneEquipmentExcludeDetail WITH (NOLOCK)
                WHERE EQUIPMENTPROFILEKEY = @c_userequipmentprofilekey
                AND PUTAWAYZONE = @c_loc_zone)
      BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 67776--84401
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': User Equipment Profile Does Not Pass Checks . (nspCheckEquipmentProfile)'
      END

      -- (Vicky02) - Start
      IF NOT EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                     WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                     AND   (MaximumLevel = 0 OR MaximumLevel = 9999999))
      BEGIN
        IF EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                   WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                   AND   @c_loc_level > MaximumLevel)
        BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 67776--84401
--         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': User Equipment Profile Does Not Pass Checks . (nspCheckEquipmentProfile)'
        END
      END

      IF NOT EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                     WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                     AND  (MaximumHeight = 0 OR MaximumHeight = 9999999))
      BEGIN
        IF EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                   WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                   AND   @c_loc_height > MaximumHeight)
        BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 67776--84401
--         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': User Equipment Profile Does Not Pass Checks . (nspCheckEquipmentProfile)'
        END
      END
      -- (Vicky02) - End
      
      IF EXISTS ( SELECT 1 
                  FROM dbo.TaskDetail TD WITH (NOLOCK)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON td.FromLoc = loc.Loc
                  WHERE TD.TaskDetailKey = @c_taskdetailkey
                  AND   TD.[Status] = '3'
                  AND   LOC.LocAisle = @c_FromAisle
                  GROUP BY TD.UserKey
                  HAVING COUNT( DISTINCT TD.UserKey) > CAST( @c_MaximumPallet AS INT))
      BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 67765
      END
    END
 END

 IF @n_continue = 1 or @n_continue = 2
 BEGIN
   IF ISNULL(RTRIM(@c_fromloc), '') <> ''
   BEGIN
      SELECT @c_userequipmentprofilekey = TASKMANAGERUSER.Equipmentprofilekey
      FROM TASKMANAGERUSER WITH (NOLOCK)
      WHERE USERKEY = @c_userid

      SELECT @c_loc_zone = PUTAWAYZONE,
             @c_loc_level = LocLevel, -- (Vicky02)
             @c_loc_height = Height   -- (Vicky02)
      FROM LOC WITH (NOLOCK)
      WHERE LOC = @c_fromloc

      IF EXISTS(SELECT 1 FROM PAZoneEquipmentExcludeDetail WITH (NOLOCK)
                WHERE EQUIPMENTPROFILEKEY = @c_userequipmentprofilekey
                AND PUTAWAYZONE = @c_loc_zone)
      BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 67777--84402
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': User Equipment Profile Does Not Pass Checks . (nspCheckEquipmentProfile)'
      END

      -- (Vicky02) - Start
      IF NOT EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                     WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                     AND   (MaximumLevel = 0 OR MaximumLevel = 9999999))
      BEGIN
        IF EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                   WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                   AND   @c_loc_level > MaximumLevel)
        BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 67776--84401
--         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': User Equipment Profile Does Not Pass Checks . (nspCheckEquipmentProfile)'
        END
      END

      IF NOT EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                     WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                     AND  (MaximumHeight = 0 OR MaximumHeight = 9999999))
      BEGIN
        IF EXISTS (SELECT 1 FROM Equipmentprofile WITH (NOLOCK)
                   WHERE EquipmentProfileKey = @c_userequipmentprofilekey
                   AND   @c_loc_height > MaximumHeight)
        BEGIN
         SELECT @n_continue = 3 
         SELECT @n_err = 67776--84401
--         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': User Equipment Profile Does Not Pass Checks . (nspCheckEquipmentProfile)'
        END
      END
      -- (Vicky02) - End
    END
 END
      /* #INCLUDE <SPCEQ2.SQL> */
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
      -- execute nsp_logerror @n_err, @c_errmsg, 'nspCheckEquipmentProfile'
      -- RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END -- End Proc

GO