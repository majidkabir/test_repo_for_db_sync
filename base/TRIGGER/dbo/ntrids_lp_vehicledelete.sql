SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrIDS_LP_VehicleDelete                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When records removed from IDS_LP_VEHICLE                  */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
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
/*  3-DEC-2015 JayLim   1.2   DELLOG for datamart                       */
/* 2019-09-25  Wan02    1.3   Fixed. MBOLkey Not insert to DELLOG       */
/************************************************************************/

CREATE TRIGGER ntrIDS_LP_VehicleDelete
 ON  IDS_LP_Vehicle
 FOR DELETE
 AS
 BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END 
    SET NOCOUNT ON
   SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF
 SET CONCAT_NULL_YIELDS_NULL OFF 	
 
 DECLARE
           @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err                int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2               int       -- For Additional Error Detection
 ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue           int                 
 ,         @n_starttcnt          int       -- Holds the current transaction count
 ,         @c_preprocess         NVARCHAR(250) -- preprocess
 ,         @c_pstprocess         NVARCHAR(250) -- post process
 ,         @n_cnt int  
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

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrIDS_LP_VEHICLEDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'
      BEGIN
         INSERT INTO dbo.IDS_LP_VEHICLE_DELLOG 
               ( Loadkey,VehicleNumber,MBOLKey )               --Wan02
         SELECT  Loadkey,VehicleNumber,MBOLKey FROM DELETED    --Wan02

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table IDS_LP_VEHICLE Failed. (ntrIDS_LP_VEHICLEDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END

 /* #INCLUDE <TRMBOA1.SQL> */     
 IF @n_continue=1 or @n_continue=2
 BEGIN
    UPDATE LOADPLAN
       SET WeightLimit = 
          CASE WHEN WeightLimit - 
          (SELECT SUM(IDS_VEHICLE.Weight) 
           FROM DELETED
           JOIN IDS_VEHICLE WITH (NOLOCK) ON (LOADPLAN.Loadkey = DELETED.LoadKey AND
                                              DELETED.VehicleNumber = IDS_VEHICLE.VehicleNumber)) < 0
           THEN 0
           ELSE Weightlimit -
           (SELECT SUM(IDS_VEHICLE.Weight) 
           FROM DELETED
           JOIN IDS_VEHICLE WITH (NOLOCK) ON (LOADPLAN.Loadkey = DELETED.LoadKey AND
                                              DELETED.VehicleNumber = IDS_VEHICLE.VehicleNumber)) 
           END,
           VolumeLimit = 
           CASE WHEN VolumeLimit -
          (SELECT SUM(IDS_VEHICLE.Volume) 
           FROM DELETED
           JOIN IDS_VEHICLE WITH (NOLOCK) ON (LOADPLAN.Loadkey = DELETED.LoadKey AND
                                              DELETED.VehicleNumber = IDS_VEHICLE.VehicleNumber)) < 0
           THEN 0
           ELSE  VolumeLIMIT -       
           (SELECT SUM(IDS_VEHICLE.Volume) 
           FROM DELETED
           JOIN IDS_VEHICLE WITH (NOLOCK) ON (LOADPLAN.Loadkey = DELETED.LoadKey AND
                                              DELETED.VehicleNumber = IDS_VEHICLE.VehicleNumber))
           END,
          TrafficCop = NULL
    FROM DELETED
    WHERE LOADPLAN.LoadKey = DELETED.LoadKey
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table LOADPLAN. (ntrIDS_LP_VehicleDelete)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END

      --(Wan01) - START
      SELECT @c_Facility = ISNULL(RTRIM(Facility),'')
      FROM DELETED
      JOIN LoadPlan WITH (NOLOCK) ON (LOADPLAN.LoadKey = DELETED.LoadKey)

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

         SELECT TOP 1 @c_VehicleNumber = ISNULL(RTRIM(LPV.VehicleNumber),'')
         FROM DELETED
         JOIN IDS_LP_Vehicle LPV WITH (NOLOCK) ON (LPV.LoadKey = DELETED.LoadKey)
         WHERE DELETED.LineNumber <> LPV.LineNumber
         ORDER BY LPV.LineNumber

         SELECT @c_VehicleType = ISNULL(RTRIM(VehicleType),'')
         FROM IDS_Vehicle WITH (NOLOCK)
         WHERE VehicleNumber = @c_VehicleNumber

         UPDATE LoadPlan WITH (ROWLOCK)
         SET Truck_Type = @c_VehicleNumber
            ,Vehicle_Type = @c_VehicleType
         FROM DELETED
         WHERE LoadPlan.Loadkey = DELETED.LoadKey

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err=72602                       -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table LOADPLAN. (ntrIDS_LP_VehicleDelete)' 
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
    execute nsp_logerror @n_err, @c_errmsg, "ntrIDS_LP_VehicleDelete"
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