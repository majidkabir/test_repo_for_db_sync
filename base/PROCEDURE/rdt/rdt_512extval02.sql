SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_512ExtVal02                                     */
/* Purpose: Move By LOC Extended Validate                               */
/*                                                                      */
/* Called from: rdtfnc_Move_LOC                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 10-Aug-2017 1.0  Ung        WMS-2602 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_512ExtVal02] (
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 512 -- Move by LOC
   BEGIN      
      IF @nStep = 2 -- To LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cToLOC <> ''
            BEGIN
               DECLARE @cLocationFlag NVARCHAR( 10)
               DECLARE @cLocationCategory  NVARCHAR( 10)
               
               SELECT 
                  @cLocationFlag = LocationFlag, 
                  @cLocationCategory = LocationCategory
               FROM LOC WITH (NOLOCK)
               WHERE LOC = @cToLOC
               
               IF @cLocationFlag = 'Inactive' OR @cLocationCategory = 'Disable'
               BEGIN
                  SET @nErrNo = 113651
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INACTIVE/DISABLE LOC
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '113651 ', @cErrMsg
                  GOTO Quit
               END
            END
         END
      END
   END

QUIT:

GO