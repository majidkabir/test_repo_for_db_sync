SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* Store procedure: rdt_608RefNoLKUP07                                        */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Reference LookUP customize                                        */  
/*                                                                            */  
/* Date        Author   Ver.  Purposes                                        */  
/* 27-07-2022  Ung      1.0   WMS-20251 Created                               */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_608RefNoLKUP07]  
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @cFacility    NVARCHAR( 5),     
   @cStorerGroup NVARCHAR( 20),   
   @cStorerKey   NVARCHAR( 15),   
   @cRefNo       NVARCHAR( 30),   
   @cReceiptKey  NVARCHAR( 10)  OUTPUT,   
   @nErrNo       INT            OUTPUT,   
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nRowCount INT

   IF @nFunc = 608 -- Return V7
   BEGIN  
      IF @cReceiptKey = ''
      BEGIN
         SELECT @cReceiptKey = ReceiptKey 
         FROM dbo.Receipt WITH (NOLOCK) 
         WHERE Facility = @cFacility
            AND StorerKey = @cStorerKey
            AND Status <> '9'
            AND ASNStatus <> 'CANC'
            AND ReceiptGroup = @cRefNo
         SELECT @nRowCount = @@ROWCOUNT
      END

      IF @cReceiptKey = ''
      BEGIN
         SELECT @cReceiptKey = R.ReceiptKey 
         FROM dbo.Receipt R WITH (NOLOCK) 
            JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.Facility = @cFacility
            AND R.StorerKey = @cStorerKey
            AND R.Status <> '9'
            AND R.ASNStatus <> 'CANC'
            AND RD.UserDefine08 = @cRefNo -- Carton ID
         SELECT @nRowCount = @@ROWCOUNT
         
         IF @nRowCount > 1 -- There will be multiple ReceiptDetail records
            SET @nRowCount = 1
      END
      
      -- Check RefNo in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 188701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END

      -- Check RefNo in ASN
      IF @nRowCount > 1
      BEGIN
         SET @nErrNo = 188702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
         GOTO Quit
      END
   END
   
Quit:
   
END  

GO