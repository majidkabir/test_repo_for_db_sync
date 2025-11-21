SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: HM India decode IT69 label return SKU                             */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2021-02-15  yeekung   1.0   WMS-16220 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_803DecodeSP02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cStation     NVARCHAR( 10),
   @cMethod      NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cUPC         NVARCHAR( 30)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUCnt int
           ,@bSuccess int
           ,@cDevicePos nvarchar(20)


   IF @nStep = 3 -- SKU
   BEGIN

      SET @nSKUCnt = 0
      EXEC RDT.rdt_GetSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cBarcode
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @bSuccess  OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT

      -- Check SKU valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 163851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU

         select top 1 @cDevicePos=logicalpos
         from deviceprofile (nolock) 
         where deviceid=@cStation
         and storerkey=@cStorerKey
         order by logicalpos desc


         exec [PTL].[isp_PTL_Light_TMS]
            @n_Func          = @nFunc
           ,@n_PTLKey        = 0
           ,@b_Success       = 0
           ,@n_Err           = @nErrNo    
           ,@c_ErrMsg        = @cErrMsg OUTPUT
           ,@c_DeviceID      = @cStation
           ,@c_DevicePos     = @cDevicePos
           ,@c_DeviceIP      = ''
           ,@c_DeviceStatus  = '1'

         IF @nErrNo<>0
            GOTO QUIt

      END
   END

Quit:

END

GO