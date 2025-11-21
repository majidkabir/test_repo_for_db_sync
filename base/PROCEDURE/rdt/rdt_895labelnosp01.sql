SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_895LabelNoSP01                                  */
/* Copyright: IDS                                                       */
/* Called From: rdt_895ExtUpdSP01                                       */
/* Purpose: Generate label no                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2020-09-23   1.0  James      WMS-15296. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_895LabelNoSP01](
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @cFacility                 NVARCHAR( 5),
   @cStorerkey                NVARCHAR( 15),
   @cReplenKey                NVARCHAR( 10),
   @cDropID                   NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cLabelNo                  NVARCHAR( 20) OUTPUT,
   @nCartonNo                 INT           OUTPUT,
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT  
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cType       NVARCHAR( 10)
   DECLARE @bSuccess    INT
   DECLARE @cOrderKey   NVARCHAR( 10)
   
   SELECT @cOrderKey = OrderKey
   FROM dbo.PackHeader WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
      
   SELECT @cType = [Type]
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   IF @cType = 'IC'
      EXEC dbo.isp_getucckey
		   @c_storerkey   = @cStorerkey
		  ,@c_fieldlength = 8
		  ,@c_keystring   = @cLabelNo OUTPUT
		  ,@b_Success     = @bSuccess  OUTPUT
		  ,@n_err         = @nErrNo      OUTPUT
		  ,@c_errmsg      = @cErrMsg   OUTPUT
		  ,@b_resultset   = 0
		  ,@n_batch       = 1 
        ,@n_joinstorer  = 1 
   ELSE
      EXEC dbo.isp_getucckey
		   @c_storerkey   = @cStorerkey
		  ,@c_fieldlength = 10
		  ,@c_keystring   = @cLabelNo OUTPUT
		  ,@b_Success     = @bSuccess  OUTPUT
		  ,@n_err         = @nErrNo      OUTPUT
		  ,@c_errmsg      = @cErrMsg   OUTPUT
		  ,@b_resultset   = 0
		  ,@n_batch       = 1 
        ,@n_joinstorer  = 1 



GO