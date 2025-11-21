SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrBooking_OutAdd                                           */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 288370-Create booking audit record                          */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records inserted                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author  Ver.  Purposes                                   */
/************************************************************************/

CREATE TRIGGER ntrBooking_OutAdd
ON  Booking_Out
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @b_Success              int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err        int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2       int       -- For Additional Error Detection
   ,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue   int
   ,         @n_starttcnt  int       -- Holds the current transaction count
   ,         @c_preprocess NVARCHAR(250) -- preprocess
   ,         @c_pstprocess NVARCHAR(250) -- post process
   ,         @n_cnt int
   
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
      SET @n_continue = 4

   IF EXISTS( SELECT 1 FROM INSERTED WHERE TrafficCop = '9')
      SET @n_continue = 4

   IF @n_continue=1 OR @n_continue=2
   BEGIN      
      INSERT INTO Booking_Audit (BookingNo, BookingType, RouteAuth, Facility, BookingDate, EndTime, Duration, Loc, Type,
                                SCAC, DriverName, LicenseNo, LoadKey, MbolKey, CBOLKey, Status, ALTReference,
                                VehicleContainer, UserDefine01, UserDefine02, UserDefine03, UserDefine04,
                                UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,
                                UserDefine10, ArrivedTime, SignInTime, UnloadTime, DepartTime)
      SELECT BookingNo, 'OUT', RouteAuth, Facility, BookingDate, EndTime, Duration, Loc, Type,                                
             SCAC, DriverName, LicenseNo, LoadKey, MbolKey, CBOLKey, Status, ALTReference,                      
             VehicleContainer, UserDefine01, UserDefine02, UserDefine03, UserDefine04,       
             UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,           
             UserDefine10, ArrivedTime, SignInTime, UnloadTime, DepartTime
      FROM INSERTED        
   END

   QUIT_TR: 
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
      execute nsp_logerror @n_err, @c_errmsg, "ntrBooking_OutAdd"
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