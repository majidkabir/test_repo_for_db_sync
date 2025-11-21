SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_841RefNoLKUP01                                  */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Look up loadkey from RefNo (pickslip no)                    */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2021-05-27  1.0  James    WMS-17077. Created                         */ 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_841RefNoLKUP01] (    
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT,
   @cStorerkey                NVARCHAR( 15),
   @cRefNo                    NVARCHAR( 20),
   @cToteNo                   NVARCHAR( 20) OUTPUT,
   @cWaveKey                  NVARCHAR( 10) OUTPUT,
   @cLoadKey                  NVARCHAR( 10) OUTPUT,
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT

) AS
BEGIN
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
     
   DECLARE @cOrderKey      NVARCHAR( 10)
   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT TOP 1 @cOrderKey = OrderKey
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerkey
         AND   PickSlipNo = @cRefNo
         AND   [Status] < '9'
         ORDER BY 1

         SELECT @cLoadKey = LoadKey
         FROM dbo.LoadPlanDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
      END   
   END
END   

QUIT:
 

GO