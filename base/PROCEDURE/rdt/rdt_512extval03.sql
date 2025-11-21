SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_512ExtVal03                                     */
/* Purpose: Move By LOC Extended Validate                               */
/*                                                                      */
/* Called from: rdtfnc_Move_LOC                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2021-09-03  1.0  James      WMS-17820. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_512ExtVal03] (
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

   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cOPSPosition   NVARCHAR( 60)
   DECLARE @cLocationCategory NVARCHAR( 10)
   DECLARE @cLocationFlag     NVARCHAR( 10)
   
   SELECT
      @cFacility = Facility, 
      @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cOPSPosition = OPSPosition 
   FROM rdt.RDTUser WITH (NOLOCK) 
   WHERE UserName = @cUserName
   
   IF @nFunc = 512 -- Move by LOC
   BEGIN      
      IF @nStep = 2 -- To LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cToLOC <> ''
            BEGIN
               SELECT 
                  @cLocationCategory = LocationCategory, 
                  @cLocationFlag = LocationFlag
               FROM dbo.LOC WITH (NOLOCK)
               WHERE Facility = @cFacility
               AND   Loc = @cToLOC

               IF @cOPSPosition = 'B2B'
               BEGIN
                  IF @cLocationFlag = 'HOLD' AND 
                     EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                              WHERE LISTNAME = 'NonITFLoc'
                              AND   Code = @cLocationCategory
                              AND   Storerkey = @cStorerKey) 
                  BEGIN
                     SET @nErrNo = 175551
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff HOLD Loc
                     GOTO Quit
                  END
               END
               
               IF @cOPSPosition = 'B2C'
               BEGIN
                  IF @cLocationFlag = 'HOLD' AND 
                     NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                                  WHERE LISTNAME = 'NonITFLoc'
                                  AND   Code = @cLocationCategory
                                  AND   Storerkey = @cStorerKey) 
                  BEGIN
                     SET @nErrNo = 175552
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Diff HOLD Loc
                     GOTO Quit
                  END
               END
            END
         END
      END
   END

QUIT:

GO