SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_511ExtValid01                                   */
/* Purpose: Move By ID Extended Validate                                */
/*                                                                      */
/* Called from: rdtfnc_Move_ID                                          */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 02-Sep-2015 1.0  James      SOS348153 - Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_511ExtValid01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cFromID          NVARCHAR( 18),    
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   SET @nErrNo = 0

   DECLARE @cStorerGroup      NVARCHAR( 20)

   SELECT @cStorerGroup = @cStorerGroup FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         IF ISNULL( @cFromLOC, '') = ''
            SELECT TOP 1 @cFromLoc = LOC
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
            WHERE ID = @cFromID
            AND  (QTY - QTYALLOCATED - QTYPICKED - 
                 (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0)
            AND  EXISTS ( SELECT 1 FROM dbo.StorerGroup SG WITH (NOLOCK) 
                          WHERE SG.StorerGroup = @cStorerGroup 
                          AND SG.StorerKey = LLI.StorerKey)

         IF EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                     WHERE LOC = @cFromLOC 
                     AND   Facility = 'BULIM')
         BEGIN
            SET @nErrNo = 56351  -- WRONG FACILITY
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID WITH (NOLOCK) 
                     WHERE ID = @cFromID
                     AND  (QTYAllocated + QTYPicked + 
                          (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END)) > 0)
         BEGIN
            SET @nErrNo = 56352  -- OPEN TRN EXIST
            GOTO Quit
         END
      END

      IF @nStep = 3
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                         WHERE LOC = @cToLOC 
                         AND   Facility = 'BULIM')
         BEGIN
            SET @nErrNo = 56353  -- WRONG FACILITY
            GOTO Quit
         END
      END
   END

QUIT:

GO