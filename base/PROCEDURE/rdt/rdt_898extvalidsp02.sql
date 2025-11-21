SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_898ExtValidSP02                                 */    
/* Purpose: Validate  UCC                                               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2018-01-30 1.0  ChewKP     WMS-3859 Created                          */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_898ExtValidSP02] (    
    @nMobile     INT  
   ,@nFunc       INT  
   ,@cLangCode   NVARCHAR(  3)  
   ,@cReceiptKey NVARCHAR( 10)  
   ,@cPOKey      NVARCHAR( 10)  
   ,@cLOC        NVARCHAR( 10)  
   ,@cToID       NVARCHAR( 18)  
   ,@cLottable01 NVARCHAR( 18)  
   ,@cLottable02 NVARCHAR( 18)  
   ,@cLottable03 NVARCHAR( 18)  
   ,@dLottable04 DATETIME  
   ,@cUCC        NVARCHAR( 20)  
   ,@nErrNo      INT           OUTPUT  
   ,@cErrMsg     NVARCHAR( 20) OUTPUT  
)    
AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
    
IF @nFunc = 898    
BEGIN    
    DECLARE  @cStorerKey       NVARCHAR(15)  
            ,@cSUSR3           NVARCHAR(18)  
            ,@cCurrentSUSR3    NVARCHAR(18)  
            ,@cShort           NVARCHAR(10)   
            ,@cCurrentShort    NVARCHAR(10)   
            ,@cToIDSKU         NVARCHAR(20)   
            ,@nInputKey        INT  
            ,@nStep            INT  
            ,@cSKU             NVARCHAR(20)   
      
    DECLARE @cSourceType       NVARCHAR(20)  
    DECLARE @cSourceKey        NVARCHAR(20)  
    DECLARE @cUCCPOKey         NVARCHAR(10)  
    DECLARE @cUCCPOLineNumber  NVARCHAR(5)  
           ,@cUCCReceiveKey    NVARCHAR(10)   
           ,@cUCCLineNumber    NVARCHAR(5)   
           ,@cContainerKey     NVARCHAR(18)  
           ,@cUCCContainerKey  NVARCHAR(18)  
      
    SELECT @nStep = Step  
          ,@nInputKey = InputKey  
    FROM rdt.rdtMobrec WITH (NOLOCK)   
    WHERE Mobile = @nMobile   
  
    IF @nStep = 6   
    BEGIN  
       IF @nInputKey = 1 -- ENTER  
       BEGIN  
            
          SET @nErrNo          = 0  
          SET @cErrMSG         = ''  
          SET @cStorerKey = ''  
  
          SELECT   
               @cSourceType = ISNULL( SourceType, ''),   
               @cSourceKey = SourceKey,  
               @cSKU       = SKU,   
               @cStorerKey = StorerKey   
          FROM dbo.UCC WITH (NOLOCK)    
          WHERE UCCNo = @cUCC   
            
          SELECT @cSUSR3 = SUSR3   
          FROM dbo.SKU WITH (NOLOCK)   
          WHERE StorerKey = @cStorerKey  
          AND SKU = @cSKU   
  
          SELECT @cShort = Short   
          FROM dbo.Codelkup WITH (NOLOCK)   
          WHERE ListName = 'SKUGroup'  
          AND StorerKey = @cStorerKey   
          AND Code = @cSUSR3   
        
          SET @cUCCReceiveKey = SUBSTRING( @cSourcekey, 1, 10)   
          SET @cUCCLineNumber = SUBSTRING( @cSourcekey, 11, 5)   
            
          SELECT @cUCCContainerKey = ContainerKey  
          FROM dbo.Receipt WITH (NOLOCK)  
          WHERE StorerKey = @cStorerKey  
          AND ReceiptKey = @cUCCReceiveKey  
            
          SELECT @cContainerKey = ContainerKey  
          FROM dbo.Receipt WITH (NOLOCK)  
          WHERE StorerKey = @cStorerKey  
          AND ReceiptKey = @cReceiptKey  
            
          IF ISNULL(@cContainerKey,'')  = ''   
          BEGIN  
              
            IF @cUCCReceiveKey <> @cReceiptKey  
            BEGIN  
               SET @nErrNo = 119302  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ReceiptKeyNotSame'  
               GOTO QUIT  
            END  
          END  
     
          ---- Get ASN  
          --SELECT TOP 1   
          --     @cUCCPOKey = RD.POKey  
          --FROM Receipt R WITH (NOLOCK)  
          --     JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)  
          --WHERE R.StorerKey = @cStorerKey  
          --     AND R.Facility = @cFacility  
          --     AND RD.POKey = @cUCCPOKey  
          --     AND RD.POLineNumber = @cUCCPOLineNumber  
      
           
  
          IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)   
                      WHERE ReceiptKey = @cUCCReceiveKey  
                      AND ToID = @cToID )   
          BEGIN  
              
            SELECT Top 1 @cToIDSKU = SKU   
            FROM dbo.ReceiptDetail WITH (NOLOCK)   
            WHERE ReceiptKey = @cUCCReceiveKey  
            AND StorerKey = @cStorerKey  
            AND ToID = @cToID   
            ORDER BY EditDate   
  
            SELECT @cCurrentSUSR3 = SUSR3   
            FROM dbo.SKU WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
            AND SKU = @cToIDSKU   
  
            SELECT @cCurrentShort = Short   
            FROM dbo.Codelkup WITH (NOLOCK)   
            WHERE ListName = 'SKUGroup'  
            AND StorerKey = @cStorerKey   
            AND Code = @cCurrentSUSR3   
  
            IF ISNULL(@cShort,'')  <> ISNULL(@cCurrentShort ,'' )   
            BEGIN  
               SET @nErrNo = 119301  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MixSKUCategory'  
               GOTO QUIT  
            END  
  
  
  
          END  
  
  
      
      
       END  
    END  
     
END    
    
QUIT:    

GO