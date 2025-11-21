SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/    
/* Store procedure: rdt_595ExtInfo                                      */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Display Extended Information                                */    
/*                                                                      */    
/* Called from: rdtfnc_InquiryUCCASN                                    */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 2014-12-01  1.0  ChewKP     SOS#326722 Created                       */   
/* 2019-05-27  1.1  James      WMS-9128 Add ASNStatus 1 (james01)       */   
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_595ExtInfo]  ( 
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cUCCNo      NVARCHAR(20), 
   @cOutField01 NVARCHAR( 20) OUTPUT, 
   @cOutField02 NVARCHAR( 20) OUTPUT, 
   @cOutField03 NVARCHAR( 20) OUTPUT, 
   @cOutField04 NVARCHAR( 20) OUTPUT, 
   @cOutField05 NVARCHAR( 20) OUTPUT, 
   @cOutField06 NVARCHAR( 20) OUTPUT, 
   @cOutField07 NVARCHAR( 20) OUTPUT, 
   @cOutField08 NVARCHAR( 20) OUTPUT, 
   @cOutField09 NVARCHAR( 20) OUTPUT, 
   @cOutField10 NVARCHAR( 20) OUTPUT, 
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS  
  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
IF @nFunc = 595  
BEGIN  
    
    DECLARE @cReceiptKey NVARCHAR(10) 
           ,@cWarehouseRef NVARCHAR(18) 
           ,@nUCCCount     INT
           
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @cReceiptKey     = ''
    SET @cWareHouseRef   = ''
    SET @nUCCCount       = 0
    
   
    IF @nStep = 1
    BEGIN
       IF EXISTS ( SELECT 1  FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                   INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
                   WHERE RD.StorerKey = @cStorerKey
                   AND RD.UserDefine01 = @cUCCNo
                   AND R.ASNStatus IN ( '0', '1')) -- (james01)
       BEGIN
            SELECT @cReceiptKey = R.Receiptkey
                  ,@cWarehouseRef = R.WarehouseReference
            FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
            INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
            WHERE RD.StorerKey = @cStorerKey
            AND RD.UserDefine01 = @cUCCNo
            AND R.ASNStatus IN ( '0', '1')   -- (james01)
            
            SELECT @nUCCCount = Count(Distinct Userdefine01 ) 
            FROM dbo.ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey
            
            
            SET @cOutField02 = @cUCCNo
            SET @cOutField03 = ''
            SET @cOutField04 = 'ASN:' + @cReceiptKey
            SET @cOutField05 = 'WareHouseReference:'
            SET @cOutfield06 = @cWarehouseRef 
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = 'TTL CARTON: ' + CAST(@nUCCCount AS NVARCHAR(5))
            SET @cOutField10 = ''
            
            
       END
    END
    

   
END  
  
QUIT:  


GO