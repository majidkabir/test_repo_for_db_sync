SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_644ExtValid01                                   */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Check validity of tracking id                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-03-24  1.0  James       WMS-12432. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_644ExtValid01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cRefNo         NVARCHAR( 20),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cParentTrackID NVARCHAR( 20),
   @cChildTrackID  NVARCHAR( 1000),
   @cSKU           NVARCHAR( 10),
   @nQty           INT,
   @cOption        NVARCHAR( 1),
   @tExtValidate   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPallet_SKU    NVARCHAR( 20)
   DECLARE @cUserDefine02  NVARCHAR( 30)
   DECLARE @nPos_Cnt       INT = 0
   DECLARE @nSKU_Cnt       INT = 0
   DECLARE @cPosition      NVARCHAR( 10)
   
   IF @nStep = 1
   BEGIN
      SELECT @cUserDefine02 = UserDefine02
      FROM dbo.RECEIPT WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      
      IF ISNULL( @cUserDefine02, '') = ''
         GOTO Quit

      SELECT @nSKU_Cnt = COUNT( DISTINCT SKU)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      
      SELECT @nPos_Cnt = COUNT( DISTINCT DevicePosition)
      FROM dbo.DeviceProfile WITH (NOLOCK)
      WHERE DeviceID = @cUserDefine02
      AND   StorerKey = @cStorerKey
      
      IF @nSKU_Cnt > @nPos_Cnt
      BEGIN
         SET @nErrNo = 150101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pos Not Enuf
         GOTO Quit
      END
   END

   IF @nStep = 3 -- SKU, Child Tracking ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cPosition = SUBSTRING( O_FIELD15, 6, 2)
         FROM rdt.RDTMOBREC WITH (nolock)
         WHERE Mobile = @nMobile

         IF ISNULL( @cPosition, '') = ''
         BEGIN
            SET @nErrNo = 150103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Loc
            GOTO Quit
         END
      END
   END
   IF @nStep = 4 -- To ID, Parent Tracking ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         -- 1 Pallet 1 SKU
         SELECT TOP 1 @cPallet_SKU = SKU
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentTrackingID = @cParentTrackID
         AND   [Status] = '0'
         ORDER BY 1
         
         IF ISNULL( @cPallet_SKU, '') <> ''
         BEGIN
            IF @cSKU <> @cPallet_SKU
            BEGIN
               SET @nErrNo = 150102
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cannot Mix SKU
               GOTO Quit
            END
         END
      END
   END

Quit:
END

GO