SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_MB_OutboundBooking                         */
/* Creation Date: 18-May-2016                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-15491 PH Nike create outbound booking from MBOL         */
/*                                                                      */
/* Called By: MBOL Dymaic RCM configure at listname 'RCMConfig'         */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-APR-2022  LZG       1.1   JSM-64372 - Filter by facility (ZG01)   */
/* 29-MAR-2023  NJOW01    1.2   WMS-22023 Update TMS_Shipment and       */
/*                              bookingvehicle when create new booking  */
/************************************************************************/

CREATE  PROCEDURE [dbo].[isp_RCM_MB_OutboundBooking]
   @c_Mbolkey NVARCHAR(10),
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int

   DECLARE @c_Facility  NVARCHAR(5),
           @c_storerkey NVARCHAR(15),
           @n_BookingNo INT,
           @c_OTMShipmentID NVARCHAR(30),
           @c_Loadkey   NVARCHAR(10),
           @dt_LoadingDate DATETIME,
           @c_TruckType  NVARCHAR(10),
           @c_vehicleNo  NVARCHAR(20),
           @c_DriverName NVARCHAR(30),
           @c_ServiceProvider NVARCHAR(18),
           @c_Loc_Bay   NVARCHAR(10),
           @c_BookingNo NVARCHAR(10),
           @dt_EndTime  DATETIME,
           @dt_Duration DATETIME,
           @c_DummyLoc  NVARCHAR(10),
           @c_BookingExist NVARCHAR(10),
           @n_FindBookingNo INT

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0

   IF @@TRANCOUNT = 0
      BEGIN TRAN

   SELECT TOP 1 @c_Storerkey = ORD.Storerkey,
                @c_Facility = ORD.Facility
   FROM MBOLDETAIL MD (NOLOCK)
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey=MD.Orderkey
   WHERE MD.Mbolkey = @c_Mbolkey

   SELECT TOP 1 @c_DummyLoc = Code
   FROM CODELKUP (NOLOCK)
   WHERE Short = @c_Facility
   AND Listname = 'DBDUMLoc'

   IF ISNULL(@c_DummyLoc,'') = ''
      SET @c_DummyLoc = 'DUMMYLOC'

   IF EXISTS(SELECT 1 FROM BOOKING_OUT (NOLOCK) WHERE Mbolkey = @c_Mbolkey)
   BEGIN
      --SELECT @n_continue = 3
      --SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      --SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The MBOL already has booking. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      SET @c_BookingExist = 'Y'
   END

   IF @n_continue IN(1,2)
   BEGIN
   	  UPDATE LOADPLANLANEDETAIL WITH (ROWLOCK)
   	  SET Mbolkey = @c_Mbolkey
   	  FROM MBOLDETAIL MD (NOLOCK)
   	  JOIN LOADPLANLANEDETAIL ON MD.Loadkey = LOADPLANLANEDETAIL.Loadkey
   	  WHERE MD.Mbolkey = @c_Mbolkey
   	  AND ISNULL(MD.Loadkey,'') <> ''
   	  AND LEFT(LOADPLANLANEDETAIL.LocationCategory,3) = 'BAY'

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LoadPlanLaneDetail Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      END
   END

   IF @n_continue IN(1,2)
   BEGIN
   	  DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT CASE WHEN ISNULL(MB.OTMShipmentID,'') <> '' THEN MB.OTMShipmentID ELSE MB.Mbolkey END,
   	            MAX(MD.Loadkey),
   	            MB.LoadingDate,
   	            ISNULL(MD.TruckType,''),
   	            ISNULL(MD.VehicleNo,''),
   	            ISNULL(MD.DriverName,''),
   	            ISNULL(MD.ServiceProvider,''),
   	            CASE WHEN MAX(ISNULL(LPD.Loc,'')) = '' THEN @c_DummyLoc ELSE MAX(LPD.Loc) END
   	     FROM MBOL MB (NOLOCK)
   	     JOIN MBOLDETAIL MD (NOLOCK) ON MB.Mbolkey = MD.Mbolkey
   	     --OUTER APPLY (SELECT TOP 1 Loc FROM LOADPLANLANEDETAIL LPL (NOLOCK) WHERE MB.Mbolkey = LPL.Mbolkey AND LEFT(LPL.LocationCategory,3) = 'BAY' AND MD.Loadkey = LPL.Loadkey) LPD
   	     LEFT JOIN LOADPLANLANEDETAIL LPD (NOLOCK) ON MB.Mbolkey = LPD.Mbolkey AND LEFT(LPD.LocationCategory,3) = 'BAY' AND MD.Loadkey = LPD.Loadkey
   	     WHERE MB.Mbolkey = @c_Mbolkey
   	     GROUP BY CASE WHEN ISNULL(MB.OTMShipmentID,'') <> '' THEN MB.OTMShipmentID ELSE MB.Mbolkey END,
   	              MB.LoadingDate,
   	              ISNULL(MD.TruckType,''),
   	              ISNULL(MD.VehicleNo,''),
   	              ISNULL(MD.DriverName,''),
   	              ISNULL(MD.ServiceProvider,'')

      OPEN CUR_MBOL

      FETCH NEXT FROM CUR_MBOL INTO @c_OTMShipmentID, @c_Loadkey, @dt_LoadingDate, @c_TruckType, @c_vehicleNo, @c_DriverName, @c_ServiceProvider, @c_Loc_Bay

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	 IF NOT EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_Loc_Bay)
      	 BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid location code ' + RTRIM(ISNULL(@c_Loc_Bay,'')) + ' (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            BREAK
      	 END

      	 IF @dt_LoadingDate IS NULL
      	   SET @dt_LoadingDate = GETDATE()

      	 SET @dt_LoadingDate = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_LoadingDate, 112) + ' 00:00:00')
      	 SET @dt_EndTime = CONVERT(DATETIME, CONVERT(NVARCHAR(8), @dt_LoadingDate, 112) + ' 23:59:59')
      	 SET @dt_Duration = CONVERT(DATETIME, '19000101 23:59:59')

    	   IF @c_BookingExist = 'Y'
         BEGIN
         	   IF NOT EXISTS(SELECT 1 FROM BOOKING_OUT BO (NOLOCK)
    	                     WHERE BO.Mbolkey = @c_Mbolkey
    	                     AND BO.VehicleType = @c_TruckType
    	                     AND BO.LicenseNo = @c_VehicleNo
    	                     AND BO.DriverName = @c_DriverName
    	                     AND BO.Carrierkey = @c_ServiceProvider)
    	       BEGIN
         	      --Find booking with outdated info
           	    SET @n_FindBookingNo = 0
         	      SELECT TOP 1 @n_FindBookingNo = BO.BookingNo
         	      FROM BOOKING_OUT BO (NOLOCK)
         	      LEFT JOIN MBOLDETAIL MD (NOLOCK) ON BO.Mbolkey = MD.Mbolkey
                         AND BO.VehicleType = MD.TruckType AND BO.LicenseNo = MD.VehicleNo AND BO.DriverName = MD.DriverName AND BO.Carrierkey = MD.ServiceProvider
         	      WHERE BO.Mbolkey = @c_Mbolkey
         	      AND MD.Mbolkey IS NULL
         	      ORDER BY BO.BookingNo

         	      IF @n_FindBookingNo > 0
         	      BEGIN
         	         UPDATE BOOKING_OUT WITH (ROWLOCK)
         	         SET VehicleType = @c_TruckType,
         	             LicenseNo = @c_VehicleNo,
         	             DriverName = @c_DriverName,
         	             CarrierKey = @c_ServiceProvider,
         	             Userdefine10 = 'UPDATED',
         	             EditWho = SUSER_SNAME(), --NJOW01
         	             EditDate = GETDATE(), --NJOW01         	             
         	             Userdefine01 = @c_MBOLKey  --NJOW01         	                      	             
         	         WHERE BookingNo = @n_FindBookingNo

                   SET @n_err = @@ERROR

                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue = 3
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Booking_Out Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                   END
                   
                   --NJOW01 S
                   UPDATE BOOKINGVEHICLE WITH (ROWLOCK)
                   SET VehicleType = @c_TruckType,
         	             LicenseNo = @c_VehicleNo,
         	             DriverName = @c_DriverName,
         	             CarrierKey = @c_ServiceProvider,
         	             TrafficCop = NULL,
         	             EditWho = SUSER_SNAME(),
         	             EditDate = GETDATE()         	             
         	         WHERE BookingNo = @n_FindBookingNo

                   SET @n_err = @@ERROR

                   IF @n_err <> 0
                   BEGIN
                      SELECT @n_continue = 3
                      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update BOOKINGVEHICLE Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
                   END
                   --NJOW01 E
         	      END
         	      ELSE
         	      BEGIN
         	         GOTO CREATENEWBOOKING
         	      END
         	   END
         END
         ELSE
         BEGIN
         	  CREATENEWBOOKING:

      	    EXEC dbo.nspg_GetKey
                @KeyName = 'BOOKINGNO'
               ,@fieldlength = 10
               ,@keystring = @c_BookingNo OUTPUT
               ,@b_Success = @b_success OUTPUT
               ,@n_err = @n_err OUTPUT
               ,@c_errmsg = @c_errmsg OUTPUT
               ,@b_resultset = 0
               ,@n_batch     = 1

            SET @n_bookingno = CAST(@c_BookingNo AS INT)

            INSERT INTO BOOKING_OUT (BookingNo, MbolKey, LoadKey, BookingDate,
                        VehicleType, LicenseNo, DriverName, Carrierkey, Loc, Facility, Endtime, Duration, ToLoc, ALTReference, Userdefine10, Userdefine01)
                 VALUES (@n_BookingNo, @c_Mbolkey, @c_Loadkey, @dt_LoadingDate,
                         @c_TruckType, @c_vehicleNo, @c_DriverName, @c_ServiceProvider, @c_Loc_Bay, @c_Facility, @dt_Endtime, @dt_Duration, @c_Loc_Bay, @c_OTMShipmentID, @c_BookingExist, @c_Mbolkey) --NJOW01

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38050   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Booking_Out Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END

            UPDATE LOADPLAN WITH (ROWLOCK)
            SET BookingNo = @n_BookingNo,
                Trafficcop = NULL
            WHERE Loadkey = @c_Loadkey

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Loadplan Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END
            
            --NJOW01 S
            INSERT INTO BOOKINGVEHICLE (BookingNo, VehicleType, LicenseNo, DriverName, CarrierKey)
            VALUES(@n_BookingNo, @c_TruckType, @c_VehicleNo, @c_DriverName, @c_ServiceProvider)

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38070   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert BOOKINGVEHICLE Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END            
            
            UPDATE TMS_SHIPMENT WITH(ROWLOCK)
            SET BookingNo = @n_BookingNo
            WHERE ShipmentGID = @c_OTMShipmentID

            SET @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update TMS_SHIPMENT Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            END                        
            --NJOW01 E
         END

         FETCH NEXT FROM CUR_MBOL INTO @c_OTMShipmentID, @c_Loadkey, @dt_LoadingDate, @c_TruckType, @c_vehicleNo, @c_DriverName, @c_ServiceProvider, @c_Loc_Bay
      END
      CLOSE CUR_MBOL
      DEALLOCATE CUR_MBOL

      IF @c_BookingExist = 'Y'
      BEGIN
      	 --Remove invalid booking.
         INSERT INTO Booking_Audit (BookingNo, BookingType, RouteAuth, Facility, BookingDate, EndTime, Duration, Loc, Type,
                                   SCAC, DriverName, LicenseNo, LoadKey, MbolKey, CBOLKey, Status, ALTReference,
                                   VehicleContainer, UserDefine01, UserDefine02, UserDefine03, UserDefine04,
                                   UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,
                                   UserDefine10, ArrivedTime, SignInTime, UnloadTime, DepartTime)
         SELECT BO.BookingNo, 'OUT_DELETE', BO.RouteAuth, BO.Facility, BO.BookingDate, BO.EndTime, BO.Duration, BO.Loc, BO.Type,
                BO.SCAC, BO.DriverName, BO.LicenseNo, BO.LoadKey, BO.MbolKey, BO.CBOLKey, BO.Status, BO.ALTReference,
                BO.VehicleContainer, BO.UserDefine01, BO.UserDefine02, BO.UserDefine03, BO.UserDefine04,
                BO.UserDefine05, BO.UserDefine06, BO.UserDefine07, BO.UserDefine08, BO.UserDefine09,
                BO.UserDefine10, BO.ArrivedTime, BO.SignInTime, BO.UnloadTime, BO.DepartTime
         FROM BOOKING_OUT BO (NOLOCK)
         LEFT JOIN MBOLDETAIL MD (NOLOCK) ON BO.Mbolkey = MD.Mbolkey
              AND BO.VehicleType = MD.TruckType AND BO.LicenseNo = MD.VehicleNo AND BO.DriverName = MD.DriverName AND BO.Carrierkey = MD.ServiceProvider
         WHERE BO.Mbolkey = @c_Mbolkey
         AND MD.Mbolkey IS NULL
         AND BO.Status = '0'
         AND BO.Facility = @c_Facility    -- ZG01

         DELETE BOOKING_OUT
         FROM BOOKING_OUT
         LEFT JOIN MBOLDETAIL MD (NOLOCK) ON BOOKING_OUT.Mbolkey = MD.Mbolkey
              AND BOOKING_OUT.VehicleType = MD.TruckType AND BOOKING_OUT.LicenseNo = MD.VehicleNo AND BOOKING_OUT.DriverName = MD.DriverName AND BOOKING_OUT.Carrierkey = MD.ServiceProvider
         WHERE BOOKING_OUT.Mbolkey = @c_Mbolkey
         AND MD.Mbolkey IS NULL
         AND BOOKING_OUT.Status = '0'

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete Booking_Out Table Failed. (isp_RCM_MB_OutboundBooking)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         END
      END
   END

ENDPROC:

   IF @n_continue=3  -- Error Occured - Process And Return
  BEGIN
     SELECT @b_success = 0
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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_MB_OutboundBooking'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     RETURN
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
END -- End PROC

GO