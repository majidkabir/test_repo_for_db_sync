SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: WM.lsp_GetBookingByMonth_Wrapper                   */
/* Creation Date: 2022-02-28                                            */
/* Copyright: IDS                                                       */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3336 - Door Booking SPsDB queries clarification        */
/*        : CONVERT FROM isp_GetBookingByMonth                          */
/* Called By: Booking                                                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-02-29  Wan      1.0   Created                                   */  
/*                            DevOps Combine Script                     */
/* 2023-04-04  Wan01-v0 1.1   LFWM-4065 - SCE RG  Inbound Door booking  */
/*                            -- SP Backend                             */
/* 2024-07-02  Inv Team 1.2   UWP-17135 - Migrate Inbound Door booking  */
/************************************************************************/

CREATE   PROC [WM].[lsp_GetBookingByMonth_Wrapper] 
   @n_Month    INT
,  @n_Year     INT
,  @c_Facility NVARCHAR(5) = '' 
,  @c_InOut    CHAR(1)     = 'I'             --'I','O', 'A'->All 
,  @c_LocGroup NVARCHAR(30)= ''             
,  @c_Floor    NVARCHAR(3) = ''                      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @d_StartDate   DATETIME     = NULL
         , @d_EndDate     DATETIME     = NULL
         , @d_FromDate    DATETIME     = NULL
         , @d_ToDate      DATETIME     = NULL
         , @c_NewLine     CHAR(5)      = ''
 
   DECLARE @t_CalendarDay TABLE 
         (
            Idx         INT
         ,  [Date]      DATETIME
         ,  LastMonday  NVARCHAR(80)
         )
              
   DECLARE @t_DayOfMonth TABLE 
         (  Idx            INT               PRIMARY KEY
         ,  WeekNo         INT
         ,  [Date]         DATETIME
         ,  BookDesc       NVARCHAR(80)
         ,  SlotStatus     CHAR(1)                          --If A:Available, L:Low, F:Full
         ,  NoOfReserved   INT                              --If NoOfReserved > 0, there are Reserved Booking
         )           
   --DECLARE @t_Month TABLE 
   --      (
   --         WeekNo      INT
   --      ,  Sunday      NVARCHAR(80)
   --      ,  Monday      NVARCHAR(80)
   --      ,  Tuesday     NVARCHAR(80)
   --      ,  Wednesday   NVARCHAR(80)
   --      ,  Thursday    NVARCHAR(80)
   --      ,  Friday      NVARCHAR(80)
   --      ,  Saturday    NVARCHAR(80)
   --      )
              
      
   SET @c_LocGroup = ISNULL(@c_LocGroup,'')  
   SET @c_Floor = ISNULL(@c_Floor,'')   
   
   SET @d_StartDate =  CONVERT( DATETIME, CAST(@n_Year AS VARCHAR(4)) + '/' + CAST(@n_Month AS VARCHAR(2)) + '/1')
   ;WITH CTE AS
   (
      SELECT  FirstOfMonth = @d_StartDate 
            , EndOfMonth = EOMONTH(@d_StartDate) 
   )
   , CTE1 AS 
   (
      SELECT 
              PreviousSunday = DATEADD(dd, -1 * (
                                    CASE DATEPART(WEEKDAY, FirstOfMonth)
                                    WHEN 1 
                                    THEN 0
                                    ELSE DATEPART(WEEKDAY, FirstOfMonth) - 1
                                    END), FirstOfMonth)                        
            , FirstOfMonth
            , EndOfMonth
            , LastMonday = DATEADD(dd, 8 - DATEPART(dw,EndOfMonth), EndOfMonth)
      FROM CTE
   )
   , CTE2 AS 
   (
       SELECT Idx = 1
            , Calendarday = PreviousSunday
            , LastMonday
       FROM CTE1
       UNION ALL
       SELECT Idx = CTE2.Idx + 1
            , Calendarday= DATEADD(dd, 1, CTE2.Calendarday)
            , CTE2.LastMonday
       FROM CTE2
       WHERE DATEADD(dd, 1, CTE2.Calendarday) < CTE2.LastMonday
   )
   INSERT INTO @t_CalendarDay
       (
           Idx,
           [Date],
           LastMonday
       )
   SELECT CTE2.Idx 
         ,CTE2.Calendarday 
         ,CTE2.LastMonday
   FROM CTE2
   ORDER BY CTE2.Idx
   
   SELECT @d_FromDate = ISNULL(MIN(tcd.[Date]), @d_StartDate)
         ,@d_ToDate   = ISNULL(MAX(tcd.[Date]), EOMONTH(@d_StartDate))
   FROM @t_CalendarDay AS tcd 
   
   INSERT INTO @t_DayOfMonth
       (
         Idx  
       , WeekNo
       , [Date]
       , BookDesc
       , SlotStatus
       , NoOfReserved
       )

      SELECT tcd.[Idx]
            ,WeekNo = DATEPART(WEEK, tcd.[Date])
            ,tcd.[Date]
            ,[BookDesc] = CASE WHEN tcd.[Date] BETWEEN @d_StartDate AND EOMONTH(@d_StartDate)
                               THEN CONVERT(VARCHAR(2), DATEPART(DAY, tcd.[Date])) + @c_NewLine + ISNULL(dbd.[Desc],'')
                               ELSE LEFT(CONVERT(VARCHAR(10), tcd.[Date], 6),6) + @c_NewLine + ISNULL(dbd.[Desc],'')
                               END
            ,SlotStatus = CASE WHEN ISNULL(dbd.LocUsedPerctg, 0.00) =  100.00 THEN 'F'
                               WHEN ISNULL(dbd.LocUsedPerctg, 0.00) >  80.00  THEN 'L'
                               ELSE 'A'
                               END
            ,NoOfReserved = ISNULL(dbd.NoOfReserved, 0.00)
      FROM @t_CalendarDay AS tcd
      LEFT OUTER JOIN [dbo].[fnc_GetBookingDescByGrpFloor]( @c_Facility, @d_FromDate, @d_ToDate
                                                          , @c_InOut, @c_LocGroup, @c_Floor ) dbd  --(Wan01-v0)
               ON dbd.[Date] =  tcd.[Date]
      ORDER BY tcd.[Idx]

      SELECT Idx  
          , WeekNo
          , [Date]
          , BookDesc
          , SlotStatus
          , NoOfReserved
       FROM @t_DayOfMonth AS tdm

      --NOT GET FROM SHIFT AS NO SETUP DATA in CODELKUP.ListName = 'BOOKSHIFT' 
   --;WITH BC AS
   --(  SELECT tcd.[Idx]
   --         ,tcd.[Date]
   --         ,[BookDesc] = CASE WHEN tcd.[Date] BETWEEN @d_StartDate AND EOMONTH(@d_StartDate)
   --                            THEN CONVERT(VARCHAR(2), DATEPART(DAY, tcd.[Date])) + @c_NewLine + ISNULL(dbd.[Desc],'')
   --                            ELSE LEFT(CONVERT(VARCHAR(10), tcd.[Date], 6),6) + @c_NewLine + ISNULL(dbd.[Desc],'')
   --                            END
   --         ,dbd.SlotStatus 
   --         ,dbd.NoOfReserved 
   --   FROM @t_CalendarDay AS tcd
   --   LEFT OUTER JOIN [dbo].[fnc_GetBookingDescByGrpFloor] ( @c_Facility, @d_FromDate, @d_ToDate, 'O', @c_LocGroup, @c_Floor ) dbd
   --            ON dbd.[Date] =  tcd.[Date]
   --   --NOT GET FROM SHIFT AS NO SETUP DATA in CODELKUP.ListName = 'BOOKSHIFT'        
   --)
   --,C AS
   --(
   --   SELECT MonthIDX   = ((BC.IDX-1)/7)+1
   --         ,WeekNo     = DATEPART(WEEK, BC.[Date])
   --         ,Monday     = CASE WHEN (BC.Idx % 7) = 1 THEN BC.[BookDesc] ELSE '' END
   --         ,Tuesday    = CASE WHEN (BC.Idx % 7) = 2 THEN BC.[BookDesc] ELSE '' END
   --         ,Wednesday  = CASE WHEN (BC.Idx % 7) = 3 THEN BC.[BookDesc] ELSE '' END
   --         ,Thursday   = CASE WHEN (BC.Idx % 7) = 4 THEN BC.[BookDesc] ELSE '' END
   --         ,Friday     = CASE WHEN (BC.Idx % 7) = 5 THEN BC.[BookDesc] ELSE '' END
   --         ,Saturday   = CASE WHEN (BC.Idx % 7) = 6 THEN BC.[BookDesc] ELSE '' END
   --         ,Sunday     = CASE WHEN (BC.Idx % 7) = 0 THEN BC.[BookDesc] ELSE '' END
   --   FROM BC
   --) 
   --INSERT INTO @t_Month
   --    (
   --        WeekNo
   --    ,   Sunday
   --    ,   Monday
   --    ,   Tuesday
   --    ,   Wednesday
   --    ,   Thursday
   --    ,   Friday
   --    ,   Saturday
   --    )
   --SELECT WeekNo     = MIN(c.WeekNo) 
   --      ,Monday     = MAX(c.Monday)    
   --      ,Tuesday    = MAX(c.Tuesday)  
   --      ,Wednesday  = MAX(c.Wednesday) 
   --      ,Thursday   = MAX(c.Thursday)  
   --      ,Friday     = MAX(c.Friday)    
   --      ,Saturday   = MAX(c.Saturday) 
   --      ,Sunday     = MAX(c.Sunday)    
   --FROM c
   --GROUP BY c.MonthIDX  
   
   --SELECT tm.WeekNo 
   --      ,tm.Sunday      
   --      ,tm.Monday     
   --      ,tm.Tuesday    
   --      ,tm.Wednesday  
   --      ,tm.Thursday   
   --      ,tm.Friday     
   --      ,tm.Saturday   
   --FROM @t_Month AS tm   
END

GO