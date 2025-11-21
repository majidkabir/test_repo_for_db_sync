SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdtUCCRcvFilter02                                   */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: Check UCC scan to ID filter by ReceiptLine Number           */      
/*                                                                      */      
/* Called from:                                                         */      
/*                                                                      */      
/* Exceed version: 5.4                                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date        Rev  Author      Purposes                                */      
/* 20-11-2013  1.0  ChewKP      SOS#295577. Created                     */      
/* 04-04-2016  1.1  ChewKP      Performance Tuning                      */  
/************************************************************************/      
      
CREATE PROCEDURE [RDT].[rdtUCCRcvFilter01]      
    @nMobile     INT      
   ,@nFunc       INT      
   ,@cLangCode   NVARCHAR(  3)      
   ,@cReceiptKey NVARCHAR( 10)      
   ,@cPOKey      NVARCHAR( 10)      
   ,@cToLOC      NVARCHAR( 10)      
   ,@cToID       NVARCHAR( 18)      
   ,@cLottable01 NVARCHAR( 18)      
   ,@cLottable02 NVARCHAR( 18)      
   ,@cLottable03 NVARCHAR( 18)      
   ,@dLottable04 DATETIME       
   ,@cSKU        NVARCHAR( 20)      
   ,@cUCC        NVARCHAR( 20)      
   ,@nQTY        INT      
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT      
   ,@nErrNo      INT            OUTPUT      
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
         
   -- Get Receipt info      
   DECLARE @cStorerKey         NVARCHAR(15)     
         , @cReceiptLineNumber NVARCHAR(5)    
         , @cSourceType        NVARCHAR(20)    
         , @cPOLineNumber      NVARCHAR(5)    
       
   SET @cSourceType = ''      
   SET @cStorerKey  = ''    
       
   SELECT @cStorerKey = StorerKey FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey      
       
       
   SELECT @cSourceType = SourceType     
   FROM dbo.UCC WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
   AND UCCNo = @cUCC    
       
   IF @cSourceType = 'ASN'    
   BEGIN          
                  
      -- Get UCC info      
      SET @cReceiptLineNumber = ''      
      SELECT @cReceiptLineNumber = SubString(UCC.Sourcekey, 11, 5)   
      FROM dbo.UCC WITH (NOLOCK)   
      WHERE UCCNo = @cUCC   
      AND StorerKey = @cStorerKey    
      AND SKU = @cSKU   
            
      -- Build custom SQL      
      IF @cReceiptLineNumber <> ''      
      BEGIN    
         SET @cCustomSQL = @cCustomSQL +       
            ' AND ReceiptLineNumber = ''' + RTRIM( @cReceiptLineNumber) + ''''       
      END    
          
   END    
   ELSE IF @cSourceType = 'PO'    
   BEGIN     
      SET @cPOLineNumber = ''    
      SET @cPOKey        = ''     
          
      SELECT  @cPOLineNumber = SubString(UCC.Sourcekey, 11, 5)     
            , @cPOKey        = SubString(UCC.Sourcekey, 1, 10)    
      FROM dbo.UCC WITH (NOLOCK)            
      WHERE UCCNo = @cUCC     
      AND StorerKey = @cStorerKey     
      AND SKU = @cSKU    
          
          
      IF @cPOLineNumber <> ''      
      BEGIN    
         SET @cCustomSQL = @cCustomSQL +       
            ' AND POKey = ''' + RTRIM( @cPOKey) + '''' +    
            ' AND POLineNumber = ''' + RTRIM( @cPOLineNumber) + ''''       
      END    
          
          
          
   END    
       
       
QUIT:    
END -- End Procedure    
SET QUOTED_IDENTIFIER OFF

GO