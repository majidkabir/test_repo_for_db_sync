SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                 
/* Copyright: LF                                                              */                 
/* Purpose: Ext Validate                                                      */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-03-31 1.0  YeeKung    WMS-12575 Created                               */ 
/* 2021-08-11 1.1  YeeKung    WMS-17672 Add new logic (yeekung01)             */      
/* 2021-10-04 1.2  Calvin     JSM-24273 Sum QtyExpected (CLVN01)              */ 
/******************************************************************************/ 

CREATE PROC [RDT].[rdt_645ExtVal01] (    
   @nMobile      INT,              
   @nFunc        INT,          
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cFacility    NVARCHAR( 5),  
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),
   @cID          NVARCHAR( 20),
   @cBatchCode   NVARCHAR( 60),
   @cCartonSN    NVARCHAR( 60),
   @cBottleSN    NVARCHAR( 100),
   @nQTYPICKED   INT,          
   @nQTYCSN      INT,          
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
)
AS    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   IF @nFunc = 645 
   BEGIN  
      IF @nStep = 2 -- SKU   
      BEGIN    
         IF @nInputKey = 1 -- ENTER    
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM SKU (NOLOCK)
                       WHERE SKU=@cSKU
                        AND storerkey=@cStorerKey
                        AND ISNULL(SKU.SUSR4,'')='SSCC'
                        AND ISNULL(LOTTABLE10LABEL,'')=''
                        AND (CASE WHEN ISNULL(BUSR7,'') ='' THEN 0 ELSE CAST(BUSR7 AS float) END) >=0.7
                        )
            BEGIN
               SET @nErrNo = 150701   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
               GOTO QUIT
            END
         END
      END

      IF @nStep = 3 -- SKU   
      BEGIN    
         IF @nInputKey = 1 -- ENTER    
         BEGIN 
            IF NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK) 
                       WHERE receiptkey=@cReceiptkey 
                        AND sku=@csku
                        AND toid=@cid
                        AND storerkey=@cstorerkey
                        )
            BEGIN
               SET @nErrNo = 150703   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID  
               GOTO QUIT
            END
         END
      END
      IF @nStep = 5 -- CartonSN
      BEGIN
         DECLARE @nQTY INT,@nASNQTY INT

         SELECT @nASNQty=sum(qtyexpected)					--(CLVN01)
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE receiptkey=@cReceiptKey AND SKU=@cSKU

         SELECT @nQTY=SUM(QTY) 
         FROM TRACKINGID (NOLOCK) 
         WHERE storerkey=@cStorerKey
            AND SKU=@cSKU
            AND UserDefine01=@cReceiptKey

         IF (@nQTY>=@nASNQty) 
         BEGIN
            SET @nErrNo = 150702   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
            GOTO QUIT
         END
      END
   END
Fail:    
Quit:  

GO