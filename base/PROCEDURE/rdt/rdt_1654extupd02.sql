SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1654ExtUpd02                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Called from: rdtfnc_TrackNo_SortToPallet_CloseLane                   */
/*                                                                      */
/* Purpose: Insert into Transmitlog2 table, trigger middleware itf      */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2023-04-26  1.0  James    WMS-22346. Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1654ExtUpd02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cLane          NVARCHAR( 20),
   @cOption        NVARCHAR( 1),
   @tExtUpdateVar  VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT
   DECLARE @cMBOLKey    NVARCHAR( 10)
   DECLARE @cOrderKey   NVARCHAR( 10)
   
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1654ExtUpd02

   --IF @nStep = 2      --SY01
   IF @nStep IN (2, 5)  --SY01
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption = '1'
         BEGIN
            SELECT @cMBOLKey = MBOLKey
            FROM dbo.MBOL WITH (NOLOCK)
            WHERE ExternMbolKey= @cLane

            -- Insert transmitlog2 here
            EXECUTE ispGenTransmitLog2
               @c_TableName      = 'WSCRSOCLOSEILS',
               @c_Key1           = @cMBOLKey,
               @c_Key2           = '',
               @c_Key3           = @cStorerkey,
               @c_TransmitBatch  = '',
               @b_Success        = @bSuccess   OUTPUT,
               @n_err            = @nErrNo     OUTPUT,
               @c_errmsg         = @cErrMsg    OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 200151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Insert TL2 Err
               GOTO RollBackTran
            END

            SELECT TOP 1 @cOrderKey = OrderKey
            FROM dbo.MBOLDETAIL WITH (NOLOCK)
            WHERE MbolKey = @cMBOLKey
            ORDER BY 1
            
            EXEC [dbo].[isp_Carrier_Middleware_Interface]        
              @c_OrderKey    = @cOrderKey     
            , @c_Mbolkey     = ''  
            , @c_FunctionID  = @nFunc      
            , @n_CartonNo    = 0  
            , @n_Step        = @nStep  
            , @b_Success     = @bSuccess  OUTPUT        
            , @n_Err         = @nErrNo    OUTPUT        
            , @c_ErrMsg      = @cErrMsg   OUTPUT        
   
            IF @bSuccess = 0
            BEGIN
               SET @nErrNo = 200152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Exec ITF Fail
               GOTO RollBackTran
            END
         END
      END
   END

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_1654ExtUpd02
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

END

GO