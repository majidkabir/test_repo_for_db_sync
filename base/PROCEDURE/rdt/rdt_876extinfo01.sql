SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_876ExtInfo01                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_SerialNoByOrder                            */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2016-02-25  1.0  ChewKP   SOS#364494 Created                         */    
/************************************************************************/    

CREATE PROC [RDT].[rdt_876ExtInfo01] (    
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cExternOrderKey   NVARCHAR(18),  
   @cOrderKey         NVARCHAR(18),  
   @cSerialNo         NVARCHAR(18),  
   @cSKU              NVARCHAR(20),
   @cOutInfo01        NVARCHAR(20) OUTPUT,
   @nErrNo            INT       OUTPUT,   
   @cErrMsg           CHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @nTTLQtyPicked INT 
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     

   
   IF @nFunc = 876          
   BEGIN     
         
         IF @nStep = '2'   
         BEGIN       
            
            
            SELECT @nTTLQtyPicked = SUM(QTYPicked) 
            FROM dbo.OrderDetail WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            AND StorerKey = @cStorerKey 
            
            SET @cOutInfo01 = 'TTLQTY: ' + CAST(@nTTLQtyPicked AS NVARCHAR(5))
            
            INSERT INTO TraceInfo (TracEName , TimeIn, Col1, Col2, col3 , col4 ) 
            VALUES ( 'rdt_876ExtInfo01' , getdate() ,@cOrderKey , @cStorerKey,@nTTLQtyPicked  ,@cOutInfo01 ) 
                      
         END      
                
   END          
          

            
       
END     

GO