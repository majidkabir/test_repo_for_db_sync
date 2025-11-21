SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtSNVal04                                        */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 21-08-2023  1.0  Ung          WMS-23485 Created                            */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_1580ExtSNVal04
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

   DECLARE @cReceiptKey NVARCHAR( 10)
   DECLARE @cChkStatus  NVARCHAR( 10)
   DECLARE @cASNType    NVARCHAR( 1)

   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      -- Get Receipt info
      SET @cReceiptKey = @cDocNo
      SELECT @cASNType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
      
      -- Normal ASN
      IF @cASNType = 'A'
      BEGIN
         -- Check SNO received
         IF EXISTS( SELECT TOP 1 1
            FROM ReceiptSerialNo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND SerialNo = @cSerialNo)
         BEGIN
            SET @nErrNo = 205601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
            GOTO Quit
         END
         
         -- Check SNO received
         IF EXISTS( SELECT TOP 1 1
            FROM SerialNo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND SerialNo = @cSerialNo)
         BEGIN
            SET @nErrNo = 205602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
            GOTO Quit
         END
      END
      
      -- Return
      IF @cASNType = 'R'
      BEGIN
         -- Get serial no info
         SELECT @cChkStatus = Status
         FROM SerialNo WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo
         
         -- SNO not received
         IF @@ROWCOUNT = 0
         BEGIN
            IF EXISTS( SELECT TOP 1 1
               FROM ReceiptSerialNo WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND SerialNo = @cSerialNo)
            BEGIN
               SET @nErrNo = 205603
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
               GOTO Quit
            END
         END         
         
         -- SNO received
         ELSE 
         BEGIN
            -- Check serial no received
            IF @cChkStatus BETWEEN '1' AND '6' OR 
               @cChkStatus = 'HOLD'
            BEGIN
               SET @nErrNo = 205604
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
               GOTO Quit
            END
         
            -- 9=Shipped is allowed, for return
            -- CANC=cancel is allowed, mark as lost and rereceive
         END
      END
   END

Quit:

END


GO