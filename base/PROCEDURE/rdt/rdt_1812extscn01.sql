SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtScn01                                     */
/* Copyright      :                                                     */
/*                                                                      */
/* Purpose:       For Unilever                                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-03-21 1.0  Dennis   Draft                                       */
/*                                                                      */
/************************************************************************/

CREATE   PROC [rdt].[rdt_1812ExtScn01] (
	@nMobile      INT,           
	@nFunc        INT,           
	@cLangCode    NVARCHAR( 3),  
	@nStep INT,           
	@nScn  INT,           
	@nInputKey    INT,           
	@cFacility    NVARCHAR( 5),  
	@cStorerKey   NVARCHAR( 15), 

	@cLOC         NVARCHAR( 20) OUTPUT, 

   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,  
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,   
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,  
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,   
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,   
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,  
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,  
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,  
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,  
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,  
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,  
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,  
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,  
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,  
	@nAction      INT, --0 Jump Screen, 1 Validation(pass through all input fields), 2 Update, 3 Prepare output fields .....
	@nAfterScn    INT OUTPUT, @nAfterStep    INT OUTPUT, 
   @nErrNo             INT            OUTPUT, 
   @cErrMsg            NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
   @nRowCount            INT,
   @cPalletTypeInUse     NVARCHAR( 5),
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeSave      NVARCHAR( 10)

   IF @nAction = 1 --Validate fields
   BEGIN
	   IF @nFunc = 1812
	   BEGIN
         IF @nInputKey = 1
         BEGIN
            IF ( @nStep IN (2,6) )
            BEGIN
               SELECT
                  @nCheckDigit = CheckDigitLengthForLocation
               FROM dbo.FACILITY WITH (NOLOCK)
               WHERE facility = @cFacility
      
               IF @nCheckDigit > 0 
               BEGIN
                  SELECT @cActLoc = loc 
                  FROM dbo.LOC WITH (NOLOCK)
                  WHERE Facility = @cFacility AND CONCAT(LOC,LOCCHECKDIGIT) = @cLOC
                  SET @nRowCount = @@ROWCOUNT
                  IF @nRowCount > 1
                  BEGIN
                     SET @nErrNo = 212603
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212603Unique location not identified
                     GOTO QUIT
                  END
                  ELSE IF @nRowCount = 0
                  BEGIN
                     SET @nErrNo = 212604
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212604Loc Not Found
                     GOTO QUIT
                  END
                  SET @cLOC = @cActLoc
                  GOTO QUIT
               END
            END
         END

		END
      GOTO Quit
	END
Exception:
   ROLLBACK TRANSACTION

Quit:

END; 

SET QUOTED_IDENTIFIER OFF 

GO