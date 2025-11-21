SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1637ExtValid04                                        */
/* Copyright      : LF Logistics                                              */  
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2020-05-29 1.0  Ung        WMS-13537 Created                               */
/* 2020-07-21 1.1  Ung        WMS-14235 Change order consignee, storer mapping*/
/******************************************************************************/

CREATE PROC [RDT].[rdt_1637ExtValid04] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerkey    NVARCHAR( 15),
   @cContainerKey NVARCHAR( 10),
   @cContainerNo  NVARCHAR( 20),
   @cMBOLKey      NVARCHAR( 10),
   @cSSCCNo       NVARCHAR( 20),
   @cPalletKey    NVARCHAR( 30),
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

   IF @nStep = 3 -- PalletKey
   BEGIN
      IF @nInputKey = 1  -- ENTER
      BEGIN
         DECLARE @cCurrPalletKey NVARCHAR( 30)
         DECLARE @cCurrHubCode   NVARCHAR( 45)
         DECLARE @cNewHubCode    NVARCHAR( 45)
         DECLARE @cConsigneeKey  NVARCHAR( 15)
         DECLARE @cCaseID        NVARCHAR( 20)

         -- Check pallet valid
         IF NOT EXISTS( SELECT 1
            FROM Pallet WITH (NOLOCK) 
            WHERE PalletKey = @cPalletKey
               AND StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 153201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PLKey
            GOTO Fail         
         END

         -- Get any existing pallet
         SET @cCurrPalletKey = ''
         SELECT TOP 1
            @cCurrPalletKey = PalletKey
         FROM ContainerDetail WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey

         -- There is existing pallet
         IF @cCurrPalletKey <> ''
         BEGIN
            -- Get a random carton on exist pallet
            SELECT TOP 1
               @cCaseID = CaseID
            FROM Pallet P WITH (NOLOCK)
               JOIN PalletDetail PD WITH (NOLOCK) ON (P.PalletKey = PD.PalletKey)
            WHERE P.PalletKey = @cCurrPalletKey

            -- Get Order info
            SELECT @cConsigneeKey = LEFT( @cCaseID, 7)
            
            -- Remove leading zero
            WHILE LEFT( @cConsigneeKey, 1) = '0'
               SET @cConsigneeKey = SUBSTRING( @cConsigneeKey, 2, LEN( @cConsigneeKey))

            -- Get exist hub code
            SELECT @cCurrHubCode = ISNULL( B_City, '') 
            FROM Storer WITH (NOLOCK) 
            WHERE SUBSTRING( StorerKey, 4, 15) = @cConsigneeKey 
               AND Type = '2'
               AND ConsigneeFor = @cStorerKey

            -- Get a random carton on new pallet
            SELECT TOP 1
               @cCaseID = CaseID
            FROM Pallet P WITH (NOLOCK)
               JOIN PalletDetail PD WITH (NOLOCK) ON (P.PalletKey = PD.PalletKey)
            WHERE P.PalletKey = @cPalletKey

            -- Get Order info
            SELECT @cConsigneeKey = LEFT( @cCaseID, 7)
            
            -- Remove leading zero
            WHILE LEFT( @cConsigneeKey, 1) = '0'
               SET @cConsigneeKey = SUBSTRING( @cConsigneeKey, 2, LEN( @cConsigneeKey))

            -- Get new hub code
            SELECT @cNewHubCode = ISNULL( B_City, '') 
            FROM Storer WITH (NOLOCK) 
            WHERE SUBSTRING( StorerKey, 4, 15) = @cConsigneeKey 
               AND Type = '2'
               AND ConsigneeFor = @cStorerKey

            -- Check same hub code
            IF @cCurrHubCode <> @cNewHubCode
            BEGIN
               SET @nErrNo = 153202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff Hub Code
               GOTO Fail
            END
         END
      END
   END

Fail:


GO