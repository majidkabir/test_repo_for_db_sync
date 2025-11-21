SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_955DropIDDecod03                                */  
/* Copyright      : LFLogistics                                         */  
/*                                                                      */  
/* Purpose: Decode dropid                                               */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 14-10-2021  1.0  Chermaine   WMS-18009.Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_955DropIDDecod03]  
   @nMobile          INT,  
   @nFunc            INT,   
   @cLangCode        NVARCHAR( 3),   
   @nStep            INT,   
   @nInputKey        INT,   
   @cStorerkey       NVARCHAR(15),  
   @cPickSlipNo      NVARCHAR(10),  
   @cDropID          NVARCHAR(60)   OUTPUT,  
   @cLOC             NVARCHAR(10)   OUTPUT,  
   @cID              NVARCHAR(18)   OUTPUT,  
   @cSKU             NVARCHAR(20)   OUTPUT,  
   @nQty             INT            OUTPUT,   
   @cLottable01      NVARCHAR( 18)  OUTPUT,   
   @cLottable02      NVARCHAR( 18)  OUTPUT,   
   @cLottable03      NVARCHAR( 18)  OUTPUT,   
   @dLottable04      DATETIME       OUTPUT,    
   @dLottable05      DATETIME       OUTPUT,    
   @cLottable06      NVARCHAR( 30)  OUTPUT,    
   @cLottable07      NVARCHAR( 30)  OUTPUT,    
   @cLottable08      NVARCHAR( 30)  OUTPUT,    
   @cLottable09      NVARCHAR( 30)  OUTPUT,    
   @cLottable10      NVARCHAR( 30)  OUTPUT,    
   @cLottable11      NVARCHAR( 30)  OUTPUT,    
   @cLottable12      NVARCHAR( 30)  OUTPUT,    
   @dLottable13      DATETIME       OUTPUT,     
   @dLottable14      DATETIME       OUTPUT,     
   @dLottable15      DATETIME       OUTPUT,     
   @nErrNo           INT            OUTPUT,   
   @cErrMsg          NVARCHAR(250)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE  @nStartPos  INT,  
            @nEndPos    INT  
               
   DECLARE  @cBarcode         NVARCHAR( 60),  
            @cCartonBarcode   NVARCHAR( 60),  
            @cMstQTY          NVARCHAR( 5)  

   DECLARE @cOrderKey         NVARCHAR(20)
  
             
   SELECT   
      @cMstQTY = O_Field15  
   FROM rdt.rdtmobrec WITH (NOLOCK)   
   WHERE mobile = @nMobile         
  
   IF @nStep = 5  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         IF ISNULL( @cDropID, '') = ''  
         BEGIN  
            SET @nErrNo = 189401  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropID Req  
            GOTO Quit  
         END  
  
         SET @cCartonBarcode = @cDropID  
  
         IF @cCartonBarcode <> '' AND @cCartonBarcode <> 'NA' AND @cCartonBarcode <> 'X'  
         BEGIN  
            --(95)030244893132694952   if len after'95' <> 18 prompt error  
            IF LEN(RIGHT(@cCartonBarcode,LEN(@cCartonBarcode)-(PATINDEX ('95%',@cCartonBarcode)+1))) <> 18  
            BEGIN  
               SET @nErrNo = 189402   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCErr  
               GOTO Quit  
            END  
  
            SET @cCartonBarcode = SUBSTRING (@cCartonBarcode,3,18)  
              
            IF NOT EXISTS (SELECT 1 FROM UCC WITH (NOLOCK) WHERE Storerkey = @cStorerKey AND UccNo = @cCartonBarcode)  
            BEGIN  
             SET @nErrNo = 189403   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCErr  
               GOTO Quit  
            END
                          
            IF EXISTS (SELECT 1 FROM pickdetail WITH (NOLOCK) 
                        WHERE Storerkey = @cStorerKey 
                        AND dropid = @cCartonBarcode
                        AND status NOT in ('9'))  
            BEGIN  
             SET @nErrNo = 189403   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CaseSSCCErr  
               GOTO Quit  
            END
              
            IF ISNULL( @cCartonBarcode, '') <> ''  
            BEGIN  
               SET @cDropID = @cCartonBarcode  
               GOTO Quit  
            END  
         END  
         ELSE IF @cCartonBarcode = 'NA'   
         BEGIN  
          IF ISNULL(@cMstQTY,'') = ''  
          BEGIN  
           SET @nErrNo = 189404   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ScanCaseSSCC  
               GOTO Quit  
          END   
         END  
      END  
   END  
  
   SET @cDropID = @cCartonBarcode  
QUIT:  
  
END -- End Procedure  

GO