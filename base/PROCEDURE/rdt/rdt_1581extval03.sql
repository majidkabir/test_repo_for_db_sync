SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1581ExtVal03                                    */  
/* Copyright      : LF logistics                                        */  
/*                                                                      */  
/* Purpose: check mix SKU on carton (L01)                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author      Purposes                                */  
/* 24-02-2021  1.1  Chermaine   WMS-16334-Add lottable02 chk            */  
/*                              (base on ExtVal02)                      */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_1581ExtVal03]  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cLangCode    NVARCHAR( 3)  
   ,@cStorerKey   NVARCHAR( 15)  
   ,@cReceiptKey  NVARCHAR( 10)   
   ,@cPOKey       NVARCHAR( 10)   
   ,@cExtASN      NVARCHAR( 20)  
   ,@cToLOC       NVARCHAR( 10)   
   ,@cToID        NVARCHAR( 18)   
   ,@cLottable01  NVARCHAR( 18)   
   ,@cLottable02  NVARCHAR( 18)   
   ,@cLottable03  NVARCHAR( 18)   
   ,@dLottable04  DATETIME    
   ,@cSKU         NVARCHAR( 20)   
   ,@nQTY         INT  
   ,@nErrNo       INT           OUTPUT   
   ,@cErrMsg      NVARCHAR( 20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   IF @nStep = 2 -- Loc  
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN  
       DECLARE @cRecType NVARCHAR(10)  
  
         SELECT @cRecType = recType FROM receipt WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ReceiptKey = @cReceiptKey  
           
         IF NOT EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE listName = 'RTNLOC2L10' AND storerKey = @cStorerKey AND code = @cToLOC)  
           -- AND @cRecType IN ('RSO-F','RSO-N')    
         BEGIN  
          SET @nErrNo = 163701  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LocNotMaintain  
            GOTO Quit  
         END  
           
         --IF EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE listName = 'RTNLOC2L10' AND storerKey = @cStorerKey AND code = @cToLOC)  
         --   AND @cRecType NOT IN ('RSO-F','RSO-N')    
         --BEGIN  
         -- SET @nErrNo = 163702  
         --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Is RSOToloc  
         --   GOTO Quit  
         --END  
      END  
   END  
     
   IF @nStep = 4 -- Lottable  
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN  
          -- Check L02   
         IF NOT EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND listName = 'NKCNLOT3V' AND code = @cLottable03)  
         BEGIN  
            SET @nErrNo = 163703  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot03  
            GOTO Quit  
         END  
           
         -- Check L02   
         IF @cLottable02 =''   
         BEGIN  
            SET @nErrNo = 163704  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Lot02  
            GOTO Quit  
         END   
         ELSE   
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM codelkup WITH (NOLOCK) where listname ='NKISEG' and code = @cLottable02)  
            BEGIN  
             SET @nErrNo = 163705  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Iseg Wrong  
                 
               UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET O_Field02 = '' WHERE mobile = @nMobile  
               GOTO Quit  
            END  
         END   
      END  
   END      
     
   IF @nStep = 5 -- SKU, QTY  
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
      BEGIN         
         DECLARE @cDuplicateFrom NVARCHAR(20),  
                 @nROWCOUNT  INT,  
                 @nPostBefRecQTY INT,  
                 @nPreQTYExpected INT,  
                 @nPostQTYExpected INT  
  
         SELECT  @nPostBefRecQTY=SUM(BeforeReceivedQty), @nPostQTYExpected=SUM(QtyExpected)  
         FROM ReceiptDetail WITH (NOLOCK)   
         WHERE ReceiptKey = @cReceiptKey   
            AND Lottable02 = @cLottable02  
            AND SKU = @cSKU   
            AND storerkey=@cStorerKey    

         SET @nROWCOUNT=@@ROWCOUNT

         SET @nPostBefRecQTY=case when ISNULL(@nPostBefRecQTY,'')='' then 0 else @nPostBefRecQTY end
         SET @nPostQTYExpected=case when ISNULL(@nPostQTYExpected,'')='' then 0 else @nPostQTYExpected end

         DECLARE @nSKUPackIndicatorQTY INT  
  
         SELECT @nSKUPackIndicatorQTY=Packqtyindicator  
         FROM SKU (NOLOCK)  
         where sku =@cSKU  
         AND  PrePackIndicator=2  
         AND StorerKey=@cStorerKey  

         SET @nSKUPackIndicatorQTY=case when ISNULL(@nSKUPackIndicatorQTY,'')='' THEN 0 else @nSKUPackIndicatorQTY END
  
         IF @nSKUPackIndicatorQTY<>0
         BEGIN
            -- Check UserDefine10 in OriLine ASN  
            IF (@nPostQTYExpected-@nPostBefRecQTY>=@nSKUPackIndicatorQTY) AND @nPostQTYExpected<>0
            BEGIN  
               SET @nErrNo = 163706  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotExceptionSKU  
               GOTO Quit  
            END  
         END
         ELSE
         BEGIN
            IF (@nPostQTYExpected>@nPostBefRecQTY)  
            BEGIN  
               SET @nErrNo = 163706  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotExceptionSKU  
               GOTO Quit  
            END  
         END
  
      END  
   END  
Quit:  
END  

GO