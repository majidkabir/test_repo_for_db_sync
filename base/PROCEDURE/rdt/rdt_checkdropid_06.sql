SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_CheckDropID_06                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Check duplicate Drop ID scanned (SOSxxxxx)                  */  
/*                                                                      */  
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 03-Aug-2012 1.0  James       Created                                 */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_CheckDropID_06] (  
   @cFacility                 NVARCHAR( 5),  
   @cStorerKey                NVARCHAR( 15),  
   @cOrderKey                 NVARCHAR( 10),  
   @cDropID                   NVARCHAR( 18),  
   @nValid                    INT          OUTPUT,   
   @nErrNo                    INT          OUTPUT,   
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max   
)  
AS  
BEGIN  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_success INT  
   DECLARE @n_err   INT  
   DECLARE @c_errmsg  NVARCHAR( 250)  
     
   DECLARE @cPickSlipNo NVARCHAR( 10)  
          ,@cWaveKey    NVARCHAR( 10)
     
   SELECT TOP 1 @cPickSlipNo = PickHeaderKey  
   FROM dbo.PickHeader WITH (NOLOCK)   
   WHERE OrderKey = @cOrderKey  
   
   SELECT @cWaveKey = UserDefine09
   FROM dbo.Orders WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
   
   IF EXISTS (SELECT 1 FROM PickDetail WITH (NOLOCK) 
              WHERE StorerKey = @cStorerKey
              AND Status <> '9' 
              AND DropID = @cDropID  ) 
   BEGIN 
      
--      IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPickLock WITH (NOLOCK)
--                      WHERE OrderKey = @cOrderKey
--                      AND StorerKey= @cStorerKey
--                      AND AddWho = suser_sname()
--                      AND DropID = @cDropID ) 
--      BEGIN
--         SET @nValid = 0  
--      END
--      ELSE
--      BEGIN
--         SET @nValid = 1
--      END
      SET @nValid = 0  
      --GOTO Quit  
   END
   ELSE
   BEGIN
      SET @nValid = 1  
   END
--   
--   IF ISNULL(@cPickSlipNo, '') = ''  
--   BEGIN  
--      SET @nValid = 0  
--      GOTO Quit  
--   END  
--   
--   
--   
--        
--   -- Check if dropid appear in different pickslip (Only work for discrete PS).  
--   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)   
--              WHERE StorerKey = @cStorerKey  
--              AND DropID = @cDropID  
--              AND PickSlipNo <> @cPickSlipNo)  
--      SET @nValid = 0  
--   ELSE  
--      SET @nValid = 1  
        
   Quit:  
END

GO