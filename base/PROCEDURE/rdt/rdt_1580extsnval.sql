SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtSNVal                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 09-05-2017  1.0  Ung          WMS-1817 Created                             */
/* 16-10-2017  1.1  Ung          WMS-3173 Check Receipt.UDF vs SerialNo.UDF   */
/* 24-11-2017  1.2  Ung          WMS-3508 Add hold serial no                  */
/* 01-02-2018  1.3  Ung          WMS-3173 Check Receipt.UDF vs SerialNo.UDF   */
/* 08-01-2019  1.4  Ung          WMS-7405 Remove SNO in different ASN         */
/* 04-03-2020  1.5  James        WMS-12331 Add pallet qty check (james01)     */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtSNVal]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT, 
   @cSerialNo        NVARCHAR( 30),
   @cType            NVARCHAR( 15), --CHECK/INSERT
   @cDocType         NVARCHAR( 10), 
   @cDocNo           NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount          INT
   DECLARE @cReceiptKey        NVARCHAR(10)
   DECLARE @cChkSKU            NVARCHAR(20)
   DECLARE @cChkStatus         NVARCHAR(10)
   DECLARE @nBeforeReceivedQty INT
   DECLARE @cASNType           NVARCHAR(1)
   DECLARE @nPallet            INT           -- (james01)
   DECLARE @nID_Qty            INT           -- (james01)
   DECLARE @cToID              NVARCHAR( 18) -- (james01)

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      -- Get Receipt info
      SET @cReceiptKey = @cDocNo
      SELECT @cASNType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
      
      -- Normal ASN
      IF @cASNType = 'A'
      BEGIN
         -- Get ReceiptDetail info
         SELECT 
            @cChkSKU = SKU, 
            @nBeforeReceivedQty = BeforeReceivedQty
         FROM ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND StorerKey = @cStorerKey
            -- AND SKU = @cSKU
            AND UserDefine01 = @cSerialNo
         SET @nRowCount = @@ROWCOUNT
         
         -- Check SNO in ASN
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 109101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not in ASN
            GOTO Quit
         END
         
         -- Check SNO multi line
         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 109102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO dup in ASN
            GOTO Quit
         END
         
         -- Check SNO diff SKU
         IF @cChkSKU <> @cSKU
         BEGIN
            SET @nErrNo = 109103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO diff SKU
            GOTO Quit
         END
         
         -- Check SNO received
         IF @nBeforeReceivedQty > 0
         BEGIN
            SET @nErrNo = 109104
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
            GOTO Quit
         END
         
         -- (james01)
         SELECT @nPallet = Pallet
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.SKU = @cSKU
         
         SELECT @nID_Qty = ISNULL( SUM( BeforeReceivedQty), 0)
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   ToId = @cToID
         
         IF ( @nID_Qty + @nQTY) > @nPallet
         BEGIN
            SET @nErrNo = 109112
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RCV>PALLET Qty
            GOTO Quit
         END
      END
      
      -- Return
      IF @cASNType = 'R'
      BEGIN
         -- Storer configure
         DECLARE @cCheckSerialNoShip NVARCHAR(20)
         SET @cCheckSerialNoShip = rdt.RDTGetConfig( @nFunc, 'CheckSerialNoShipByUs', @cStorerKey)
         
         IF @cCheckSerialNoShip = '1'
         BEGIN
            -- Get receipt info 
            DECLARE @cReceiptUDF NVARCHAR( 40)
            DECLARE @cReturnFrom NVARCHAR( 30)
            SELECT 
               @cReceiptUDF = ISNULL( UserDefine01, '') + ISNULL( UserDefine02, ''), -- The order being return
               @cReturnFrom = ISNULL( UserDefine03, '') 
            FROM Receipt WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
            
            -- Serial no ship by us
            IF @cReturnFrom = @cStorerKey
            BEGIN
               DECLARE @cSerialUDF NVARCHAR(40)
               
               -- Get serial no info
               SELECT 
                  @cSerialUDF = ISNULL( UserDefine01, '') + ISNULL( UserDefine02, ''),  -- Order that ship out this serial no (not OrderKey or ExternOrderKey)
                  @cChkStatus = Status
               FROM SerialNo WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND SerialNo = @cSerialNo

               -- Check serial no shipped before
               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 109105
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not exist
                  GOTO Quit
               END
                        
               IF @cSerialUDF <> @cReceiptUDF
               BEGIN
                  SET @nErrNo = 109106
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO NotInOrder
                  GOTO Quit
               END
               
               -- Check serial no shipped before
               IF @cChkStatus <> '9'
               BEGIN
                  SET @nErrNo = 109107
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO NotYetShip
                  GOTO Quit
               END
            END
         END
      END

      -- Get serial no info
      IF @cChkStatus IS NULL
         SELECT @cChkStatus = Status
         FROM SerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo

      -- Check serial no received
      IF @cChkStatus = '1'
      BEGIN
         SET @nErrNo = 109110
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
         GOTO Quit
      END
      
      /*
      -- Check serial no received to another ASN
      IF EXISTS( SELECT 1 
         FROM ReceiptDetail RD WITH (NOLOCK) 
            JOIN ReceiptSerialNo RSO WITH (NOLOCK) ON (RD.ReceiptKey = RSO.ReceiptKey AND RD.ReceiptLineNumber = RSO.ReceiptLineNumber)
         WHERE RD.ReceiptKey <> @cReceiptKey 
            AND RD.StorerKey = @cStorerKey
            AND RD.SKU = @cSKU
            AND RSO.SerialNo = @cSerialNo)
      BEGIN
         SET @nErrNo = 109111
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
         GOTO Quit
      END
      */
      
      -- Get hold LOC
      DECLARE @cHoldLOC NVARCHAR( 10)
      SET @cHoldLOC = rdt.RDTGetConfig( @nFunc, 'HoldLOC', @cStorerKey)         

      -- Get receiving LOC
      DECLARE @cLOC NVARCHAR( 10)
      SELECT @cLOC = V_LOC FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

      -- Serial no is hold
      IF EXISTS( SELECT 1 
         FROM SerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo
            AND Status = '0'
            AND ExternStatus = 'H')
      BEGIN
         -- Check NOT receive into hold LOC
         IF @cLOC <> @cHoldLOC
         BEGIN
            SET @nErrNo = 109108
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO is HOLD
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check receive into hold LOC
         IF @cLOC = @cHoldLOC
         BEGIN
            SET @nErrNo = 109109
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC is HOLD
            GOTO Quit
         END
      END
   END

Quit:

END


GO