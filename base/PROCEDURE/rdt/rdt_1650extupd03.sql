SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1650ExtUpd03                                    */
/* Purpose: Handle pallet with CBOM key or MBOL key                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-07-18 1.0  NLT013     FCR-574 Create                            */
/************************************************************************/

CREATE PROC [RDT].[rdt_1650ExtUpd03] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @cLangCode        NVARCHAR( 3),  
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cPalletID        NVARCHAR( 20), 
   @cMbolKey         NVARCHAR( 10), 
   @cDoor            NVARCHAR( 20), 
   @cOption          NVARCHAR( 1),  
   @nAfterStep       INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
      @nRowCount              INT,
      @nLoopIndex             INT,
      @nTranCount             INT,
      @cLoopPalletID          NVARCHAR( 20),
      @cLoopMBOLKey           NVARCHAR( 10),
      @cFacility              NVARCHAR( 5),
      @nCBOLKey               INT

   DECLARE @tPalletID TABLE
   (
      id INT IDENTITY(1,1),
      MBOLKey           NVARCHAR(10),
      PalletID          NVARCHAR(20)
   )

   DECLARE @tMBOLKeys TABLE
   (
      id INT IDENTITY(1,1),
      MBOLKey          NVARCHAR(10)
   )

   SELECT @cFacility = Facility,
      @nCBOLKey      = C_Integer5,
      @cMBOLKey      = C_String30
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   
   IF @nFunc = 1650
   BEGIN
      IF @nStep = 2 
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = object_id(N'rdt.rdt_1650ExtUpd01') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
            BEGIN
               SET @nErrNo = 219501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExtUpd01Miss
               GOTO Quit
            END

            IF @nCBOLKey IS NOT NULL AND @nCBOLKey > 0
            BEGIN
               INSERT INTO @tPalletID (MBOLKey, PalletID)
               SELECT DISTINCT M.MBOLKey, PD.ID
               FROM dbo.MBOL M WITH (NOLOCK)
               INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
               INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
               WHERE M.Status <> '9'
                  AND M.Facility = @cFacility
                  AND M.CBOLKey = @nCBOLKey
                  AND PD.Notes = 'SCANNED'
            END
            ELSE 
            BEGIN
               IF @cMBOLKey IS NOT NULL AND @cMBOLKey <> ''
               BEGIN
                  INSERT INTO @tPalletID (MBOLKey, PalletID)
                  SELECT DISTINCT M.MBOLKey, PD.ID
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.MBOLKey = @cMBOLKey
                     AND PD.Notes = 'SCANNED'
               END
            END
            
            SELECT @nRowCount = COUNT(1) FROM @tPalletID

            IF @nRowCount = 0
               GOTO Quit

            IF @nTranCount = 0
               BEGIN TRAN
            ELSE
               SAVE TRAN rdt_1650ExtUpd03

            BEGIN TRY
               SET @nLoopIndex = -1
               WHILE 1 = 1
               BEGIN
                  SELECT TOP 1 
                     @cLoopPalletID = PalletID,
                     @cMBOLKey = MBOLKey,
                     @nLoopIndex = id
                  FROM @tPalletID
                  WHERE id > @nLoopIndex
                  ORDER BY id

                  SELECT @nRowCount = @@ROWCOUNT

                  IF @nRowCount = 0
                     BREAK

                  EXEC [RDT].[rdt_1650ExtUpd01] 
                     @nMobile          = @nMobile, 
                     @nFunc            = @nFunc, 
                     @nStep            = @nStep, 
                     @cLangCode        = @cLangCode,  
                     @nInputKey        = @nInputKey, 
                     @cStorerKey       = @cStorerKey, 
                     @cPalletID        = @cLoopPalletID, 
                     @cMbolKey         = @cMbolKey, 
                     @cDoor            = @cDoor, 
                     @cOption          = @cOption,  
                     @nAfterStep       = @nAfterStep, 
                     @nErrNo           = @nErrNo OUTPUT, 
                     @cErrMsg          = @cErrMsg OUTPUT 
                     
                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 219502
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropPalletFail

                     IF @nTranCount = 0 AND @@TRANCOUNT > 0
                        ROLLBACK TRANSACTION
                     ELSE IF @nTranCount > 0 AND @@TRANCOUNT > 0
                        ROLLBACK TRANSACTION rdt_1650ExtUpd03
                     GOTO Quit
                  END

                  UPDATE RDT.RDTMOBREC WITH (ROWLOCK) 
                  SET C_Integer5 = 0,
                     C_String30 = ''
                  WHERE Mobile = @nMobile
               END
            END TRY
            BEGIN CATCH
               IF @nTranCount = 0 AND @@TRANCOUNT > 0
                  ROLLBACK TRANSACTION
               ELSE IF @nTranCount > 0 AND @@TRANCOUNT > 0
                  ROLLBACK TRANSACTION rdt_1650ExtUpd03
               GOTO Quit
            END CATCH

            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
               COMMIT TRANSACTION rdt_1650ExtUpd03
         END
      END
      ELSE IF @nStep = 3
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cOption = '1'
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE id = object_id(N'rdt.rdt_1650ExtUpd01') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
               BEGIN
                  SET @nErrNo = 219503
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExtUpd01Miss
                  GOTO Quit
               END

               IF @nCBOLKey IS NOT NULL AND @nCBOLKey > 0
               BEGIN
                  INSERT INTO @tMBOLKeys (MBOLKey)
                  SELECT DISTINCT M.MBOLKey
                  FROM dbo.MBOL M WITH (NOLOCK)
                  INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                  INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
                  WHERE M.Status <> '9'
                     AND M.Facility = @cFacility
                     AND M.CBOLKey = @nCBOLKey
                     AND PD.Notes = 'SCANNED'
               END
               ELSE 
               BEGIN
                  IF @cMBOLKey IS NOT NULL AND @cMBOLKey <> ''
                  BEGIN
                     INSERT INTO @tMBOLKeys (MBOLKey)
                     SELECT DISTINCT M.MBOLKey
                     FROM dbo.MBOL M WITH (NOLOCK)
                     INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                     INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                     WHERE M.Status <> '9'
                        AND M.Facility = @cFacility
                        AND M.MBOLKey = @cMBOLKey
                        AND PD.Notes = 'SCANNED'
                  END
               END

               SELECT @nRowCount = COUNT(1) FROM @tMBOLKeys

               IF @nRowCount = 0
                  GOTO Quit

               IF @nTranCount = 0
                  BEGIN TRAN
               ELSE
                  SAVE TRAN rdt_1650ExtUpd03_01

               BEGIN TRY
                  SET @nLoopIndex = -1
                  WHILE 1 = 1
                  BEGIN
                     SELECT TOP 1 
                        @cLoopMBOLKey = MBOLKey,
                        @nLoopIndex = id
                     FROM @tMBOLKeys
                     WHERE id > @nLoopIndex
                     ORDER BY id

                     SELECT @nRowCount = @@ROWCOUNT

                     IF @nRowCount = 0
                        BREAK

                     EXEC [RDT].[rdt_1650ExtUpd01] 
                        @nMobile          = @nMobile, 
                        @nFunc            = @nFunc, 
                        @nStep            = @nStep, 
                        @cLangCode        = @cLangCode,  
                        @nInputKey        = @nInputKey, 
                        @cStorerKey       = @cStorerKey, 
                        @cPalletID        = '', 
                        @cMbolKey         = @cLoopMBOLKey, 
                        @cDoor            = @cDoor, 
                        @cOption          = @cOption,  
                        @nAfterStep       = @nAfterStep, 
                        @nErrNo           = @nErrNo OUTPUT, 
                        @cErrMsg          = @cErrMsg OUTPUT 
                        
                     IF @nErrNo <> 0
                     BEGIN
                        SET @nErrNo = 219504
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --loseTruckFail

                        IF @nTranCount = 0 AND @@TRANCOUNT > 0
                           ROLLBACK TRANSACTION
                        ELSE IF @nTranCount > 0 AND @@TRANCOUNT > 0
                           ROLLBACK TRANSACTION rdt_1650ExtUpd03_01
                        GOTO Quit
                     END
                  END
               END TRY
               BEGIN CATCH
                  IF @nTranCount = 0 AND @@TRANCOUNT > 0
                     ROLLBACK TRANSACTION
                  ELSE IF @nTranCount > 0 AND @@TRANCOUNT > 0
                     ROLLBACK TRANSACTION rdt_1650ExtUpd03_01
                  GOTO Quit
               END CATCH

               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                  COMMIT TRANSACTION rdt_1650ExtUpd03_01
            END
            ELSE IF @cOption = '2'
            BEGIN
               DECLARE @cRollbackScannedStatus NVARCHAR(30)
               SET @cRollbackScannedStatus = rdt.rdtGetConfig(@nFunc, 'RollbackScannedStatus', @cStorerKey)

               IF @cRollbackScannedStatus = '1'
               BEGIN
                  IF @nCBOLKey IS NOT NULL AND @nCBOLKey > 0
                  BEGIN
                     UPDATE PD
                        SET PD.Notes = ''
                     FROM dbo.PickDetail PD 
                     INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                     INNER JOIN dbo.MBOL M WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                     INNER JOIN dbo.CBOL C WITH (NOLOCK) ON M.Facility = C.Facility AND M.CBOLKey = C.CBOLKey
                     WHERE M.Status <> '9'
                        AND M.Facility = @cFacility
                        AND M.MBOLKey = @cMBOLKey
                        AND PD.Notes = 'SCANNED'
                  END
                  ELSE 
                  BEGIN
                     IF @cMBOLKey IS NOT NULL AND @cMBOLKey <> ''
                     BEGIN
                        UPDATE PD
                           SET PD.Notes = ''
                        FROM dbo.PickDetail PD 
                        INNER JOIN dbo.MBOLDETAIL MD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                        INNER JOIN dbo.MBOL M WITH (NOLOCK) ON M.MBOLKey = MD.MBOLKey
                        WHERE M.Status <> '9'
                           AND M.Facility = @cFacility
                           AND M.MBOLKey = @cMBOLKey
                           AND PD.Notes = 'SCANNED'
                     END
                  END
               END
            END

            UPDATE RDT.RDTMOBREC WITH (ROWLOCK) 
            SET C_Integer5 = 0,
               C_String30 = ''
            WHERE Mobile = @nMobile
         END
      END
   END


Quit:
   
END

GO