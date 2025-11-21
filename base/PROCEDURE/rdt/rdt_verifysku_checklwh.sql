SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Store procedure: rdt_VerifySKU_CheckLWH                              */          
/* Copyright      : LF Logistics                                        */          
/*                                                                      */          
/* Date        Rev  Author       Purposes                               */          
/* 04/05-2020  1.0  YeeKung     WMS-11867. Created                      */          
/************************************************************************/          
                      
CREATE PROCEDURE [RDT].[rdt_VerifySKU_CheckLWH]         
   @nMobile     INT,          
   @nFunc       INT,          
   @cLangCode   NVARCHAR( 3),          
   @nStep       INT,           
   @nInputKey   INT,           
   @cFacility   NVARCHAR( 3),           
   @cStorerKey  NVARCHAR( 15),          
   @cSKU        NVARCHAR( 20),          
   @cType       NVARCHAR( 15),          
   @cLabel      NVARCHAR( 30)  OUTPUT,           
   @cShort      NVARCHAR( 10)  OUTPUT,           
   @cValue      NVARCHAR( MAX) OUTPUT,           
   @nErrNo      INT            OUTPUT,          
   @cErrMsg     NVARCHAR( 20)  OUTPUT          
AS          
BEGIN          
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @cPackKey       NVARCHAR( 10)    
   DECLARE @fWeight        FLOAT    
   DECLARE @fCube          FLOAT    
   DECLARE @fLength        FLOAT    
   DECLARE @fWidth         FLOAT    
   DECLARE @fHeight        FLOAT    
   DECLARE @fInnerPack     FLOAT    
   DECLARE @fCaseCount     FLOAT    
   DECLARE @fPalletCount   FLOAT    
   DECLARE @nShelfLife     INT    
   DECLARE @cPackUOM2      NVARCHAR( 10)    
   DECLARE @cPackUOM1      NVARCHAR( 10)    
   DECLARE @cPackUOM4      NVARCHAR( 10)    
   DECLARE @cInnerUOM      NVARCHAR( 10)    
   DECLARE @cCaseUOM       NVARCHAR( 10)    
   DECLARE @cPalletUOM     NVARCHAR( 10)          
    
   DECLARE  @cErrMsg1 NVARCHAR(20),    
            @cErrMsg2 NVARCHAR(20),    
            @cErrMsg3 NVARCHAR(20),    
            @cErrMsg4 NVARCHAR(20),    
            @cErrMsg5 NVARCHAR(20),    
            @cErrMsg6 NVARCHAR(20),    
            @cErrMsg7 NVARCHAR(20),    
            @cErrMsg8 NVARCHAR(20),    
            @cErrMsg9 NVARCHAR(20),    
            @cErrMsgShow INT =0    
       
   DECLARE @cChkInfo        NVARCHAR( 1)      
   DECLARE @cChkWeight      NVARCHAR( 1)      
   DECLARE @cChkCube        NVARCHAR( 1)      
   DECLARE @cChkLength      NVARCHAR( 1)      
   DECLARE @cChkWidth       NVARCHAR( 1)      
   DECLARE @cChkHeight      NVARCHAR( 1)      
   DECLARE @cChkInnerPack   NVARCHAR( 1)      
   DECLARE @cChkCaseCount   NVARCHAR( 1)      
   DECLARE @cChkPalletCount NVARCHAR( 1)      
                        
               
          
   /***********************************************************************************************          
                                                 CHECK          
   ***********************************************************************************************/          
   IF @cType = 'CHECK'          
   BEGIN         
    
       SELECT    
         @fWeight      = SKU.STDGrossWGT,    
         @fCube        = SKU.STDCube,    
         @nShelfLife   = SKU.ShelfLife,    
         @fLength      = SKU.Length,    
         @fWidth       = SKU.Width,    
         @fHeight      = SKU.Height,    
         @fInnerPack   = Pack.InnerPack,    
         @fCaseCount   = Pack.CaseCnt,    
         @fPalletCount = Pack.Pallet,    
         @cPackKey     = Pack.PackKey,    
         @cPackUOM2    = Pack.PackUOM2,    
         @cPackUOM1    = Pack.PackUOM1,    
         @cPackUOM4    = Pack.PackUOM4    
      FROM dbo.SKU WITH (NOLOCK)    
         JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
      WHERE StorerKey = @cStorerKey    
         AND SKU = @cSKU    
    
      -- Get check field setting    
      SET @cChkWeight      = ''      
      SET @cChkCube        = ''      
      SET @cChkLength      = ''      
      SET @cChkWidth       = ''      
      SET @cChkHeight      = ''          SET @cChkInnerPack   = ''      
      SET @cChkCaseCount   = ''      
      SET @cChkPalletCount = ''      
      SET @cChkInfo        = ''      
      
      SELECT @cChkInfo        = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Info'      
      SELECT @cChkWeight      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Weight'      
      SELECT @cChkCube        = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Cube'      
      SELECT @cChkLength      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Length'      
      SELECT @cChkWidth       = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Width'      
      SELECT @cChkHeight      = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Height'      
      SELECT @cChkInnerPack   = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Inner'      
      SELECT @cChkCaseCount   = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Case'      
      SELECT @cChkPalletCount = Short FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'VerifySKU' AND StorerKey = @cStorerKey AND Code = 'Pallet'      
      
      DECLARE @nQTY INT,  
              @cReceiptkey NVARCHAR(20)  
  
      SELECT @cReceiptkey = V_ReceiptKey  
      FROM RDT.RDTmobrec (NOLOCK)  
      WHERE Mobile =@nMobile  
  
      IF EXISTS (SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)  
                  WHERE receiptkey=@cReceiptkey  
                  AND SKU=@cSKU  
                  AND BeforeReceivedQty=0)  
      BEGIN  
  
         -- Check weight      
         IF @cChkWeight = '1' AND @fWeight = 0      
         BEGIN     
            SET @cErrMsgShow='-1'    
            SET @nErrNo = 152901          
            SET @cErrMsg2 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg2 = @cErrMsg2+':'+ Cast(@fWeight AS NVARCHAR(5))       
         END      
      
         -- Check cube      
         IF @cChkCube = '1'   AND @fCube = 0      
         BEGIN     
            SET @cErrMsgShow='-1'   
            SET @nErrNo = 152902          
            SET @cErrMsg3 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg3 = @cErrMsg3+':'+ Cast(@fCube AS NVARCHAR(5))     
         END      
      
         -- Check length      
         IF  @cChkLength = '1' AND @fLength = 0      
         BEGIN    
            SET @cErrMsgShow='-1'    
            SET @nErrNo = 152903         
            SET @cErrMsg4 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg4 = @cErrMsg4+':'+ Cast(@fLength AS NVARCHAR(5))      
         END      
        
         -- Check width      
         IF  @cChkWidth = '1' AND @fWidth = 0      
         BEGIN     
            SET @cErrMsgShow='-1'    
            SET @nErrNo = 152904        
            SET @cErrMsg5 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg5 = @cErrMsg5+':'+ Cast(@fWidth AS NVARCHAR(5))    
         END      
      
         -- Check Height      
         IF  @cChkHeight = '1'  AND @fHeight = 0      
         BEGIN      
            SET @cErrMsgShow='-1'    
            SET @nErrNo = 152905        
            SET @cErrMsg6 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg6 = @cErrMsg6+':'+ Cast(@fHeight AS NVARCHAR(5))    
         END      
    
         -- Check Inner      
         IF  @cChkInnerPack = '1'  AND @fInnerPack = 0      
         BEGIN     
            SET @cErrMsgShow='-1'    
            SET @nErrNo = 152906       
            SET @cErrMsg7 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg7 = @cErrMsg7+':'+ Cast(@fInnerPack AS NVARCHAR(5))    
         END      
    
         -- Check Case      
         IF  @cChkCaseCount = '1'  AND @fCaseCount = 0      
         BEGIN      
            SET @cErrMsgShow='-1'    
            SET @nErrNo = 152907       
            SET @cErrMsg8 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg8 = @cErrMsg8+':'+ Cast(@fCaseCount AS NVARCHAR(5))    
         END      
    
         -- Check Pallet      
         IF  @cChkPalletCount = '1'  AND @fPalletCount = 0      
         BEGIN      
            SET @cErrMsgShow='-1'    
            SET @nErrNo = 152908       
            SET @cErrMsg9 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')      
            SET @cErrMsg9 = @cErrMsg9+':'+ Cast(@fPalletCount AS NVARCHAR(5))       
         END     
    
         IF @cErrMsgShow='-1'             
            GOTO Message    
      END  
   END    
   GOTO QUIT    
    
MESSAGE: --(yeekung01)    
       
   SET @cErrMsg1='WARNING'    
    
   EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,    
   'Pls Setup Correct',        
   'Value',    
   @cErrMsg1,    
   @cErrMsg2,    
   @cErrMsg3,    
   @cErrMsg4,    
   @cErrMsg5,    
   @cErrMsg6,    
   @cErrMsg7,    
   @cErrMsg8,    
   @cErrMsg9    
       
   SET @nErrNo=-2  
    
Fail:          
QUIT:    
             
END     

GO