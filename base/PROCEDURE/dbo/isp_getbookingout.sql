SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetBookingOut          								*/
/* Creation Date: 20/10/2010                                            */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Booking outboud dashboard                                   */
/*                                                                      */
/* Called By: d_dw_booking_dashboard_out                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 9 May 2013   TLTING01 1.1  Miss datatype Nvarchar                    */
/* 31-OCT-2014  YTWan    1.2  SOS#322304 - PH - CPPI WMS Door Booking   */
/*                            Enhancement (Wan01)                       */
/************************************************************************/

CREATE PROC [dbo].[isp_GetBookingOut] (
        @c_facility nvarchar(5),
        @dt_date datetime
)
 AS
 BEGIN
    SET NOCOUNT ON 
    SET QUOTED_IDENTIFIER OFF 
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @n_bookingno int,
            @c_mbolkey NVARCHAR(10),
            @c_loadkey NVARCHAR(10),
            @n_cbolkey int,
            @c_storerkey NVARCHAR(15),
            @c_destination nvarchar(45),
            @n_casecnt int,
            @n_cnt int
    
    DECLARE @result TABLE(
            bookingdate datetime NULL,
            cbolkey int NULL,
            bookingno int NULL,
            routeauth nvarchar(30) NULL,
            casecnt int NULL,
            storerkey NVARCHAR(15) NULL,
            destination nvarchar(45) NULL,            
            scac nvarchar(10) NULL,
            loc nvarchar(10) NULL,
            arrivedtime datetime NULL,
            signintime datetime NULL,
            unloadtime datetime NULL,
            departtime datetime NULL,
            status NVARCHAR(10) NULL,
            drivername nvarchar(30) NULL,
            mbolkey NVARCHAR(10) NULL,
            loadkey NVARCHAR(10) NULL,
            loc2 nvarchar(10) NULL                                                                    --(Wan01)
            )
	
	INSERT INTO @result (bookingdate, cbolkey, bookingno, routeauth, scac, loc, arrivedtime, signintime, 
	                     unloadtime, departtime, status, drivername, mbolkey, loadkey, loc2)           --(Wan01)
   SELECT Booking_Out.BookingDate,
          Booking_Out.CBOLKey, 
          Booking_Out.BookingNo, 
          Booking_Out.RouteAuth, 
          Booking_Out.SCAC, 
          Booking_Out.Loc,
          Booking_Out.ArrivedTime, 
          Booking_Out.SignInTime, 
          Booking_Out.UnloadTime, 
          Booking_Out.DepartTime,
          Booking_Out.Status, 
          Booking_Out.DriverName,
          Booking_Out.Mbolkey,
          Booking_Out.Loadkey,
          Booking_Out.Loc2                                                                            --(Wan01)
    FROM Booking_Out (NOLOCK)
    WHERE Booking_Out.Facility = @c_facility
    AND DATEDIFF(Day, Booking_Out.BookingDate, @dt_date) = 0
           

    SELECT @n_bookingno = 0 		
 
    WHILE 1=1 
    BEGIN
      SET ROWCOUNT  1  	
      SELECT @n_bookingno = bookingno,
             @c_mbolkey = ISNULL(mbolkey,''),
             @c_loadkey = ISNULL(loadkey,''),
             @n_cbolkey = ISNULL(cbolkey,0)
      FROM @result
      WHERE bookingno > @n_bookingno
      ORDER BY bookingno
      
      SELECT @n_cnt = @@ROWCOUNT

      SET ROWCOUNT  0
      IF @n_cnt = 0
         BREAK
      
      SELECT @n_casecnt = 0,
             @c_storerkey = '',
             @c_destination = ''
      
      IF @n_cbolkey > 0 
      BEGIN
         SELECT @n_casecnt = SUM(MBOL.CaseCnt)
         FROM MBOL (NOLOCK) 
         WHERE MBOL.Cbolkey = @n_cbolkey
         
         SELECT @c_storerkey = MAX(ORDERS.Storerkey),
                @c_destination = MAX(ORDERS.B_company)
         FROM MBOL (NOLOCK) 
         JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey)
         JOIN ORDERS (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
         WHERE MBOL.Cbolkey = @n_cbolkey         
         
         GOTO TOUPD
      END
      
      IF @c_mbolkey <> '' AND @c_mbolkey <> 'MULTI' 
      BEGIN
         SELECT @n_casecnt = MBOL.CaseCnt
         FROM MBOL (NOLOCK) 
         WHERE MBOL.Mbolkey = @c_mbolkey
         
         SELECT @c_storerkey = MAX(ORDERS.Storerkey),
                @c_destination = MAX(ORDERS.B_company)
         FROM MBOL (NOLOCK) 
         JOIN MBOLDETAIL (NOLOCK) ON (MBOL.Mbolkey = MBOLDETAIL.Mbolkey)
         JOIN ORDERS (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
         WHERE MBOL.mbolkey = @c_mbolkey                  
      END

      IF @c_loadkey <> '' AND @c_loadkey <> 'MULTI' 
      BEGIN
         SELECT @n_casecnt = Loadplan.CaseCnt
         FROM LOADPLAN (NOLOCK) 
         WHERE LOADPLAN.Loadkey = @c_loadkey
         
         SELECT @c_storerkey = MAX(ORDERS.Storerkey),
                @c_destination = MAX(ORDERS.B_company)
         FROM LOADPLAN (NOLOCK) 
         JOIN LOADPLANDETAIL (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.loadkey)
         JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
         WHERE LOADPLAN.loadkey = @c_loadkey                  
      END
      
      TOUPD:
      
      UPDATE @result
      SET storerkey = @c_storerkey,
          destination = @c_destination,
          casecnt = @n_casecnt
      WHERE Bookingno = @n_bookingno
    END
        
    SELECT * 
    FROM @result
    ORDER BY bookingdate
 END        

GO