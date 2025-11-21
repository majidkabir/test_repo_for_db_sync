SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_ABC_Dashboard_02                                   */
/* Creation Date: 17-MAY-2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  LOC ABC Dashboard                                             */
/*                                                                         */
/* Called By:  r_dw_abc_dashboard_02 & r_dw_abc_dashboard_03               */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/***************************************************************************/
CREATE PROC [dbo].[isp_ABC_Dashboard_02]
         @c_Facility             NVARCHAR(5)
       , @c_AreaKey              NVARCHAR(10)
       , @c_PutawayZone          NVARCHAR(10)
       , @c_PickZone             NVARCHAR(10)
       , @c_LocAisle             NVARCHAR(10)
       , @c_Type                 NVARCHAR(10)

AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  @c_SQL                  NVARCHAR(MAX)

   DECLARE  @n_LocA                 FLOAT
          , @n_LocB                 FLOAT
          , @n_LocC                 FLOAT
          , @n_LocD                 FLOAT
          , @n_LocNA                FLOAT
          , @n_EALocA               FLOAT
          , @n_EALocB               FLOAT
          , @n_EALocC               FLOAT
          , @n_EALocD               FLOAT
          , @n_EALocNA              FLOAT
          , @n_CSLocA               FLOAT
          , @n_CSLocB               FLOAT
          , @n_CsLocC               FLOAT
          , @n_CSLocD               FLOAT
          , @n_CSLocNA              FLOAT
          , @n_PLLocA               FLOAT
          , @n_PLLocB               FLOAT
          , @n_PLLocC               FLOAT
          , @n_PLLocD               FLOAT
          , @n_PLLocNA              FLOAT
          , @n_TotalABC             FLOAT
          , @n_TotalEAABC           FLOAT
          , @n_TotalCSABC           FLOAT
          , @n_TotalPLABC           FLOAT
          , @n_OriginTotalABC       FLOAT
                                      
   DECLARE  @n_AnalysisA            FLOAT
          , @n_AnalysisB            FLOAT
          , @n_AnalysisC            FLOAT
          , @n_AnalysisD            FLOAT
          , @n_AnalysisNA           FLOAT
          , @n_AnalysisTotalABC     FLOAT
                                      
          , @n_AvgDailyPickA        FLOAT
          , @n_AvgDailyPickB        FLOAT
          , @n_AvgDailyPickC        FLOAT
          , @n_AvgDailyPickD        FLOAT
          , @n_AvgDailyPickNA       FLOAT

          , @n_PAnalysisA           FLOAT
          , @n_PAnalysisB           FLOAT
          , @n_PAnalysisC           FLOAT
          , @n_PAnalysisD           FLOAT
          , @n_PAnalysisNA          FLOAT

          , @n_CAnalysisA           FLOAT
          , @n_CAnalysisB           FLOAT
          , @n_CAnalysisC           FLOAT
          , @n_CAnalysisD           FLOAT
          , @n_CAnalysisNA          FLOAT

          , @n_BAnalysisA           FLOAT
          , @n_BAnalysisB           FLOAT
          , @n_BAnalysisC           FLOAT
          , @n_BAnalysisD           FLOAT
          , @n_BAnalysisNA          FLOAT

                                      
   SET @n_LocA                = 0.00
   SET @n_LocB                = 0.00
   SET @n_LocC                = 0.00
   SET @n_LocD                = 0.00
   SET @n_LocNA               = 0.00
   SET @n_EALocA              = 0.00
   SET @n_EALocB              = 0.00
   SET @n_EALocC              = 0.00
   SET @n_EALocD              = 0.00
   SET @n_EALocNA             = 0.00
   SET @n_CSLocA              = 0.00
   SET @n_CSLocB              = 0.00
   SET @n_CSLocC              = 0.00
   SET @n_CsLocD              = 0.00
   SET @n_CSLocNA             = 0.00
   SET @n_PLLocA              = 0.00
   SET @n_PLLocB              = 0.00
   SET @n_PLLocC              = 0.00
   SET @n_PLLocD              = 0.00
   SET @n_PLLocNA             = 0.00
   SET @n_TotalABC            = 0.00
   SET @n_OriginTotalABC      = 0.00
                                    
   SET @n_AnalysisA           = 0.00
   SET @n_AnalysisB           = 0.00
   SET @n_AnalysisC           = 0.00
   SET @n_AnalysisD           = 0.00
   SET @n_AnalysisNA          = 0.00
   SET @n_AnalysisTotalABC    = 0.00
                                    
   SET @n_PAnalysisA          = 0.00
   SET @n_PAnalysisB          = 0.00
   SET @n_PAnalysisC          = 0.00
   SET @n_PAnalysisD          = 0.00
   SET @n_PAnalysisNA         = 0.00
                                    
   SET @n_CAnalysisA          = 0.00
   SET @n_CAnalysisB          = 0.00
   SET @n_CAnalysisC          = 0.00
   SET @n_CAnalysisD          = 0.00
   SET @n_CAnalysisNA         = 0.00
                                    
   SET @n_BAnalysisA          = 0.00
   SET @n_BAnalysisB          = 0.00
   SET @n_BAnalysisC          = 0.00
   SET @n_BAnalysisD          = 0.00
   SET @n_BAnalysisNA         = 0.00

   CREATE TABLE #TMP_LOC 
         (
            Facility                NVARCHAR(5)
         ,  Loc                     NVARCHAR(10)
         )
         
   CREATE TABLE #TMP_LOCABC
         (  Type_descr              NVARCHAR(50)
         ,  ABC                     NVARCHAR(5)
         ,  TotalABC                FLOAT       NULL
         ,  CurrentABC              FLOAT       NULL
         ,  PerctgABC               FLOAT       NULL
         ,  ProposedABC             FLOAT       NULL
         ,  PerctgProposedABC       FLOAT       NULL
         )

