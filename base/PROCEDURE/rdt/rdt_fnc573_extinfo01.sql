SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Copyright: IDS                                                       */  
/* Purpose: ReceiptDetail received base on UCC. 1 UCC consist of        */  
/*          multiple ReceiptDetail line                                 */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2012-10-18 1.0  UngDH      SOS#255485 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_Fnc573_ExtInfo01] (  
   @nMobile     int,  
   @nFunc       int,  
   @nStep       int,  
   @cStorerKey  nvarchar(15),  
   @cReceiptKey nvarchar(20),  
   @cLoc        nvarchar(20),  
   @cID         nvarchar(18),  
   @cUCC        nvarchar(20),  
   @nErrNo      int  OUTPUT,  
   @cErrMsg     nvarchar(1024) OUTPUT, -- screen limitation, 20 char max  
   @cOutField01 nvarchar(60) OUTPUT ,  
   @cOutField02 nvarchar(60) OUTPUT,  
   @cOutField03 nvarchar(60) OUTPUT,  
   @cOutField04 nvarchar(60) OUTPUT,  
   @cOutField05 nvarchar(60) OUTPUT,  
   @cOutField06 nvarchar(60) OUTPUT,  
   @cOutField07 nvarchar(60) OUTPUT,  
   @cOutField08 nvarchar(60) OUTPUT,  
   @cOutField09 nvarchar(60) OUTPUT,  
   @cOutField10 nvarchar(60) OUTPUT  
     
)  
AS  
BEGIN  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
-- Misc variable  
DECLARE  
   @cExternPOKey       nvarchar(20)  
   , @cOUserDefine01   nvarchar(18)  
   , @cOUserDefine02   nvarchar(18)  
   , @cOrderKey        nvarchar(10)  
   , @cRoute           nvarchar(10)  
     
  
   SET @cExternPOKey    = ''  
     
   SET @cOUserDefine01  = ''  
   SET @cOUserDefine02  = ''  
   SET @cOrderKey       = ''  
   SET @cRoute          = ''  
     
   --SET @cOutField01  = ''  
   --SET @cOutField02  = ''  
   --SET @cOutField03  = ''  
   --SET @cOutField04  = ''  
   --SET @cOutField05  = ''  
   SET @cOutField06  = ''  
   SET @cOutField07  = ''  
   SET @cOutField08  = ''  
   --SET @cOutField09  = ''  
   --SET @cOutField10  = ''  
  
     
     
   IF @nStep = 4  
   BEGIN  
        
      SELECT TOP 1 @cExternPOKey = ExternPOKey  
      FROM dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND ReceiptKey = @cReceiptKey  
      AND UserDefine01 = ISNULL(RTRIM(@cUCC),'')  
        
        
        
      SELECT TOP 1 @cOrderKey = OrderKey  
      FROM dbo.OrderDetail WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND ExternOrderKey = @cExternPOKey  
      AND ISNULL(RTRIM(@cUCC),'') = ISNULL(RTRIM(UserDefine01),'') + ISNULL(RTRIM(UserDefine02),'')  
        
        
      SELECT @cRoute = Route  
      FROM dbo.Orders WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  
        
       
        
      SET @cOutField06 = 'Route:'  
      SET @cOutField07 = @cRoute  
      SET @cOutField08 = @cUCC  
        
   END  
  
     
END  

GO