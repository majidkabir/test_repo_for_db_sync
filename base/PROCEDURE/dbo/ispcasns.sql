SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: ispChangeASNStorer                                  */  
/* Copyright: IDS                                                       */  
/* Purpose: Resume StorerKey from Userdefine01                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date         Author    Ver.  Purposes                                */  
/* 2014-03-28   Roy He    1.0   SOS307109 ChangeASNStorer               */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispCASNS]  
   @cReceiptKey  NVARCHAR(10),  
   @bSuccess     INT = 1  OUTPUT,  
   @nErrNo       INT = 0  OUTPUT,  
   @cErrMsg      NVARCHAR(250) = '' OUTPUT,  
   @c_ReceiptLineNumber  NVARCHAR(5) = ''   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cStorerKey    NVARCHAR( 15),  
           @cUDStorerKey  NVARCHAR( 15)  
     
   SET @bSuccess = 1  
     
   -- Get StorerKey in userdefine01  
   SELECT  
      @cStorerKey   = StorerKey,   
      @cUDStorerKey = UserDefine01  
   FROM dbo.Receipt WITH (NOLOCK)  
   WHERE ReceiptKey = @cReceiptKey  
   SET @cUDStorerKey = ISNULL(@cUDStorerKey,'')  
       
   -- Check userdefine01  
   IF RTrim(@cUDStorerKey) = ''  
      GOTO Quit  
     
   -- Validate storerKey and userdefine01  
   IF @cStorerKey = @cUDStorerKey  
      GOTO Quit  
  
   -- Validate UDStorerKey  
   IF NOT EXISTS(SELECT 1 FROM dbo.Storer WITH (NOLOCK) WHERE StorerKey = @cUDStorerKey AND [type] = '1')  
   BEGIN  
      SET @cErrMsg = 'Invalid StorerKey In UserDefine01: ' + @cUDStorerKey  
      GOTO Quit  
   END  
     
   -- Update data  
   UPDATE dbo.Receipt WITH (ROWLOCK) SET  
      StorerKey = @cUDStorerKey   
   WHERE ReceiptKey = @cReceiptKey  
   IF @@ERROR <> 0  
   BEGIN  
      SET @cErrMsg = 'Error update ReceiptKey =' + @cUDStorerKey  
      SET @bSuccess = 0  
   END  
  
Quit:  
  
END

GO