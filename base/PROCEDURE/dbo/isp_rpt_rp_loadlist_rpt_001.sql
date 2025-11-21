SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_RP_LOADLIST_RPT_001                         */
/* Creation Date: 09-Jan-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: Adarsh                                                    */
/*                                                                       */
/* Purpose: WMS-21517-Migrate WMS Report To LogiReport                   */
/*                                                                       */
/* Called By: RPT_RP_LOADLIST_RPT_001                                    */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 09-Jan-2023  WLChooi 1.0   DevOps Combine Script                      */
/* 14-Sep-2023  WZPang  1.1   Add Filter Column (WZ01)                   */
/* 04-Oct-2023  WZPang  1.2   Order by LOC.LogicalLocation, Loc (WZ02)   */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_RP_LOADLIST_RPT_001]
(
   @c_LoadkeyFrom NVARCHAR(10)
 , @c_LoadkeyTo   NVARCHAR(10)
 , @c_Type        NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_storerkeyfrom NVARCHAR(10)
         , @c_storerkeyto   NVARCHAR(10)
         , @n_NoOfLine      INT
         , @n_recgrpsort    INT

   SET @n_NoOfLine = 80

   CREATE TABLE #TMPLOADBYORD
   (
      RowNo    INT
    , Loadkey  NVARCHAR(20)
    , Orderkey NVARCHAR(20) NULL
    , TotalQty INT          NULL
    , OHROUTE  NVARCHAR(20) NULL
    , recgrp   INT
   )

   SELECT @c_storerkeyfrom = MIN(OH.StorerKey)
        , @c_storerkeyto = MAX(OH.StorerKey)
   FROM ORDERS OH (NOLOCK)
   WHERE LoadKey BETWEEN @c_LoadkeyFrom AND @c_LoadkeyTo

   IF @c_Type = '' OR @c_Type = '1'
   BEGIN
      INSERT INTO #TMPLOADBYORD (RowNo, Loadkey, Orderkey, TotalQty, OHROUTE, recgrp)
      SELECT ROW_NUMBER() OVER (ORDER BY OrdHD.LoadKey
                                       , LOC.Score
                                       , LOC.LogicalLocation         --(WZ02)
                                       , LOC.Loc                     --(WZ02)
                                       , OrdHD.OrderKey
                                       , OrdHD.Route) AS [RowNo]
           , OrdHD.LoadKey AS Loadkey
           , OrdHD.OrderKey AS Orderkey
           , SUM(OrdDT.OriginalQty) [TotalQty]
           , OrdHD.Route AS OHROUTE
           , (ROW_NUMBER() OVER (PARTITION BY OrdHD.LoadKey  ORDER BY Loc.Score , LOC.LogicalLocation, LOC.Loc , OrdHD.Route Asc)-1)/@n_NoOfLine+1 AS recgrp --(WZ02)
      FROM ORDERS AS OrdHD WITH (NOLOCK)
      JOIN ORDERDETAIL AS OrdDT WITH (NOLOCK) ON OrdHD.StorerKey = OrdDT.StorerKey AND OrdHD.OrderKey = OrdDT.OrderKey
      JOIN PICKDETAIL AS PickDT WITH (NOLOCK) ON  OrdDT.StorerKey = PickDT.Storerkey
                                              AND OrdDT.OrderKey = PickDT.OrderKey
                                              AND OrdDT.OrderLineNumber = PickDT.OrderLineNumber
      JOIN LOC WITH (NOLOCK) ON PickDT.Loc = LOC.Loc AND LOC.Facility = 'HM'
      WHERE OrdHD.StorerKey BETWEEN @c_storerkeyfrom AND @c_storerkeyto
      AND   OrdHD.LoadKey BETWEEN @c_LoadkeyFrom AND @c_LoadkeyTo
      AND   OrdHD.Status <> '0' --WZ01
      GROUP BY OrdHD.LoadKey
             , OrdHD.OrderKey
             , OrdHD.Route
             , LOC.Loc
             , LOC.LogicalLocation
             , LOC.Score
      ORDER BY OrdHD.LoadKey
             , LOC.Score
             , LOC.LogicalLocation
             , LOC.Loc
             , OrdHD.OrderKey
   END
   ELSE
   BEGIN
      INSERT INTO #TMPLOADBYORD (RowNo, Loadkey, Orderkey, TotalQty, OHROUTE, recgrp)
      SELECT ROW_NUMBER() OVER (ORDER BY OrdHD.LoadKey
                                       , OrdHD.OrderKey
                                       , OrdHD.Route) AS [RowNo]
           , OrdHD.LoadKey AS Loadkey
           , OrdHD.OrderKey AS Orderkey
           , SUM(OrdDT.OriginalQty) [TotalQty]
           , OrdHD.Route AS OHROUTE
           , (ROW_NUMBER() OVER (PARTITION BY OrdHD.LoadKey
                                 ORDER BY OrdHD.LoadKey
                                        , OrdHD.OrderKey
                                        , OrdHD.Route ASC) - 1) / @n_NoOfLine + 1 AS recgrp
      FROM ORDERS AS OrdHD WITH (NOLOCK)
      JOIN ORDERDETAIL AS OrdDT (NOLOCK) ON OrdHD.StorerKey = OrdDT.StorerKey AND OrdHD.OrderKey = OrdDT.OrderKey
      WHERE OrdHD.StorerKey BETWEEN @c_storerkeyfrom AND @c_storerkeyto
      AND   OrdHD.LoadKey BETWEEN @c_LoadkeyFrom AND @c_LoadkeyTo
      AND   OrdHD.Status <> '0' --WZ01
      GROUP BY OrdHD.LoadKey
             , OrdHD.OrderKey
             , OrdHD.Route
      ORDER BY OrdHD.LoadKey
             , OrdHD.OrderKey

   END

   CREATE TABLE #TMPSPLITLOAD
   (
      Loadkey      NVARCHAR(20)
    , OrderkeyGrp1 NVARCHAR(20) NULL
    , Rownogrp1    INT          NULL
    , OrderkeyGrp2 NVARCHAR(20) NULL
    , recgrp       INT
    , Rownogrp2    INT          NULL
   )

   DECLARE @n_maxline  INT
         , @n_rowno    INT
         , @c_loadkey  NVARCHAR(20)
         , @c_orderkey NVARCHAR(20)
         , @n_recgrp   INT
         , @n_maxrec   INT

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT RowNo
                 , Loadkey
                 , Orderkey
                 , recgrp
                 , ROW_NUMBER() OVER (PARTITION BY Loadkey
                                      ORDER BY RowNo
                                             , Loadkey
                                             , Orderkey)
   FROM #TMPLOADBYORD ORD
   ORDER BY RowNo

   OPEN CUR_RESULT

   FETCH NEXT FROM CUR_RESULT
   INTO @n_rowno
      , @c_loadkey
      , @c_orderkey
      , @n_recgrp
      , @n_recgrpsort

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @n_recgrpsort <= (@n_NoOfLine / 2)
      BEGIN
         INSERT INTO #TMPSPLITLOAD (Loadkey, recgrp, Rownogrp1, Rownogrp2, OrderkeyGrp1, OrderkeyGrp2)
         VALUES (@c_loadkey, @n_recgrp, @n_recgrpsort, '', @c_orderkey, '')
      END
      ELSE IF @n_recgrpsort > (@n_NoOfLine / 2) AND @n_recgrpsort <= @n_NoOfLine
      BEGIN
      
         UPDATE #TMPSPLITLOAD
         SET Rownogrp2 = @n_recgrpsort
           , OrderkeyGrp2 = @c_orderkey
         WHERE Loadkey = @c_loadkey 
         AND recgrp = @n_recgrp 
         AND Rownogrp1 = @n_recgrpsort - (@n_NoOfLine / 2)
      END
      ELSE IF @n_recgrpsort > @n_NoOfLine
      BEGIN
         SET @n_maxrec = 1
         SELECT @n_maxrec = MAX(recgrp)
         FROM #TMPSPLITLOAD
         WHERE Loadkey = @c_loadkey

         IF @n_recgrp = @n_maxrec + 1 OR @n_recgrp = @n_maxrec
         BEGIN

            IF (@n_recgrpsort % @n_NoOfLine) <= (@n_NoOfLine / 2) AND (@n_recgrpsort % @n_NoOfLine) > 0
            BEGIN
               INSERT INTO #TMPSPLITLOAD (Loadkey, recgrp, Rownogrp1, Rownogrp2, OrderkeyGrp1, OrderkeyGrp2)
               VALUES (@c_loadkey, @n_recgrp, @n_recgrpsort, '', @c_orderkey, '')
            END
            ELSE IF (@n_recgrpsort % @n_NoOfLine) = 0
                 OR ((@n_recgrpsort % @n_NoOfLine) > (@n_NoOfLine / 2) AND (@n_recgrpsort % @n_NoOfLine) <= @n_NoOfLine)
            BEGIN

               UPDATE #TMPSPLITLOAD
               SET Rownogrp2 = @n_recgrpsort
                 , OrderkeyGrp2 = @c_orderkey
               WHERE Loadkey = @c_loadkey
               AND   recgrp = @n_recgrp
               AND   Rownogrp1 = CASE WHEN (@n_recgrpsort % @n_NoOfLine) = 0 THEN (@n_recgrpsort - @n_NoOfLine) + (@n_NoOfLine / 2)
                                      WHEN @n_recgrpsort <= 200 THEN (@n_recgrpsort % @n_NoOfLine) + (@n_NoOfLine / 2)
                                      ELSE (@n_recgrpsort % @n_NoOfLine) + ((@n_NoOfLine) * (@n_recgrp - 1) - (@n_NoOfLine / 2)) END
            END
         END
      END

      FETCH NEXT FROM CUR_RESULT
      INTO @n_rowno, @c_loadkey, @c_orderkey, @n_recgrp, @n_recgrpsort
   END

   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT



   SELECT Loadkey AS loadkey
        , OrderkeyGrp1 AS orderkeygrp1
        , CAST(Rownogrp1 AS NVARCHAR(10)) AS rownogrp1
        , OrderkeyGrp2 AS orderkeygrp2
        , recgrp AS recgrp
        , CASE WHEN ISNULL(OrderkeyGrp2, '') <> '' THEN CAST(Rownogrp2 AS NVARCHAR(10)) ELSE '' END AS rownogrp2
   FROM #TMPSPLITLOAD

   DROP TABLE #TMPLOADBYORD
   DROP TABLE #TMPSPLITLOAD

   QUIT_SP:
END

GO