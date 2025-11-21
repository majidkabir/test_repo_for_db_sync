SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtDelPack05                                 */
/* Purpose: Unassign tacking no and insert back to cartontrack_pool     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-03-05 1.0  James      WMS8142. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtDelPack05] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @nCartonNo   INT,
   @cOption     NVARCHAR( 1), 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT, 
           @cPickDetailKey NVARCHAR( 10), 
           @cLabelNo       NVARCHAR( 20), 
           @bSuccess       INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_840ExtDelPack05

   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   OrderKey = @cOrderKey)
   BEGIN
      SET @nErrNo = 1
      GOTO Quit
   END

   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT DISTINCT CartonNo, LabelNo
   FROM dbo.packdetail_DELLOG WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo
   AND   CartonNo > 1
   ORDER BY 1
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @nCartonNo, @cLabelNo
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF 
      --EXISTS ( 
      --         SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
      --         WHERE PickSlipNo = @cPickSlipNo
      --         AND   CartonNo = @nCartonNo) AND 
      NOT EXISTS ( 
               SELECT 1  FROM dbo.ORDERS WITH (NOLOCK)   
               WHERE Orderkey = @cOrderkey  
               AND   (TrackingNo = @cLabelNo OR UserDefine04 = @cLabelNo))
      BEGIN
         SET @nErrNo = 0
         EXEC ispClearAsgnTNo  
               @c_TrackingNo  = @cLabelNo  
            ,  @c_OrderKey    = @cOrderkey    
            ,  @b_ChildFlag   = 1   
            ,  @b_Success     = @bSuccess    OUTPUT        
            ,  @n_Err         = @nErrNo      OUTPUT          
            ,  @c_ErrMsg      = @cErrMsg     OUTPUT     

         IF @nErrNo > 0 OR @bSuccess = 0
         BEGIN
            CLOSE CUR_UPD
            DEALLOCATE CUR_UPD
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM CUR_UPD INTO @nCartonNo, @cLabelNo
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD
 
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtDelPack05  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN rdt_840ExtDelPack05

GO