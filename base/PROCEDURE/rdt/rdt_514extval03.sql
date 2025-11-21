SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_514ExtVal03                                     */
/* Purpose: Validate UCC                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-08-10 1.0  Ung        WMS-2600 Created                          */
/* 2019-03-26 1.1  James      WMS-8352 Add From ID (james01)            */  
/************************************************************************/

CREATE PROC [RDT].[rdt_514ExtVal03] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cToID          NVARCHAR( 18),
   @cToLoc         NVARCHAR( 10),
   @cFromLoc       NVARCHAR( 10),
   @cFromID        NVARCHAR( 18), 
   @cUCC           NVARCHAR( 20),
   @cUCC1          NVARCHAR( 20),
   @cUCC2          NVARCHAR( 20),
   @cUCC3          NVARCHAR( 20),
   @cUCC4          NVARCHAR( 20),
   @cUCC5          NVARCHAR( 20),
   @cUCC6          NVARCHAR( 20),
   @cUCC7          NVARCHAR( 20),
   @cUCC8          NVARCHAR( 20),
   @cUCC9          NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 514
   BEGIN
      IF @nStep = 2 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
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
               SET @nErrNo = 113601
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INACTIVE/DISABLE LOC
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, '113601 ', @cErrMsg
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO