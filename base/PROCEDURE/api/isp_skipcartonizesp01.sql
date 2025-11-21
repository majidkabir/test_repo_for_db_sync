SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: isp_SkipCartonizeSP01                                     */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-08-28   1.0  Chermaine  Created                                       */
/******************************************************************************/

CREATE   PROC [API].[isp_SkipCartonizeSP01] (
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cPickslipNo   NVARCHAR( 20),
   @cDropID       NVARCHAR( 20),
   @cOrderKey     NVARCHAR( 10),
   @skipCartonize NVARCHAR( 1) OUTPUT,
   @b_Success     INT = 1      OUTPUT,
   @n_Err         INT = 0      OUTPUT,
   @c_ErrMsg      NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

BEGIN
	IF @cOrderKey <> ''
	BEGIN
		IF EXISTS (SELECT 1 FROM Orders WITH (NOLOCK) WHERE storerKey = @cStorerKey AND Orderkey = @cOrderKey AND TYPE = 'ECOM')
	   BEGIN
		   SET @skipCartonize = '0'
	   END
	   ELSE
	   BEGIN
		   SET @skipCartonize = '1'
	   END
	END
END


SET QUOTED_IDENTIFIER OFF

GO