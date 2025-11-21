SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrIDS_LP_VehicleAdd                                        */
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
/* Date        Author   Ver   Purposes                                  */
/* 21-OCT-2011 YTWan    1.1   SOS#218979- HK DG loadPlan. - Populate    */
/*                            vehicle number & vehicle type to loadplan */
/*                            if configkey 'LPUPDVHCINFO' turn on       */     
/************************************************************************/


CREATE TRIGGER ntrIDS_LP_VehicleAdd
ON  IDS_LP_Vehicle
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
            @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
   ,        @n_err                int       -- Error number returned by stored procedure or this trigger
   ,        @n_err2               int       -- For Additional Error Detection
   ,        @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,        @n_continue           int                 
   ,        @n_starttcnt          int       -- Holds the current transaction count
   ,        @c_preprocess         NVARCHAR(250) -- preprocess
   ,        @c_pstprocess         NVARCHAR(250) -- post process
   ,        @n_cnt int                  
   -- (Wan01) - START
   ,        @c_Facility          NVARCHAR(5)
   ,        @c_Configkey         NVARCHAR(30)
   ,        @c_Authority         NVARCHAR(10)
   ,        @c_VehicleNumber     NVARCHAR(10)
   ,        @c_VehicleType       NVARCHAR(10)
   
   SET @c_Facility = ''
   SET @c_Configkey = 'LPUPDVHCINFO'
   SET @c_Authority = '0'
   SET @c_VehicleNumber = ''
   SET @c_VehicleType = ''
   -- (Wan01) - END   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRMBOA1.SQL> */     
   IF @n_continue=1 or @n_continue=2
   BEGIN
      UPDATE LOADPLAN
       SET WeightLimit = WeightLimit + 
          (SELECT SUM(IDS_VEHICLE.Weight) 
           FROM INSERTED
           JOIN IDS_VEHICLE WITH (NOLOCK) ON (LOADPLAN.Loadkey = INSERTED.LoadKey AND
                                              INSERTED.VehicleNumber = IDS_VEHICLE.VehicleNumber)),
           VolumeLimit = VolumeLimit + 
          (SELECT SUM(IDS_VEHICLE.Volume) 
           FROM INSERTED
           JOIN IDS_VEHICLE WITH (NOLOCK) ON (LOADPLAN.Loadkey = INSERTED.LoadKey AND
                                              INSERTED.VehicleNumber = IDS_VEHICLE.VehicleNumber))
      FROM INSERTED
      WHERE LOADPLAN.LoadKey = INSERTED.LoadKey
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table LOADPLAN. (ntrIDS_LP_VehicleAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END

      --(Wan01) - START
      SELECT @c_Facility = ISNULL(RTRIM(Facility),'')
      FROM INSERTED
      JOIN LoadPlan WITH (NOLOCK) ON (LOADPLAN.LoadKey = INSERTED.LoadKey)

      EXEC nspGetRight @c_Facility
                     , ''
                     , ''
                     , @c_configkey
                     , @b_Success   OUTPUT 
                     , @c_Authority OUTPUT 
                     , @n_Err       OUTPUT 
                     , @c_Errmsg    OUTPUT 

      IF @c_Authority = '1' 
      BEGIN
         SELECT TOP 1 
                @c_VehicleNumber = ISNULL(RTRIM(LPV.VehicleNumber),'')
         FROM INSERTED
         JOIN IDS_LP_Vehicle LPV WITH (NOLOCK) ON (LPV.LoadKey = INSERTED.Loadkey)
         ORDER BY LPV.LineNumber


         SELECT @c_VehicleType = ISNULL(RTRIM(VehicleType),'')
         FROM IDS_Vehicle WITH (NOLOCK)
         WHERE VehicleNumber = @c_VehicleNumber

         UPDATE LoadPlan WITH (ROWLOCK)
         SET Truck_Type = @c_VehicleNumber
            ,Vehicle_Type = @c_VehicleType 
         FROM INSERTED
         WHERE LoadPlan.Loadkey = INSERTED.LoadKey
 
         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err=72602                       -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOADPLAN. (ntrIDS_LP_VehicleAdd)' 
                         +' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END
      END
      --(Wan01) - END
   END
   /* #INCLUDE <TRMBOHA2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, "ntrIDS_LP_VehicleAdd"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END


GO