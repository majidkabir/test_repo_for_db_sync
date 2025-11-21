SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1641ExtInfo03                                         */
/* Purpose: Display scanned carton id                                         */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2023-05-05 1.0  YeeKung  WMS-22419 Created                                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1641ExtInfo03] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR(3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR(15),
   @cDropID          NVARCHAR(20),
   @cUCCNo           NVARCHAR(20),
   @cParam1          NVARCHAR(20),
   @cParam2          NVARCHAR(20),
   @cParam3          NVARCHAR(20),
   @cParam4          NVARCHAR(20),
   @cParam5          NVARCHAR(20),
   @cExtendedInfo1   NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 1641
BEGIN
   DECLARE @cLoadkey NVARCHAR(20)



   IF @nStep IN (1, 3) -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cLoadkey = Loadkey
         FROM PACKHEADER PH (NOLOCK) 
            JOIN  PackDetail PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         WHERE LabelNo = @cUCCNo
            AND PD.Storerkey = @cStorerKey

         SELECT @cExtendedInfo1 = DeliveryNote
         FROM Orders (nolock)
         WHERE Loadkey = @cLoadkey
            AND Storerkey = @cStorerKey
      END

   END
END

Quit:



GO