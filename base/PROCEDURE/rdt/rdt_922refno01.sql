SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_922RefNo01                                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-02-28 1.0  Ung        WMS-24945 Created                         */
/************************************************************************/

CREATE   PROC rdt.rdt_922RefNo01 (
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @nStep        INT,             
   @nInputKey    INT,             
   @cFacility    NVARCHAR( 5),    
   @cStorerKey   NVARCHAR( 15),   
   @cRefNum      NVARCHAR( 30),   
   @cMbolKey     NVARCHAR( 10) OUTPUT,   
   @cLoadKey     NVARCHAR( 10) OUTPUT,   
   @cOrderKey    NVARCHAR( 10) OUTPUT,   
   @cType        NVARCHAR( 1)  OUTPUT,   
   @nErrNo       INT           OUTPUT,   
   @cErrMsg      NVARCHAR( 20) OUTPUT  
)
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nFunc = 922 -- Scan to truck
BEGIN
   -- Find open MBOL with the Ref
   SELECT @cMBOLKey = MBOLKey
   FROM dbo.MBOL WITH (NOLOCK)
   WHERE Facility = @cFacility
      AND ExternMBOLKey = @cRefNum
      AND Status = '0'

   IF @@ROWCOUNT = 0
   BEGIN
      DECLARE @nSuccess INT = 1
      EXECUTE dbo.nspg_getkey
         'MBOL'
         , 10
         , @cMBOLKey    OUTPUT
         , @nSuccess    OUTPUT
         , @nErrNo      OUTPUT
         , @cErrMsg     OUTPUT
      IF @nSuccess <> 1
      BEGIN
         SET @nErrNo = 212051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_getkey
      END
      
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_922RefNo01 -- For rollback or commit only our own transaction
      
      -- MBOL
      INSERT INTO dbo.MBOL (MBOLKey, ExternMBOLKey, Facility, Status) 
      VALUES (@cMBOLKey, @cRefNum, @cFacility, '0')
      IF @@ERROR <> 0
      BEGIN
         ROLLBACK TRAN rdt_922RefNo01 -- Only rollback change made here
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN 
            
         SET @nErrNo = 212052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail
         GOTO Quit
      END
    
      COMMIT TRAN rdt_922RefNo01
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN 
   END
END

Quit:


GO