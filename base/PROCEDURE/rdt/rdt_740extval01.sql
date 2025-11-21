SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_740ExtVal01                                     */
/* Purpose: Trolley build                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2013-05-20 1.0  Ung        SOS259761. Created                        */
/* 2015-06-11 1.1  Ung        SOS343960                                 */
/*                            Change ExtendedUpdate to ExtendedValidate */
/*                            Rename rdtVFTBExtUpd to rdt_740ExtVal01   */
/************************************************************************/

CREATE PROC [RDT].[rdt_740ExtVal01] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nInputKey     INT, 
   @cStorerKey    NVARCHAR( 15), 
   @cUCC          NVARCHAR( 20),
   @cPutawayZone  NVARCHAR( 10),
   @cSuggestedLOC NVARCHAR( 10),
   @cTrolleyNo    NVARCHAR( 10),
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   
   IF @nFunc = 740 -- Trolley build
   BEGIN
      IF @nStep = 1 -- UCC or trolley
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cUCC <> ''
            BEGIN
               DECLARE @cOrderKey NVARCHAR(10)
               DECLARE @cUOM NVARCHAR( 10)
               DECLARE @cType NVARCHAR( 10)
               
               -- Get UCC info
               SELECT TOP 1 
                  @cOrderKey = OrderKey, 
                  @cUOM = UOM
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
                  AND Status < '9' -- Exclude cancel order that ship out and generate ASN, and re-receive the same UCC
                  AND DropID = @cUCC

               -- Get order info
               SELECT @cType = Type FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               -- Check full case 
               IF @cUOM = '2' AND @cType <> 'VFLeisure'
               BEGIN
                  SET @nErrNo = 81201
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotForPicking
                  GOTO Fail
               END
            END
         END
      END

      IF @nStep = 2 -- Close trolley
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF LEFT( @cTrolleyNo, 3) <> 'TRO'
            BEGIN
               SET @nErrNo = 81202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Bad TrolleyNo
               GOTO Fail
            END
         END
      END
   END
      
Quit:
Fail:

END

GO