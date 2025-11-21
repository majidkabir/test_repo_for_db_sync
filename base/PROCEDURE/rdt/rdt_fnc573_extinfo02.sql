SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Copyright: LF                                                        */  
/* Purpose:                                                             */  
/*                                                                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2017-05-17 1.0  ChewKP     WMS-1920 Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_Fnc573_ExtInfo02] (  
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
    @nType INT 
   ,@cType NVARCHAR(10)   
  

     
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
  
     
     
   IF @nStep IN ( 3, 4  )
   BEGIN  
      SET @cReceiptKey = ''
      
      SELECT @cReceiptKey = V_String1 
      FROM rdt.rdtMobrec WITH (NOLOCK) 
      WHERE Mobile = @nMobile 

      INSERT INTO TRACEINFO ( TracEName , TimeIN, Col1, Col2 ) 
      VALUES ( 'rdt_Fnc573_ExtInfo02' , Getdate() ,@cReceiptKey ,@cUCC ) 
 
      IF ISNULL(@cUCC,'') <> '' 
      BEGIN 
         SELECT @nType = ISNULL(COUNT(1) ,0 ) 
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND UserDefine01 = @cUCC
         GROUP BY Userdefine01

         SET @cType = CASE WHEN @nType = 1 THEN 'S' ELSE 'M' END
      END
      ELSE
      BEGIN
         SELECT @nType = ISNULL(COUNT(1) ,0 ) 
         FROM RECEIPTDETAIL (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cID
         GROUP BY Userdefine01

         IF @@ROWCOUNT = 0 
         BEGIN 
            SET @cType = 'NEW ID'
         END
         ELSE
         BEGIN
            SET @cType = CASE WHEN @nType = 1 THEN 'S' ELSE 'M' END
         END
      END
      
  
      SET @cOutField06 = 'ID TYPE: '  + @cType
      SET @cOutField07 = ''
      SET @cOutField08 = ''  
        
   END  
  
     
END  

GO