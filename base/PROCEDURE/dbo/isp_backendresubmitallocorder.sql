SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: isp_BackendResubmitAllocOrder                       */              
/* Creation Date: 5/18/2022                                             */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author      Purposes									         */
/* 5/18/2022                  Initial                                   */
/************************************************************************/ 
CREATE PROCEDURE [dbo].[isp_BackendResubmitAllocOrder] (
     @n_TotalHour    INT = 2 
   , @b_Success      INT = 1            OUTPUT  
   , @n_Err          INT = ''           OUTPUT  
   , @c_ErrMsg       NVARCHAR(250) = '' OUTPUT   
   , @b_Debug        INT = 0 )   
AS
BEGIN
   SET NOCOUNT ON;

   /* declare variables */
   DECLARE @c_StorerKey    NVARCHAR(15),
           @c_Facility     NVARCHAR(5),
           @n_RowRef       BIGINT,
           @c_OrderKey     NVARCHAR(10),
           @d_StartDate    DATETIME, 
           @d_EndDate      DATETIME 

   SET @n_TotalHour = ABS(@n_TotalHour) * -1
   SET @d_StartDate = DATEADD(hour, @n_TotalHour, GETDATE())
   SET @d_EndDate = DATEADD(MINUTE, -30, GETDATE())

   IF @b_Debug = 1
   BEGIN
      PRINT 'DEBUG:  StartDate - ' + CONVERT(VARCHAR(20), @d_StartDate, 120)
      PRINT 'DEBUG:  EndDate - ' + CONVERT(VARCHAR(20), @d_EndDate, 120)
   END

   DECLARE CUR_AUTOALLOC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT 
         VH.StorerKey,  
         VH.Facility 
   FROM  V_Build_Load_Parm_Header VH  
   WHERE VH.BL_ActiveFlag = '1'  
   AND   VH.[BL_BuildType] = 'BackendSOAlloc'  
   AND   VH.Facility <> ''  
   
   OPEN CUR_AUTOALLOC
   
   FETCH NEXT FROM CUR_AUTOALLOC INTO @c_StorerKey, @c_Facility
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      DECLARE CUR_ORDERTORELEASE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT AABD.RowRef, AABD.OrderKey
         FROM dbo.AutoAllocBatchDetail AABD WITH (NOLOCK) 
         JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = AABD.OrderKey
         WHERE AABD.Status = '1'
         AND O.StorerKey = @c_StorerKey 
         AND O.Facility = @c_Facility
         AND O.Status IN ('0','1') 
         AND AABD.AddDate BETWEEN @d_StartDate AND  @d_EndDate         
         AND NOT EXISTS (SELECT 1 FROM dbo.TCPSocket_QueueTask TQT WITH (NOLOCK) 
                         WHERE TQT.DataStream='BckEndAllo'
                         AND TQT.TransmitLogKey=AABD.RowRef)
   
      OPEN CUR_ORDERTORELEASE
   
      FETCH NEXT FROM CUR_ORDERTORELEASE INTO @n_RowRef, @c_OrderKey
   
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT 'DEBUG: Cursor loop, RowRef ' + + CAST(@n_RowRef AS VARCHAR(10)) + ' Order# ' + @c_OrderKey 
         END

         SET @c_ErrMsg = ''

         SELECT TOP (1) @c_ErrMsg = TQTL.ErrMsg 
         FROM dbo.TCPSocket_QueueTask_Log TQTL WITH (NOLOCK) 
         WHERE TQTL.Status='5' 
         AND TQTL.DataStream='BckEndAllo'
         AND TQTL.TransmitLogKey=@n_RowRef
         ORDER BY TQTL.ID DESC         
         BEGIN
            IF @b_Debug = 1
            BEGIN
               PRINT 'DEBUG: TCPSocket_QueueTask_Log Error Message = ' + @c_ErrMsg
            END

            IF @c_ErrMsg > '' AND CHARINDEX(N'conflicted with the CHECK constraint', @c_ErrMsg) > 0
            BEGIN
               -- Move the record to AutoAllocBatchDetail_Log table, to let Auto Allocation to pickup 
               -- the order and send again.
               EXEC dbo.isp_UpdateAutoAllocBatchDetail_Status
                   @n_AABD_RowRef = @n_RowRef,   -- bigint
                   @c_Status = N'9',             -- nvarchar(10)
                   @n_Err = @n_Err OUTPUT,       -- int
                   @c_ErrMsg = @c_ErrMsg OUTPUT  -- nvarchar(250)

               IF @b_Debug = 1
               BEGIN
                  PRINT 'DEBUG: Moving record ' + CAST(@n_RowRef AS VARCHAR(10)) + ' to AutoAllocBatchDetail_Log  ' + @c_ErrMsg 
               END
            
            END -- IF @c_ErrMsg > '' 
            ELSE 
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  PRINT 'DEBUG: No Error! Do Nothing' 
               END
            END
         END
   
         FETCH NEXT FROM CUR_ORDERTORELEASE INTO @n_RowRef, @c_OrderKey
      END
   
      CLOSE CUR_ORDERTORELEASE
      DEALLOCATE CUR_ORDERTORELEASE
           
       FETCH NEXT FROM CUR_AUTOALLOC INTO @c_StorerKey, @c_Facility
   END
   
   CLOSE CUR_AUTOALLOC
   DEALLOCATE CUR_AUTOALLOC


END

GO