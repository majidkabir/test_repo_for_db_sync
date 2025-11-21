SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_DoorBookAutoBuild_STD                               */
/* Creation Date: 2022-04-12                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3482 - UAT RG  Generate appointment & Generate booking */
/*        : SP creation                                                 */
/*                                                                      */
/* Called By: [WM].[lsp_DoorBookAutoBuild_Wrapper]                      */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2022-04-12  Wan      1.0   Created & DevOps Combine Script           */
/* 2022-07-20  Wan      1.1   LFWM-3482 Version 2                       */
/************************************************************************/
CREATE   PROC [WM].[lsp_DoorBookAutoBuild_STD]
      @c_DoorBookingStrategyKey  NVARCHAR(10)
   ,  @b_Success                 INT = 1              OUTPUT
   ,  @n_Err                     INT = 0              OUTPUT
   ,  @c_ErrMsg                  NVARCHAR(255)  = ''  OUTPUT
   ,  @c_UserName                NVARCHAR(128)  = ''  
   ,  @n_ErrGroupKey             INT            = 0   OUTPUT 
   ,  @b_debug                   INT            = 0  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                   INT   = @@TRANCOUNT
         , @n_Continue                    INT   = 1
         , @c_Message                     NVARCHAR(255)  = ''
         
         , @c_Facility                    NVARCHAR(5)    = ''
         , @c_Storerkey                   NVARCHAR(15)   = ''
         , @c_ShipmentGroupProfile        NVARCHAR(100)  = ''
         
         , @c_TableName                   NVARCHAR(50)   = 'DoorBookingAutoBuild'
         , @c_SourceType                  NVARCHAR(50)   = 'lsp_DoorBookAutoBuild_STD'
         , @c_Refkey1                     NVARCHAR(20)   = ''                      
         , @c_Refkey2                     NVARCHAR(20)   = ''                      
         , @c_Refkey3                     NVARCHAR(20)   = ''    
         , @c_WriteType                   NVARCHAR(10)   = ''          
         , @n_LogWarningNo                INT            = 0     
         
         , @c_SortSequece                 NVARCHAR(1000) = ''
         , @c_MatchSubBannerToLocField    NVARCHAR(100)  = ''
         , @c_DoorLimitByCase             NVARCHAR(10)   = ''
         , @c_CycleLocBayByWave           NVARCHAR(10)   = ''
         --, @c_AdjacentLoc4LocBayByWave    NVARCHAR(10)   = '' 
         , @c_AdjacentLocByShipmentGroup  NVARCHAR(10)   = ''              --CR 1.8  
         , @c_CycleLocBayByShipmentGroup  NVARCHAR(10)   = ''              --CR 1.8 
         , @c_Hierarchy                   NVARCHAR(10)   = ''

         , @n_RowID_Shpm                  INT            = 0               --CR 1.8
         , @n_RowRef_Shpm                 INT            = 0
         , @c_ShipmentGID                 NVARCHAR(50)   = ''
         , @c_AppointmentID               NVARCHAR(20)   = ''
         , @c_ShipmentWave                NVARCHAR(20)   = ''
         , @c_Banner                      NVARCHAR(100)  = ''
         , @c_Subbanner                   NVARCHAR(100)  = ''
         , @c_Route                       NVARCHAR(10)   = ''   
         , @c_Equipment                   NVARCHAR(20)   = ''
         , @c_DriverName                  NVARCHAR(50)   = ''
         , @c_VehicleLPN                  NVARCHAR(50)   = ''
         , @c_VehicleType                 NVARCHAR(30)   = '' 
         , @c_ServiceProviderID           NVARCHAR(50)   = '' 
         , @c_ShipmentGroup               NVARCHAR(100)  = '' 
         , @n_Duration                    INT            = 0 
         , @n_CallTimeInMin               INT            = 0               --CR 2.0
         , @dt_Duration                   DATETIME       = '1900-01-01'
         , @dt_EarlyPickupDate            DATETIME
         , @dt_PickupEndTime              DATETIME
         , @dt_calltime                   DATETIME                         --CR 2.0
         , @c_CallTimeInMin               NVARCHAR(30)                     --CR 2.0
         
         , @c_SubBanners                  NVARCHAR(500)  = ''
         , @c_HierarchyLoc_Join           NVARCHAR(1000) = ''
         , @c_HierarchyLoc_OrderBy        NVARCHAR(1000) = '' 
         
         , @n_TotalCasePerAPM             INT            = 0               --2022-07-07 Fix   
         , @c_LocBay_Filter               NVARCHAR(500)  = ''
         , @c_LocBay                      NVARCHAR(10)   = ''
         , @c_LocBay_PrevShpGrp           NVARCHAR(10)   = ''              --CR 1.8
         , @c_Loc_PrevShpGrp              NVARCHAR(10)   = ''              --CR 1.8
         , @n_RowID_Start                 INT            = 0
         , @n_RowID_End                   INT            = 0 
         
         , @b_FindAvailableFromLastBlock  BIT            = 0               --2022-07-20 Fix         
         , @n_RowID_lastLoc               INT            = ''              --2022-07-15 Fix
         , @n_RowID_lastblock             INT            = 0               --2022-07-07 Fix 
         , @n_BookingNo_Shpm              INT            = 0
         , @n_BookingNo                   INT            = 0
         , @c_BookingNo                   NVARCHAR(10)   = '' 
         , @c_BookOType                   NVARCHAR(10)   = ''
         , @c_Loc                         NVARCHAR(10)   = ''  
         , @c_ToLoc                       NVARCHAR(10)   = ''          
         
         , @c_SQL                         NVARCHAR(4000) = ''
         , @c_SQLParms                    NVARCHAR(1000) = ''
         
         , @CUR_ERRLIST                   CURSOR
   
    DECLARE  @t_WMSErrorList   TABLE                                 
         (  RowID                INT            IDENTITY(1,1)     PRIMARY KEY    
         ,  TableName            NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  SourceType           NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  Refkey1              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  Refkey2              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  Refkey3              NVARCHAR(20)   NOT NULL DEFAULT('')  
         ,  WriteType            NVARCHAR(50)   NOT NULL DEFAULT('')  
         ,  LogWarningNo         INT            NOT NULL DEFAULT(0)  
         ,  ErrCode              INT            NOT NULL DEFAULT(0)  
         ,  Errmsg               NVARCHAR(255)  NOT NULL DEFAULT('') 
         )   

    DECLARE @t_TMS_Shipment      TABLE                                     --CR 1.8
         (  RowID                INT            IDENTITY(1,1)     PRIMARY KEY  
         ,  RowRef_Shpm          INT            NOT NULL DEFAULT(0)        --2022-07-06 Fixed
         ,  AppointmentID        NVARCHAR(20)   NOT NULL DEFAULT('')       --2022-07-06 Fixed
         ) 
                   
   BEGIN TRY
            
      IF OBJECT_ID('tempdb..#TMP_LOC','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_LOC
      END
      
      CREATE TABLE #TMP_LOC 
         (  RowID             INT            IDENTITY(1,1) PRIMARY KEY
         ,  SubBanner         NVARCHAR(30)   NOT NULL DEFAULT('')   
         ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')   
         ,  LocationCategory  NVARCHAR(10)   NOT NULL DEFAULT('')   
         ,  LocBay            NVARCHAR(10)   NOT NULL DEFAULT('')  
         ,  MaxCarton         INT            NOT NULL DEFAULT(0)
         )  
         
      IF OBJECT_ID('tempdb..#TMP_LOC_WIP','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_LOC_WIP
      END
      
      CREATE TABLE #TMP_LOC_WIP 
         (  RowID             INT            IDENTITY(1,1) PRIMARY KEY
         ,  SubBanner         NVARCHAR(30)   NOT NULL DEFAULT('')   
         ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('')
         ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')   
         ,  LocationCategory  NVARCHAR(10)   NOT NULL DEFAULT('')   
         ,  LocBay            NVARCHAR(10)   NOT NULL DEFAULT('')  
         ,  MaxCarton         INT            NOT NULL DEFAULT(0)
         )    
         
      IF OBJECT_ID('tempdb..#TMP_HIEARACHYLOC','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_HIEARACHYLOC 
      END
      
      CREATE TABLE #TMP_HIEARACHYLOC 
      (  RowID       INT            IDENTITY(1,1) PRIMARY KEY
      ,  SubBanner   NVARCHAR(30)   NOT NULL DEFAULT('')
      )
       
      IF OBJECT_ID('tempdb..#TMP_BOOKLOC','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_BOOKLOC  
      END  
      
      CREATE TABLE #TMP_BOOKLOC 
      (  RowID             INT            NOT NULL             IDENTITY(1,1)  PRIMARY KEY
      ,  RowID_Loc         INT            NOT NULL DEFAULT(0)        
      ,  SubBanner         NVARCHAR(30)   NOT NULL DEFAULT('')   
      ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  LogicalLocation   NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  LocationCategory  NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  LocBay            NVARCHAR(10)   NOT NULL DEFAULT('')  
      ,  MaxCarton         INT            NOT NULL DEFAULT(0)
      ,  BookingNo         INT            NOT NULL DEFAULT(0)  
      ,  BlockSlotKey      NVARCHAR(10)   NOT NULL DEFAULT('')        
      )  

      SET @n_Err = 0  
   
      IF SUSER_SNAME() <> @c_UserName     
      BEGIN 
         EXEC [WM].[lsp_SetUser]   
               @c_UserName = @c_UserName  OUTPUT  
            ,  @n_Err      = @n_Err       OUTPUT  
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT  
         
         IF @n_Err <> 0   
         BEGIN
            GOTO EXIT_SP  
         END          
                  
         EXECUTE AS LOGIN = @c_UserName  
      END 
               
      SELECT @c_Facility   = dbs.Facility  
         ,   @c_Storerkey  = dbs.Storerkey 
         ,   @c_ShipmentGroupProfile = dbs.ShipmentGroupProfile
      FROM DoorBookingStrategy dbs WITH (NOLOCK)
      WHERE  dbs.DoorBookingstrategykey = @c_DoorBookingStrategyKey
      
      SELECT @c_SortSequece               = MAX(IIF (dbsd.Code = 'SortSequence', dbsd.[Value], ''))
            ,@c_MatchSubBannerToLocField  = MAX(IIF (dbsd.Code = 'MatchSubBannerTo', dbsd.[Value], ''))
            ,@c_DoorLimitByCase           = MAX(IIF (dbsd.Code = 'DoorLimitByCase', dbsd.[Value], ''))  
            ,@c_CycleLocBayByWave         = MAX(IIF (dbsd.Code = 'CycleLocBayByWave', dbsd.[Value], ''))    
            --,@c_AdjacentLoc4LocBayByWave  = MAX(IIF (dbsd.Code = 'AdjacentLoc4LocBayByWave', dbsd.[Value], '')) --CR 1.8  
            ,@c_AdjacentLocByShipmentGroup= MAX(IIF (dbsd.Code = 'AdjacentLocByShipmentGroup', dbsd.[Value], '')) --CR 1.8   
            ,@c_CycleLocBayByShipmentGroup= MAX(IIF (dbsd.Code = 'CycleLocBayByShipmentGroup', dbsd.[Value], '')) --CR 1.8    
            ,@c_Hierarchy                 = MAX(IIF (dbsd.Code = 'Hierarchy', dbsd.[Value], ''))                           
      FROM DoorBookingStrategydetail dbsd WITH (NOLOCK) 
      WHERE dbsd.DoorBookingstrategykey = @c_DoorBookingStrategyKey
      GROUP BY dbsd.DoorBookingstrategykey
 
      SET @c_SQL = N'SELECT ts.Rowref'                         --CR 1.8
                 + ' FROM dbo.TMS_Shipment AS ts WITH (NOLOCK)'
                 + ' WHERE ts.ShipmentGroupProfile = @c_ShipmentGroupProfile'
                 + ' AND ts.AppointmentID <> '''' AND ts.AppointmentID IS NOT NULL'
                 + ' AND (ts.BookingNo = 0 OR ts.BookingNo IS NULL)'                --2022-07-05 Fixed 
                 + CASE WHEN @c_AdjacentLocByShipmentGroup = 'Y' THEN ' ORDER BY ts.ShipmentGroup, ts.Rowref'
                        ELSE ' ORDER BY ts.Rowref' END
      SET @c_SQLParms = N'@c_ShipmentGroupProfile NVARCHAR(100)'
               
      INSERT INTO @t_TMS_Shipment  ( RowRef_Shpm )             
      EXECUTE sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@c_ShipmentGroupProfile

      SET @n_RowID_Shpm = 0
      SET @n_RowRef_Shpm = 0
      
      SELECT @n_Duration = CAST(nsqlvalue AS INT) 
      FROM NSQLCONFIG (NOLOCK)
      WHERE configkey = 'BOOKINGINTERVAL'
      
      IF @n_Duration = 0 SET @n_Duration = 30
      
      --CR 2.0
      SELECT @c_CallTimeInMin = ISNULL(f.UserDefine07,'') 
      FROM dbo.FACILITY AS f WITH (NOLOCK)
      WHERE f.Facility = @c_Facility
    
      WHILE 1 = 1 AND @n_Continue IN (1,2)
      BEGIN
         SELECT TOP 1                                       --CR 1.8
                  @n_RowID_Shpm     = tts.RowID
               ,  @n_RowRef_Shpm    = ts.Rowref
               ,  @c_ShipmentGID    = ts.ShipmentGID
               ,  @c_AppointmentID  = ts.AppointmentID
               ,  @c_ShipmentWave   = ISNULL(ts.Wave,'')   
               ,  @c_Banner         = ISNULL(ts.Banner,'')
               ,  @c_Subbanner      = ISNULL(ts.Subbanner,'')
               ,  @dt_EarlyPickupDate= ts.ShipmentPlannedStartDate
               ,  @c_Equipment      = ts.EquipmentID
               ,  @c_DriverName     = ISNULL(ts.DriveName,'')
               ,  @c_VehicleLPN     = ISNULL(ts.VehicleLPN,'')
               ,  @c_ServiceProviderID = ts.ServiceProviderID
               ,  @c_ShipmentGroup  = ISNULL(ts.ShipmentGroup,'')
         FROM @t_TMS_Shipment AS tts 
         JOIN dbo.TMS_Shipment AS ts WITH (NOLOCK) ON ts.Rowref = tts.RowRef_Shpm
         WHERE tts.RowID > @n_RowID_Shpm
         ORDER BY tts.RowID
           
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
   
         SET @n_BookingNo = 0

         SELECT @n_BookingNo = ts.BookingNo FROM dbo.TMS_Shipment AS ts WITH (NOLOCK) 
         WHERE ts.Rowref <> @n_RowRef_Shpm
         AND ts.AppointmentID = @c_AppointmentID
                       
         IF @n_BookingNo > 0
         BEGIN 
            SELECT @c_Loc = bo.loc
                  ,@c_ToLoc = bo.Toloc
            FROM dbo.Booking_Out AS bo WITH (NOLOCK)
            WHERE bo.BookingNo = @n_BookingNo 
                
            GOTO NEXT_SHIPMENT
         END
         ELSE                 --2022-07-06 Fixed - START                                                 
         BEGIN
            IF EXISTS ( SELECT 1 FROM @t_TMS_Shipment AS tts WHERE AppointmentID = @c_AppointmentID )
            BEGIN
               CONTINUE
            END
         END                  --2022-07-06 Fixed - END
         
         UPDATE @t_TMS_Shipment SET AppointmentID = @c_AppointmentID WHERE RowID = @n_RowID_Shpm               --2022-07-06 Fixed
         
         SET @n_BookingNo = 0
         --CR 2.0 - START
         SET @dt_calltime = NULL
         
         IF ISNUMERIC(@c_CallTimeInMin) = 1
         BEGIN
            SET @n_CallTimeInMin = CONVERT(INT, @c_CallTimeInMin)
            SET @dt_calltime = DATEADD(MINUTE, @n_CallTimeInMin * -1 , @dt_EarlyPickupDate)
         END
         --CR 2.0 - END
         
         IF @b_debug = 1
         BEGIN
            SELECT @c_AppointmentID '@c_AppointmentID', @c_DoorBookingStrategyKey '@c_DoorBookingStrategyKey', @c_Subbanner '@c_SubBanner' 
            
            PRINT   '@c_AppointmentID: ' + @c_AppointmentID 
                + ', @c_DoorBookingStrategyKey: ' + @c_DoorBookingStrategyKey
                + ', @c_Subbanner: ' + @c_SubBanner
                
            PRINT '-----------------------------------------------------'  
            PRINT ' MatchSubBannerToLocField: = ' + @c_MatchSubBannerToLocField
            PRINT ' INSERT LOC INTO #TMP_LOC         ' 
            PRINT '-----------------------------------------------------'    
         END
         
         TRUNCATE TABLE #TMP_LOC;
         
         SET @c_SQL = N'SELECT ' + IIF(@c_MatchSubBannerToLocField='', '''''', @c_MatchSubBannerToLocField)
                    + ', LOC.Loc, LOC.LogicalLocation, LOC.LocationCategory, LOC.LocBay, LOC.MaxCarton'
                    + ' FROM dbo.LOC WITH (NOLOCK)'
                    + ' WHERE LOC.Facility = @c_Facility'
                    + ' AND   LOC.LocationCategory IN (''BAY'', ''BAYOUT'')'
                    + IIF(@c_MatchSubBannerToLocField='', '', ' AND ' + @c_MatchSubBannerToLocField + ' =  @c_SubBanner' )   
                    + IIF(@c_SortSequece = '', ' ORDER BY LOC.LOC', ' ORDER BY ' + @c_SortSequece)
         
         SET @c_SQLParms = N'@c_Facility  NVARCHAR(5)'
                         + ',@c_SubBanner NVARCHAR(30)'              --2022-07-13 Fix

         INSERT INTO #TMP_LOC (SubBanner, Loc, Logicallocation, LocationCategory, LocBay, MaxCarton)                
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@c_Facility
                           ,@c_SubBanner
                           
         IF @c_Hierarchy = 'Y'
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '-----------------------------------------------------'  
               PRINT ' @c_Hierarchy = ''Y''                                '
               PRINT ' BUILD HIRARCHY LOC AND INSERT INTO #TMP_LOC         ' 
               PRINT '-----------------------------------------------------'   
            END
         
            TRUNCATE TABLE #TMP_HIEARACHYLOC;
            SET @c_HierarchyLoc_Join = ''
            SET @c_HierarchyLoc_OrderBy = ''
            
            IF @c_MatchSubBannerToLocField <> ''
            BEGIN
               SET @c_SubBanners = ''              --2022-07-22 Fixed
               SELECT @c_SubBanners = c.UDF01 + '|' + c.UDF02 + '|' + c.UDF03 + '|'  + c.UDF04 + '|' + c.UDF05                               
               FROM dbo.CODELKUP AS c WITH (NOLOCK)
               WHERE c.LISTNAME = 'ULPDOORBK'
               AND c.Storerkey= @c_Storerkey
               AND c.Long = @c_SubBanner
       
               IF @c_SubBanners <> ''
               BEGIN
                  INSERT INTO #TMP_HIEARACHYLOC (SubBanner)
                  SELECT ss.[Value]
                  FROM STRING_SPLIT(@c_SubBanners, '|') AS ss
                  WHERE ss.[Value] <> ''
                  
                  SET @c_HierarchyLoc_Join    = ' JOIN #TMP_HIEARACHYLOC t ON t.SubBanner = ' + @c_MatchSubBannerToLocField
                  SET @c_HierarchyLoc_OrderBy = ' ORDER BY t.RowId, ' + IIF(@c_SortSequece = '', 'LOC.LOC', @c_SortSequece)
               END
            END       
         
            IF EXISTS (SELECT 1 FROM #TMP_HIEARACHYLOC AS th)
            BEGIN
               SET @c_SQL = N'SELECT ' + IIF(@c_MatchSubBannerToLocField='', '''', @c_MatchSubBannerToLocField) 
                           + ', LOC.Loc, LOC.LogicalLocation, LOC.LocationCategory, LOC.LocBay, LOC.MaxCarton' 
                           + ' FROM dbo.LOC WITH (NOLOCK)'
                           + @c_HierarchyLoc_JOIN
                           + ' WHERE LOC.Facility = @c_Facility'
                           + ' AND   LOC.LocationCategory IN (''BAY'', ''BAYOUT'')'
                           + @c_HierarchyLoc_OrderBy
         
               SET @c_SQLParms = N'@c_Facility  NVARCHAR(5)'
                               + ',@c_SubBanner NVARCHAR(30)'              --2022-07-13 Fix
      
               INSERT INTO #TMP_LOC (SubBanner, Loc, Logicallocation, LocationCategory, LocBay, MaxCarton)                      
               EXEC sp_ExecuteSQL @c_SQL
                                 ,@c_SQLParms
                                 ,@c_Facility
                                 ,@c_SubBanner
            END
         END                  

         IF @c_DoorLimitByCase = 'Y'
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '-----------------------------------------------------'  
               PRINT ' @c_DoorLimitByCase = ''Y''                          '
               PRINT ' GET Appointment Total Case                          ' 
               PRINT '-----------------------------------------------------'   
            END
            
            SET @n_TotalCasePerAPM = 0                --2022-07-14 fix 
            
            ;WITH o AS
            (
               SELECT ts.AppointmentID
                     ,o.Orderkey
               FROM dbo.TMS_Shipment AS ts (NOLOCK)
               JOIN dbo.TMS_ShipmentTransOrderLink AS tstol WITH (NOLOCK) ON tstol.ShipmentGID = ts.ShipmentGID
               JOIN dbo.TMS_TransportOrder AS tto WITH (NOLOCK) ON tto.ProvShipmentID = tstol.ProvShipmentID
               JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.Orderkey = tto.OrderSourceID 
               WHERE ts.AppointmentID = @c_AppointmentID
               GROUP BY ts.AppointmentID                    --2022-07-12 fix - START
                     ,  o.Orderkey
            )
            , cps AS 
            (
               SELECT o.AppointmentID
                     ,CasePerSku =  IIF(p2.CaseCnt > 0, CEILING(SUM(p.qty)/p2.CaseCnt), 0)
               FROM o
               JOIN dbo.PICKDETAIL AS p WITH (NOLOCK) ON p.OrderKey = o.OrderKey
               JOIN dbo.SKU AS s WITH (NOLOCK) ON s.StorerKey = p.Storerkey AND s.Sku = p.Sku
               JOIN dbo.PACK AS p2 WITH (NOLOCK) ON p2.PackKey = s.PACKKey
               WHERE o.AppointmentID = @c_AppointmentID
               GROUP BY o.AppointmentID, p.Storerkey, p.Sku, s.PACKKey, p2.CaseCnt
            )
            SELECT @n_TotalCasePerAPM = SUM(cps.CasePerSku)
            FROM cps
            GROUP BY cps.AppointmentID
         END
        
         SET @c_VehicleType = ''             --2022-07-22
  
         SELECT @c_VehicleType = c.Code
               ,@n_Duration    = IIF(ISNUMERIC(ISNULL(c.Short,@n_Duration)) = 0, @n_Duration, CONVERT(INT, ISNULL(c.Short,@n_Duration)))  
         FROM dbo.CODELKUP AS c WITH (NOLOCK)
         WHERE c.ListName = 'TrkLoadDur'
         AND c.Code = @c_Equipment
         AND c.Storerkey = @c_Storerkey
         
         SET @dt_PickupEndTime = DATEADD(MINUTE, @n_Duration , @dt_EarlyPickupDate)
         SET @dt_Duration      = DATEADD(MINUTE, @n_Duration , 0)
      
         SET @n_RowID_Start = 0    
         SET @c_LocBay_Filter = ''  
      
         -- Find 1st available Loc
         IF @c_CycleLocBayByWave = 'Y' --OR @c_AdjacentLoc4LocBayByWave = 'Y'
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '-----------------------------------------------------'  
               PRINT ' @c_CycleLocBayByWave = ' + @c_CycleLocBayByWave     
               PRINT ' @c_ShipmentWave: ' + @c_ShipmentWave                       
               PRINT ' GET LocBay to determine Next Loc                    ' 
               PRINT '-----------------------------------------------------'   
            END
           
            SET @n_BookingNo_Shpm = 0
            SET @c_LocBay = ''
            SELECT TOP 1 
                   @n_BookingNo_Shpm = bo.BookingNo
                  ,@c_LocBay = l.LocBay
            FROM dbo.Booking_Out AS bo  (NOLOCK)
            JOIN LOC AS l WITH (NOLOCK) ON bo.Loc = l.loc
            WHERE bo.FACILITY = @c_Facility
            AND bo.Wave = @c_ShipmentWave
            AND bo.BookingDate BETWEEN CONVERT(NVARCHAR(10), @dt_EarlyPickupDate,121) AND CONVERT(NVARCHAR(11), @dt_EarlyPickupDate,121) + '23:59:59.999'
            AND L.LocationCategory IN ( 'BAY', 'BAYOUT' )
            ORDER BY bo.BookingDate DESC
            
            IF @n_BookingNo_Shpm = 0--IF @c_CycleLocBayByWave = 'Y' AND @c_LocBay = ''
            BEGIN
               --Next Last use LocBay
                  
               SELECT TOP 1 @c_LocBay = l.LocBay
               FROM dbo.Booking_Out AS bo  (NOLOCK)
               JOIN LOC AS l WITH (NOLOCK) ON bo.Loc = l.loc
               WHERE bo.FACILITY = @c_Facility
               AND l.LocationCategory IN ( 'BAY', 'BAYOUT' )
               ORDER BY bo.BookingDate DESC
              
               --IF @c_LocBay <> ''
               --BEGIN
                  SELECT TOP 1 @c_LocBay = tl.LocBay
                  FROM #TMP_LOC AS tl WITH (NOLOCK)
                  WHERE tl.SubBanner = @c_SubBanner
                  AND   tl.LocBay NOT IN (@c_LocBay)              --Fixed: LFWM-3553
                  ORDER BY tl.RowID 
               --END
            END               

            IF @c_LocBay <> '' 
            BEGIN 
               SET @c_LocBay_Filter = ' AND tl.LocBay = @c_LocBay'
               
               SELECT TOP 1 @n_RowID_Start = tl.RowID - 1
               FROM #TMP_LOC tl
               WHERE tl.LocBay = @c_LocBay 
               ORDER BY tl.RowID
            END
            
            --IF @c_AdjacentLoc4LocBayByWave = 'Y'
            --BEGIN
            --   SET @c_LocBay_Filter = ''
            --END
         END

         IF @c_CycleLocBayByShipmentGroup = 'Y'         --CR 1.8
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '-----------------------------------------------------'  
               PRINT ' @c_CycleLocBayByShipmentGroup = ' + @c_CycleLocBayByShipmentGroup 
               PRINT ' @c_ShipmentGroup: ' + @c_ShipmentGroup                
               PRINT ' @c_ShipmentGroupProfile: ' + @c_ShipmentGroupProfile                   
               PRINT '-----------------------------------------------------'   
            END
            
            SET @c_LocBay_PrevShpGrp = ''
            SELECT TOP 1 @c_LocBay_PrevShpGrp = l.LocBay
            FROM dbo.Booking_Out AS bo WITH (NOLOCK)
            JOIN dbo.TMS_Shipment AS ts WITH (NOLOCK) ON bo.BookingNo = ts.BookingNo
            JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = bo.Loc
            WHERE ts.ShipmentGroupProfile = @c_ShipmentGroupProfile
            AND ts.ShipmentGroup = @c_ShipmentGroup
            AND ts.Wave < @c_ShipmentWave
            AND CONVERT(CHAR(8), bo.BookingDate, 112) = CONVERT(CHAR(8), @dt_EarlyPickupDate, 112)
            ORDER BY bo.BookingDate DESC
            
            IF @c_LocBay_PrevShpGrp <> '' AND @c_LocBay_PrevShpGrp = @c_LocBay
            BEGIN
               SET @c_Errmsg = 'Disallow same shipment group: ' + @c_ShipmentGroup
                             +  ' to book on same LocBay. (lsp_DoorBookAutoBuild_STD)'
                              
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
               VALUES ( @c_TableName, @c_SourceType, @c_DoorBookingStrategyKey, @c_AppointmentID, '', 'MESSAGE', 0, 0, @c_ErrMsg )   
                                             
               CONTINUE       
            END
         END
         
         IF @c_AdjacentLocByShipmentGroup = 'Y'         --CR 1.8
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT '-----------------------------------------------------'  
               PRINT ' @c_AdjacentLocByShipmentGroup = ' + @c_AdjacentLocByShipmentGroup 
               PRINT ' @c_ShipmentGroup: ' + @c_ShipmentGroup                
               PRINT ' @c_ShipmentGroupProfile: ' + @c_ShipmentGroupProfile                   
               PRINT '-----------------------------------------------------'   
            END
            
            SET @c_Loc_PrevShpGrp = ''                         --2022-07-05 Fixed initial correct variable
            SELECT TOP 1 @c_Loc_PrevShpGrp = l.Loc
            FROM dbo.Booking_Out AS bo WITH (NOLOCK)
            JOIN dbo.TMS_Shipment AS ts WITH (NOLOCK) ON bo.BookingNo = ts.BookingNo
            JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = bo.Loc
            WHERE ts.ShipmentGroupProfile = @c_ShipmentGroupProfile
            AND ts.ShipmentGroup = @c_ShipmentGroup
            AND ts.Wave < @c_ShipmentWave
            AND CONVERT(CHAR(8), bo.BookingDate, 112) = CONVERT(CHAR(8), @dt_EarlyPickupDate, 112)
            ORDER BY bo.BookingDate DESC
          
            IF @c_Loc_PrevShpGrp <> ''
            BEGIN 
               SET @c_SQL = N'SELECT TOP 1 @n_RowID_Start = tl.RowId - 1'
                          + ' FROM #TMP_LOC tl'
                          --+ ' WHERE tl.Loc < @c_Loc_PrevShpGrp'                                                                      --2022-07-12 Fix
                          + ' WHERE EXISTS (SELECT 1 FROM #TMP_LOC tl2 WHERE tl2.Loc =  @c_Loc_PrevShpGrp AND tl.RowId < tl2.RowID)'   --2022-07-12 Fix
                          + @c_LocBay_Filter 
                          + ' ORDER BY tl.RowId DESC'
                          
               SET @c_SQLParms= N'@n_RowID_Start      INT   OUTPUT'
                              + ',@c_Loc_PrevShpGrp   NVARCHAR(10)' 
                              + ',@c_LocBay           NVARCHAR(10)' 
                              
               EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@n_RowID_Start   OUTPUT
                           ,@c_Loc_PrevShpGrp
                           ,@c_LocBay   
            END
         END


         IF @b_debug = 1
         BEGIN
            PRINT '-----------------------------------------------------'  
            PRINT ' Start Allocate Door base on Door strategy           ' 
            PRINT '-----------------------------------------------------'
            PRINT '@c_LocBay_Filter: ' + @c_LocBay_Filter 
            PRINT '@c_LocBay: ' + @c_LocBay   
            PRINT '@n_RowID_Start: ' + CAST(@n_RowID_Start AS CHAR)
            PRINT '@n_TotalCasePerAPM: ' + CAST(@n_TotalCasePerAPM AS CHAR) 
         END
            
         TRUNCATE TABLE #TMP_LOC_WIP;

         SET @c_SQL = N'SELECT tl.SubBanner, tl.Loc, tl.LogicalLocation, tl.LocationCategory, tl.LocBay, tl.MaxCarton'
                    + ' FROM #TMP_LOC tl'
                    + ' WHERE tl.RowID > @n_RowID_Start'
                    + @c_LocBay_Filter 
                    + ' ORDER BY tl.RowId'
                          
         SET @c_SQLParms= N'@n_RowID_Start   INT'
                        + ',@c_LocBay        NVARCHAR(10)' 

         INSERT INTO #TMP_LOC_WIP (  SubBanner, Loc, LogicalLocation, LocationCategory, LocBay, MaxCarton )                     
         EXEC sp_ExecuteSQL @c_SQL
                           ,@c_SQLParms
                           ,@n_RowID_Start
                           ,@c_LocBay

         SET @n_RowID_Start = 0
         SELECT TOP 1 @n_RowID_Start = tlw.RowId 
         FROM #TMP_LOC_WIP AS tlw
         ORDER BY tlw.RowId

                     
         SET @n_RowID_End = 0   

         TRUNCATE TABLE #TMP_BOOKLOC;  
         WHILE @n_RowID_Start > 0 AND @n_Continue IN (1,2)
         BEGIN
            --2022-07-15 Enhance - START
            IF @c_DoorLimitByCase = 'Y' AND @n_TotalCasePerAPM = 0 -- Continue Next Shipment
            BEGIN
               BREAK
            END
            --2022-07-15 Enhance - END   
            --Get End Loc
            --CR 1.8
            SET @n_RowID_End = 0
            SELECT TOP 1 @n_RowID_End = tlw.RowID 
            FROM #TMP_LOC_WIP AS tlw WITH (NOLOCK)
            WHERE tlw.RowID >= @n_RowID_Start
            ORDER BY tlw.RowID

            IF @b_debug = 1
            BEGIN
               --SELECT @c_DoorBookingStrategyKey'@c_DoorBookingStrategyKey', @c_AppointmentID '@c_AppointmentID'
               --     , @n_RowID_Start '@n_RowID_Start',@n_RowID_End '@n_RowID_End',* 
               --FROM #TMP_LOC_WIP AS tlw WITH (NOLOCK)
               --WHERE tlw.RowID BETWEEN @n_RowID_Start AND @n_RowID_End
               
               PRINT  ' @n_RowID_Start: ' + CAST(@n_RowID_Start AS NVARCHAR(3))
                  +  ', @n_RowID_End: ' + CAST(@n_RowID_End AS NVARCHAR(3))

            END

            IF @n_RowID_End = 0
            BEGIN
               BREAK
            END

            ;WITH dbook AS 
            (  SELECT bo.BookingNo
                    , d.loc
                    , trucktimebooked = CASE WHEN @dt_EarlyPickupDate BETWEEN bo.BookingDate AND bo.EndTime THEN 1
                                             WHEN bo.BookingDate BETWEEN @dt_EarlyPickupDate AND @dt_PickupEndTime THEN 1 
                                             ELSE 0
                                             END
               FROM dbo.Booking_Out AS bo WITH (NOLOCK) 
               OUTER APPLY dbo.Fnc_GetBookingDoor(bo.facility,bo.loc, bo.toloc,'','O') d
               WHERE bo.Facility = @c_Facility
               AND bo.[status] NOT IN ('CANC', '9')
            )
            , blkl AS
             ( SELECT bbs.Blockslotkey
                    , bbs.loc
                    , trucktimebooked = CASE WHEN CONVERT(NVARCHAR(10), @dt_EarlyPickupDate, 112) BETWEEN bbs.FromDate AND ISNULL(bbs.FromTime,bbs.FromDate) AND
                                                  SUBSTRING(CONVERT(NVARCHAR(25), @dt_EarlyPickupDate,121),12,12) BETWEEN SUBSTRING(CONVERT(NVARCHAR(25), bbs.ToTime ,121),12,12) AND 
                                                  SUBSTRING(CONVERT(NVARCHAR(25), bbs.FromTime ,121),12,12)      
                                             THEN 1
                                             WHEN  CONVERT(NVARCHAR(10), @dt_PickupEndTime,112) BETWEEN bbs.FromDate AND ISNULL(bbs.FromTime,bbs.FromDate) AND
                                                  SUBSTRING(CONVERT(NVARCHAR(25), @dt_PickupEndTime,121),12,12) BETWEEN SUBSTRING(CONVERT(NVARCHAR(25), bbs.ToTime ,121),12,12) AND 
                                                  SUBSTRING(CONVERT(NVARCHAR(25), bbs.FromTime ,121),12,12)      
                                             THEN 1
                                             ELSE 0
                                             END
               FROM dbo.Booking_BlockSlot AS bbs WITH (NOLOCK) 
               WHERE bbs.Facility = @c_Facility
               AND bbs.loc <> '' AND bbs.Loc IS NOT NULL
            )
            
            INSERT INTO #TMP_BOOKLOC ( RowID_Loc, SubBanner, Loc, LogicalLocation, LocationCategory, LocBay, MaxCarton, BookingNo, Blockslotkey )
            SELECT  tlw.RowID, tlw.SubBanner, tlw.Loc, tlw.LogicalLocation, tlw.LocationCategory, tlw.LocBay, tlw.MaxCarton
                  , BookingNo = ISNULL(dbook.BookingNo,'')
                  , Blockslotkey = ISNULL(blkl.Blockslotkey, '')
            FROM #TMP_LOC_WIP AS tlw WITH (NOLOCK)
            LEFT OUTER JOIN dbook ON dbook.Loc = tlw.Loc AND dbook.trucktimebooked = 1
            LEFT OUTER JOIN blkl  ON blkl.Loc = tlw.Loc
                                  AND blkl.trucktimebooked = 1
            WHERE tlw.RowID BETWEEN @n_RowID_Start AND @n_RowID_End
            
            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END
            
            IF @b_debug = 1
            BEGIN
               PRINT  ' Total Book Loc: ' + CAST(@@ROWCOUNT AS NVARCHAR(3))
               --SELECT @c_DoorBookingStrategyKey'@c_DoorBookingStrategyKey', @c_AppointmentID '@c_AppointmentID',* FROM #TMP_BOOKLOC 
            END

          
            --SET @n_RowID_Start = 0
            --SELECT TOP 1 @n_RowID_Start = tb.RowID 
            --FROM #TMP_BOOKLOC AS tb WITH (NOLOCK)
            --JOIN #TMP_BOOKLOC AS tb2 WITH (NOLOCK) ON tb.Rowid >= tb2.RowID   
            --GROUP BY tb.RowID 
            --HAVING COUNT(DISTINCT tb2.SubBanner) > 1
            --ORDER BY tb.RowID DESC
            
            --IF @n_RowID_Start > 0
            --BEGIN
            --   IF @b_debug = 1
            --   BEGIN
            --      PRINT 'Found Mix SubBanned at #TMP_BOOKLOC.RowID: ' + CAST(@n_RowID_Start AS NVARCHAR(3))
            --   END

            --   SET @n_RowID_Start = @n_RowID_Start + 1
            --   CONTINUE
            --END

            SET @n_RowID_Start = 0
            SELECT TOP 1 @n_RowID_Start = tlw.RowID
            FROM #TMP_LOC_WIP AS tlw
            WHERE tlw.RowID > @n_RowID_END
            ORDER BY tlw.RowID
         END   

   
         IF @b_debug = 1
         BEGIN
            SET @n_RowID_Start = 0
            SELECT TOP 1 @n_RowID_Start = tb.RowID 
            FROM #TMP_BOOKLOC AS tb  WITH (NOLOCK)
            WHERE (tb.BookingNo <> 0 OR tb.BlockSlotKey <> '')
           
            IF @n_RowID_Start > 0
            BEGIN
               PRINT  'Found BlockSlotKey or Booking # at ##TMP_BOOKLOC.RowID: ' + CAST(@n_RowID_Start AS NVARCHAR(3))
            END
            SET @n_RowID_Start = 0
         END 
                  
         SET @c_Loc = '' 
         SET @c_ToLoc = ''
         
         IF @c_DoorLimitByCase = 'N'                           --2022-07-12 Only calculate door if totalcaseperAPM > 0. No door to be booked if shipment not allocated
         BEGIN
            SELECT TOP 1 @c_Loc = tb.Loc
                        ,@c_ToLoc = tb.Loc
            FROM #TMP_BOOKLOC AS tb 
            WHERE tb.BookingNo = 0 AND tb.BlockSlotKey = ''           
            ORDER BY tb.RowID ASC
         END
         ELSE IF @n_TotalCasePerAPM > 0                        --2022-07-12 Only calculate door if totalcaseperAPM > 0. No door to be booked if shipment not allocated
         BEGIN
            -- Find from Same Sub Banner torward Hierarchy Loc
            --2022-07-20 - Fix - START
            SET @b_FindAvailableFromLastBlock = 0

            SET @n_RowID_lastblock = 0
            SELECT TOP 1 @c_Loc = tb.Loc 
            , @n_RowID_lastblock = tb.RowID - 1                                                 
            FROM #TMP_BOOKLOC AS tb
            WHERE (tb.BookingNo = 0 AND tb.BlockSlotKey = '')                                    
            ORDER BY tb.RowID  

            SET @n_RowID_lastLoc = 0
            SELECT TOP 1 @n_RowID_lastLoc = tb.RowID - 1                                         
            FROM #TMP_BOOKLOC AS tb  
            WHERE tb.RowID > @n_RowID_lastblock 
            AND (tb.BookingNo <> 0 OR tb.BlockSlotKey <> '')  
            ORDER BY tb.RowID 

            IF @n_RowID_lastLoc = 0
            BEGIN
               SELECT TOP 1 @n_RowID_lastLoc = tb.RowID - 1                                        
               FROM #TMP_BOOKLOC AS tb  
               ORDER BY tb.RowID DESC
            END
            --2022-07-20 - Fix - END   
              
            FIND_AVAILABLE_LOC:                                                                    --2022-07-20 Fix                
            IF @c_Loc <> ''
            BEGIN
               ;WITH tl AS
               (  
                  SELECT TOP 1 tb.RowID_Loc  
                  FROM #TMP_BOOKLOC AS tb   
                  JOIN #TMP_BOOKLOC AS tb2 ON tb.RowID_Loc >= tb2.RowID_Loc 
                  WHERE tb.RowID > @n_RowID_lastblock AND tb.RowID <= @n_RowID_lastLoc             --2022-07-15 Fix
                  AND tb2.RowID > @n_RowID_lastblock AND tb.RowID <= @n_RowID_lastLoc              --2022-07-15 Fix
                  GROUP BY tb.RowID_Loc  
                  HAVING @n_TotalCasePerAPM BETWEEN 1 AND SUM(tb2.MaxCarton)  
                  ORDER BY tb.RowID_Loc                
                  
               )
               SELECT TOP 1 @c_ToLoc = tb.loc
               FROM tl
               JOIN #TMP_BOOKLOC AS tb ON tb.RowID_Loc = tl.RowID_Loc
            END
            --2022-07-07 - Fix - END
            
            --CR 2.2
            IF @c_Loc <> '' AND @c_ToLoc <> ''
            BEGIN 
               IF EXISTS ( SELECT 1 FROM #TMP_BOOKLOC AS tb
                           WHERE tb.Loc BETWEEN @c_Loc AND @c_ToLoc
                           HAVING SUM(tb.MaxCarton) < @n_TotalCasePerAPM
               )
               BEGIN
                  SET @c_Loc = '' 
                  SET @c_ToLoc = ''                
               END
            END 
            
            --2022-07-20 - FIX START
            IF @c_Loc = '' AND @c_ToLoc = '' AND @b_FindAvailableFromLastBlock = 0 
            BEGIN
               SET @n_RowID_lastblock = 0                        
               SELECT TOP 1 @n_RowID_lastblock = tb.RowID  
               FROM #TMP_BOOKLOC AS tb   
               WHERE (tb.BookingNo <> 0 OR tb.BlockSlotKey <> '')              
               ORDER BY tb.RowID DESC  
              
               IF @n_RowID_lastblock = 0  
               BEGIN  
                  SELECT TOP 1 @c_Loc = tb.Loc  
                  FROM #TMP_BOOKLOC AS tb  
                  ORDER BY tb.RowID  
               END   
               ELSE  
               BEGIN  
                  SELECT TOP 1 @c_Loc = tb.Loc  
                  FROM #TMP_BOOKLOC AS tb  
                  WHERE tb.RowID > @n_RowID_lastblock  
                  ORDER BY tb.RowID  
               END   

               SET @n_RowID_lastLoc = @n_RowID_lastblock                                           --2022-07-18 
               SELECT TOP 1 @n_RowID_lastLoc = tb.RowID                                            --2022-07-15 Fix 
               FROM #TMP_BOOKLOC AS tb  
               WHERE tb.RowID > @n_RowID_lastblock  
               ORDER BY tb.RowID DESC

               SET @b_FindAvailableFromLastBlock = 1
               GOTO FIND_AVAILABLE_LOC
            END
            --2022-07-20 - FIX END
            
            ----2022-07-18 - FIX START
            IF @c_Loc <> '' AND @c_ToLoc <> '' AND @c_ToLoc < @c_Loc
            BEGIN
               SET @c_Loc = '' 
               SET @c_ToLoc = '' 
            END
            --2022-07-18 - FIX END
         END
          
         IF @b_debug = 1
         BEGIN
            PRINT  '@c_Loc: ' + @c_Loc
                +', @c_ToLoc: ' + @c_ToLoc
         END
             
         IF @c_Loc <> '' AND @c_ToLoc <> ''
         BEGIN
            EXEC dbo.nspg_GetKey
                 @KeyName = N'BookingNo'
               , @fieldlength = 10            
               , @keystring = @c_BookingNo     OUTPUT
               , @b_Success = @b_Success       OUTPUT
               , @n_err     = @n_err           OUTPUT       
               , @c_errmsg  = @c_errmsg        OUTPUT
                
            IF @b_Success = 0
            BEGIN
               CONTINUE
            END

            IF @b_debug = 1
            BEGIN
               PRINT  'Create Booking #: ' + @c_BookingNo
            END
         
            SET @n_BookingNo = CONVERT(INT, @c_BookingNo)
            --Generate Booking_out
            INSERT INTO dbo.Booking_Out
                (
                    BookingNo,
                    RouteAuth,
                    Facility,
                    BookingDate,
                    EndTime,
                    Duration,
                    Loc,
                    Type,
                    SCAC,
                    DriverName,
                    LicenseNo,
                    LoadKey,
                    MbolKey,
                    CBOLKey,
                    Status,
                    ALTReference,
                    VehicleContainer,
                    UserDefine01,
                    UserDefine02,
                    UserDefine03,
                    UserDefine04,
                    UserDefine05,
                    UserDefine06,
                    UserDefine07,
                    UserDefine08,
                    UserDefine09,
                    UserDefine10,
                    ArrivedTime,
                    SignInTime,
                    UnloadTime,
                    DepartTime,
                    CallTime,
                    Loc2,
                    VehicleType,
                    Carrierkey,
                    FinalizeFlag,
                    ToLoc,
                    Banner,
                    SubBanner,
                    Wave,
                    ShipmentGroupProfile,
                    ShipmentGroup
                )
            VALUES
                (
                    @n_BookingNo,            -- BookingNo - int
                    @c_Route,                -- RouteAuth - nvarchar(30)
                    @c_Facility,             -- Facility - nvarchar(5)
                    @dt_EarlyPickupDate,     -- BookingDate - datetime
                    @dt_PickupEndTime,       -- EndTime - datetime
                    @dt_Duration,            -- Duration - datetime
                    @c_Loc,                  -- Loc - nvarchar(10)
                    N'',            -- Type - nvarchar(10)
                    N'',                     -- SCAC - nvarchar(10)
                    @c_DriverName,           -- DriverName - nvarchar(30)
                    @c_VehicleLPN,           -- LicenseNo - nvarchar(20)
                    N'',                     -- LoadKey - nvarchar(10)
                    N'',                     -- MbolKey - nvarchar(10)
                    0,                       -- CBOLKey - int
                    N'0',                    -- Status - nvarchar(10)
                    @c_AppointmentID,        -- ALTReference - nvarchar(30)
                    N'',                     -- VehicleContainer - nvarchar(30)
                    N'',                     -- UserDefine01 - nvarchar(20)
                    N'',                     -- UserDefine02 - nvarchar(20)
                    N'',                     -- UserDefine03 - nvarchar(20)
                    N'',                     -- UserDefine04 - nvarchar(20)
                    N'',                     -- UserDefine05 - nvarchar(20)
                    GETDATE(),               -- UserDefine06 - datetime
                    GETDATE(),               -- UserDefine07 - datetime
                    N'',                     -- UserDefine08 - nvarchar(10)
                    N'',                     -- UserDefine09 - nvarchar(10)
                    N'',                     -- UserDefine10 - nvarchar(10)
                    GETDATE(),               -- ArrivedTime - datetime
                    GETDATE(),               -- SignInTime - datetime
                    GETDATE(),               -- UnloadTime - datetime
                    GETDATE(),               -- DepartTime - datetime
                    @dt_calltime,            -- CallTime - datetime              --CR 2.0
                    N'',                     -- Loc2 - nvarchar(10)
                    @c_VehicleType,          -- VehicleType - nvarchar(20)
                    @c_ServiceProviderID,    -- Carrierkey - nvarchar(18)
                    N'N',                    -- FinalizeFlag - nvarchar(1)
                    @c_ToLoc,                -- ToLoc - nvarchar(10)
                    N'',                     -- Banner - nvarchar(100)
                    @c_SubBanner,            -- SubBanner - nvarchar(100)
                    @c_ShipmentWave,         -- Wave - nvarchar(20)
                    @c_ShipmentGroupProfile, -- ShipmentGroupProfile - nvarchar(100)
                    @c_ShipmentGroup         -- ShipmentGroup - nvarchar(100)
                )
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 560601
               SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Insert Into Booking_Out Fail. (lsp_DoorBookAutoBuild_STD)'
                              + '( ' + ERROR_MESSAGE() + ' )'
                              
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
               VALUES ( @c_TableName, @c_SourceType, @c_DoorBookingStrategyKey, @c_AppointmentID, '', 'ERROR', 0, @n_Err, @c_ErrMsg )                              
               BREAK              
            END 
           
            IF @b_debug = 1
            BEGIN
               PRINT  'Insert into Booking_Vehicle: ' + @c_BookingNo
            END
            
            INSERT INTO dbo.BookingVehicle
                (
                    BookingNo,
                    BookingType,
                    SCAC,
                    DriverName,
                    LicenseNo,
                    VehicleContainer,
                    VehicleType,
                    Carrierkey
                )
            VALUES
                (
                    @n_BookingNo,            -- BookingNo - int
                    N'',                     -- Type - nvarchar(10)
                    N'',                     -- SCAC - nvarchar(10)
                    @c_DriverName,           -- DriverName - nvarchar(30)
                    @c_VehicleLPN,           -- LicenseNo - nvarchar(20)
                    N'',                     -- VehicleContainer - nvarchar(30)
                    @c_VehicleType,          -- VehicleType - nvarchar(20)
                    @c_ServiceProviderID      -- Carrierkey - nvarchar(18)
                )
                
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 560602
               SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Insert into BookingVehicle Fail. (lsp_DoorBookAutoBuild_STD)'
                              + '( ' + ERROR_MESSAGE() + ' )'
                              
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
               VALUES ( @c_TableName, @c_SourceType, @c_DoorBookingStrategyKey, @c_AppointmentID, '', 'ERROR', 0, @n_Err, @c_ErrMsg )                              
               BREAK              
            END 
            
            IF @b_debug = 1
            BEGIN
               PRINT  'Update Booking # to TMS_Shipment - @c_AppointmentID: ' + @c_AppointmentID
            END
            
         END

         NEXT_SHIPMENT:
         SET @c_Message = 'No Door available for booking'  
                   
         IF @n_BookingNo > 0
         BEGIN
            UPDATE TMS_Shipment
            SET
                 BookingNo = @n_BookingNo
               , Editwho = SUSER_SNAME()
               , EditDate= GETDATE()
            WHERE Rowref >= @n_RowRef_Shpm
            AND AppointmentID = @c_AppointmentID
            
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 560603
               SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Update TMS_Shipment Fail. (lsp_DoorBookAutoBuild_STD)'
                              + '( ' + ERROR_MESSAGE() + ' )'
                              
               INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
               VALUES ( @c_TableName, @c_SourceType, @c_DoorBookingStrategyKey, @c_AppointmentID, '', 'ERROR', 0, @n_Err, @c_ErrMsg )
  
               BREAK              
            END
         
            IF @c_Loc <> '' 
            BEGIN
               SET @c_Message = IIF(@c_Loc = @c_ToLoc, 'Door is' , 'Doors are') + ' booked for shipment.'
            END
         END
         
         INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
         VALUES ( @c_TableName, @c_SourceType, @c_DoorBookingStrategyKey, @c_AppointmentID, '', 'MESSAGE', 0, 0, @c_Message )
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @n_Err = 0
      SET @c_ErrMsg   = ERROR_MESSAGE() 
      
      INSERT INTO @t_WMSErrorList (TableName, SourceType, Refkey1, Refkey2, Refkey3, WriteType, LogWarningNo, ErrCode, ErrMsg)           
      VALUES ( @c_TableName, @c_SourceType, @c_DoorBookingStrategyKey, '', '', 'ERROR', 0, @n_Err, @c_ErrMsg )
   END CATCH
   
   EXIT_SP:
   
   IF (XACT_STATE()) = -1                                      
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 
  
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt       
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_DoorBookAutoBuild_STD'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   SET @CUR_ERRLIST = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT   twl.TableName           
         ,  twl.SourceType          
         ,  twl.Refkey1             
         ,  twl.Refkey2             
         ,  twl.Refkey3             
         ,  twl.WriteType           
         ,  twl.LogWarningNo        
         ,  twl.ErrCode             
         ,  twl.Errmsg                 
   FROM @t_WMSErrorList AS twl  
   ORDER BY twl.RowID  
     
   OPEN @CUR_ERRLIST  
     
   FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName           
                                     , @c_SourceType          
                                     , @c_Refkey1             
                                     , @c_Refkey2             
                                     , @c_Refkey3             
                                     , @c_WriteType           
                                     , @n_LogWarningNo        
                                     , @n_Err             
                                     , @c_Errmsg              
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      EXEC [WM].[lsp_WriteError_List]   
         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT   
      ,  @c_TableName   = @c_TableName  
      ,  @c_SourceType  = @c_SourceType  
      ,  @c_Refkey1     = @c_Refkey1  
      ,  @c_Refkey2     = @c_Refkey2  
      ,  @c_Refkey3     = @c_Refkey3  
      ,  @n_LogWarningNo= @n_LogWarningNo  
      ,  @c_WriteType   = @c_WriteType  
      ,  @n_err2        = @n_err   
      ,  @c_errmsg2     = @c_errmsg   
      ,  @b_Success     = @b_Success      
      ,  @n_err         = @n_err          
      ,  @c_errmsg      = @c_errmsg           
       
      FETCH NEXT FROM @CUR_ERRLIST INTO   @c_TableName           
                                        , @c_SourceType          
                                        , @c_Refkey1             
                                        , @c_Refkey2             
                                        , @c_Refkey3             
                                        , @c_WriteType           
                                        , @n_LogWarningNo        
                                        , @n_Err             
                                        , @c_Errmsg       
   END  
   CLOSE @CUR_ERRLIST  
   DEALLOCATE @CUR_ERRLIST 
    
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
         
   REVERT
END

GO