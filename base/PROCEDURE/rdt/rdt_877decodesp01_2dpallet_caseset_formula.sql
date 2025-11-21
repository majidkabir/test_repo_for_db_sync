SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/**************************************************************************/  
/* Store procedure: rdt_877DecodeSP01_2DPallet_CaseSet_Formula            */  
/* Copyright      : LF Logistics                                          */  
/*                                                                        */  
/* Purpose: Decode GS1-128 barcode                                        */  
/*                                                                        */  
/* Modifications log:                                                     */  
/*                                                                        */  
/* Date        Rev  Author      Purposes                                  */  
/* 03-05-2018  1.0  Ung         WMS-4846 Created                          */  
/* 20-09-2018  1.1  Grick       INC0383981 - Change cCasePrefix for       */  
/*                                           @cDropID     (G01)           */  
/**************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_877DecodeSP01_2DPallet_CaseSet_Formula]  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cCasePrefix    NVARCHAR( MAX),   
   @cFormula       NVARCHAR( MAX),   
   @cCaseSurfix    NVARCHAR( MAX),   
   @cLottable01    NVARCHAR( 18),   
   @cLottable06    NVARCHAR( 30),   
   @nErrNo         INT            OUTPUT,  
   @cErrMsg        NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cBarcode    NVARCHAR(MAX)  
   DECLARE @cSubFormula NVARCHAR(MAX)  
   DECLARE @cCaseID     NVARCHAR(MAX)  
   DECLARE @nCaseID     INT  
   DECLARE @nCaseIDLen  INT  
   DECLARE @cInterval   NVARCHAR(MAX)  
   DECLARE @nInterval   INT  
   DECLARE @cCount      NVARCHAR(MAX)  
   DECLARE @nCount      INT  
   DECLARE @nStart      INT  
   DECLARE @nToken      INT  
   DECLARE @cDropID     NVARCHAR(MAX)   
  
   SET @cCaseID = ''  
   SET @cSubFormula = ''  
  
   -- Get initial case ID  
   SET @cCaseID = rdt.rdtGetParsedString( @cFormula, 1, ';')  
  
   IF @cCaseID = ''  
   BEGIN  
      SET @nErrNo = 123901  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank CaseID  
      GOTO Quit  
   END  
  
   -- Check case ID valid  
   IF rdt.rdtIsValidQTY( @cCaseID, 0) = 0  
   BEGIN  
      SET @nErrNo = 123902  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CaseID  
      GOTO Quit  
   END  
   SET @nCaseID = CAST( @cCaseID AS INT)  
   SET @nCaseIDLen = LEN( @cCaseID)  
  
   SET @cBarcode = @cCasePrefix + @cCaseID + @cCaseSurfix  
   SET @cDropID = RIGHT( @cCasePrefix, 1) + @cCaseID            --(G01)  
  
   -- Save initial case ID  
   INSERT INTO rdt.rdtCaseIDCaptureLog (Mobile, StorerKey, CaseID, Lottable01, Lottable06, Barcode) --(G01)  
   VALUES( @nMobile, @cStorerKey, @cDropID, @cLottable01, @cLottable06, @cBarcode)  
  
   SET @nToken = 2  
   SET @cSubFormula = rdt.rdtGetParsedString( @cFormula, @nToken, ';')  
   WHILE @cSubFormula <> ''  
   BEGIN  
      SET @nStart = CHARINDEX( 'x', @cSubFormula)   
      IF @nStart = 0  
      BEGIN  
         IF rdt.rdtIsValidQTY( @cSubFormula, 0) = 0  
         BEGIN  
            SET @nErrNo = 123903  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad interval  
            GOTO Quit  
         END  
  
         SET @nInterval = CAST( @cSubFormula AS INT)  
         SET @nCaseID = @nCaseID + @nInterval   
         SET @cCaseID = CAST( @nCaseID AS NVARCHAR( MAX))  
         SET @cCaseID = REPLICATE( '0', @nCaseIDLen) + @cCaseID   
         SET @cCaseID = RIGHT( @cCaseID, @nCaseIDLen)  
         SET @cDropID = RIGHT( @cCasePrefix, 1) + @cCaseID        --(G01)  
           
         SET @cBarcode = @cCasePrefix + @cCaseID + @cCaseSurfix  
           
         INSERT INTO rdt.rdtCaseIDCaptureLog (Mobile, StorerKey, CaseID, Lottable01, Lottable06, Barcode)   
         VALUES( @nMobile, @cStorerKey, @cDropID, @cLottable01, @cLottable06, @cBarcode)  
      END  
      ELSE  
      BEGIN  
         -- Get interval  
         SET @cInterval = SUBSTRING( @cSubFormula, 1, @nStart-1)  
         IF @cInterval = ''  
         BEGIN  
            SET @nErrNo = 123904  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank interval  
            GOTO Quit  
         END  
           
         -- Check interval valid  
         IF rdt.rdtIsValidQTY( @cInterval, 0) = 0  
         BEGIN  
            SET @nErrNo = 123905  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad interval  
            GOTO Quit  
         END  
         SET @nInterval = CAST( @cInterval AS INT)  
  
         -- Get counter  
         SET @cCount = SUBSTRING( @cSubFormula, @nStart+1, LEN( @cSubFormula))  
         IF @cCount = ''  
         BEGIN  
            SET @nErrNo = 123906  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Blank counter  
            GOTO Quit  
         END  
  
         -- Check counter valid  
         IF rdt.rdtIsValidQTY( @cCount, 0) = 0  
         BEGIN  
            SET @nErrNo = 123907  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad counter  
            GOTO Quit  
         END  
         SET @nCount = CAST( @cCount AS INT)  
  
         -- Loop (counter)  
         WHILE @nCount > 0  
         BEGIN  
            -- Calc case ID  
            SET @nCaseID = @nCaseID + @nInterval   
            SET @cCaseID = CAST( @nCaseID AS NVARCHAR( MAX))  
            SET @cCaseID = REPLICATE( '0', @nCaseIDLen) + @cCaseID   
            SET @cCaseID = RIGHT( @cCaseID, @nCaseIDLen)  
            SET @cDropID = RIGHT( @cCasePrefix, 1) + @cCaseID  --G01  
            SET @nInterval = 1  
  
            SET @cBarcode = @cCasePrefix + @cCaseID + @cCaseSurfix  
  
            -- Save case ID  
            INSERT INTO rdt.rdtCaseIDCaptureLog (Mobile, StorerKey, CaseID, Lottable01, Lottable06, Barcode)   
            VALUES( @nMobile, @cStorerKey, @cDropID, @cLottable01, @cLottable06, @cBarcode)  
  
            SET @nCount = @nCount - 1  
         END  
      END  
        
      SET @nToken = @nToken + 1  
      SET @cSubFormula = rdt.rdtGetParsedString( @cFormula, @nToken, ';')  
   END  
  
Quit:  

END

GO