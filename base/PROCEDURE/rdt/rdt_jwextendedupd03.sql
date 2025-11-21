SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_JWExtendedUpd03                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update POD.Status for Click & Collect orders                */
/*                                                                      */
/* Called from:  rdtfnc_CC_Sort_Tote                                    */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 03-09-2014  1.0  James       SOS320178 - Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_JWExtendedUpd03] (
   @nMobile                   INT,          
   @nFunc                     INT,          
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cLabelNo                  NVARCHAR( 20), 
   @cToteNo                   NVARCHAR( 18), 
   @cOption                   NVARCHAR( 1),  
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT    

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey      NVARCHAR( 10)

   SELECT TOP 1 @cOrderKey = PH.OrderKey 
   FROM dbo.PackDetail PD WITH (NOLOCK) 
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON PD.PickslipNo = PH.PickSlipNo
   JOIN dbo.Orders O WITH (NOLOCK) ON PH.OrderKey = O.OrderKey
   WHERE PH.StorerKey = @cStorerKey
   AND   PD.LabelNo = @cLabelNo

   IF EXISTS ( SELECT 1 FROM dbo.POD WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey
               AND   FinalizeFlag <> 'Y')
   BEGIN
      UPDATE dbo.POD WITH (ROWLOCK) SET 
         [Status] = '8'
      WHERE OrderKey = @cOrderKey
      AND   Status <> '8'
      AND   FinalizeFlag <> 'Y'
   
      IF @@ERROR <> 0
         SET @cErrMsg = 'UPD POD FAIL'
   END
Quit:
END

GO