SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdtVFTWUCCRcvFilter                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Check UCC scan to ID have same SKU, QTY, L02                */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 12-09-2012  1.0  Ung         SOS255639. Created                      */  
/* 25-02-2014  1.1  ChewKP      SOS#303765 - Add additional filter      */  
/*                              on UCC.UserDefined03 (ChewKP01)         */  
/* 26-03-2015  1.2  ChewKP      SOS#337011 (ChewKP02)                   */  
/* 29-09-2015  1.3  ChewKP      SOS#352657 Add CNV StorerKey (ChewKP03) */
/* 06-03-2018  1.4  SPChin      INC0095381 - Fixed                      */  
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdtVFTWUCCRcvFilter]  
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
   DECLARE @cStorerKey NVARCHAR(15)  
          ,@cPOLineNumber NVARCHAR(5)   
          ,@cFilterCode   NVARCHAR(5) -- (ChewKP03)   
     
             
   SELECT @cStorerKey = StorerKey FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey  
     
   -- Get UCC info  
   DECLARE @cExternKey NVARCHAR( 20)  
         , @cUserDefine03 NVARCHAR(20)   
   SET @cExternKey = ''  
   SET @cPOKey     = ''  
   SET @cPOLineNumber = ''  
  
   DECLARE @cSourceKey NVARCHAR(20)   
   SELECT @cExternKey    = ExternKey  
         ,@cUserDefine03 = SubString(UserDefined03, 1, 10)     -- (ChewKP01)  
         ,@cPOKey        = SUBSTRING(UCC.Sourcekey,1,10)       -- (ChewKP02)   
         ,@cPOLineNumber = SUBSTRING(UCC.Sourcekey,11,5)       -- (ChewKP02)   
          
   FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey AND SKU = @cSKU   
     
   SELECT @cFilterCode = Code   
   FROM dbo.Codelkup WITH (NOLOCK)  
   WHERE ListName = 'UCCFilter'  
   AND StorerKey = ISNULL(RTRIM(@cStorerKey),'' )   
  
   -- Build custom SQL  
   IF @cExternKey <> ''  
   BEGIN  
      IF ISNULL(RTRIM(@cFilterCode),'' ) = '1' --IF ISNULL(RTRIM(@cUserDefine03),'' ) = '' -- Storer = NIK -- (ChewKP03)  
      BEGIN  
  
         SET @cCustomSQL = @cCustomSQL +   
         ' AND RTRIM( ExternReceiptKey) = ''' + RTRIM( @cExternKey) + '''' +   
         ' AND RTRIM( PoKey) = ''' + RTRIM( @cPOKey) + '''' + -- (ChewKP02)  
         ' AND RTRIM( POLineNumber) = ''' + RTRIM( @cPOLineNumber) + '''' -- (ChewKP02)  
      END  
      ELSE IF ISNULL(RTRIM(@cFilterCode),'' ) = '2'  
      BEGIN  
  
         SET @cCustomSQL = @cCustomSQL +   
            ' AND RTRIM( ExternReceiptKey) = ''' + RTRIM( @cExternKey) + '''' +  
            ' AND RTRIM( UserDefine03) = ''' + RTRIM( @cUserDefine03) + '''' + -- (ChewKP01) --INC0095381 
            ' AND RTRIM( PoKey) = ''' + RTRIM( @cPOKey) + '''' -- (ChewKP02)   
  
  
      END  
   END  
QUIT:  
END -- End Procedure  
  


GO