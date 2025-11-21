SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_838ExtSNVal                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 23-05-2017  1.0  Ung          WMS-1919 Created                             */
/* 04-09-2017  1.1  Ung          WMS-2795 Fix SerialNo already scanned        */
/* 28-11-2017  1.2  Ung          WMS-3540 Add serial no HOLD                  */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_838ExtSNVal]
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

   DECLARE @nRowCount  INT
   DECLARE @cChkStatus NVARCHAR(10)
   DECLARE @cChkExternStatus NVARCHAR(10)

   IF @nFunc = 838 -- Pack
   BEGIN
      -- Get serial no info
      SELECT 
         @cChkStatus = Status, 
         @cChkExternStatus = ExternStatus
      FROM SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo
      SET @nRowCount = @@ROWCOUNT

      -- Check SNO in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 109851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not exists
         GOTO Quit
      END
         
      -- Check SNO multi line
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 109852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNOMultiRecord
         GOTO Quit
      END
         
      IF @cChkStatus <> '1'
      BEGIN
         -- Check SNO received
         IF @cChkStatus = '0'
         BEGIN
            SET @nErrNo = 109853
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO NotYet RCV
            GOTO Quit
         END
   
         -- Check SNO received
         ELSE IF @cChkStatus = '5'
         BEGIN
            SET @nErrNo = 109854
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady picked
            GOTO Quit
         END
         
         -- Check SNO received
         ELSE IF @cChkStatus = '6'
         BEGIN
            SET @nErrNo = 109855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady packed
            GOTO Quit
         END

         -- Check SNO received
         ELSE IF @cChkStatus = '9'
         BEGIN
            SET @nErrNo = 109856
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady ship
            GOTO Quit
         END
         
         -- Check SNO received
         ELSE IF @cChkStatus = 'H'
         BEGIN
            SET @nErrNo = 109859
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO is HOLD
            GOTO Quit
         END
         
         -- Status unknown
         ELSE
         BEGIN
            SET @nErrNo = 109857
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad SNO status
            GOTO Quit
         END
      END
      
      IF @cChkExternStatus = 'H'
      BEGIN
         SET @nErrNo = 109860
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO is HOLD
         GOTO Quit
      END
      
      -- Check SNO already scanned
      IF EXISTS( SELECT 1 
         FROM PackSerialNo WITH (NOLOCK)
         WHERE PickSlipNo = @cDocNo
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo)
      BEGIN
         SET @nErrNo = 109858
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
         GOTO Quit
      END
   END

Quit:

END


GO