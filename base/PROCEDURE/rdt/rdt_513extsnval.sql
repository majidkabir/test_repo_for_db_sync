SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_513ExtSNVal                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 04-12-2017  1.0  Ung          WMS-3547 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtSNVal]
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
   DECLARE @cChkSKU            NVARCHAR(20)

   IF @nFunc = 513 -- Move by SKU
   BEGIN
      -- Get serial no info
      DECLARE @cChkStatus NVARCHAR(10)
      DECLARE @cChkID NVARCHAR(18)
      SELECT 
         @cChkStatus = Status, 
         @cChkID = ID
      FROM SerialNo WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo

      -- Check serial no valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 117751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not exist
         GOTO Quit
      END
      
      -- Check serial no shipped before
      IF @cChkStatus NOT IN ('1', 'H')
      BEGIN
         SET @nErrNo = 117752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO bad status
         GOTO Quit
      END
      
      -- Get session info
      DECLARE @cFromID NVARCHAR(18)
      SELECT @cFromID = V_ID FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
      
      -- Check serial no ID
      IF @cChkID <> @cFromID
      BEGIN
         SET @nErrNo = 117753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO not on ID
         GOTO Quit
      END
      
      -- Check duplicate scan
      IF EXISTS( SELECT 1 
         FROM rdt.rdtMoveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND SerialNo = @cSerialNo)
      BEGIN
         SET @nErrNo = 117754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO scanned
         GOTO Quit
      END
   END

Quit:

END


GO