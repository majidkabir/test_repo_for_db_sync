SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtDropID01                                 */
/* Purpose: Cluster Pick Extended DropID SP.                            */
/*          Generate DropID from PackDetail.LabelNo.                    */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 17-Nov-2015 1.0  James      SOS356971 - Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtDropID01] (
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,           
   @nInputKey       INT,           
   @cFacility       NVARCHAR( 5),  
   @cStorerkey      NVARCHAR( 15), 
   @cWaveKey        NVARCHAR( 10), 
   @cLoadKey        NVARCHAR( 10), 
   @cOrderKey       NVARCHAR( 10), 
   @cLOC            NVARCHAR( 10),  
   @cSKU            NVARCHAR( 20), 
   @cCartonType     NVARCHAR( 10), 
   @cDropID         NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT           OUTPUT,  
   @cErrMsg         NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @bsuccess    INT,
           @nCartonNo   INT, 
           @cLabelNo    NVARCHAR( 20), 
           @cUserName   NVARCHAR( 20)

   IF SUBSTRING( @cDropID, 1, 2) = 'ID'
      GOTO Quit

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SET @nErrNo = 0  
   EXECUTE rdt.rdt_Cluster_Pick_DropID  
      @nMobile, 
      @nFunc,    
      @cStorerKey,  
      @cUserName,  
      @cFacility,  
      @cLoadKey,
      '',   --@cPickSlipNo,  
      @cOrderKey, 
      @cDropID       OUTPUT,  
      @cSKU,  
      'R',      -- R = Retrieve
      @cLangCode,  
      @nErrNo        OUTPUT,  
      @cErrMsg       OUTPUT  -- screen limitation, 20 NVARCHAR max  

   -- If existing drop id exists, either user key in or 
   -- system retrieve then quit
   IF ISNULL( @cDropID, '') <> ''
      GOTO Quit
   
   SET @nCartonNo = 0

   SET @cLabelNo = ''
   SET @nErrNo = 0
   SET @cErrMsg = ''

   EXECUTE dbo.nsp_GenLabelNo
      '',
      @cStorerKey,
      @c_labelno     = @cDropID   OUTPUT,
      @n_cartonno    = @nCartonNo OUTPUT,
      @c_button      = '',
      @b_success     = @bsuccess  OUTPUT,
      @n_err         = @nErrNo    OUTPUT,
      @c_errmsg      = @cErrMsg   OUTPUT

QUIT:

GO