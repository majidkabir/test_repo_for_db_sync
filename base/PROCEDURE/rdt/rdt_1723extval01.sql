SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1723ExtVal01                                    */
/*                                                                      */
/* Purpose: Validate pallet id                                          */
/*                                                                      */
/* Called from: rdtfnc_PalletConsolidate_SSCC                           */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 18-Sep-2017  1.0  James    WMS2991. Created                          */
/* 27-Dec-2017  1.1  James    WMS3665. Not allow pallet with different  */
/*                            Lot07 to be merged (james01)              */
/* 02-Jul-2018  1.2  James    WMS5526. Add step 6 validation (james02)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_1723ExtVal01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cFromID         NVARCHAR( 18),
   @cToID           NVARCHAR( 10),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @nMultiStorer    NVARCHAR( 10),
   @cOption         NVARCHAR( 1),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cErrMsg1    NVARCHAR( 20), 
            @cErrMsg2    NVARCHAR( 20),
            @cErrMsg3    NVARCHAR( 20), 
            @cErrMsg4    NVARCHAR( 20),
            @cErrMsg5    NVARCHAR( 20)

   DECLARE @cConsigneeKey  NVARCHAR( 15)

   IF @nFunc = 1723
   BEGIN
      IF @nStep = 1
      BEGIN
         -- Check if from pallet exists different lottable07
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.OrderDetail OD WITH (NOLOCK) ON 
                        ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                     WHERE PD.StorerKey = @cStorerKey
                     AND   PD.ID = @cFromID
                     AND   PD.Status < '9'
                     GROUP BY PD.ID
                     HAVING COUNT( DISTINCT OD.Lottable07) > 1)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 115204, @cLangCode, 'DSP'), 7, 14)
            SET @cErrMsg2 = rdt.rdtgetmessage( 115205, @cLangCode, 'DSP')
            SET @cErrMsg3 = rdt.rdtgetmessage( 115206, @cLangCode, 'DSP')

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
            IF @nErrNo = 1
            BEGIN
               SET @cErrMsg1 = ''
               SET @cErrMsg2 = ''
               SET @cErrMsg3 = ''
            END

            GOTO Quit
         END 
      END

      IF @nStep = 3
      BEGIN
         IF SUBSTRING( @cToID, 1, 1) = 'P'
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.CONTAINERDETAIL WITH (NOLOCK) 
                        WHERE PalletKey = @cToID)
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 115201, @cLangCode, 'DSP'), 7, 14)
               SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 115202, @cLangCode, 'DSP'), 7, 14)
               SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 115203, @cLangCode, 'DSP'), 7, 14)

               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
               IF @nErrNo = 1
               BEGIN
                  SET @cErrMsg1 = ''
                  SET @cErrMsg2 = ''
                  SET @cErrMsg3 = ''
               END

               GOTO Quit
            END  
         END

         -- If to pallet has inventory only check
         IF EXISTS ( SELECT 1 
                     FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
                     WHERE LLI.StorerKey = @cStorerKey 
                     AND   LLI.ID = @cToID 
                     AND   LOC.Facility = @cFacility
                     AND   Qty > 0)
         BEGIN
            -- To pallet must at least allocated only check
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   ID = @cToID
                        AND   [Status] < '9')
            BEGIN
               DECLARE @tLot07Value TABLE ( Lottable07    NVARCHAR( 30) NULL)

               INSERT INTO @tLot07Value (Lottable07)
               SELECT DISTINCT OD.Lottable07
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               WHERE PD.StorerKey = @cStorerKey
               AND   PD.ID = @cFromID
               AND   PD.Status < '9'
               
               IF EXISTS ( SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.ID = @cToID
                  AND   PD.Status < '9'
                  AND   NOT EXISTS ( SELECT 1 FROM @tLot07Value LV WHERE OD.Lottable07 = LV.Lottable07))
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 115207, @cLangCode, 'DSP'), 7, 14)
                  SET @cErrMsg2 = rdt.rdtgetmessage( 115208, @cLangCode, 'DSP')
                  SET @cErrMsg3 = rdt.rdtgetmessage( 115209, @cLangCode, 'DSP')

                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
                  IF @nErrNo = 1
                  BEGIN
                     SET @cErrMsg1 = ''
                     SET @cErrMsg2 = ''
                     SET @cErrMsg3 = ''
                  END

                  GOTO Quit
               END  
               /*
               DECLARE @tLot01Value TABLE ( Lottable01    NVARCHAR( 18) NULL)

               INSERT INTO @tLot01Value (Lottable01)
               SELECT DISTINCT OD.Lottable01
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               WHERE PD.StorerKey = @cStorerKey
               AND   PD.ID = @cFromID
               AND   PD.Status < '9'
               
               IF EXISTS ( SELECT 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.ID = @cToID
                  AND   PD.Status < '9'
                  AND   NOT EXISTS ( SELECT 1 FROM @tLot01Value LV WHERE OD.Lottable01 = LV.Lottable01))
               BEGIN
                  SET @nErrNo = 0
                  SET @cErrMsg1 = rdt.rdtgetmessage( 115210, @cLangCode, 'DSP')

                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1
                  IF @nErrNo = 1
                     SET @cErrMsg1 = ''

                  GOTO Quit
               END  
               */
               /*
               SELECT TOP 1 @cConsigneeKey = O.ConsigneeKey
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
               WHERE PD.StorerKey = @cStorerKey
               AND   PD.ID = @cFromID
               AND   PD.Status < '9'
               
               IF @cConsigneeKey = 'XDIV7901'
               BEGIN
                  DECLARE @tLot0102Value TABLE ( Lottable0102 NVARCHAR( 36) NULL)

                  INSERT INTO @tLot0102Value ( Lottable0102)
                  SELECT DISTINCT ISNULL( OD.Lottable01, '') + ISNULL( OD.Lottable02, '')
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                  WHERE PD.StorerKey = @cStorerKey
                  AND   PD.ID = @cFromID
                  AND   PD.Status < '9'

                 IF EXISTS ( SELECT 1
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
                     WHERE PD.StorerKey = @cStorerKey
                     AND   PD.ID = @cToID
                     AND   PD.Status < '9'
                     AND   NOT EXISTS ( SELECT 1 FROM @tLot0102Value LV WHERE (ISNULL( OD.Lottable01, '') + ISNULL( OD.Lottable02, '')) = LV.Lottable0102))
                  BEGIN
                     SET @nErrNo = 0
                     SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 115210, @cLangCode, 'DSP'), 7, 14)
                     SET @cErrMsg2 = rdt.rdtgetmessage( 115211, @cLangCode, 'DSP')
                     SET @cErrMsg3 = rdt.rdtgetmessage( 115212, @cLangCode, 'DSP')

                     EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
                     IF @nErrNo = 1
                     BEGIN
                        SET @cErrMsg1 = ''
                        SET @cErrMsg2 = ''
                        SET @cErrMsg3 = ''
                     END

                     GOTO Quit
                  END  
               END
               */
            END
         END
      END

      IF @nStep = 6
      BEGIN
         SELECT TOP 1 @cConsigneeKey = O.ConsigneeKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey AND PD.StorerKey = O.StorerKey)
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.ID = @cFromID
         AND   PD.Status < '9'

         
      END
   END

   QUIT:

END

GO