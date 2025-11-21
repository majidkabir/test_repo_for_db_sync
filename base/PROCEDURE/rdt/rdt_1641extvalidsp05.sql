SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP05                                      */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-05-31 1.0  ChewKP   WMS-1992 Created                                  */
/* 2019-02-11 1.1  ChewKP   WMS-7894 Add Pallet Criteria Validation (ChewKP01)*/
/* 2019-11-27 1.2  James    WMS-11249 Add extra pallet validation (james01)   */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP05] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nFunc = 1641
BEGIN
   DECLARE @cPickSlipNo NVARCHAR(10) 
          ,@cOrderKey   NVARCHAR(10) 
          ,@cSortCode   NVARCHAR(13)
          ,@cRoute      NVARCHAR(10) 
          ,@cExternOrderKey NVARCHAR(30) 
          ,@cPalletSortCode NVARCHAR(13) 
          ,@cUserDefine09   NVARCHAR(10)
          
   DECLARE @cUDF01          NVARCHAR(60)  
   DECLARE @cUDF02          NVARCHAR(60)  
   DECLARE @cUDF03          NVARCHAR(60)  
   DECLARE @cUDF04          NVARCHAR(60)  
   DECLARE @cUDF05          NVARCHAR(60)            

   DECLARE @nSGRetailer     INT = 0
   DECLARE @cConsigneeKey   NVARCHAR( 15)
   DECLARE @cChkUCCNo       NVARCHAR( 20)
   DECLARE @cChkPickSlipNo  NVARCHAR( 10)
   DECLARE @cChkRoute       NVARCHAR( 10)
   DECLARE @cChkOrderKey    NVARCHAR( 10)
       
   SET @nErrNo = 0

   IF @nStep = 1 -- Drop id
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   PalletKey = @cDropID
                     AND  [Status] = '9')
         BEGIN
            SET @nErrNo = 110651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet closed
            GOTO Quit               
         END
      END
   END

   IF @nStep = 3 -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         
         -- (ChewKP01) 
         SELECT  
            @cUDF01 = LEFT( ISNULL( UDF01, ''), 20),   
            @cUDF02 = LEFT( ISNULL( UDF02, ''), 20),   
            @cUDF03 = LEFT( ISNULL( UDF03, ''), 20),   
            @cUDF04 = LEFT( ISNULL( UDF04, ''), 20),   
            @cUDF05 = LEFT( ISNULL( UDF05, ''), 20)  
         FROM DropID WITH (NOLOCK)   
         WHERE DropID = @cDropID  
         
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   CaseID = @cUCCNo
                     AND  [Status] < '9')
         BEGIN
            SET @nErrNo = 110652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CartonExist
            GOTO Quit               
         END
         
         IF EXISTS ( SELECT 1   
                           FROM dbo.PalletDetail WITH (NOLOCK) 
                           WHERE StorerKey = @cStorerKey
                           AND PalletKey = @cDropID  ) 
         BEGIN 
            
            IF ISNULL(@cUDF01,'')  IN ( '' , '1' ) 
            BEGIN
            
               SELECT Top 1 @cPalletSortCode = ISNULL(UserDefine01 ,'') 
               FROM dbo.PalletDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND PalletKey = @cDropID 
               
               
               SELECT @cPickSlipNo = PickSlipNo 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND LabelNo = @cUCCNo 
               
               SELECT @cOrderKey = OrderKey 
               FROM dbo.PackHeader WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
               
               SELECT @cRoute = ISNULL(Route,'') 
                     ,@cExternOrderKey = ExternOrderKey
                     ,@cConsigneeKey = ConsigneeKey
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey 

               -- ( james01)
               IF EXISTS ( SELECT 1 FROM dbo.STORER S WITH (NOLOCK) 
                           WHERE StorerKey = @cConsigneeKey 
                           AND S.[type] = '2' 
                           AND S.Notes2 = 'SGRETAILER')               
                  SET @nSGRetailer = 1

               IF @nSGRetailer <> 1
               BEGIN
                  SET @cSortCode = RTRIM(@cRoute) + RIGHT(RTRIM(@cExternOrderKey),5)

                  IF @cSortCode <> @cPalletSortCode
                  BEGIN
                     SET @nErrNo = 110653
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SortCodeDiff
                  END
               END
            END
            ELSE IF @cUDF01 = '2'
            BEGIN
               SELECT Top 1 @cPalletSortCode = ISNULL(UserDefine01 ,'') 
               FROM dbo.PalletDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND PalletKey = @cDropID 
               
               
               SELECT @cPickSlipNo = PickSlipNo 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND LabelNo = @cUCCNo 
               
               SELECT @cOrderKey = OrderKey 
               FROM dbo.PackHeader WITH (NOLOCK) 
               WHERE PickSlipNo = @cPickSlipNo 
               
               SELECT @cRoute = ISNULL(Route,'') 
                     ,@cUserDefine09 = ISNULL(UserDefine09,'') 
                     ,@cConsigneeKey = ConsigneeKey
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey 

               -- ( james01)
               IF EXISTS ( SELECT 1 FROM dbo.STORER S WITH (NOLOCK) 
                           WHERE StorerKey = @cConsigneeKey 
                           AND S.[type] = '2' 
                           AND S.Notes2 = 'SGRETAILER')               
                  SET @nSGRetailer = 1

               IF @nSGRetailer <> 1
               BEGIN
                  SET @cSortCode = RTRIM(@cRoute) + RIGHT(RTRIM(@cUserDefine09),5)

                  IF @cSortCode <> @cPalletSortCode
                  BEGIN
                     SET @nErrNo = 110655
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --SortCodeDiff
                  END
               END
            END
            
            IF @nSGRetailer = 1 AND ISNULL(@cUDF01,'')  IN ( '' , '1', '2' ) 
            BEGIN
               -- Get top 1 case from pallet
               SELECT TOP 1 @cChkUCCNo = CaseID
               FROM dbo.PalletDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   PalletKey = @cDropID 
               AND   [Status] < '9'
               ORDER BY 1
               
               IF @@ROWCOUNT = 0
                  GOTO Quit

               -- Look for orderkey of the case
               SELECT TOP 1 @cChkPickSlipNo = PickSlipNo 
               FROM dbo.PackDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND LabelNo = @cChkUCCNo 
               ORDER BY 1
               
               SELECT @cChkOrderKey = OrderKey 
               FROM dbo.PackHeader WITH (NOLOCK) 
               WHERE PickSlipNo = @cChkPickSlipNo 
               
               SELECT @cChkRoute = ISNULL(Route,'') 
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND OrderKey = @cChkOrderKey                

               IF @cRoute <> @cChkRoute
               BEGIN
                  SET @nErrNo = 110656
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Route Diff
               END
            END
         END
      END
   END
END

Quit:



GO