SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetBookingOut_Display2_Wrapper                      */
/* Creation Date: 17-MAR-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Processing logic for page flip on dashboard show on TV      */
/*        :                                                             */
/* Called By: Logo Report                                               */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 17-MAR-2022 shong    1.0   Initial version                           */  
/* 21-MAR-2022 NJOW01   1.1   check if change parameter refresh page 1  */
/* 22-MAR-2022 WLChooi  1.2   DevOps Combine Script                     */
/* 22-MAR-2022 WLChooi  1.2   WMS-19286 Grant EXEC to JReportRole (WL01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_GetBookingOut_Display2_Wrapper]
      (  @c_Facility          NVARCHAR(5)
      ,  @c_Storerkey         NVARCHAR(15)
      ,  @c_Door              NVARCHAR(10)
      ,  @dt_StartLoadDate    DATETIME
      ,  @dt_EndLoadDate      DATETIME
      ,  @c_DeviceID          NVARCHAR(30) 
      )
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @c_SQL         NVARCHAR(MAX)
         ,  @c_SQLWhere    NVARCHAR(MAX)
         ,  @c_SQLSTR      NVARCHAR(MAX)
         ,  @c_STRWhere    NVARCHAR(MAX)

         ,  @n_TotalCnt    INT
         ,  @n_RecToIns    INT
         ,  @n_RowPerPage  INT
         ,  @n_starttcnt   INT
         ,  @d_StartTime   DATETIME
         
   SET @n_starttcnt=@@TRANCOUNT
   SET @d_StartTime=GETDATE()

   IF ISNULL(RTRIM(@c_Facility),'') = ''
   BEGIN
      GOTO QUIT_SP
   END

   IF OBJECT_ID('tempdb..#TMP_DSP2_WRP') IS NOT NULL
      DROP TABLE #TMP_DSP2_WRP
      
   CREATE TABLE #TMP_DSP2_WRP
      (  RowNo                INT NOT NULL PRIMARY KEY
      ,  Facility             NVARCHAR(5)    NULL
      ,  Storerkey            NVARCHAR(15)   NULL
      ,  BookingNo            INT            NULL
      ,  BookingDate          DATETIME       NULL
      ,  EndTime              DATETIME       NULL
      ,  Loc                  NVARCHAR(10)   NULL
      ,  ToLoc                NVARCHAR(10)   NULL
      ,  Loc2                 NVARCHAR(10)   NULL
      ,  VehicleType          NVARCHAR(10)   NULL
      ,  Truck_Name           NVARCHAR(38)   NULL
      ,  Truck_Status         NVARCHAR(20)   NULL
      ,  Order_Status         NVARCHAR(20)   NULL
      ,  Order_Status_Color   INT            NULL
      ,  Remarks              NVARCHAR(30)   NULL
      ,  PageGroup            INT            NULL
      ,  MBOLKey              NVARCHAR(10)   NULL   
      ,  CallTime             DATETIME       NULL   
      )

   BEGIN TRAN;
   
   -------------------------------------------------------
   -- Information require to control the dashboard data
   -------------------------------------------------------
   -- Unique Device ID
   -- Dashboard-ID
   -- Last run date
   -- Total Page
   -- Current Page
   -- Refresh Time (Duration of refresh data)
   
   DECLARE @c_DashboardID        NVARCHAR(60) = N'isp_GetBookingOut_Display2_Wrapper'
         , @d_LastRefreshDate    DATETIME   
         , @n_TotalPage          INT = 0 
         , @n_CurrentPage        INT = 0
         , @n_RefreshDuration    INT = 2 -- in minute
         , @n_DB_HeaderID        INT = 0 
         , @b_GetDetail          BIT = 0
         , @c_ParameterValues    NVARCHAR(1000)  --NJOW01
         , @c_NewParameterValues NVARCHAR(1000)  --NJOW01
            
   SELECT 
      @n_DB_HeaderID     = dh.DB_HeaderID
    , @n_CurrentPage     = dh.CurrentPage 
    , @n_TotalPage       = dh.TotalPages 
    , @d_LastRefreshDate = dh.DataRefreshTime
    , @c_ParameterValues = dh.ParameterValues  --NJOW01
   FROM BI.Dashboard_HDR AS dh WITH(NOLOCK) 
   WHERE DashboardID = @c_DashboardID
   AND   DeviceID = @c_DeviceID 
   
   SET @c_NewParameterValues = RTRIM(ISNULL(@c_Facility,'')) + ',' + RTRIM(ISNULL(@c_Storerkey,'')) + ',' + RTRIM(ISNULL(@c_Door,'')) + ','  +
                               ISNULL(CONVERT(NVARCHAR, @dt_StartLoadDate,112),'19000101') + ',' + ISNULL(CONVERT(NVARCHAR, @dt_EndLoadDate,112),'19000101')  --NJOW01
   
   IF ISNULL(@n_DB_HeaderID,0) = 0 
   BEGIN
      SET @b_GetDetail = 1
      
      INSERT INTO BI.Dashboard_HDR (  DeviceID, DashboardID, CurrentPage, TotalPages, DataRefreshTime, ParameterValues) 
      VALUES ( @c_DeviceID, @c_DashboardID, 0, 0, GETDATE(), @c_NewParameterValues )
         
      SELECT @n_DB_HeaderID = @@IDENTITY
      
   END
   ELSE
   BEGIN
      -- If Last Retrieve date more than duration, refresh again
      IF DATEDIFF(minute, @d_LastRefreshDate, GETDATE()) > @n_RefreshDuration 
         OR @c_NewParameterValues <> @c_ParameterValues  --NJOW01
      BEGIN
         SET @b_GetDetail = 1
         SET @n_CurrentPage = 1
         
         GOTO GET_DAETAIL 
      END
      
      IF @n_CurrentPage + 1 > @n_TotalPage 
      BEGIN
         SET @b_GetDetail = 1
      END
      ELSE
         SET @n_CurrentPage = @n_CurrentPage + 1
         
   END
   
   GET_DAETAIL:
   
   IF NOT EXISTS (SELECT 1 FROM BI.Dashboard_HDR AS dh WITH(NOLOCK) WHERE dh.DB_HeaderID = @n_DB_HeaderID)
   BEGIN
      PRINT 'Header Not Found'
   END
      
   IF @b_GetDetail = 1
   BEGIN
      BEGIN TRY
         DELETE FROM BI.Dashboard_DET
         WHERE DB_HeaderID = @n_DB_HeaderID         
            
         --INSERT INTO BI.Dashboard_DET
         --(
         --   DB_HeaderID,
         --   RowID,
         --   CharCol001, -- Facility
         --   CharCol002, -- Storerkey
         --   CharCol003, -- BookingNo
         --   DateCol001, -- BookingDate
         --   DateCol002, -- EndTime            
         --   CharCol004, -- Loc
         --   CharCol005, -- ToLoc
         --   CharCol006, -- Loc2
         --   CharCol007, -- VehicleType
         --   CharCol010, -- Truck_Name
         --   CharCol011, -- Truck_Status            
         --   CharCol008, -- Order_Status            
         --   IntCol001,  -- Order_Status_Color
         --   CharCol031, -- Remarks
         --   PageGroup, 
         --   CharCol012, -- MBOLKey
         --   CharCol013  -- CallTime 
         --   )   
         EXEC isp_GetBookingOut_Display2
               @c_Facility       
            ,  @c_Storerkey      
            ,  @c_Door           
            ,  @dt_StartLoadDate 
            ,  @dt_EndLoadDate 
            ,  @n_DB_HeaderID     
            
         SET @n_CurrentPage = 1
            
         SELECT TOP 1 
            @n_TotalPage = dd.PageGroup
         FROM BI.Dashboard_DET AS dd WITH(NOLOCK)
         WHERE dd.DB_HeaderID = @n_DB_HeaderID
         ORDER BY dd.RowID DESC
                        
      END TRY
      BEGIN CATCH
       
            SELECT
               ERROR_NUMBER() AS ErrorNumber,
               ERROR_SEVERITY() AS ErrorSeverity,
               ERROR_STATE() AS ErrorState,
               ERROR_PROCEDURE() AS ErrorProcedure,
               ERROR_LINE() AS ErrorLine,
               ERROR_MESSAGE() AS ErrorMessage
      
      END CATCH
      
   END -- IF @b_GetDetail = 1
         
      

   QUIT_SP:  

   SELECT 
   RowID,
   CharCol001 AS [Facility],
   CharCol002 AS [Storerkey],
   CharCol003 AS [BookingNo],
   DateCol001 AS [BookingDate],
   DateCol002 AS [EndTime],            
   CharCol004 AS [Loc],
   CharCol005 AS [ToLoc],
   CharCol006 AS [Loc2],
   CharCol007 AS [VehicleType],
   CharCol010 AS [Truck_Name],
   CharCol011 AS [Truck_Status],            
   CharCol008 AS [Order_Status],            
   IntCol001  AS [Order_Status_Color],
   CharCol031 AS [Remarks],
   PageGroup, 
   CharCol012 AS [MBOLKey],
   DateCol003 AS [CallTime]   --CharCol013    --WL01 
   FROM BI.Dashboard_DET AS dd WITH(NOLOCK)
   WHERE dd.DB_HeaderID = @n_DB_HeaderID
   AND dd.PageGroup = @n_CurrentPage
   
   
   UPDATE BI.Dashboard_HDR
   SET
      CurrentPage = @n_CurrentPage,
      TotalPages = @n_TotalPage,
      DataRefreshTime = GETDATE(),
      ParameterValues = @c_NewParameterValues  --NJOW01
   WHERE DB_HeaderID = @n_DB_HeaderID
      
   WHILE @@TRANCOUNT > 0 
      COMMIT TRAN

   WHILE @@TRANCOUNT < @n_starttcnt 
      BEGIN TRAN

END -- procedure

GO