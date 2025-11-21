SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_534ExtSNVal01                                         */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 30-07-2023  1.0  Ung          WMS-23069 based on rdt_838ExtSNVal           */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_534ExtSNVal01
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
   DECLARE @cChkID            NVARCHAR(18)
   DECLARE @cChkSKU           NVARCHAR(20)
   DECLARE @cChkStatus        NVARCHAR(10)
   DECLARE @cChkExternStatus  NVARCHAR(10)

   IF @nFunc = 534 -- Move to ID
   BEGIN
      -- Get serial no info
      SELECT TOP 1 
         @cChkID = ID, 
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
         SET @nErrNo = 204551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not exists
         GOTO Quit
      END
         
      -- Check SNO multi line
      IF @cChkSKU <> @cSKU
      BEGIN
         SET @nErrNo = 204552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff SKU
         GOTO Quit
      END
         
      IF @cChkStatus <> '1'
      BEGIN
         -- Check SNO received
         IF @cChkStatus = '0'
         BEGIN
            SET @nErrNo = 204553
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO NotYet RCV
            GOTO Quit
         END
   
         -- Check SNO received
         ELSE IF @cChkStatus = '5'
         BEGIN
            SET @nErrNo = 204554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady picked
            GOTO Quit
         END
         
         -- Check SNO received
         ELSE IF @cChkStatus = '6'
         BEGIN
            SET @nErrNo = 204555
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady packed
            GOTO Quit
         END

         -- Check SNO received
         ELSE IF @cChkStatus = '9'
         BEGIN
            SET @nErrNo = 204556
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady ship
            GOTO Quit
         END
         
         -- Check SNO received
         ELSE IF @cChkStatus = 'H'
         BEGIN
            SET @nErrNo = 204559
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO is HOLD
            GOTO Quit
         END
         
         -- Status unknown
         ELSE
         BEGIN
            SET @nErrNo = 204557
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad SNO status
            GOTO Quit
         END
      END
      
      IF @cChkExternStatus = 'H'
      BEGIN
         SET @nErrNo = 204560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO is HOLD
         GOTO Quit
      END
      
      -- Check SNO already scanned
      IF EXISTS( SELECT 1 
         FROM rdt.rdtMoveToIDLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo)
      BEGIN
         SET @nErrNo = 204558
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
         GOTO Quit
      END
      
      DECLARE @cFromLOC NVARCHAR( 10)
      SELECT @cFromLOC = V_String1 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

      -- Check ID match
      IF NOT EXISTS( SELECT 1
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND LOC = @cFromLOC
            AND ID = @cChkID
            AND QTY - QTYAllocated - QTYPicked - (CASE WHEN QtyReplen < 0 THEN 0 ELSE QtyReplen END) > 0)
      BEGIN
         SET @nErrNo = 204561
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO diff ID
         GOTO Quit
      END
   END

Quit:

END


GO