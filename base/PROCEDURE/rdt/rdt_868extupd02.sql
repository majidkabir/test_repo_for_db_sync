SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_868ExtUpd02                                     */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-11-25 1.0  Ung        SOS326107 Temp fix last PS not pack cfm   */
/************************************************************************/

CREATE PROC [RDT].[rdt_868ExtUpd02] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerKey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cOrderKey   NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cADCode     NVARCHAR( 18),
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT

   IF @nFunc = 868 -- Pick and pack
   BEGIN
      IF @nStep = 6 -- Pick completed
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cLoadKey = ''
               GOTO Quit

            DECLARE @cPickSlipNo NVARCHAR(10)
            DECLARE @cPHOrderKey NVARCHAR(10)
            DECLARE @cSum_PickedQty INT
            DECLARE @cSum_PackedQty INT

            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT PickHeaderKey, OrderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE ExternOrderKey = @cLoadKey
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @cPickSlipNo, @cPHOrderKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF NOT EXISTS (SELECT 1 
                  FROM dbo.PickDetail WITH (NOLOCK)  
                  WHERE Orderkey = @cPHOrderKey  
                     AND Status < '5')  
               BEGIN
                  SELECT @cSum_PickedQty = ISNULL( SUM( QTY), 0)
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE OrderKey = @cPHOrderKey
   
                  SELECT @cSum_PackedQty = ISNULL( SUM( QTY), 0)
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
   
                  IF @cSum_PickedQty = @cSum_PackedQty
                  BEGIN
                     IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status <> '9')
                     BEGIN
                        UPDATE dbo.PackHeader WITH (ROWLOCK) SET
                           Status = '9'
                        WHERE PickSlipNo = @cPickSlipNo
                     END
                  END
               END
               FETCH NEXT FROM CUR_LOOP INTO @cPickSlipNo, @cPHOrderKey
            END
         END
      END
   END
Quit:
Fail:

GO