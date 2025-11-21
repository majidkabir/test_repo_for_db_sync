SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_512ExtValid01                                   */
/* Purpose: Move By LOC Extended Validate                               */
/*                                                                      */
/* Called from: rdtfnc_Move_LOC                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 02-Sep-2015 1.0  James      SOS348153 - Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_512ExtValid01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @cOption          NVARCHAR( 1), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                     WHERE LOC = @cFromLOC 
                     AND   Facility = 'BULIM')
         BEGIN
            SET @nErrNo = 94101  -- WRONG FACILITY
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK) 
                     WHERE LOC = @cFromLOC
                     AND  (QTYAllocated + QTYPicked +  
                          (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
         BEGIN
            SET @nErrNo = 94102  -- OPEN TRN EXIST
            GOTO Quit
         END
      END

      IF @nStep = 2
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                         WHERE LOC = @cToLOC 
                         AND   Facility = 'BULIM')
         BEGIN
            SET @nErrNo = 94103  -- WRONG FACILITY
            GOTO Quit
         END
      END
   END

QUIT:

GO