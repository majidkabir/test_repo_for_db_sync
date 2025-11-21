SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_Letdown4VNADriver_rpt                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2005-Jul-19  Shong         Bug Fixing SOS# 38299                     */
/* 2006-Nov-13  James         add to be                                 */ 
/*                            consistent with table structure           */
/*                            of nsp_ReplenishLetdown_rpt               */
/************************************************************************/



CREATE PROC [dbo].[nsp_Letdown4VNADriver_rpt] (
      @c_facility     NVARCHAR(5)
,     @c_loadkeystart NVARCHAR(10)
,     @c_loadkeyend   NVARCHAR(10) )
AS
BEGIN
	-- 24Jan2005 YTWan - Replenishment LetDown SP Change for (replenishment to BBA)
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   CREATE Table #ReplenishLetdown (
      StorerKey NVARCHAR(15) NULL,
      SKU       NVARCHAR(20) NULL,
      Lottable02 NVARCHAR(18) Null,   --added by james on 13/11/2006 add to be consistent with table structure of nsp_ReplenishLetdown_rpt
      Loc       NVARCHAR(10) NULL,
      ID        NVARCHAR(18) NULL,
      Qty       int NULL,
      QtyInEA   int NULL, 
      PackKey   NVARCHAR(10) NULL,
      CaseCnt   int NULL,
      PickQrt   int NULL,
      ReplQty   int NULL,
      ReplQtyEA int NULL, 
      ToLoc     NVARCHAR(10) NULL,
      CaseRtn2Rack   int NULL,
      CaseRtn2RackEA int NULL,
   --   MoveToPal      NVARCHAR(15) NULL, -- 24Jan2005 YTWan - Replenishment LetDown SP Change for (replenishment to BBA)
      MoveToLoc      NVARCHAR(15) NULL,
      Facility       NVARCHAR(5)  NULL,
      LoadKeyStart   NVARCHAR(10) NULL,
      LoadKeyEnd     NVARCHAR(10) NULL,   
      -- Added by SHONG SOS# 38299 
      PackUOM3       NVARCHAR(10) NULL)
      
      
 INSERT INTO #ReplenishLetdown
 EXEC nsp_ReplenishLetdown_rpt @c_facility, @c_loadkeystart, @c_loadkeyend

 CREATE Table #Report (
   Facility       NVARCHAR(5),
   LoadKeyStart   NVARCHAR(10) NULL,
   LoadKeyEnd     NVARCHAR(10) NULL, 
   PageNo         int,
   Line           int,
   ItemNo1        int, 
   Loc1           NVARCHAR(10),
   CaseRtn2Rack1  int,
   Side1          NVARCHAR(5),
   ItemNo2        int, 
   Loc2           NVARCHAR(10),
   CaseRtn2Rack2  int,
   Side2          NVARCHAR(5)
   )

   DECLARE @cLoc          NVARCHAR(10),
           @nCaseRtn2Rack int,
           @cSide         NVARCHAR(5),
           @nPage         int, 
           @nLine         int,
           @nItems        int,
           @nTotItems     int   


   DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT LOC, SUM(CaseRtn2Rack) as CaseRtn2Rack, 
   CASE WHEN SUM(ReplQty + ReplQtyEA) > 0 OR SUM(CaseRtn2Rack + CaseRtn2RackEA) > 0 THEN ''
             ELSE 'DN' 
   END as Side 
   FROM #ReplenishLetdown
   GROUP BY LOC 
   ORDER BY LOC 

   OPEN CUR1

   SELECT @nPage = 1 
   SELECT @nItems = 0 
   Fetch Next FROM CUR1 INTO @cLOC, @nCaseRtn2Rack, @cSide
   WHILE @@Fetch_Status <> -1
   BEGIN
      IF @nItems < 40
      BEGIN
         SELECT @nItems = @nItems + 1 
         IF @nItems <= 20
         BEGIN
            SELECT @nTotItems = ( (@nPage - 1) * 40 ) + @nItems

            INSERT INTO #Report VALUES (@c_facility, @c_loadkeystart, @c_loadkeyend, @nPage, 
                 @nItems, @nTotItems, @cLOC, @nCaseRtn2Rack, @cSide, '', '', 0, '')
         END 
         ELSE
         BEGIN
            UPDATE #Report
               SET ItemNo2 = ( (@nPage - 1) * 40 ) + @nItems, 
                   Loc2    = @cLOC, 
                   CaseRtn2Rack2 = @nCaseRtn2Rack, 
                   Side2 = @cSide
            WHERE  PageNo = @nPage
            AND    Line = @nItems - 20 

         END 
		   -- Changed by June 18.Nov.2004
         Fetch Next FROM CUR1 INTO @cLOC, @nCaseRtn2Rack, @cSide
      END
      ELSE 
      BEGIN 
         SELECT @nPage = @nPage + 1
         SELECT @nItems = 0 
      END 
		-- Changed by June 18.Nov.2004
      -- Fetch Next FROM CUR1 INTO @cLOC, @nCaseRtn2Rack, @cSide
   END 
   SELECT * FROM #Report
   Order By PageNo, Line 

END -- Procedure


GO