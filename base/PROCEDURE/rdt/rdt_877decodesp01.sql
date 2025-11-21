SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_877DecodeSP01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode GS1-128 barcode                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 27-04-2018  1.0  Ung         WMS-4846 Created                        */
/* 10-10-2018  1.1  Ung         WMS-6576 Add inner barcode              */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_877DecodeSP01]
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cPickSlipNo    NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cBarcode       NVARCHAR( MAX),
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
   DECLARE @nStart      INT
   DECLARE @nEnd        INT
   DECLARE @cUserName   NVARCHAR(18)
   DECLARE @cSeq        NVARCHAR(14)
   DECLARE @cLottable01 NVARCHAR(18)
   DECLARE @cOrgBarcode NVARCHAR(MAX)

   SET @cSKU = ''
   SET @cBatchNo = ''
   SET @cCaseID = ''
   SET @cPalletID = ''
   SET @cUserName = SUSER_SNAME()

   -- Clear log (case ID)
   IF EXISTS( SELECT 1 FROM rdt.rdtCaseIDCaptureLog WITH (NOLOCK) WHERE Mobile = @nMobile)
      DELETE rdt.rdtCaseIDCaptureLog WHERE Mobile = @nMobile

   /*----------------------------------------------------------------------------------------------
                                             Pallet barcode
   ----------------------------------------------------------------------------------------------*/
   -- 2D Pallet
   IF LEFT( @cBarcode, 2) = 'P:'
   BEGIN
      -- Decode 2D pallet
      EXECUTE rdt.rdt_877DecodeSP01_2DPallet @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
         ,@cBarcode
         ,@nErrNo       OUTPUT
         ,@cErrMsg      OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   /*----------------------------------------------------------------------------------------------
                                             Case barcode
   ----------------------------------------------------------------------------------------------*/
   /*
      Barcode format:
      (01)SeqNo(10)BatchNo(21)CaseID(240)Lottable01
      
      SeqNo   = fixed 14 chars
      BatchNo = fixed 8 chars
      CaseID  = fixed 6 chars
      Lottable01 = fixed 8 chars
            
      Example:
      (01)14902210113804(10)09619538(21)100001(240)14014750
   */
      
   -- 1st delimeter (Seq)
   ELSE IF LEN( @cBarcode) = 45
   BEGIN
      SET @cOrgBarcode = @cBarcode

      -- 1st delimeter (Seq )
      SET @cSeq = SUBSTRING( @cBarcode, 3, 14)
      SET @cBarcode = SUBSTRING( @cBarcode, 3 + 14, LEN( @cBarcode))
      
      -- Check Seq valid
      IF LEN( @cSeq) <> 14
      BEGIN
         SET @nErrNo = 123751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Seq
         GOTO Quit
      END
            
      -- 2nd delimeter (Batch)
      IF LEFT( @cBarcode, 2) = '10'
      BEGIN
         SET @cBatchNo = SUBSTRING( @cBarcode, 3, 8)
         SET @cBarcode = SUBSTRING( @cBarcode, 3 + 8, LEN( @cBarcode))
      END
      ELSE
      BEGIN
         SET @nErrNo = 123752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad BatchStart
         GOTO Quit
      END

      -- Check batch
      IF LEN( @cBatchNo) <> 8
      BEGIN
         SET @nErrNo = 123753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad BatchNo
         GOTO Quit
      END

      -- 3rd delimeter (case ID)
      IF LEFT( @cBarcode, 2) = '21'
      BEGIN
         SET @cCaseID = SUBSTRING( @cBarcode, 3, 6)
         SET @cBarcode = SUBSTRING( @cBarcode, 3 + 6, LEN( @cBarcode))
      END
      ELSE
      BEGIN
         SET @nErrNo = 123754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadCaseIDStart
         GOTO Quit
      END
         
      -- Check case ID
      IF LEN( @cCaseID) <> 6
      BEGIN
         SET @nErrNo = 123755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Case ID
         GOTO Quit
      END
      
      -- 4th delimeter (Lottable01)
      IF LEFT( @cBarcode, 3) = '240'
         SET @cLottable01 = SUBSTRING( @cBarcode, 4, 8)
      ELSE
      BEGIN
         SET @nErrNo = 123756
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad L01Start
         GOTO Quit
      END
         
      -- Check case ID
      IF LEN( @cLottable01) <> 8
      BEGIN
         SET @nErrNo = 123757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Lottable01
         GOTO Quit
      END

      INSERT INTO rdt.rdtCaseIDCaptureLog (Mobile, StorerKey, CaseID, Lottable01, Lottable06, UserDefine01, Barcode) 
      VALUES( @nMobile, @cStorerKey, @cCaseID, @cLottable01, @cBatchNo, '', @cOrgBarcode)
   END

   /*----------------------------------------------------------------------------------------------
                                             Inner barcode
   ----------------------------------------------------------------------------------------------*/
   /*
      Barcode format:
      (01)SeqNo(21)CaseID(240)Lottable01
      
      SeqNo   = fixed 14 chars
      CaseID  = fixed 12 chars
      Lottable01 = fixed 8 chars
            
      Example:
      (01)14902210113804(10)09619538(21)100001(240)14014750
   */
   ELSE IF LEN( @cBarcode) = 41   
   BEGIN
      SET @cOrgBarcode = @cBarcode

      -- 1st delimeter (Seq )
      SET @cSeq = SUBSTRING( @cBarcode, 3, 14)
      SET @cBarcode = SUBSTRING( @cBarcode, 3 + 14, LEN( @cBarcode))
      
      -- Check Seq valid
      IF LEN( @cSeq) <> 14
      BEGIN
         SET @nErrNo = 123758
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Seq
         GOTO Quit
      END

      -- 2rd delimeter (case ID)
      IF LEFT( @cBarcode, 2) = '21'
      BEGIN
         SET @cCaseID = SUBSTRING( @cBarcode, 3, 12)
         SET @cBarcode = SUBSTRING( @cBarcode, 3 + 12, LEN( @cBarcode))
      END
      ELSE
      BEGIN
         SET @nErrNo = 123759
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadCaseIDStart
         GOTO Quit
      END
         
      -- Check case ID
      IF LEN( @cCaseID) <> 12
      BEGIN
         SET @nErrNo = 123760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Case ID
         GOTO Quit
      END
      
      -- 4th delimeter (Lottable01)
      IF LEFT( @cBarcode, 3) = '240'
         SET @cLottable01 = SUBSTRING( @cBarcode, 4, 8)
      ELSE
      BEGIN
         SET @nErrNo = 123761
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad L01Start
         GOTO Quit
      END
         
      -- Check case ID
      IF LEN( @cLottable01) <> 8
      BEGIN
         SET @nErrNo = 123762
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad Lottable01
         GOTO Quit
      END

      INSERT INTO rdt.rdtCaseIDCaptureLog (Mobile, StorerKey, CaseID, Lottable01, Lottable06, UserDefine01, Barcode) 
      VALUES( @nMobile, @cStorerKey, @cCaseID, @cLottable01, @cBatchNo, '', @cOrgBarcode)
   END
   
   ELSE
   BEGIN
      SET @nErrNo = 123763
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidBarcode
      GOTO Quit
   END
      

   /*----------------------------------------------------------------------------------------------
                                                Processing
   ----------------------------------------------------------------------------------------------*/
   -- Confirm (update case ID to PickDetail)
   EXECUTE rdt.rdt_877DecodeSP01_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
      ,@cPickSlipNo
      ,@cOrderKey
      ,@nErrNo       OUTPUT
      ,@cErrMsg      OUTPUT
   IF @nErrNo <> 0
      GOTO Quit

   -- Calc statistic
   EXEC rdt.rdt_877GetStatSP01 @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerkey
      ,@cOrderKey
      ,@nScan     OUTPUT
      ,@nTotal    OUTPUT
      ,@cOrgBarcode

   -- Remain in current screen
   IF @nErrNo = 0
      SET @nErrNo = -1

Quit:

END

GO