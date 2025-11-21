SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_906VerifyDecod01                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode GS1-128 barcode                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-03-2019  1.0  James       WMS-8002 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_906VerifyDecod01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @tDecodeSP      VariableTable READONLY,
   @cSKU           NVARCHAR( 20)  OUTPUT,
   @cBatchNo       NVARCHAR( 18)  OUTPUT,
   @cCaseID        NVARCHAR( 18)  OUTPUT,
   @cPalletID      NVARCHAR( 18)  OUTPUT,
   @nScan          INT            OUTPUT,
   @nTotal         INT            OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nPOS        INT
   DECLARE @nSKUCnt     INT
   DECLARE @bSuccess    INT
   DECLARE @cUPC        NVARCHAR( 30)
   DECLARE @cBarcode_Ori   NVARCHAR( MAX)
   DECLARE @cBarcode    NVARCHAR( MAX)

   SELECT @cBarcode = Value FROM @tDecodeSP WHERE Variable = '@cBarcode'

   SET @cBarcode_Ori = @cBarcode

   SET @cUPC = ''
   SET @cBatchNo = ''
   SET @cCaseID = ''
   SET @cPalletID = ''

   -- Pallet ID
   IF LEFT( @cBarcode, 2) = 'ID'
   BEGIN
      SET @cPalletID = LEFT( @cBarcode, 18)
      GOTO Quit
   END

   -- Case ID
   /*
   Barcode format:
   1. (01)EAN21CaseID(10)BatchNo
   2. (01)EAN21CaseID
   3. (01)EAN10BatchNo(21)CaseID

   EAN     = fixed 14 digits (DB 13 digits)
   CaseID  = fixed 5 digits
   BatchNo = alpha numeric, optional.

   Example:
   (01)032459900099242100003(10)TEST5
   (01)032459900099242100003
   */

   -- 1st delimeter
   IF LEFT( @cBarcode, 4) = '(01)'
   BEGIN
      -- Decode SKU
      SET @cUPC = SUBSTRING( @cBarcode, 6, 13)
      SET @cBarcode = SUBSTRING( @cBarcode, 19, LEN( @cBarcode))

      -- 2nd delimeter
      IF LEFT( @cBarcode, 2) = '21'
      BEGIN
         -- Decode Case ID
         SET @nPOS = PATINDEX( '%(10)%', @cBarcode)
         IF @nPOS = 0
         BEGIN
            SET @cCaseID = SUBSTRING( @cBarcode, 3, LEN( @cBarcode))
            SET @cBarcode = ''
         END
         ELSE
         BEGIN
            SET @cCaseID = SUBSTRING( @cBarcode, 3, @nPOS-3)
            SET @cBarcode = SUBSTRING( @cBarcode, @nPOS, LEN( @cBarcode))
         END

         -- 3rd delimeter
         IF LEFT( @cBarcode, 4) = '(10)'
            -- Decode Batch no
            SET @cBatchNo = SUBSTRING( @cBarcode, 5, LEN( @cBarcode))
      END

      -- 2nd delimeter
      ELSE IF LEFT( @cBarcode, 2) = '10'
      BEGIN
         -- Decode Batch no
         SET @nPOS = PATINDEX( '%(21)%', @cBarcode)
         IF @nPOS = 0
         BEGIN
            SET @cBatchNo = SUBSTRING( @cBarcode, 3, LEN( @cBarcode))
            SET @cBarcode = ''
         END
         ELSE
         BEGIN
            SET @cBatchNo = SUBSTRING( @cBarcode, 3, @nPOS-3)
            SET @cBarcode = SUBSTRING( @cBarcode, @nPOS, LEN( @cBarcode))
         END

         -- 3rd delimeter
         IF LEFT( @cBarcode, 4) = '(21)'
            -- Decode CaseID
            SET @cCaseID = SUBSTRING( @cBarcode, 5, LEN( @cBarcode))
      END
   END

   /*
   Barcode format:
   1. (10)BatchNo(21)CaseID

   BatchNo = alpha numeric, variable length
   CaseID  = max 20 digits

   Example:
   (10)327516(21)032751600030
   */

   ELSE IF LEFT( @cBarcode, 4) = '(10)'
   BEGIN
      -- Decode Batch no
      SET @nPOS = PATINDEX( '%(21)%', @cBarcode)
      IF @nPOS > 0
      BEGIN
         SET @cBatchNo = SUBSTRING( @cBarcode, 5, @nPOS-5)
         SET @cBarcode = SUBSTRING( @cBarcode, @nPOS, LEN( @cBarcode))
      END

      -- Decode case ID
      IF LEFT( @cBarcode, 4) = '(21)'
         SET @cCaseID = SUBSTRING( @cBarcode, 5, LEN( @cBarcode))
   END
   ELSE
      SET @cUPC = @cBarcode

   IF ISNULL( @cUPC, '') <> ''
   BEGIN
      -- Get SKU count
      EXEC RDT.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
   
      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 136901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Quit
      END
   
      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 136902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         GOTO Quit
      END
   
      -- Get SKU code
      EXEC RDT.rdt_GETSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @bSuccess      OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      SET @cSKU = @cUPC
   END

--delete from traceinfo where tracename = '830decode'
--insert into traceinfo (tracename, timein, step1, step2, step3, col1, col2, col3, col4, col5) values 
--('830decode', getdate(), substring( @cBarcode_Ori, 1, 20), substring( @cBarcode_Ori, 21, 20), substring( @cBarcode_Ori, 41, 20), @cSKU, @cCaseID, @cBatchNo, '', '')

Quit:

END

GO