SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Stored Proc : isp_BookLocationAndZone_Wrapper                                       */
/* Creation Date:                                                                      */
/* Copyright: Maersk WMS                                                               */
/* Written by:  CYU027                                                                 */
/*                                                                                     */
/* Purpose: It called by IML to get Location & Zone Before Putaway                     */
/*                                                                                     */
/*  Process:                                                                           */
/*            1. Find and book location                                                */
/*            2. Return location & zone accordingly                                   */
/*                                                                                     */
/* Usage:                                                                              */
/*                                                                                     */
/* Local Variables:                                                                    */
/*                                                                                     */
/* Called By: DIML                                                                     */
/*                                                                                     */
/* PVCS Version:                                                                       */
/*                                                                                     */
/* Version: Maersk WMS V2                                                              */
/*                                                                                     */
/* Data Modifications:                                                                 */
/*                                                                                     */
/* Updates:                                                                            */
/* Date        Rev  Author       Purposes                                              */
/* 20-11-2024  1.0  CYU027       FCR-1205 Created                                      */
/***************************************************************************************/

CREATE PROC dbo.isp_BookLocationAndZone_Wrapper(
   @cStorerKey                      NVARCHAR(15),
   @cID                             NVARCHAR(18),
   @cFacility                       NVARCHAR( 5),
   @cPutawayZone                    NVARCHAR(10)      OUTPUT,
   @cSuggestedLoc                   NVARCHAR(10)      OUTPUT,
   @nErrNo                          INT               OUTPUT,
   @cErrMsg                         NVARCHAR( 255)    OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
       @cSQL                  NVARCHAR( MAX)
      ,@cSQLParam             NVARCHAR( MAX)
      ,@cUserName             NVARCHAR( 18) = 'WCSAPI'
      ,@nMobile               INT
      ,@nFunc                 INT = 520
      ,@cLangCode             NVARCHAR( 3) = 'ENG'
      ,@cPickAndDropLoc       INT
      ,@nPABookingKey         INT = 0
      ,@cLOC                  NVARCHAR( 10)
      ,@cLOT                  NVARCHAR( 10) = ''
      ,@cUCC                  NVARCHAR( 20) = ''
      ,@cSKU                  NVARCHAR( 20)
      ,@nQTY                  INT
      ,@nRowCount             INT
      ,@cExtendedPutawaySP    NVARCHAR(20)


   IF NOT EXISTS( SELECT 1
                  FROM dbo.LOTxLOCxID LLI (NOLOCK)
                  WHERE LLI.StorerKey = @cStorerKey
                    AND ID = @cID
                    AND (QTY - QTYPicked - QtyAllocated ) > 0)
   BEGIN
      SET @nErrNo = -1
      SET @cErrMsg = 'Invalid ID'
      GOTO Quit
   END

   -- Count pallet LOC
   SELECT @nRowCount = COUNT( DISTINCT LOC)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
   WHERE ID = @cID
     AND LLI.StorerKey = @cStorerKey
     AND (QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QtyReplen) > 0

   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = -1
      SET @cErrMsg = 'From Loc > 1'
      GOTO Quit
   END

   -- Get LLI info
   SELECT TOP 1
      @cSKU       = LLI.SKU,
      @cID        = LLI.ID,
      @cLOC       = LLI.LOC,
      @nQTY       = SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated - LLI.QtyReplen)
   FROM dbo.LotxLocxID LLI WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey
     --AND LLI.LOC = @cFromLOC
     AND ID = @cID
   GROUP BY LLI.LOC, LLI.ID, LLI.SKU

   SET @cExtendedPutawaySP = 'rdt_520ExtPA01' -- Need configurable

   SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedPutawaySP) +
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, @cLOC, @cID, @cLOT, @cUCC, @cSKU, @nQTY, ' +
               ' @cSuggestedLOC OUTPUT, @cPickAndDropLoc OUTPUT, @nPABookingKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
   SET @cSQLParam =
           '@nMobile          INT,                  ' +
           '@nFunc            INT,                  ' +
           '@cLangCode        NVARCHAR( 3),         ' +
           '@cUserName        NVARCHAR( 18),        ' +
           '@cStorerKey       NVARCHAR( 15),        ' +
           '@cFacility        NVARCHAR( 5),         ' +
           '@cLOC         NVARCHAR( 10),        ' +
           '@cID              NVARCHAR( 18),        ' +
           '@cLOT             NVARCHAR( 10),        ' +
           '@cUCC             NVARCHAR( 20),        ' +
           '@cSKU             NVARCHAR( 20),        ' +
           '@nQTY             INT,                  ' +
           '@cSuggestedLOC    NVARCHAR( 10) OUTPUT, ' +
           '@cPickAndDropLoc  NVARCHAR( 10) OUTPUT, ' +
           '@nPABookingKey    INT           OUTPUT, ' +
           '@nErrNo           INT           OUTPUT, ' +
           '@cErrMsg          NVARCHAR( 20) OUTPUT  '

   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
        @nMobile, @nFunc, @cLangCode, @cUserName, @cStorerKey, @cFacility, @cLOC, @cID, @cLOT, @cUCC, @cSKU, @nQTY,
        @cSuggestedLOC OUTPUT, @cPickAndDropLoc OUTPUT, @nPABookingKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN
      SET @nErrNo = -1 --Fail
      GOTO Quit
   END

   SELECT @cPutawayZone = PutawayZone
      FROM dbo.LOC (NOLOCK)
   WHERE LOC = @cSuggestedLoc

   IF ISNULL(@cPutawayZone,'') = ''
   BEGIN
      SET @nErrNo = -1 --Fail
      GOTO Quit
   END

   Quit:

END



GO