SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspOrderPerformceAnalysisRpt                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspOrderPerformceAnalysisRpt]
@d_Date DateTime
AS
BEGIN -- start of procedure
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @i_hour      int,
   @c_Select    NVARCHAR(500),
   @d_StartTime NVARCHAR(30),
   @d_EndTime   NVARCHAR(30),
   @n_NoOfOrder int,
   @n_Allocated int,
   @n_PickInProcess int,
   @n_PickConfirmed int,
   @n_Shipped int
   CREATE TABLE #OrderAnl
   (OrderDate DateTime NULL,
   StartTime DateTime NULL,
   EndTime   DateTime NULL,
   NoOfOrder int,
   Allocated int,
   PickInProgress int,
   PickComfirmation int,
   Shipped int)
   SELECT @i_hour = 0
   WHILE @i_Hour <= 23
   BEGIN
      SELECT @d_StartTime = CONVERT(CHAR(10), @d_date, 101) + " " + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), @i_hour)), 2) + ":00:00"
      SELECT @d_EndTime = CONVERT(CHAR(10), @d_date, 101) + " " + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), @i_hour)), 2) + ":59:59"
      -- Select No of Orders
      SELECT @c_Select = "DECLARE CUR1 SCROLL CURSOR FOR SELECT COUNT(*) FROM ORDERS (NOLOCK) " +
      "WHERE ADDDATE >= " + "'" + CONVERT(CHAR(10), @d_date, 101) + " " + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), @i_hour)), 2) + ":00:00" + "'"
      SELECT @c_Select = dbo.fnc_RTrim(@c_Select) + " AND ADDDATE <= " + "'" + CONVERT(CHAR(10), @d_date, 101) + " " + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), @i_hour)), 2) + ":59:59" + "'"
      EXECUTE (@c_Select)
      OPEN CUR1
      FETCH FIRST FROM CUR1 INTO @n_NoOfOrder
      CLOSE CUR1
      DEALLOCATE CUR1
      -- Select No of Allocated Orders within this hour
      CREATE TABLE #P
      (OrderKey NVARCHAR(10), AddDate datetime)
      EXECUTE( "INSERT INTO #P SELECT ORDERKEY, AddDate=MAX(Adddate) FROM PICKDETAIL (NOLOCK) "
      + " GROUP BY ORDERKEY "
      + " HAVING Max(AddDate) >= " + "'" + @d_StartTime  + "' "
      + " AND Max(AddDate) <= " + "'" + @d_EndTime + "'" )
      SELECT @n_Allocated = COUNT(*) FROM #P
      DROP TABLE #P
      -- Select No of Scan In Orders within this hour
      EXECUTE ("DECLARE CUR1 SCROLL CURSOR FOR SELECT COUNT(*) FROM ORDERS (NOLOCK) " +
      "WHERE ORDERKEY IN (SELECT DISTINCT L.ORDERKEY " +
      "FROM PICKHEADER H (NOLOCK), PICKINGINFO P (NOLOCK), LOADPLANDETAIL L (NOLOCK) " +
      "WHERE H.PickHeaderKey = P.PickSlipNo AND H.ExternOrderKey = L.LoadKey " +
      "AND ScanInDate >= " + "'" + @d_StartTime  + "' " +
      "AND ScanInDate <= " + "'" + @d_EndTime + "'" + ")"
      )
      OPEN CUR1
      FETCH FIRST FROM CUR1 INTO @n_PickInProcess
      CLOSE CUR1
      DEALLOCATE CUR1
      -- Select No of Scan Out Orders within this hour
      EXECUTE ("DECLARE CUR1 SCROLL CURSOR FOR SELECT COUNT(*) FROM ORDERS (NOLOCK) " +
      "WHERE ORDERKEY IN (SELECT DISTINCT L.ORDERKEY " +
      "FROM PICKHEADER H (NOLOCK), PICKINGINFO P (NOLOCK), LOADPLANDETAIL L (NOLOCK) " +
      "WHERE H.PickHeaderKey = P.PickSlipNo AND H.ExternOrderKey = L.LoadKey " +
      "AND ScanOutDate >= " + "'" + @d_StartTime  + "' " +
      "AND ScanOutDate <= " + "'" + @d_EndTime + "'" + ")"
      )
      OPEN CUR1
      FETCH FIRST FROM CUR1 INTO @n_PickConfirmed
      CLOSE CUR1
      DEALLOCATE CUR1
      -- Select No of Scan Out Orders within this hour
      EXECUTE ("DECLARE CUR1 SCROLL CURSOR FOR SELECT COUNT(ORDERKEY) " +
      "FROM MBOL H (NOLOCK), MBOLDETAIL D (NOLOCK) " +
      "WHERE H.MBOLKey = D.MBOLKEY  " +
      "AND H.Status = '9' " +
      "AND H.EditDate >= " + "'" + @d_StartTime  + "' " +
      "AND H.EditDate <= " + "'" + @d_EndTime + "'"
      )
      OPEN CUR1
      FETCH FIRST FROM CUR1 INTO @n_Shipped
      CLOSE CUR1
      DEALLOCATE CUR1
      INSERT INTO #OrderAnl
      VALUES (@d_date , @d_StartTime, @d_EndTime, @n_NoOfOrder, @n_Allocated, @n_PickInProcess, @n_PickConfirmed, @n_Shipped)
      SELECT @i_Hour = @i_hour + 1
   END
   SELECT * FROM #OrderAnl
   DROP TABLE #OrderAnl
END -- end of procedure


GO