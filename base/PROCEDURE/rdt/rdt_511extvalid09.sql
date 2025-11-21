SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/
/* Store procedure: rdt_511ExtValid09                                            */
/* Copyright      : Maersk                                                       */
/*                                                                               */
/* Purpose: For Grape Galina                                                     */
/*                                                                               */
/* Date        Rev      Author     Purposes                                      */
/* 2025-02-14  1.0.0    JCH507     FCR-2597. Created                             */
/*********************************************************************************/

CREATE PROC rdt.rdt_511ExtValid09 (
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bDebugFlag     BINARY = 0
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cKITUsrDef4    NVARCHAR( 30)
   
   SELECT
      @cFacility = Facility, 
      @cUserName = UserName
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFunc = 511 -- Move by ID
   BEGIN
      IF @nStep = 1 -- From Id
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT TOP 1
               @cKITUsrDef4 = ISNULL(KIT.USRDEF4, '')
            FROM KIT WITH (NOLOCK)
            JOIN KITDETAIL WITH (NOLOCK) 
               ON KIT.KITKey = KITDETAIL.KITKey
            WHERE KIT.Facility = @cFacility
               AND   KIT.StorerKey = @cStorerKey
               AND   KIT.[Status] <> '9'
               AND   KITDETAIL.Id = @cFromID
               AND   KITDETAIL.[Type] = 'F'

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 233301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID not associated
               GOTO Quit
            END

            IF @cKITUsrDef4 = ''
            BEGIN
               SET @nErrNo = 233302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No production line  
               GOTO Quit
            END

            --Check FinalLoc is valid
            IF NOT EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cKITUsrDef4)
            BEGIN
               SET @nErrNo = 233303
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- production line not exists  
               GOTO Quit
            END
            
         END --inputkey=1
      END --step=1
   
      Quit:
   END

GO