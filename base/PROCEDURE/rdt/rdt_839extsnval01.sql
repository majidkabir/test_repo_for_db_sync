SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839ExtSNVal01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 28-07-2023  1.0  Ung          WMS-23002 based on rdt_838ExtSNVal           */
/* 11-10-2023  1.1  Ung          WMS-23832 remove check SN in PickSerialNo    */
/*                               Control by SerialNo.Status                   */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839ExtSNVal01]
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

   DECLARE @nRowCount         INT
   DECLARE @cChkSKU           NVARCHAR(20)
   DECLARE @cChkStatus        NVARCHAR(10)
   DECLARE @cChkExternStatus  NVARCHAR(10)

   IF @nFunc = 839 -- Pick piece
   BEGIN
      -- Get serial no info
      SELECT TOP 1 
         @cChkSKU = SKU, 
         @cChkStatus = Status, 
         @cChkExternStatus = ExternStatus
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         -- AND SKU = @cSKU
         AND SerialNo = @cSerialNo
      ORDER BY CASE WHEN SKU = @cSKU THEN 1 ELSE 2 END
      SET @nRowCount = @@ROWCOUNT

      -- Check SNO in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 204501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not exists
         GOTO Quit
      END
         
      -- Check SNO multi line
      IF @cChkSKU <> @cSKU
      BEGIN
         SET @nErrNo = 204502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff SKU
         GOTO Quit
      END
         
      IF @cChkStatus <> '1'
      BEGIN
         -- Check SNO received
         IF @cChkStatus = '0'
         BEGIN
            SET @nErrNo = 204503
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO NotYet RCV
            GOTO Quit
         END
   
         -- Check SNO received
         ELSE IF @cChkStatus = '5'
         BEGIN
            SET @nErrNo = 204504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady picked
            GOTO Quit
         END
         
         -- Check SNO received
         ELSE IF @cChkStatus = '6'
         BEGIN
            SET @nErrNo = 204505
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady packed
            GOTO Quit
         END

         -- Check SNO received
         ELSE IF @cChkStatus = '9'
         BEGIN
            SET @nErrNo = 204506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady ship
            GOTO Quit
         END
         
         -- Check SNO received
         ELSE IF @cChkStatus = 'H'
         BEGIN
            SET @nErrNo = 204509
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO is HOLD
            GOTO Quit
         END
         
         -- Status unknown
         ELSE
         BEGIN
            SET @nErrNo = 204507
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad SNO status
            GOTO Quit
         END
      END
      
      IF @cChkExternStatus = 'H'
      BEGIN
         SET @nErrNo = 204510
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO is HOLD
         GOTO Quit
      END
      
      /*
      -- Check SNO already scanned
      IF EXISTS( SELECT 1 
         FROM PickSerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo)
      BEGIN
         SET @nErrNo = 204508
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
         GOTO Quit
      END
      */
   END

Quit:

END


GO