--   INSERT INTO #TMP_LOC 
--         (  Facility
--         ,  Loc
--         )
--
--   SELECT DISTINCT 
--          LOC.Facility
--         ,LOC.Loc
--   FROM LOC  WITH (NOLOCK)
--   LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone)
--   WHERE Loc.Facility = CASE WHEN @c_Facility = 'ALL' THEN LOC.Facility ELSE @c_Facility END
--   AND   ISNULL(RTRIM(LOC.PutawayZone),'')= CASE WHEN @c_PutawayZone = 'ALL' THEN ISNULL(RTRIM(LOC.PutawayZone),'')     ELSE @c_PutawayZone  END
--   AND   ISNULL(RTRIM(LOC.PickZone),'')   = CASE WHEN @c_PickZone    = 'ALL' THEN ISNULL(RTRIM(LOC.PickZone),'')        ELSE @c_PickZone     END
--   AND   ISNULL(RTRIM(LOC.LocAisle),'')   = CASE WHEN @c_LocAisle    = 'ALL' THEN ISNULL(RTRIM(LOC.LocAisle),'')        ELSE @c_LocAisle     END
--   AND   ISNULL(RTRIM(AREADETAIL.AreaKey),'') = CASE WHEN @c_AreaKey = 'ALL' THEN ISNULL(RTRIM(AREADETAIL.AreaKey),'')  ELSE @c_AreaKey      END

   SET @c_SQL = N'INSERT INTO #TMP_LOC '
              +  '(  Facility '
              +  ',  Loc '
              +  ') '
              +  'SELECT DISTINCT '
              +  ' LOC.Facility '
              +  ',LOC.Loc '
              +  'FROM LOC WITH (NOLOCK) '
              +  'LEFT JOIN AREADETAIL WITH (NOLOCK) ON (LOC.PutawayZone = AREADETAIL.PutawayZone) '
              +  'WHERE 1 = 1 '
              +  CASE WHEN @c_Facility    <> 'ALL' THEN 'AND Loc.Facility   = N''' + @c_Facility + ''' '    ELSE '' END
              +  CASE WHEN @c_PutawayZone <> 'ALL' THEN 'AND Loc.PutawayZone= N''' + @c_PutawayZone + ''' ' ELSE '' END
              +  CASE WHEN @c_PickZone    <> 'ALL' THEN 'AND Loc.PickZone   = N''' + @c_PickZone + ''' '    ELSE '' END
              +  CASE WHEN @c_LocAisle    <> 'ALL' THEN 'AND Loc.LocAisle   = N''' + @c_LocAisle + ''' '    ELSE '' END
              +  CASE WHEN @c_AreaKey     <> 'ALL' THEN 'AND AREADETAIL.AreaKey = N''' + @c_AreaKey + ''' ' ELSE '' END
--
--   SELECT DISTINCT 
--          LOC.Facility
--         ,LOC.Loc
--   FROM LOC  WITH (NOLOCK)
   EXEC (@c_SQL)


   SELECT @n_LocA = ISNULL(SUM(CASE WHEN LOC.ABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_LocB = ISNULL(SUM(CASE WHEN LOC.ABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_LocC = ISNULL(SUM(CASE WHEN LOC.ABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_LocD = ISNULL(SUM(CASE WHEN LOC.ABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_LocNA= ISNULL(SUM(CASE WHEN LOC.ABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE 1 END),0)
         ,@n_EALocA = ISNULL(SUM(CASE WHEN LOC.LocationType = 'PICK' AND LOC.ABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_EALocB = ISNULL(SUM(CASE WHEN LOC.LocationType = 'PICK' AND LOC.ABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_EALocC = ISNULL(SUM(CASE WHEN LOC.LocationType = 'PICK' AND LOC.ABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_EALocD = ISNULL(SUM(CASE WHEN LOC.LocationType = 'PICK' AND LOC.ABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_EALocNA= ISNULL(SUM(CASE WHEN LOC.LocationType = 'PICK' AND LOC.ABC NOT IN ('A', 'B', 'C', 'D') THEN 1 ELSE 0 END),0)
         ,@n_CSLocA = ISNULL(SUM(CASE WHEN LOC.LocationType = 'CASE' AND LOC.ABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_CSLocB = ISNULL(SUM(CASE WHEN LOC.LocationType = 'CASE' AND LOC.ABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_CSLocC = ISNULL(SUM(CASE WHEN LOC.LocationType = 'CASE' AND LOC.ABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_CSLocD = ISNULL(SUM(CASE WHEN LOC.LocationType = 'CASE' AND LOC.ABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_CSLocNA= ISNULL(SUM(CASE WHEN LOC.LocationType = 'CASE' AND LOC.ABC NOT IN ('A', 'B', 'C', 'D') THEN 1 ELSE 0 END),0)
         ,@n_PLLocA = ISNULL(SUM(CASE WHEN LOC.LocationType = 'OTHER' AND LOC.ABC = 'A' THEN 1 ELSE 0 END),0)
         ,@n_PLLocB = ISNULL(SUM(CASE WHEN LOC.LocationType = 'OTHER' AND LOC.ABC = 'B' THEN 1 ELSE 0 END),0)
         ,@n_PLLocC = ISNULL(SUM(CASE WHEN LOC.LocationType = 'OTHER' AND LOC.ABC = 'C' THEN 1 ELSE 0 END),0)
         ,@n_PLLocD = ISNULL(SUM(CASE WHEN LOC.LocationType = 'OTHER' AND LOC.ABC = 'D' THEN 1 ELSE 0 END),0)
         ,@n_PLLocNA= ISNULL(SUM(CASE WHEN LOC.LocationType = 'OTHER' AND LOC.ABC NOT IN ('A', 'B', 'C', 'D') THEN 1 ELSE 0 END),0)
         ,@n_TotalABC = ISNULL(COUNT(1),0)
   FROM LOC WITH (NOLOCK)
   JOIN #TMP_LOC TMP ON (LOC.Loc = TMP.Loc)  


--   SELECT @n_AnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'A' THEN NoOfPieceLoc + NoOfCaseLoc + NoOfBulkLoc ELSE 0 END),0)
--         ,@n_AnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'B' THEN NoOfPieceLoc + NoOfCaseLoc + NoOfBulkLoc ELSE 0 END),0)
--         ,@n_AnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'C' THEN NoOfPieceLoc + NoOfCaseLoc + NoOfBulkLoc ELSE 0 END),0)
--         ,@n_AnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'D' THEN NoOfPieceLoc + NoOfCaseLoc + NoOfBulkLoc ELSE 0 END),0)
--         ,@n_AnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE NoOfPieceLoc + NoOfCaseLoc + NoOfBulkLoc END),0)
--
--         ,@n_PAnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'A' THEN NoOfPieceLoc ELSE 0 END),0)
--         ,@n_PAnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'B' THEN NoOfPieceLoc ELSE 0 END),0)
--         ,@n_PAnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'C' THEN NoOfPieceLoc ELSE 0 END),0)
--         ,@n_PAnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'D' THEN NoOfPieceLoc ELSE 0 END),0)
--         ,@n_PAnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE NoOfPieceLoc END),0)
--
--         ,@n_CAnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'A' THEN NoOfCaseLoc ELSE 0 END),0)
--         ,@n_CAnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'B' THEN NoOfCaseLoc ELSE 0 END),0)
--         ,@n_CAnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'C' THEN NoOfCaseLoc ELSE 0 END),0)
--         ,@n_CAnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'D' THEN NoOfCaseLoc ELSE 0 END),0)
--         ,@n_CAnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE NoOfCaseLoc END),0)
--
--         ,@n_BAnalysisA = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'A' THEN NoOfBulkLoc ELSE 0 END),0)
--         ,@n_BAnalysisB = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'B' THEN NoOfBulkLoc ELSE 0 END),0)
--         ,@n_BAnalysisC = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'C' THEN NoOfBulkLoc ELSE 0 END),0)
--         ,@n_BAnalysisD = ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC = 'D' THEN NoOfBulkLoc ELSE 0 END),0)
--         ,@n_BAnalysisNA= ISNULL(SUM(CASE WHEN ABCANALYSIS.ABC IN ('A', 'B', 'C', 'D') THEN 0 ELSE NoOfBulkLoc END),0)
--   FROM ABCANALYSIS WITH (NOLOCK)
--   JOIN (SELECT DISTINCT Facility FROM #TMP_LOC) TMP ON (ABCANALYSIS.Facility = TMP.Facility)
--   WHERE ABCANALYSIS.Facility = @c_Facility

   SET @n_OriginTotalABC = @n_TotalABC
   IF @n_TotalABC = 0.00
   BEGIN
      SET @n_TotalABC = 1
   END

   -- ALL
   IF @c_Type = 'ALL' 
   BEGIN
      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Location Analysis', 'A', @n_OriginTotalABC, @n_LocA, ((@n_LocA / @n_TotalABC) * 100) 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Location Analysis', 'B', @n_OriginTotalABC, @n_LocB, ((@n_LocB / @n_TotalABC) * 100) 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Location Analysis', 'C', @n_OriginTotalABC, @n_LocC, ((@n_LocC / @n_TotalABC) * 100)
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Location Analysis', 'D', @n_OriginTotalABC, @n_LocD, ((@n_LocD / @n_TotalABC) * 100) 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Location Analysis','N/A', @n_OriginTotalABC, @n_LocNA, ((@n_LocNA / @n_TotalABC) * 100) 
             )

      GOTO QUIT
   END

   -- Piece
   IF @c_Type = 'EA'
   BEGIN
      SET @n_TotalEAABC = @n_EALocA + @n_EALocB + @n_EALocC + @n_EALocD + @n_EALocNA
      SET @n_TotalEAABC = @n_EALocA + @n_EALocB + @n_EALocC + @n_EALocD + @n_EALocNA
      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Piece Pick Location Analysis', 'A', @n_TotalEAABC, @n_EALocA, CASE WHEN @n_TotalEAABC = 0 THEN 0 ELSE ((@n_EALocA / @n_TotalEAABC) * 100) END 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Piece Pick Location Analysis', 'B', @n_TotalEAABC, @n_EALocB, CASE WHEN @n_TotalEAABC = 0 THEN 0 ELSE ((@n_EALocB / @n_TotalEAABC) * 100) END 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Piece Pick Location Analysis', 'C', @n_TotalEAABC, @n_EALocC, CASE WHEN @n_TotalEAABC = 0 THEN 0 ELSE ((@n_EALocC / @n_TotalEAABC) * 100) END  
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Piece Pick Location Analysis', 'D', @n_TotalEAABC, @n_EALocD, CASE WHEN @n_TotalEAABC = 0 THEN 0 ELSE ((@n_EALocD / @n_TotalEAABC) * 100) END 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Piece Pick Location Analysis','N/A', @n_TotalEAABC, @n_EALocNA, CASE WHEN @n_TotalEAABC = 0 THEN 0 ELSE ((@n_EALocNA / @n_TotalEAABC) * 100) END  
             )

      GOTO QUIT
   END


   -- Case
   IF @c_Type = 'CS'
   BEGIN
      SET @n_TotalCSABC = @n_CSLocA + @n_CSLocB + @n_CSLocC + @n_CSLocD + @n_CSLocNA
      SET @n_TotalCSABC = @n_CSLocA + @n_CSLocB + @n_CSLocC + @n_CSLocD + @n_CSLocNA
      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Case Pick Location Analysis', 'A', @n_TotalCSABC, @n_CSLocA, CASE WHEN @n_TotalCSABC = 0 THEN 0 ELSE ((@n_CSLocA / @n_TotalCSABC) * 100) END  
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Case Pick Location Analysis', 'B', @n_TotalCSABC, @n_CSLocB, CASE WHEN @n_TotalCSABC = 0 THEN 0 ELSE ((@n_CSLocB / @n_TotalCSABC) * 100) END  
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Case Pick Location Analysis', 'C', @n_TotalCSABC, @n_CSLocC, CASE WHEN @n_TotalCSABC = 0 THEN 0 ELSE ((@n_CSLocC / @n_TotalCSABC) * 100) END 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Case Pick Location Analysis', 'D', @n_TotalCSABC, @n_CSLocD, CASE WHEN @n_TotalCSABC = 0 THEN 0 ELSE ((@n_CSLocD / @n_TotalCSABC) * 100) END 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Case Pick Location Analysis','N/A', @n_TotalCSABC, @n_CSLocNA, CASE WHEN @n_TotalCSABC = 0 THEN 0 ELSE ((@n_CSLocNA / @n_TotalCSABC) * 100) END 
             )

      GOTO QUIT
   END

   -- Bulk
   IF @c_Type = 'PL'
   BEGIN
      SET @n_TotalPLABC = @n_PLLocA + @n_PLLocB + @n_PLLocC + @n_PLLocD + @n_PLLocNA

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Bulk Pick Location Analysis', 'A', @n_TotalPLABC, @n_PLLocA, CASE WHEN @n_TotalPLABC = 0 THEN 0 ELSE ((@n_PLLocA / @n_TotalPLABC) * 100) END 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Bulk Pick Location Analysis', 'B', @n_TotalPLABC, @n_PLLocB, CASE WHEN @n_TotalPLABC = 0 THEN 0 ELSE ((@n_PLLocB / @n_TotalPLABC) * 100) END 
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Bulk Pick Location Analysis', 'C', @n_TotalPLABC, @n_PLLocC, CASE WHEN @n_TotalPLABC = 0 THEN 0 ELSE ((@n_PLLocC / @n_TotalPLABC) * 100) END   
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Bulk Pick Location Analysis', 'D', @n_TotalPLABC, @n_PLLocD, CASE WHEN @n_TotalPLABC = 0 THEN 0 ELSE ((@n_PLLocD / @n_TotalPLABC) * 100) END   
             )

      INSERT INTO #TMP_LOCABC (Type_descr, ABC, TotalABC, CurrentABC, PerctgABC)
      VALUES ('Bulk Pick Location Analysis','N/A', @n_TotalPLABC, @n_PLLocNA,CASE WHEN @n_TotalPLABC = 0 THEN 0 ELSE ((@n_PLLocNA / @n_TotalPLABC) * 100) END 
             )

      GOTO QUIT
   END 

   QUIT:
   SELECT ABC
         ,CurrentABC               
         ,PerctgABC  
         ,TotalABC 
   FROM #TMP_LOCABC 
END

GO