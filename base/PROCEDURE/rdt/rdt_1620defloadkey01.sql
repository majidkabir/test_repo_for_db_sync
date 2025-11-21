SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1620DefLoadKey01                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_Cluster_Pick                                     */    
/*                                                                      */    
/* Purpose: Retrieve LoadKey from Wave                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-03-08  1.0  James    WMS-19077. Created                         */  
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_1620DefLoadKey01] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cWaveKey       NVARCHAR( 10),
   @cLoadKey       NVARCHAR( 10) OUTPUT,
   @cOrderKey      NVARCHAR( 10) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   IF @nStep =1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cLoadKey = LPD.Loadkey
         From dbo.LoadPlanDetail LPD WITH (NOLOCK)
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( LPD.OrderKey = O.OrderKey)
         WHERE O.UserDefine09 = @cWaveKey
         AND   O.StorerKey = @cStorerKey
         ORDER BY 1
      END
   END
   
   Quit:  
    
END    

GO