SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_841ExtInfoSP03                                  */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-11-22 1.0  YeeKung    WMS-20327 Created                         */
/************************************************************************/

CREATE     PROC [RDT].[rdt_841ExtInfoSP03] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR(3),
   @nStep       INT,
   @cStorerKey  NVARCHAR(15),
   @cDropID     NVARCHAR(20),
   @cSKU        NVARCHAR(20),
   @cPickSlipNo NVARCHAR(10),
   @cLoadKey    NVARCHAR(20),
   @cWavekey    NVARCHAR(20),
   @nInputKey   INT,
   @cSerialNo   NVARCHAR( 30),
   @nSerialQTY   INT,
   @cExtendedinfo  NVARCHAR( 20) OUTPUT,
   @nErrNo      INT       OUTPUT,
   @cErrMsg     CHAR( 20) OUTPUT
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTotalBatchQty      INT = 0
   DECLARE @nTotalScannedQty       INT = 0

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN

         SELECT @cPickSlipNo=V_String33
         FROM RDT.RDTMOBREC (NOLOCK)
         WHERE mobile=@nMobile

         select @nTotalBatchQty = sum(pd.qty)
         from pickdetail pd (nolock)
         where pd.storerkey =@cStorerKey
            and pd.pickslipno = @cPickSlipNo

         select @nTotalScannedQty = sum(pd.qty)
         from pickdetail pd (nolock)
         where pd.storerkey =@cStorerKey
            and pd.pickslipno = @cPickSlipNo
            AND ISNULL(caseid,'')<>''

         SET @nTotalScannedQty= CASE WHEN ISNULL(@nTotalScannedQty,'')=0 THEN 0 ELSE @nTotalScannedQty END

         SET @cExtendedinfo = 'TTLBatchQty:'+CAST(@nTotalScannedQty AS NVARCHAR(4)) + '/' +CAST(@nTotalBatchQty AS NVARCHAR(4))
      END
   END


QUIT:
END


GO