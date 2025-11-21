SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_868CapPackInfo01                                */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: UA check ordtype to determine whether need capture weight   */  
/*                                                                      */  
/* Called from: rdtfnc_PickAndPack                                      */  
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */  
/* 2021-05-07  1.0  James    WM-16960. Created                          */  
/************************************************************************/  

CREATE PROC [RDT].[rdt_868CapPackInfo01] (  
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @cPickSlipNo NVARCHAR( 10),
   @cDropID NVARCHAR( 20), 
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT,
   @cPackInfo   NVARCHAR( 3)  OUTPUT,
   @cWeight     NVARCHAR( 10) OUTPUT,
   @cCube       NVARCHAR( 10) OUTPUT,
   @cRefNo      NVARCHAR( 20) OUTPUT,
   @cCartonType NVARCHAR( 10) OUTPUT  

) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cOrderGroup    NVARCHAR( 20)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @nNeedWeight    INT = 0
   DECLARE @nNeedCtnType   INT = 0
   
   SET @cPackInfo = ''

   SELECT @cOrderKey = OrderKey
   FROM dbo.PICKHEADER WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo
               
   SELECT @cOrderGroup = OrderGroup, 
            @cShipperKey = ShipperKey
   FROM dbo.ORDERS WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey
               
   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
               WHERE LISTNAME = 'UAOrder' 
               AND   Short = @cOrderGroup 
               AND   Long = @cShipperKey)
   BEGIN
      SET @cPackInfo = 'TC'
      GOTO Quit
   END

   IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
               WHERE LISTNAME = 'UAOrder' 
               AND   ISNULL( Long, '') <> @cShipperKey) 
   BEGIN
      SET @cPackInfo = 'T'
      GOTO Quit
   END
      
   Quit:
END

GO