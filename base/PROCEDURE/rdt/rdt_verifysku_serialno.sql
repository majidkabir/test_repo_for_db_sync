SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_VerifySKU_SerialNo                              */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Verify pallet Ti Hi setting                                 */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 21-09-2015  1.0  Ung          SOS347397. Created                     */
/* 18-09-2017  1.1  Ung          WMS-2953 Add serial no                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_VerifySKU_SerialNo]
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cFacility   NVARCHAR( 3),
   @cStorerKey  NVARCHAR( 15),
   @cSKU        NVARCHAR( 20),
   @cType       NVARCHAR( 15),
   @cLabel      NVARCHAR( 30)  OUTPUT,
   @cShort      NVARCHAR( 10)  OUTPUT,
   @cValue      NVARCHAR( MAX) OUTPUT,
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   DECLARE @cSUSR4     NVARCHAR(18)

   SET @nTranCount = @@TRANCOUNT

   /***********************************************************************************************
                                                 CHECK
   ***********************************************************************************************/
   IF @cType = 'CHECK'
   BEGIN
      -- Get SKU info
      SELECT @cSUSR4 = ISNULL( SKU.SUSR4, '')
      FROM SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

      -- Check not setup
      IF @cSUSR4 = 'AD'
         SET @nErrNo = -1 --Need setup
   END

   /***********************************************************************************************
                                                 UPDATE
   ***********************************************************************************************/
   -- Check SKU setting
   IF @cType = 'UPDATE'
   BEGIN
      -- Exit
      IF @cValue = ''
         GOTO Quit

      /*
         1 case = multi bundle
         1 bundle = multi piece

         Case SN	   Bundle SN	Piece SN
         310000101C	310000201B	3100003001
         		                  3100003002
         	         310000202B	3100003003
         		                  3100003004
         	         310000203B	3100003005
         		                  3100003006

         MasterSeralNo:
         UnitType	   SerialNo	   ParentSerialNo
         BUNDLECASE	310000201B	310000101C
         BUNDLEPCS	3100003001	310000201B
         BUNDLEPCS	3100003002	310000201B
         BUNDLECASE	310000202B	310000101C
         BUNDLEPCS	3100003003	310000202B
         BUNDLEPCS	3100003004	310000202B
         BUNDLECASE	310000203B	310000101C
         BUNDLEPCS	3100003005	310000203B
         BUNDLEPCS	3100003006	310000203B

         SerialNo
         3100003001
         3100003002
         3100003003
         3100003004
         3100003005
         3100003006
      */

      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_VerifySKU_SerialNo -- For rollback or commit only our own transaction

      -- Case or bundle
      IF RIGHT( @cValue, 1) IN ('C', 'B')
      BEGIN
         DECLARE @nMasterKey BIGINT
         DECLARE @nPieceKey  BIGINT
         DECLARE @cChildSNO  NVARCHAR( 50)
         DECLARE @cPieceSNO  NVARCHAR( 50)
         
         -- Loop bundle or piece
         DECLARE @curParent CURSOR
         SET @curParent = CURSOR FOR
            SELECT MasterSerialNoKey, SerialNo
            FROM MasterSerialNo WITH (NOLOCK)
            WHERE ParentSerialNo = @cValue
         OPEN @curParent
         FETCH NEXT FROM @curParent INTO @nMasterKey, @cChildSNO
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Child is bundle
            IF RIGHT( @cChildSNO, 1) = 'B'
            BEGIN
               DECLARE @nFound INT
               SET @nFound = 0

               -- Loop piece
               DECLARE @curPiece CURSOR
               SET @curPiece = CURSOR FOR
                  SELECT MasterSerialNoKey, SerialNo
                  FROM MasterSerialNo WITH (NOLOCK)
                  WHERE ParentSerialNo = @cChildSNO -- Bundle
               OPEN @curPiece
               FETCH NEXT FROM @curPiece INTO @nPieceKey, @cPieceSNO
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Delete SerialNo and MasterSerialNo
                  EXEC rdt.rdt_VerifySKU_SerialNo_Delete @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                     ,@cPieceSNO  -- Piece
                     ,@nPieceKey  -- MasterSerialNoKey
                     ,@nErrNo     OUTPUT
                     ,@cErrMsg    OUTPUT
                  IF @nErrNo <> 0
                     GOTO RollBackTran
                  
                  IF @nFound = 0
                     SET @nFound = 1
                     
                  FETCH NEXT FROM @curPiece INTO @nPieceKey, @cPieceSNO
               END
               
               -- Check case or bundle exist
               IF @nFound = 0
               BEGIN
                  SET @nErrNo = 117801
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not on MstSN
                  GOTO RollbackTran
               END
            END

            -- Child is piece
            ELSE
            BEGIN
               -- Delete SerialNo and MasterSerialNo
               EXEC rdt.rdt_VerifySKU_SerialNo_Delete @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
                  ,@cChildSNO  -- Piece
                  ,@nMasterKey   
                  ,@nErrNo     OUTPUT
                  ,@cErrMsg    OUTPUT
               IF @nErrNo <> 0
                  GOTO RollBackTran
            END
         
            FETCH NEXT FROM @curParent INTO @nMasterKey, @cChildSNO
         END

         -- Some times the "case or bundle" is actually piece
         EXEC rdt.rdt_VerifySKU_SerialNo_Delete @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cValue     -- Piece
            ,0           -- @nMasterKey 
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Piece
      ELSE
      BEGIN
         -- Get piece SNO
         SELECT @nMasterKey = MasterSerialNoKey FROM MasterSerialNo WITH (NOLOCK) WHERE SerialNo = @cValue AND StorerKey = @cStorerKey

         -- Delete SerialNo and MasterSerialNo
         EXEC rdt.rdt_VerifySKU_SerialNo_Delete @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cValue     -- Piece
            ,@nMasterKey 
            ,@nErrNo     OUTPUT
            ,@cErrMsg    OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      COMMIT TRAN rdt_VerifySKU_SerialNo

      SET @cValue = ''
      SET @nErrNo = -1
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_VerifySKU_SerialNo -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO