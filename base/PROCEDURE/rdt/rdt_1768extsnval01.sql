SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1768ExtSNVal01                                        */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 2024-07-29  1.0  James        WMS-23113. Created                           */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_1768ExtSNVal01
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

   DECLARE @cTaskDetailKey NVARCHAR( 10)
   DECLARE @cCCKey         NVARCHAR( 10)
   DECLARE @cCCSheetNo     NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @cChkSerialSKU  NVARCHAR( 20)
   DECLARE @nChkSerialQTY  INT
   DECLARE @nRowCount      INT

   IF @nFunc = 1768 -- Piece receiving
   BEGIN
      -- Get Receipt info
      SET @cTaskDetailKey = @cDocNo
      SET @cCCSheetNo = @cTaskDetailKey
      
      SELECT 
         @cID = V_ID,
         @cCCKey = V_String1
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      -- Get serial no info
      SELECT
         @cChkSerialSKU = SKU,
         @nChkSerialQTY = QTY
      FROM dbo.CCSerialNoLog WITH (NOLOCK)
      WHERE CCKey = @cCCKey
      AND   CCSheetNo = @cCCSheetNo
      AND   StorerKey = @cStorerKey
      AND   SerialNo = @cSerialNo
      AND   ID = CASE WHEN ISNULL( @cID, '') = '' THEN ID ELSE @cID END
      SET @nRowCount = @@ROWCOUNT

      IF @nRowCount = 1
      BEGIN
         -- Check SKU matches
         IF @cChkSerialSKU <> @cSKU
         BEGIN
            SET @nErrNo = 220351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO Diff SKU
            GOTO Quit
         END

         -- Check serial no received
         IF @nChkSerialQTY <> 0
         BEGIN
            SET @nErrNo = 220352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady rcv
            GOTO Quit
         END
      END
   END

Quit:

END


GO