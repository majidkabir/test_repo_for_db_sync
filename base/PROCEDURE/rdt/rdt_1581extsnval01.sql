SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581ExtSNVal01                                        */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 2024-06-27  1.0  James        UWP-1930. Created                            */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_1581ExtSNVal01
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

   DECLARE @cReceiptKey       NVARCHAR( 10)
   DECLARE @cChkSerialSKU     NVARCHAR( 20)
   DECLARE @nChkSerialQTYExp  INT
   DECLARE @nChkSerialQTY     INT
   DECLARE @nRowCount         INT

   IF @nFunc = 1581 -- Piece receiving
   BEGIN
      -- Get Receipt info
      SET @cReceiptKey = @cDocNo

      -- Get serial no info
      SELECT
         @nChkSerialQTYExp = QTYExpected,
         @cChkSerialSKU = SKU,
         @nChkSerialQTY = QTY
      FROM ReceiptSerialNo WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND StorerKey = @cStorerKey
         AND SerialNo = @cSerialNo
      SET @nRowCount = @@ROWCOUNT

      IF @nRowCount = 0
         GOTO Quit   -- New serial no
      ELSE IF @nRowCount = 1
      BEGIN
         -- Check SKU matches
         IF @cChkSerialSKU <> @cSKU
         BEGIN
            SET @nErrNo = 217651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff SKU
            GOTO Quit
         END

         -- Check QTY matches
         IF @nChkSerialQTYExp <> @nQTY
         BEGIN
            SET @nErrNo = 217652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff QTY
            GOTO Quit
         END

         -- Check serial no received
         IF @nChkSerialQTY <> 0
         BEGIN
            SET @nErrNo = 217653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady rcv
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 217654
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNOMultiRecord
         GOTO Quit
      END

      -- Check SNO received
      IF EXISTS( SELECT TOP 1 1
         FROM ReceiptSerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            -- AND SKU = @cSKU
            AND SerialNo = @cSerialNo)
      BEGIN
         SET @nErrNo = 211051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO received
         GOTO Quit
      END
   END

   Quit:

END

GO