SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetBookingOut_Display2                              */
/* Creation Date: 01-FEB-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-918 - WMS Door Booking Dashboard Enhancement            */
/*        :                                                             */
/* Called By: d_dw_booking_dashboard_out_dsp2                           */
/*          :                                                           */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 14-MAR-2017 Wan01    1.1   Fixed Order_Status                        */
/* 22-MAR-2017 TLTING   1.2   foce Commit tran -                        */
/* 17-SEP-2020 WLChooi  1.3   WMS-15141 - Add new columns, extra remark */
/*                            and status (WL01)                         */
/* 18-MAR-2022 Shong    1.4   Add New Column for Dashboard (SWT01)      */
/* 22-MAR-2022 WLChooi  1.5   DevOps Combine Script                     */
/* 22-MAR-2022 WLChooi  1.5   WMS-19286 Grant EXEC to JReportRole (WL02)*/
/* 08-Jul-2022 WLChooi  1.6   WMS-20181 Use Codelkup to store Truck     */
/*                            Status & Revise table linkage (WL03)      */
/************************************************************************/
CREATE PROC [dbo].[isp_GetBookingOut_Display2]
      (  @c_Facility          NVARCHAR(5)
      ,  @c_Storerkey         NVARCHAR(15)
      ,  @c_Door              NVARCHAR(10)
      ,  @dt_StartLoadDate    DATETIME
      ,  @dt_EndLoadDate      DATETIME
      ,  @n_DB_HeaderID       INT = 0 -- (SWT01)
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

         ,  @c_Ref         NVARCHAR(30) = ''   --WL03

   SET @n_starttcnt=@@TRANCOUNT

   SET @n_RowPerPage = 20

   CREATE TABLE #TMP_DSP2
      (  RowNo                INT            IDENTITY(1,1)  NOT NULL PRIMARY KEY
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
      ,  BKO_Status           NVARCHAR(10)   NULL
      ,  MBOLKey              NVARCHAR(10)   NULL   --WL01
      ,  CallTime             DATETIME       NULL   --WL01
      )

   --WL03 S
   CREATE TABLE #TMP_BKTRSTATUS (
      [Status]                NVARCHAR(10)
    , Status_DESCR            NVARCHAR(50)      
   )

   CREATE TABLE #TMP_BOOKINGNO (
      BookingNo               INT
    , Loadkey                 NVARCHAR(10)
    , [Status]                NVARCHAR(10)
    , ProcessFlag             NVARCHAR(50)
   )
   --WL03 E

   IF ISNULL(RTRIM(@c_Facility),'') = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_SQLWhere = N' WHERE BKO.Facility = N''' + RTRIM(@c_Facility) + ''''
   SET @c_STRWhere = ''

   IF ISNULL(RTRIM(@c_Storerkey),'') <> ''
   BEGIN
      SET @c_STRWhere = @c_STRWhere + N' AND Storerkey = N''' + RTRIM(@c_Storerkey) + ''''
   END

   IF ISNULL(RTRIM(@c_Door),'') <> ''
   BEGIN
      SET @c_SQLWhere = @c_SQLWhere
                      + N' AND EXISTS ( SELECT 1'
                      +              ' FROM dbo.fnc_GetBookingDoor(BKO.Facility, BKO.Loc, BKO.ToLoc, BKO.Loc2, ''O'') DOOR'
                      +              ' WHERE DOOR.Loc = N''' +  RTRIM(@c_Door) + ''' )'
   END

   IF ISNULL(@dt_StartLoadDate,'1900-01-01') <> '1900-01-01'
   BEGIN
      SET @c_SQLWhere =  @c_SQLWhere
                      + N' AND BKO.BookingDate >= N''' + CONVERT(NVARCHAR(20), @dt_StartLoadDate, 120) + ''''
   END

   IF ISNULL(@dt_EndLoadDate,'1900-01-01') <> '1900-01-01'
   BEGIN
      SET @c_SQLWhere =  @c_SQLWhere
                      + N' AND BKO.EndTime <= N''' + CONVERT(NVARCHAR(20), @dt_EndLoadDate, 120) + ''''
   END

   SET @c_SQLWhere = @c_SQLWhere + N' AND (BKO.Status <> ''9'' OR LP.Status <> ''9'')'

   --START
   SET @c_SQLSTR = N'DECLARE CUR_STR CURSOR FAST_FORWARD READ_ONLY FOR'
                 + ' SELECT RTRIM(STORER.Storerkey)'
                 + ' FROM   STORER WITH (NOLOCK)'
                 + ' WHERE  STORER.Type = ''1'''
                 + @c_STRWhere
                 + ' ORDER BY STORER.SUSR2'

   EXEC (@c_SQLSTR)

   OPEN CUR_STR

   FETCH NEXT FROM CUR_STR INTO @c_Storerkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --WL03 S
      INSERT INTO #TMP_BKTRSTATUS ([Status], Status_DESCR)
      SELECT DISTINCT CL.Code, CL.[Description]
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'BKTRSTATUS'
      AND CL.Storerkey = @c_Storerkey

      IF NOT EXISTS (SELECT 1 FROM #TMP_BKTRSTATUS)
      BEGIN
         INSERT INTO #TMP_BKTRSTATUS ([Status], Status_DESCR)
         SELECT '0','Normal'  UNION ALL
         SELECT '1','Arrived' UNION ALL
         SELECT '2','Loading' UNION ALL
         SELECT '3','Loaded'  UNION ALL
         SELECT '9','Departed'
      END

      --WMS Exceed
      SET @c_SQL = ' SELECT BKO.BookingNo, MIN(LP.Loadkey), MIN(LP.[Status]), MIN(LP.ProcessFlag)'
                 + ' FROM BOOKING_OUT BKO WITH (NOLOCK)'
                 + ' JOIN LOADPLAN    LP  WITH (NOLOCK) ON (BKO.BookingNo = LP.BookingNo)'
                 + ' JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Loadkey = LP.Loadkey)'
                 + ' JOIN ORDERS      OH  WITH (NOLOCK) ON (OH.Orderkey = LPD.Orderkey)'
                 + ' JOIN FACILITY    FAC WITH (NOLOCK) ON (BKO.Facility = FAC.Facility)'
                 + ' ' + @c_SQLWhere
                 + ' AND OH.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''
                 + ' GROUP BY BKO.BookingNo'

      INSERT INTO #TMP_BOOKINGNO (BookingNo, Loadkey, [Status], ProcessFlag)
      EXEC ( @c_SQL )

      --SCE WM
      SELECT @c_Ref = CODELKUP.UDF01
      FROM CODELKUP (NOLOCK) 
      WHERE LISTNAME = 'LOGILPNREF'
      AND Storerkey = @c_Storerkey

      IF NOT EXISTS (SELECT COUNT(COLUMN_NAME) FROM INFORMATION_SCHEMA.COLUMNS
                     WHERE TABLE_NAME = 'LOADPLAN' AND DATA_TYPE = 'NVARCHAR' AND COLUMN_NAME = @c_Ref)
      BEGIN
         SET @c_Ref = 'Loadkey'
      END
      ELSE IF ISNULL(@c_Ref,'') = ''
      BEGIN
         SET @c_Ref = 'Loadkey'
      END

      SET @c_SQL = ' SELECT BKO.BookingNo, MIN(LP.Loadkey), MIN(LP.[Status]), MIN(LP.ProcessFlag)'
                 + ' FROM BOOKING_OUT BKO WITH (NOLOCK)'
                 + ' JOIN TMS_Shipment TMS WITH (NOLOCK) ON (BKO.BookingNo = TMS.BookingNo)'
                 + ' JOIN LOADPLAN LP  WITH (NOLOCK) ON (LP.' + @c_Ref + ' = TMS.ShipmentGID)'
                 + ' JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.Loadkey = LP.Loadkey)'
                 + ' JOIN ORDERS OH WITH (NOLOCK) ON (OH.Orderkey = LPD.Orderkey)'
                 + ' JOIN FACILITY    FAC WITH (NOLOCK) ON (BKO.Facility = FAC.Facility)'
                 + ' ' + @c_SQLWhere 
                 + ' AND BKO.BookingNo NOT IN (SELECT DISTINCT BookingNo FROM #TMP_BOOKINGNO) '
                 + ' AND OH.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''
                 + ' GROUP BY BKO.BookingNo'

      INSERT INTO #TMP_BOOKINGNO (BookingNo, Loadkey, [Status], ProcessFlag)
      EXEC ( @c_SQL )
      --WL03 E

      SET @c_SQL = N'SELECT DISTINCT'
                + '  BKO.Facility'
                + ' ,Storerkey = RTRIM(OH.Storerkey)'
                + ' ,BKO.BookingNo'
                + ' ,BKO.BookingDate'
                + ' ,BKO.EndTime'
                + ' ,Loc  = ISNULL(RTRIM(BKO.Loc),'''')'
                + ' ,ToLoc= ISNULL(RTRIM(BKO.ToLoc),'''')'
                + ' ,Loc2 = ISNULL(RTRIM(BKO.Loc2),'''')'
                + ' ,VehicleType= ISNULL(RTRIM(BKO.VehicleType),'''')'
                + ' ,Truck_Name = ISNULL(RTRIM(BKO.LicenseNo),'''') + ''/''+ ISNULL(RTRIM(BKO.Carrierkey),'''')'
                --+ ' ,Truck_Status = CASE WHEN BKO.Status = ''0'' THEN ''Normal'''   --WL03 S
                --+                      ' WHEN BKO.Status = ''1'' THEN ''Arrived'''
                --+                      ' WHEN BKO.Status = ''2'' THEN ''Loading'''
                --+                      ' WHEN BKO.Status = ''3'' THEN ''Loaded'''
                --+                      ' WHEN BKO.Status = ''9'' THEN ''Departed'''
                --+                      ' END'
                + ' ,Truck_Status = BTS.Status_DESCR '   --WL03 E
                + ' ,Order_Status = (SELECT MIN(CASE WHEN LPN.Status = ''0'' THEN ''0-Allocated'''
                +                      ' WHEN LPN.Status < ''5'' AND LPN.ProcessFlag = ''Y'' THEN ''3-Picking'''
                +                      ' WHEN LPN.Status < ''3'' THEN ''0-Allocated'''
                +                      ' WHEN LPN.Status = ''3'' THEN ''3-Picking'''
                +                      ' WHEN LPN.Status = ''5'' THEN ''5-Picked'''
                +                      ' WHEN LPN.Status = ''9'' THEN ''9-Shipped'''
                +                      ' END) FROM #TMP_BOOKINGNO LPN WITH (NOLOCK) WHERE LPN.BookingNo = BKO.BookingNo)'   --WL03
                + ' ,Remarks = CASE WHEN BKO.Status = ''2'' AND GETDATE() > BKO.EndTime'
                +                 ' THEN ''Extended Loading'''
                +                 ' WHEN ISNUMERIC(FAC.USERDEFINE07) = 1 AND BKO.Status = ''0'' AND GETDATE() > DATEADD(hour, CONVERT(INT, FAC.USERDEFINE07), BKO.BookingDate)'
                +                 ' THEN ''Late Arrival'''
                +                 ' WHEN ISNUMERIC(FAC.USERDEFINE07) = 0 AND BKO.Status = ''0'' AND GETDATE() > DATEADD(hour, 0, BKO.BookingDate)'
                +                 ' THEN ''Late Arrival'''
                +                 ' WHEN ISNUMERIC(FAC.USERDEFINE07) = 1 AND BKO.Status = ''1'' AND GETDATE() > DATEADD(hour, CONVERT(INT, FAC.USERDEFINE07), BKO.BookingDate)'
                +                 ' THEN ''Late For Loading'''
                +                 ' WHEN ISNUMERIC(FAC.USERDEFINE07) = 0 AND BKO.Status = ''1'' AND GETDATE() > DATEADD(hour, 0, BKO.BookingDate)'
                +                 ' THEN ''Late For Loading'''
                +                 ' WHEN ISNULL(CL.Short,''N'') = ''Y'' AND BKO.Status = ''9'' AND BKO.CallTime > BKO.EndTime'   --WL01
                +                 ' THEN ''Early Departure'''   --WL01
                +                 ' ELSE '''''
                +                 ' END'
                + ' ,BKO.Status'
                + ' ,BKO.MBOLKey '    --WL01
                + ' ,BKO.CallTime '   --WL01
                + ' FROM BOOKING_OUT BKO WITH (NOLOCK)'
                --WL03 S
                --+ ' JOIN LOADPLAN    LP  WITH (NOLOCK) ON (BKO.BookingNo = LP.BookingNo)'
                --+ ' JOIN ORDERS      OH  WITH (NOLOCK) ON (LP.Loadkey = OH.Loadkey)'
                + ' JOIN #TMP_BOOKINGNO TBKO  WITH (NOLOCK) ON (BKO.BookingNo = TBKO.BookingNo)'
                + ' JOIN LOADPLANDETAIL LPD   WITH (NOLOCK) ON (LPD.Loadkey = TBKO.Loadkey)'
                + ' JOIN LOADPLAN LP WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)'
                + ' JOIN ORDERS      OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)'
                --WL03 E
                + ' JOIN FACILITY    FAC WITH (NOLOCK) ON (BKO.Facility = FAC.Facility)'
                + ' LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.Listname = ''DBoardCFG'' AND CL.Code = ''ExtraRemark'' AND (CL.Code2 = OH.Facility OR CL.Code2 = '''') '   --WL01
                + '                                         AND CL.Long = ''d_dw_booking_dashboard_out_dsp2'' ) '   --WL01
                + ' LEFT JOIN #TMP_BKTRSTATUS BTS ON (BTS.Status = BKO.Status) '   --WL03
                + ' ' + @c_SQLWhere
                + ' AND OH.Storerkey = N''' + RTRIM(@c_Storerkey) + ''''
                + ' ORDER BY BKO.Facility'
                +       ' ,  RTRIM(OH.Storerkey)'
                +       ' ,  BKO.BookingDate'

      INSERT INTO #TMP_DSP2 ( Facility, Storerkey, BookingNo, BookingDate, EndTime, Loc, ToLoc, Loc2
                            , VehicleType, Truck_Name, Truck_Status, Order_Status, Remarks, BKO_Status
                            , MBOLKey, CallTime   --WL01
                            )
      EXEC ( @c_SQL )

      --WL01 START
      DECLARE @c_MBOLKey       NVARCHAR(10)
            , @c_OrderStatus   NVARCHAR(50) = ''
            , @c_TruckStatus   NVARCHAR(50) = ''
            , @n_CountCaseID   INT = 0
            , @n_CountURNNo    INT = 0
            , @c_ExtraStatus   NVARCHAR(10) = 'N'

      SELECT @c_ExtraStatus = ISNULL(CL.Short,'N')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.LISTNAME = 'DBoardCFG'
      AND CL.Code = 'ExtraStatus'
      AND CL.Storerkey = @c_Storerkey
      AND CL.Long = 'd_dw_booking_dashboard_out_dsp2'
      AND (CL.code2 = @c_Facility OR CL.code2 = '')
      ORDER BY CASE WHEN ISNULL(CL.code2,'') = '' THEN 2 ELSE 1 END

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT MBOLKey
      FROM #TMP_DSP2
      WHERE ISNULL(MBOLKey,'') <> '' AND @c_ExtraStatus = 'Y'

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_MBOLKey

      WHILE @@FETCH_STATUS <> - 1
      BEGIN
      	SET @c_OrderStatus = ''
      	SET @c_TruckStatus = ''

      	--Order Status
      	SELECT @c_OrderStatus = CASE WHEN MAX(LOC.LocationCategory) <> 'Staging' THEN ''
      		                         WHEN ISNULL(MAX(LOC.LocationCategory),'') = '' THEN ''
      		                         ELSE 'Staged' END
      	FROM PICKDETAIL (NOLOCK)
      	JOIN ORDERS (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
      	JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.Loc
      	WHERE ORDERS.MBOLKey = @c_MBOLKey
      	--AND LOC.LocationCategory <> 'Staging'

      	IF EXISTS (SELECT 1
      	           FROM RDT.rdtScanToTruck RSTT (NOLOCK)
      	           WHERE RSTT.MBOLKey = @c_MBOLKey)
      	BEGIN
      		SET @c_OrderStatus = 'Loading'
      		SET @c_TruckStatus = 'Loading'   --Truck Status
      	END

      	--Truck Status
         SELECT @n_CountCaseID = COUNT(DISTINCT PD.CaseID)
              , @n_CountURNNo  = COUNT(DISTINCT RSTT.URNNo)
         FROM ORDERS OH (NOLOCK)
         JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
         LEFT JOIN rdt.RDTScanToTruck RSTT (NOLOCK) ON OH.MBOLKey = RSTT.MBOLKey
         WHERE OH.MBOLKey = @c_MBOLKey

         IF ISNULL(@n_CountCaseID,0) > 0 AND ISNULL(@n_CountURNNo,0) > 0 AND ISNULL(@n_CountCaseID,0) = ISNULL(@n_CountURNNo,0)
         BEGIN
         	SET @c_TruckStatus = 'Loaded'
         END

         UPDATE #TMP_DSP2
         SET Order_Status = CASE WHEN @c_OrderStatus = '' THEN Order_Status ELSE '5-' + @c_OrderStatus END
           , Truck_Status = CASE WHEN @c_TruckStatus = '' THEN Truck_Status ELSE @c_TruckStatus END
         WHERE MBOLKey = @c_MBOLKey

      	FETCH NEXT FROM CUR_LOOP INTO @c_MBOLKey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
      --WL01 END

      SET @n_TotalCnt = 0
      SELECT @n_TotalCnt = COUNT(1)
      FROM #TMP_DSP2
      WHERE Storerkey = @c_Storerkey

      IF @n_TotalCnt > 0 AND ( @n_TotalCnt % @n_RowPerPage ) > 0
      BEGIN
         SET @n_RecToIns = @n_RowPerPage - ( @n_TotalCnt % @n_RowPerPage )
      END

      WHILE @n_RecToIns > 0
      BEGIN
         INSERT INTO #TMP_DSP2 ( Facility, Storerkey, BookingNo, BookingDate, EndTime, Loc, ToLoc, Loc2
                               , VehicleType, Truck_Name, Truck_Status, Order_Status, Order_Status_Color, Remarks
                               , BKO_Status
                               , MBOLKey, CallTime   --WL01
                               )
         VALUES ('', '', NULL, NULL, NULL, '', '', ''
               , '', '','', '', NULL, ''
               , ''
               , '', NULL)   --WL01

         SET @n_RecToIns = @n_RecToIns - 1
      END

      TRUNCATE TABLE #TMP_BKTRSTATUS   --WL03

      FETCH NEXT FROM CUR_STR INTO @c_Storerkey
   END
   CLOSE CUR_STR
   DEALLOCATE CUR_STR

   QUIT_SP:
   IF  ISNULL(@n_DB_HeaderID,0) = 0 -- (SWT01)
   BEGIN
      SELECT RowNo
            ,Facility
            ,Storerkey
            ,BookingNo
            ,BookingDate
            ,EndTime
            ,Loc
            ,ToLoc
            ,Loc2
            ,VehicleType
            ,Truck_Name
            ,Truck_Status
            ,Order_Status = STUFF(Order_Status,1,2,'')
            ,Order_Status_Color = CASE LEFT(Order_Status,1)
                                       WHEN '0' THEN 255        --Red
                                       WHEN '3' THEN 65535      --Yellow
                                       WHEN '5' THEN 32768      --Green
                                       WHEN '9' THEN 16711680   --Blue
                                       END
            ,Remarks
            ,PageGroup = CEILING ( (RowNo * 1.00) / @n_RowPerPage )
            ,MBOLKey   --WL01
            ,CallTime  --WL01
      FROM #TMP_DSP2
      ORDER BY RowNo      
   END 
   ELSE
   BEGIN
      INSERT INTO BI.Dashboard_DET
      (
         DB_HeaderID,
         RowID,
         CharCol001, -- Facility
         CharCol002, -- Storerkey
         CharCol003, -- BookingNo
         DateCol001, -- BookingDate
         DateCol002, -- EndTime            
         CharCol004, -- Loc
         CharCol005, -- ToLoc
         CharCol006, -- Loc2
         CharCol007, -- VehicleType
         CharCol010, -- Truck_Name
         CharCol011, -- Truck_Status            
         CharCol008, -- Order_Status            
         IntCol001,  -- Order_Status_Color
         CharCol031, -- Remarks
         PageGroup, 
         CharCol012, -- MBOLKey
         DateCol003   --CharCol013  -- CallTime   --WL02 
         )         
      SELECT @n_DB_HeaderID AS [DB_HeaderID]
            ,RowNo
            ,Facility
            ,Storerkey
            ,BookingNo
            ,BookingDate
            ,EndTime
            ,Loc
            ,ToLoc
            ,Loc2
            ,VehicleType
            ,Truck_Name
            ,Truck_Status
            ,Order_Status = STUFF(Order_Status,1,2,'')
            ,Order_Status_Color = CASE LEFT(Order_Status,1)
                                       WHEN '0' THEN 255        --Red
                                       WHEN '3' THEN 65535      --Yellow
                                       WHEN '5' THEN 32768      --Green
                                       WHEN '9' THEN 16711680   --Blue
                                       END
            ,Remarks
            ,PageGroup = CEILING ( (RowNo * 1.00) / @n_RowPerPage )
            ,MBOLKey   --WL01
            ,CallTime  --WL01
      FROM #TMP_DSP2
      ORDER BY RowNo            
   END

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_STR') in (0 , 1)
   BEGIN
      CLOSE CUR_STR
      DEALLOCATE CUR_STR
   END

   --WL03 S
   IF OBJECT_ID('tempdb..#TMP_DSP2') IS NOT NULL
      DROP TABLE #TMP_DSP2
      
   IF OBJECT_ID('tempdb..#TMP_BKTRSTATUS') IS NOT NULL
      DROP TABLE #TMP_BKTRSTATUS

   IF OBJECT_ID('tempdb..#TMP_BOOKINGNO') IS NOT NULL
      DROP TABLE #TMP_BOOKINGNO
   --WL03 E

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   WHILE @@TRANCOUNT < @n_starttcnt
      BEGIN TRAN

END -- procedure

GO