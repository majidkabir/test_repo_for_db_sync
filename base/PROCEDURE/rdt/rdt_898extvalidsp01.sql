SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_898ExtValidSP01                                 */  
/* Purpose: Validate  UCC                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-03-26 1.0  ChewKP     SOS#337011 Created                        */  
/* 2020-09-30 1.1  James      WMS-15353 Block user scan ucc with        */
/*                            status = 6 (james01)                      */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_898ExtValidSP01] (  
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
    ,@nErrNo      INT       OUTPUT 
    ,@cErrMsg     NVARCHAR( 20) OUTPUT 
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 898  
BEGIN  
   
    
    DECLARE  @cStorerKey        NVARCHAR(15)
--           , @cPalletConsigneeKey NVARCHAR(15)
--           , @cChildID            NVARCHAR(20)

    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    SET @cPOKey = ''
    SET @cStorerKey = ''

    SELECT @cStorerKey = StorerKey
    FROM dbo.Receipt WITH (NOLOCK) 
    WHERE ReceiptKey = @cReceiptKey

    
    SELECT @cPOKey = SUBSTRING(UCC.Sourcekey,1,10)      
    FROM dbo.UCC WITH (NOLOCK) 
    WHERE UCCNo = @cUCC 
    AND StorerKey = @cStorerKey

    
    IF NOT EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
                    WHERE ReceiptKey = @cReceiptKey
                    AND PoKey = ISNULL(RTRIM(@cPOKey),'')  ) 
    BEGIN
      SET @nErrNo = 93251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCNo'
      GOTO QUIT
    END  
    
    -- (james01)
    IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                WHERE Storerkey = @cStorerKey
                AND   UCCNo = @cUCC
                AND   [Status] = '6')
    BEGIN
      SET @nErrNo = 93252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCNo'
      GOTO QUIT
    END  
END  
  
QUIT:  

GO