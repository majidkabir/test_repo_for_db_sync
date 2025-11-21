SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc    : isp_GetDefaultRcptLoc                               */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Get Default Receipt Location                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2013-09-26   1.0  Shong      Created                                 */
/************************************************************************/
CREATE PROC [dbo].[isp_GetDefaultRcptLoc]   
(  
   @cReceiptKey NVARCHAR(10)
  ,@cStorerKey  NVARCHAR(15)
  ,@cSKU        NVARCHAR(20)
  ,@cDefaultLoc NVARCHAR(10) OUTPUT  
)  
AS  
BEGIN  
   DECLARE @cErrMsg     NVARCHAR(215)
          ,@nErrNo      INT
          ,@bSuccess    INT
          ,@cFacility   NVARCHAR(10)
          ,@cDocType    NVARCHAR(10)
   
   DECLARE @cAuthority NVARCHAR(1)    
   SET @bSuccess = 0    

   SET @cDefaultLoc = ''
   
   SELECT @cFacility = r.Facility, 
          @cDocType = r.DOCTYPE 
   FROM RECEIPT r WITH (NOLOCK)
   WHERE r.ReceiptKey = @cReceiptKey 
      
   EXECUTE nspGetRight    
      @cFacility,    
      @cStorerKey,    
      NULL, -- @cSKU    
      'ASNReceiptLocBasedOnFacility',    
      @bSuccess   OUTPUT,    
      @cAuthority OUTPUT,    
      @nErrNo     OUTPUT,    
      @cErrMsg    OUTPUT    
 
   IF @bSuccess = '1' AND @cAuthority = '1'  
   BEGIN
      SELECT @cDefaultLoc = UserDefine04    
      FROM Facility WITH (NOLOCK)    
      WHERE Facility = @cFacility         
   END
     
   IF @cDocType = 'R' AND ISNULL(RTRIM(@cSKU),'') <> '' 
   BEGIN
 		SELECT @cDefaultLoc = ReceiptInspectionLoc	
		FROM   SKU WITH (NOLOCK)
		WHERE  Storerkey = @cStorerKey 
		AND    SKU = @cSKU 
		
      IF ISNULL(RTRIM(@cDefaultLoc), '') <> ''
         GOTO ReturnValue      
   END         
   EXECUTE nspGetRight    
      @cFacility,    
      @cStorerKey,    
      NULL, -- @cSKU    
      'DefaultRcptLOC',    
      @bSuccess    OUTPUT,    
      @cDefaultLoc OUTPUT,    
      @nErrNo      OUTPUT,    
      @cErrMsg     OUTPUT    
 
   IF @bSuccess = '1' AND ISNULL(RTRIM(@cDefaultLoc),'') <> ''  
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cDefaultLoc AND Facility = @cFacility)
      BEGIN
         SET @cDefaultLoc = ''
      END       
   END
   

ReturnValue:
   SET @cDefaultLoc =  ISNULL(@cDefaultLoc, '')
END -- Function

GO