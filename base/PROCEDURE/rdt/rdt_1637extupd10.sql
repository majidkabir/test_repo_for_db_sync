SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1637ExtUpd10                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Update extra info into Container upon close container       */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-10-20 1.0  Ung        WMS-23860 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1637ExtUpd10] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerkey    NVARCHAR( 15),
   @cContainerKey NVARCHAR( 10),
   @cMBOLKey      NVARCHAR( 10),
   @cSSCCNo       NVARCHAR( 20),
   @cPalletKey    NVARCHAR( 18),
   @cTrackNo      NVARCHAR( 20),
   @cOption       NVARCHAR( 1),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1637 -- Scan to container
   BEGIN
      IF @nStep = 6  -- Close container
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
           DECLARE @cData1 NVARCHAR(60)
           DECLARE @cData2 NVARCHAR(60)

            -- Get session info
            SELECT 
               @cData1 = V_String42,
               @cData2 = V_String43
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            UPDATE dbo.Container SET
               Vessel = @cData1,
               Seal01 = @cData2, 
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE ContainerKey = @cContainerKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 207651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd Cont Fail
               GOTO Quit
            END
         END
      END
   END

Quit:

GO