SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LOCInquiry_InfoRetrieval                        */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes:                                                            */
/* 1) To Retrieve detail Location Information                           */
/* 2) Call From rdtfnc_LOCInquiry                                       */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2007-11-16  1.0  Vicky       Created                                 */
/* 2011-04-19  1.1  James       Add database parameter                  */
/************************************************************************/

CREATE PROC [RDT].[rdt_LOCInquiry_InfoRetrieval] (
   @cLOC             NVARCHAR(10),
   @cFacility        NVARCHAR( 5),
   @cDPutawayZone    NVARCHAR(10) OUTPUT,
   @cDPickZone       NVARCHAR(10) OUTPUT,
   @cLogicalLoc      NVARCHAR(10) OUTPUT,
   @cCCLogicalLoc    NVARCHAR(10) OUTPUT,
   @cLocationType    NVARCHAR(10) OUTPUT,
   @cLocationFlag    NVARCHAR(10) OUTPUT,
   @cLocHandling     NVARCHAR(10) OUTPUT,
   @cLocStatus       NVARCHAR(10) OUTPUT,
   @cLoseID          NVARCHAR( 1) OUTPUT,
   @cABC             NVARCHAR( 1) OUTPUT,
   @cComSKU          NVARCHAR( 1) OUTPUT,
   @cComLOT          NVARCHAR( 1) OUTPUT
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cSQL             NVARCHAR(4000),
           @cSQL1            NVARCHAR(4000),
           @cExecStatements  NVARCHAR(4000),
           @cExecArguments   NVARCHAR(4000),
           @n_debug          INT


   SET @n_debug = 0

   SET @cDPutawayZone = ''
   SET @cDPickZone = ''
   SET @cLogicalLoc = ''
   SET @cCCLogicalLoc = ''
   SET @cLocationType = ''
   SET @cLocationFlag = ''
   SET @cLocHandling = ''
   SET @cLocStatus = ''
   SET @cLoseID = ''
   SET @cABC = ''
   SET @cComSKU = ''
   SET @cComLOT = ''


   SELECT @cDPutawayZone = ISNULL(RTRIM(LOC.Putawayzone), ''),
          @cDPickZone = ISNULL(RTRIM(LOC.PickZone), ''),
          @cLogicalLoc = ISNULL(RTRIM(LOC.LogicalLocation), ''),
          @cCCLogicalLoc = ISNULL(RTRIM(LOC.CCLogicalLoc), ''),
          @cLocationType = ISNULL(RTRIM(LOC.LocationType), ''),
          @cLocationFlag = ISNULL(RTRIM(LOC.LocationFlag), ''),
          @cLocHandling = ISNULL(RTRIM(CLK.Description), ''),
          @cLocStatus = ISNULL(RTRIM(LOC.Status), ''),
          @cLoseID = CASE WHEN RTRIM(LOC.LoseID) = '1' THEN 'Y' ELSE 'N' END,
          @cABC = ISNULL(RTRIM(LOC.ABC), ''),
          @cComSKU = CASE WHEN RTRIM(LOC.CommingleSKU) = '1' THEN 'Y' ELSE 'N' END,
          @cComLOT = CASE WHEN RTRIM(LOC.CommingleLOT) = '1' THEN 'Y' ELSE 'N' END
   FROM dbo.LOC LOC WITH (NOLOCK)
   LEFT OUTER JOIN dbo.CODELKUP CLK WITH (NOLOCK)
     ON (CLK.Code = LOC.LocationHandling AND CLK.Listname = 'LOCHDLING')
   WHERE LOC.LOC = RTRIM(@cLOC)
   AND   LOC.Facility = RTRIM(@cFacility)


	IF @n_debug = 1
	BEGIN
	   SELECT '@cDPutawayZone', @cDPutawayZone, '@cDPickZone', @cDPickZone
      SELECT '@cLogicalLoc', @cLogicalLoc, '@cCCLogicalLoc', @cCCLogicalLoc
      SELECT '@cLocationType', @cLocationType, '@cLocationFlag', @cLocationFlag
      SELECT '@cLocHandling', @cLocHandling, '@cLocStatus', @cLocStatus
      SELECT '@cLoseID', @cLoseID, '@cABC', @cABC
      SELECT '@cComSKU', @cComSKU, '@cComLOT', @cComLOT
	END
END


GO