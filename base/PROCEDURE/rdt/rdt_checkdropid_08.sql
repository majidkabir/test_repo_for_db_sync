SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_CheckDropID_08                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Check duplicate Drop ID scanned                             */  
/*                                                                      */  
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2021-02-17  1.0  James       WMS-16369. Created                      */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CheckDropID_08] (  
   @cFacility                 NVARCHAR( 5),  
   @cStorerKey                NVARCHAR( 15),  
   @cOrderKey                 NVARCHAR( 10),  
   @cDropID                   NVARCHAR( 18),  
   @nValid                    INT          OUTPUT,   
   @nErrNo                    INT          OUTPUT,   
   @cErrMsg                   NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
       
   DECLARE @cWaveKey    NVARCHAR( 10)
          ,@cLoadKey    NVARCHAR( 10)
          ,@cDropID_OrderKey  NVARCHAR( 10)
          ,@cDropID_WaveKey   NVARCHAR( 10)
          ,@cDropID_LoadKey   NVARCHAR( 10)
     
   SELECT @cWaveKey = UserDefine09,
          @cLoadKey = LoadKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   
   SELECT TOP 1 @cDropID_OrderKey = OrderKey
   FROM dbo.PICKDETAIL WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   --AND Status <> '9' 
   AND DropID = @cDropID
   ORDER BY 1

   -- If dropid already picked something
   IF @@ROWCOUNT > 0
   BEGIN 
      SELECT @cDropID_WaveKey = UserDefine09,
             @cDropID_LoadKey = LoadKey
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cDropID_OrderKey
      
      -- If dropid not under same wave/load
      IF @cWaveKey <> @cDropID_WaveKey OR
         @cLoadKey <> @cDropID_LoadKey
         SET @nValid = 0
      ELSE
         SET @nValid = 1  
   END
   ELSE
   BEGIN
      SET @nValid = 1  
   END

        
   Quit:  
END

GO