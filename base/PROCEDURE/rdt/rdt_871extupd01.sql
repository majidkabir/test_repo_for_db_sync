SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_871ExtUpd01                                           */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2017-Sep-13 1.0  James    WMS2954 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_871ExtUpd01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cSerialNo    NVARCHAR(50),
   @cOption      NVARCHAR(1),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nTranCount     INT
   DECLARE @cChildSerialNo NVARCHAR( 30)
   DECLARE @cNewSerialNo   NVARCHAR( 30)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_871ExtUpd01

   IF @nStep = 3 -- Delete serial no
   BEGIN
      SET @cNewSerialNo = RIGHT( @cSerialNo, 10)

      -- Delete only if it is BOM serial no
      IF RIGHT( RTRIM( @cSerialNo), 1) IN ('B', 'C')
      BEGIN
         DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT SerialNo 
         FROM dbo.MasterSerialNo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ParentSerialNo = @cNewSerialNo
         AND   UnitType='BUNDLEPCS' 
         OPEN CUR_UPD
         FETCH NEXT FROM CUR_UPD INTO @cChildSerialNo
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DELETE FROM dbo.SerialNo 
            WHERE StorerKey = @cStorerKey
            AND   SerialNo = @cChildSerialNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 114901
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del SrNo Error

               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD
               GOTO RollBackTran
            END

            FETCH NEXT FROM CUR_UPD INTO @cChildSerialNo
         END
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD
      END
      ELSE
      BEGIN
         DELETE FROM dbo.SerialNo 
         WHERE StorerKey = @cStorerKey
         AND   SerialNo = @cNewSerialNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 114902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del SrNo Error
            GOTO RollBackTran
         END
      END
   END
         
   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_871ExtUpd01
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN


GO