SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Procedure: isp_GetBookingOut_Display                          */  
/* Creation Date: 11/02/2015                                            */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 332663-Booking outboud dashboard                            */  
/*                                                                      */  
/* Called By: d_dw_booking_dashboard_out_dsp                            */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 14-July-2015 TLTING  1.1   Performance Tune - on blocking            */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GetBookingOut_Display] (  
        @c_facility nvarchar(5) = '',  
        @dt_date datetime = NULL,  
        @n_recordno int = 0  
)  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF     
    SET CONCAT_NULL_YIELDS_NULL OFF  
      
    DECLARE @n_Cnt INT,  
            @n_Rowid BIGINT,  
            @n_MaxRowId BIGINT,  
            @c_Loc NVARCHAR(10),  
            @c_PrevLoc NVARCHAR(10),
            @n_StartTCnt INT  


    SET @n_StartTCnt = @@TRANCOUNT  
         
    IF @dt_date IS NULL  
       SELECT @dt_date = GETDATE()  
    
    WHILE @@TRANCOUNT > 0
      COMMIT TRAN
      
    BEGIN TRAN
         
    DECLARE @result TABLE(  
                          rowid int identity(1,1) NOT NULL,  
                          bookingdate datetime NULL,  
                          loc nvarchar(10) NULL,  
                          vehicletype nvarchar(20) NULL,  
                          carrierkey nvarchar(18) NULL,  
                          licenseno nvarchar(20) NULL,  
                          rmdescr nvarchar(60) NULL,  
                          status nvarchar(20) NULL,  
                          endtime datetime NULL,  
                          recordno int NULL  
                         )              
      
    INSERT INTO @result (bookingdate, loc, vehicletype, carrierkey, licenseno, rmdescr, status, endtime)   
    SELECT BO.BookingDate,  
           BO.LOC,  
           BO.VehicleType,  
           BO.Carrierkey,  
           BO.LicenseNo,  
           MAX(RM.Descr) AS RMDescr,  
           CASE WHEN BO.Status IN('0') AND LP.Status IN('0','1','2') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                   'Allocated'  
                WHEN BO.Status IN('1') AND LP.Status IN('0','1','2','9') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                   'Arrived'  
                WHEN BO.Status IN('0','1') AND LP.Status = '3' THEN -- AND LP.ProcessFlag = 'Y' THEN  
                   'Picking'  
                WHEN BO.Status IN('0','1') AND LP.Status = '5' THEN  
                   'Staging Area'  
                WHEN BO.Status = '0' AND LP.Status = '9' THEN  
                   'Advance MBOL'  
                WHEN BO.Status = '2' THEN  
                   'Loading'  
                WHEN BO.Status = '3' THEN  
                   'Loaded'  
                WHEN BO.Status = '9' THEN  
                   'Departed'  
                ELSE   
                   'Unknown'  
           END AS Status,  
           BO.EndTime  
    FROM BOOKING_OUT BO (NOLOCK)  
    JOIN LOC (NOLOCK) ON BO.Loc = LOC.Loc   
    LEFT JOIN LOADPLAN LP (NOLOCK) ON BO.BookingNo = LP.BookingNo   
    LEFT JOIN ORDERS O (NOLOCK) ON LP.LoadKey = O.LoadKey  
    LEFT JOIN ROUTEMASTER RM (NOLOCK) ON O.Route = RM.Route  
    WHERE (BO.Status <> '9' OR (BO.Status = '9' AND DATEDIFF(MI,BO.EditDate,GETDATE()) <= 5))  
    AND LOC.LocationCategory IN('BAYOUT')  
    AND DATEDIFF(DAY, BO.BookingDate, @dt_date) = 0  
    AND BO.Facility = CASE WHEN ISNULL(@c_facility,'') <> '' THEN @c_Facility ELSE BO.Facility END  
    AND BO.FinalizeFlag = 'Y'   
    GROUP BY BO.BookingDate,  
             BO.Loc,  
             BO.VehicleType,  
             BO.Carrierkey,  
             BO.LicenseNo,  
             CASE WHEN BO.Status IN('0') AND LP.Status IN('0','1','2') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                     'Allocated'  
                  WHEN BO.Status IN('1') AND LP.Status IN('0','1','2','9') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                     'Arrived'  
                  WHEN BO.Status IN('0','1') AND LP.Status = '3' THEN --AND LP.ProcessFlag = 'Y' THEN  
                     'Picking'  
                  WHEN BO.Status IN('0','1') AND LP.Status = '5' THEN  
                     'Staging Area'  
                  WHEN BO.Status = '0' AND LP.Status = '9' THEN  
                     'Advance MBOL'  
                  WHEN BO.Status = '2' THEN  
                     'Loading'  
                  WHEN BO.Status = '3' THEN  
                     'Loaded'  
                  WHEN BO.Status = '9' THEN  
                     'Departed'  
                  ELSE   
                     'Unknown'  
             END,  
             BO.EndTime  
    UNION ALL  
    SELECT BO.BookingDate,  
           BO.Loc2 AS loc,  
           BO.VehicleType,  
           BO.Carrierkey,  
           BO.LicenseNo,  
           MAX(RM.Descr) AS RMDescr,  
           CASE WHEN BO.Status IN('0') AND LP.Status IN('0','1','2') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                   'Allocated'  
                WHEN BO.Status IN('1') AND LP.Status IN('0','1','2','9') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                   'Arrived'  
                WHEN BO.Status IN('0','1') AND LP.Status = '3' THEN --AND LP.ProcessFlag = 'Y' THEN  
                   'Picking'  
                WHEN BO.Status IN('0','1') AND LP.Status = '5' THEN  
                   'Staging Area'  
                WHEN BO.Status = '0' AND LP.Status = '9' THEN  
                   'Advance MBOL'  
                WHEN BO.Status = '2' THEN  
                   'Loading'  
                WHEN BO.Status = '3' THEN  
                   'Loaded'  
                WHEN BO.Status = '9' THEN  
                   'Departed'  
                ELSE   
                   'Unknown'  
           END AS Status,  
           BO.EndTime  
    FROM BOOKING_OUT BO (NOLOCK)  
    JOIN LOC (NOLOCK) ON BO.Loc2 = LOC.Loc  
    LEFT JOIN LOADPLAN LP (NOLOCK) ON BO.BookingNo = LP.BookingNo   
    LEFT JOIN ORDERS O (NOLOCK) ON LP.LoadKey = O.LoadKey  
    LEFT JOIN ROUTEMASTER RM (NOLOCK) ON O.Route = RM.Route  
    WHERE (BO.Status <> '9' OR (BO.Status = '9' AND DATEDIFF(MI,BO.EditDate,GETDATE()) <= 5))  
    AND LOC.LocationCategory IN('BAYOUT')  
    AND ISNULL(BO.Loc2,'') <> ''  --second location of the booking  
    AND DATEDIFF(DAY, BO.BookingDate, @dt_date) = 0  
    AND BO.Facility = CASE WHEN ISNULL(@c_facility,'') <> '' THEN @c_Facility ELSE BO.Facility END  
    AND BO.FinalizeFlag = 'Y'   
    GROUP BY BO.BookingDate,  
             BO.Loc2,  
             BO.VehicleType,  
             BO.Carrierkey,  
             BO.LicenseNo,  
             CASE WHEN BO.Status IN('0') AND LP.Status IN('0','1','2') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                     'Allocated'  
                  WHEN BO.Status IN('1') AND LP.Status IN('0','1','2','9') THEN --AND LP.ProcessFlag <> 'Y' THEN  
                     'Arrived'  
                  WHEN BO.Status IN('0','1') AND LP.Status = '3' THEN --AND LP.ProcessFlag = 'Y' THEN  
                     'Picking'  
                  WHEN BO.Status IN('0','1') AND LP.Status = '5' THEN  
                     'Staging Area'  
                  WHEN BO.Status = '0' AND LP.Status = '9' THEN  
                     'Advance MBOL'  
                  WHEN BO.Status = '2' THEN  
                     'Loading'  
                  WHEN BO.Status = '3' THEN  
                     'Loaded'  
                  WHEN BO.Status = '9' THEN  
                     'Departed'  
                  ELSE   
                     'Unknown'  
             END,  
             BO.EndTime  
    ORDER BY 2, 1  
      
    SET @n_Rowid = 1  
    SET @n_Cnt = 0  
    SET @c_Loc = ''  
    SET @c_PrevLoc = ''  
    SELECT @n_MaxRowID = MAX(rowid) FROM @result  
      
    --remove 3rd booking onward of a bay  
    WHILE (@n_rowid <= @n_MaxRowID)   
    BEGIN   
       SELECT @c_loc = Loc   
       FROM @result   
       WHERE rowid = @n_Rowid          
                
       IF @c_Loc = @c_PrevLoc   
          SELECT @n_Cnt = @n_Cnt + 1            
       ELSE         
          SELECT @n_Cnt = 1  
         
        IF @n_Cnt > 2  
           DELETE FROM @result WHERE rowid = @n_Rowid        
        ELSE  
          UPDATE @result SET Recordno = @n_Cnt WHERE rowid = @n_Rowid   
  
       SET @c_PrevLoc = @c_Loc                 
       SET @n_Rowid = @n_Rowid + 1   
    END   
      
    IF ISNULL(@n_recordno,0) <> 0  
    BEGIN  
       SELECT r.bookingdate,  
              LOC.loc,  
              r.vehicletype,  
              ISNULL(r.carrierkey, ''),  
              ISNULL(r.licenseno, ''),  
              r.rmdescr,  
              r.status,  
              r.endtime,  
              r.recordno  
       FROM LOC (NOLOCK)  
       LEFT JOIN @result r ON LOC.Loc = r.Loc AND ISNULL(r.recordno,0) = @n_recordno  
       WHERE LOC.LocationCategory IN('BAYOUT')  
       ORDER BY LOC.Loc, r.RowId      
    END  
    ELSE  
    BEGIN  
       SELECT r.bookingdate,  
              LOC.loc,  
              r.vehicletype,  
              ISNULL(r.carrierkey, ''),  
              ISNULL(r.licenseno, ''),  
              r.rmdescr,  
              r.status,  
              r.endtime,  
              r.recordno  
       FROM LOC (NOLOCK)  
       LEFT JOIN @result r ON LOC.Loc = r.Loc   
       WHERE LOC.LocationCategory IN('BAYOUT')  
       ORDER BY LOC.Loc, r.RowId      
    END 
    
    WHILE @@ROWCOUNT < @n_StartTCnt  
       BEGIN TRAN
    
    
    /*  
    SELECT r.bookingdate,  
           LOC.loc,  
           r.vehicletype,  
           ISNULL(r.carrierkey, ''),  
           ISNULL(r.licenseno, ''),  
           r.rmdescr,  
           r.status,  
           r.recordno  
    FROM LOC (NOLOCK)  
    LEFT JOIN @result r ON LOC.Loc = r.Loc  
    WHERE LOC.LocationCategory IN('BAYOUT')  
    AND ISNULL(r.recordno,0) = CASE WHEN ISNULL(@n_recordno,0) <>  0 AND ISNULL(r.recordno,'') <> '' THEN @n_recordno ELSE ISNULL(r.recordno,0) END  
    ORDER BY LOC.Loc, r.RowId  
    */      
 END          

GO