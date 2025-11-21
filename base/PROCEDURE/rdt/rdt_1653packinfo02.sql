SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store procedure: rdt_1653PackInfo02                                  */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Called from: rdtfnc_TrackNo_SortToPallet                             */      
/*                                                                      */      
/* Purpose: If shipperkey within pallet is not within codelkup don't    */      
/*          show dimesion screen                                        */  
/*                                                                      */      
/* Modifications log:                                                   */      
/* Date        Rev  Author   Purposes                                   */      
/* 2023-05-22  1.0  James    WMS-22499. Created                         */    
/************************************************************************/      
      
CREATE   PROC [RDT].[rdt_1653PackInfo02] (      
   @nMobile            INT,  
   @nFunc              INT,  
   @cLangCode          NVARCHAR( 3),  
   @nStep              INT,  
   @nInputKey          INT,  
   @cFacility          NVARCHAR( 5),  
   @cStorerkey         NVARCHAR( 15),  
   @cTrackNo           NVARCHAR( 40),  
   @cOrderKey          NVARCHAR( 10),  
   @cPalletKey         NVARCHAR( 20),  
   @cMBOLKey           NVARCHAR( 10),  
   @cWeight            NVARCHAR( 10) OUTPUT,  
   @cLength            NVARCHAR( 10) OUTPUT,  
   @cWidth             NVARCHAR( 10) OUTPUT,  
   @cHeight            NVARCHAR( 10) OUTPUT,  
   @cCapturePackInfo   NVARCHAR( 10) OUTPUT,  
   @tCapturePackInfo   VariableTable READONLY,  
   @nErrNo             INT           OUTPUT,  
   @cErrMsg            NVARCHAR( 20) OUTPUT  
) AS      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
     
   DECLARE @cShipperKey    NVARCHAR( 15)  
   DECLARE @fPltLength     FLOAT  
   DECLARE @fPltWidth      FLOAT  
   DECLARE @fPltHeight     FLOAT  
   DECLARE @cUDF01         NVARCHAR( 60)  
   DECLARE @cUDF02         NVARCHAR( 60)  
   DECLARE @cUDF03         NVARCHAR( 60)  
     
   SET @cCapturePackInfo = ''  
     
   IF EXISTS ( SELECT 1   
               FROM dbo.PalletDetail PD WITH (NOLOCK)  
               JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.UserDefine01 = O.OrderKey AND PD.StorerKey = O.StorerKey)   
               LEFT JOIN dbo.Codelkup CL WITH (NOLOCK) ON O.BillToKey = CL.Code AND O.StorerKey = CL.StorerKey AND CL.ListName = 'NOMIXPLSHP'  
               WHERE O.StorerKey = @cStorerKey  
               AND PD.PalletKey = @cPalletKey  
               AND ISNULL( CL.Code, '') <> '')  
   BEGIN  
    --UDF01 = width, UDF02 = length in cm, UDF03 = height in cm  
    SELECT   
       @cUDF01 = UDF01,   
       @cUDF02 = UDF02,  
       @cUDF03 = UDF03  
    FROM dbo.CODELKUP WITH (NOLOCK)   
    WHERE LISTNAME = 'ADIPLTDM'  
    AND   Storerkey = @cStorerkey  
    AND   CHARINDEX( Code, @cPalletKey) > 0  
  
      IF @cUDF03 = ''  
      BEGIN  
       SELECT   
          @cUDF03 = UDF03  
       FROM dbo.CODELKUP WITH (NOLOCK)   
       WHERE LISTNAME = 'ADIPLTDM'  
       AND   Storerkey = @cStorerkey  
       AND   CODE = 'DEFAULT'  
      END  
           
    SET @cCapturePackInfo = 'H'   -- Default need key in height, other disable  
      
      SET @cLength = CASE WHEN @cUDF02 <> '' THEN @cUDF02 ELSE '' END  
      SET @cWidth = CASE WHEN @cUDF01 <> '' THEN @cUDF01 ELSE '' END  
      SET @cHeight = CASE WHEN @cUDF03 <> '' THEN @cUDF03 ELSE '' END  
   END  
   ELSE  
    SET @cCapturePackInfo = ''  
        
   GOTO Quit  
     
   Quit:    
  
END      

GO