SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1628ExtUpd03                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update UCC after finish picking                             */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 2020-08-24   1.0  James       WMS-14577. Created                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtUpd03] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cLoc                      NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOption     NVARCHAR( 1)
   DECLARE @cKey2       NVARCHAR( 30) = ''
   DECLARE @cTransmitlogkey   NVARCHAR( 10)
   DECLARE @cTransmitflag     NVARCHAR( 5)
   DECLARE @bSuccess    INT
   
   SELECT @cOption = I_Field01
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @nStep = 15
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @cOption = '1'
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.WAVE WITH (NOLOCK) 
                            WHERE WaveKey = @cWaveKey 
                            AND Userdefine01 = 'PTL')
               GOTO Quit

            IF EXISTS ( SELECT 1
               FROM dbo.TRANSMITLOG3 WITH (NOLOCK)
               WHERE tablename = 'DPIDRDTLOG'
               AND   key1 = @cDropID
               AND   key2 = @cWaveKey
               AND   key3 = @cStorerkey)
               GOTO Quit

            -- Insert transmitlog3 here
            EXECUTE ispGenTransmitLog3 
               @c_TableName      = 'DPIDRDTLOG', 
               @c_Key1           = @cDropID, 
               @c_Key2           = @cWaveKey, 
               @c_Key3           = @cStorerkey, 
               @c_TransmitBatch  = '', 
               @b_Success        = @bSuccess   OUTPUT,    
               @n_err            = @nErrNo     OUTPUT,    
               @c_errmsg         = @cErrMsg    OUTPUT    

            IF @bSuccess <> 1    
            BEGIN
               SET @nErrNo = 157401
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsertTL3 Fail
               GOTO Quit
            END
         END
      END
   END

   Quit:
END

GO