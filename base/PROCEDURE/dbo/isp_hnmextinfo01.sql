SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: isp_HnMExtInfo01                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: HnM cart inquiry Extended info                              */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-07-10 1.0  James    SOS303322 Created                           */    
/************************************************************************/    

CREATE PROCEDURE [dbo].[isp_HnMExtInfo01]    
   @nMobile          INT, 
   @nStep            INT,    
   @nInputKey        INT,    
   @cStorerKey       NVARCHAR( 15), 
   @cCartID          NVARCHAR( 10),    
   @cToteID          NVARCHAR( 20),    
   @cExtendedInfo    NVARCHAR( 20) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE 	@cPickZone     NVARCHAR( 10), 
            @cPTLPKZoneReq NVARCHAR( 1), 
            @nFunc         INT 

   IF @nStep <> 1 AND @nInputKey <> 1
      GOTO Quit

   SELECT @nFunc = Func FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile
   
     -- (james01)
   SET @cPTLPKZoneReq = ''
   SET @cPTLPKZoneReq = rdt.rdtGetConfig( @nFunc, 'PTLPicKZoneReq', @cStorerKey)  

   IF ISNULL( @cPTLPKZoneReq, '') <> ''
   BEGIN
      SET @cPickZone = ''
      SELECT TOP 1 @cPickZone = DL.UserDefine10 
      FROM dbo.DeviceProfileLog DL WITH (NOLOCK) 
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON D.DeviceProfileKey = DL.DeviceProfileKey
      WHERE D.DeviceID = @cCartID
      AND   DL.Status IN ('1','3')
      ORDER BY DL.UserDefine10 DESC -- with pickzone come first

      -- If RDT config is turn on and pickzone is blank then prompt error
      SET @cExtendedInfo = 'PKZONE: ' + @cPickZone
   END
     
QUIT:    
END -- End Procedure  

GO