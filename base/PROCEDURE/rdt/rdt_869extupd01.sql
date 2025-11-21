SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: [rdt_869ExtUpd01]                                   */
/* Copyright: Maersk                                                    */
/* Customer:  Levis                                                     */
/*                                                                      */
/* Date         VER    Author   Purpose                                 */
/* 2024-11-21   1.0.0  Dennis   FCR-1349 Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_869ExtUpd01] (
@nMobile    INT,
@nFunc      INT,
@cLangCode  NVARCHAR( 3),
@nStep      INT,
@nInputKey  INT,
@cFacility  NVARCHAR( 5),
@cStorerKey NVARCHAR( 15),
@cOption    NVARCHAR(  1),
@cLoadKey   NVARCHAR( 10),
@cOrderKey  NVARCHAR( 10),
@cWaveKey   NVARCHAR( 10),
@nErrNo     INT           OUTPUT,
@cErrMsg    NVARCHAR( 20) OUTPUT
) AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
DECLARE 
   @nLoopIndex INT = -1,
   @cCaseID    NVARCHAR(20),
   @nQTY       INT,
   @nRowCount  INT,
   @nTranCount INT,
   @bSuccess   INT,
   @cSKU       NVARCHAR(20)
DECLARE @List TABLE
   (
   ID INT IDENTITY(1,1) NOT NULL,
   CASEID NVARCHAR(20),
   OrderKey NVARCHAR(20),
   SKU      NVARCHAR(20)
   )

IF @nFunc = 869
BEGIN
   IF @nStep = 3 
   BEGIN
      IF @nInputKey = 1 AND @cOption = '1'
      BEGIN
         DECLARE @curPD CURSOR
         IF @cOrderKey <> ''
         BEGIN
            INSERT INTO @List
               SELECT DISTINCT CaseID,@cOrderKey,SKU
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
         END

         IF @cLoadKey <> ''
         BEGIN
            INSERT INTO @List
               SELECT DISTINCT CaseID, OD.OrderKey,PD.SKU
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
               WHERE OD.LoadKey = @cLoadKey
         END

         IF @cWaveKey <> ''
         BEGIN
            INSERT INTO @List
               SELECT DISTINCT CaseID,OD.OrderKey,PD.SKU
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
                  INNER JOIN dbo.WaveDetail WD  WITH (NOLOCK) ON (OD.OrderKey = WD.OrderKey)
               WHERE WD.WaveKey = @cWaveKey
         END

         SET @nTranCount = @@TRANCOUNT  
         IF @nTranCount = 0
            BEGIN TRANSACTION
         ELSE
            SAVE TRANSACTION rdt_869ExtUpd01

         -- CASE ID
         SET @nLoopIndex = -1
         WHILE 1 = 1
         BEGIN
            SELECT TOP 1 
               @cCaseID = CaseID,
               @cOrderKey = OrderKey,
               @cSKU = SKU,
               @nLoopIndex = id
            FROM @List
            WHERE id > @nLoopIndex
            ORDER BY id

            SELECT @nRowCount = @@ROWCOUNT
            IF @nRowCount = 0
               BREAK

            IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH(NOLOCK) WHERE LABELNO = @cCaseID AND StorerKey = @cStorerKey)
            BEGIN
               SELECT @nQTY = SUM(QTY) FROM dbo.PickDetail WITH(NOLOCK) WHERE CaseID = @cCaseID AND StorerKey = @cStorerKey AND SKU = @cSKU
               UPDATE dbo.PackDetail WITH(ROWLOCK) SET QTY = @nQTY WHERE LABELNO = @cCaseID AND StorerKey = @cStorerKey AND SKU = @cSKU
            END

            EXEC ispGenTransmitLog2
               @c_TableName        = 'WSSOAlloUpd'
               ,@c_Key1             = @cOrderKey
               ,@c_Key2             = ''
               ,@c_Key3             = @cStorerkey
               ,@c_TransmitBatch    = ''
               ,@b_Success          = @bSuccess   OUTPUT
               ,@n_err              = @nErrNo     OUTPUT
               ,@c_errmsg           = @cErrMsg    OUTPUT

            IF @bSuccess <> 1      
               GOTO RollBackTran
         END

         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRANSACTION
         GOTO QUIT
      END
   END
END
GOTO QUIT

RollBackTran:
   ROLLBACK TRANSACTION
QUIT:


GO