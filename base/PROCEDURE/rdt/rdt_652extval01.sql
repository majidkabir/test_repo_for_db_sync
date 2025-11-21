SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_652ExtVal01                                        */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date        Rev  Author       Purposes                                  */
/* 2024-05-27  1.0  Cuize        FCR-242 Created                           */
/***************************************************************************/

CREATE   PROCEDURE rdt.rdt_652ExtVal01(
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cContainerNo        NVARCHAR( 20),
   @cAppointmentNo      NVARCHAR( 20),
   @cMenuOption         NVARCHAR( 10),
   @cActionType         NVARCHAR( 10),
   @cRefNo1             NVARCHAR( 10),
   @cDefaultOption      NVARCHAR( 10),
   @cDefaultCursor      NVARCHAR( 10),
   @cActivityStatus     NVARCHAR( 20),
   @nErrNo              INT           OUTPUT,
   @cErrMsg             NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 652
   BEGIN

      IF @nStep = 2
      BEGIN

         IF @nInputKey = 1
         BEGIN
            DECLARE @t_SplitValue   TABLE
              (  RowID    INT            IDENTITY(1,1)  PRIMARY KEY
                 ,Value  NVARCHAR(255)  NOT NULL DEFAULT('')
              )

            DECLARE @cUSContainerValidation  NVARCHAR( 30)
            DECLARE @cTableName              NVARCHAR( 20)
            DECLARE @cColumnName             NVARCHAR( 20)
            DECLARE @cKeyValue               NVARCHAR( 10) --POKey / Receiptkey
            DECLARE @cSQLCustom              NVARCHAR( MAX)
            DECLARE @cSQLCustomParam         NVARCHAR( MAX)


            SELECT
               @cUSContainerValidation = SValue
            FROM rdt.StorerConfig (NOLOCK)
            WHERE Function_ID = @nFunc
              AND StorerKey = @cStorerKey
              AND ConfigKey = 'USContainerValidation'

            --Example: PO.userdefine05
            IF @cUSContainerValidation = ''
               GOTO Quit

            INSERT INTO @t_SplitValue (Value)
            SELECT SplitValues = s.[Value]
            FROM STRING_SPLIT(@cUSContainerValidation, '.') AS s


            SELECT @cTableName = UPPER(ISNULL(Value,'')) FROM @t_SplitValue WHERE RowID = 1
            SELECT @cColumnName = UPPER(ISNULL(Value,'')) FROM @t_SplitValue WHERE RowID = 2


            --SValue Column configuration error”
            IF ( (@cTableName <> 'PO' AND @cTableName <> 'RECEIPT') OR @cColumnName = '' OR COL_LENGTH(@cTableName,@cColumnName) IS NULL)
            BEGIN
               SET @nErrNo = 215551
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Quit
            END

            IF @cTableName = 'PO'
               SET @cSQLCustom = ' SELECT TOP 1 @cKeyValue = POKey ';
            ELSE IF @cTableName = 'RECEIPT'
               SET @cSQLCustom = ' SELECT TOP 1 @cKeyValue = Receiptkey ';
            ELSE
               GOTO Quit

            SET @cSQLCustom = @cSQLCustom +
                              ' FROM '+ @cTableName + ' WITH (NOLOCK) ' +
                              ' WHERE ' + @cColumnName +' = @cContainerNo ' +
                              ' AND StorerKey = @cStorerKey '

            SET @cSQLCustomParam = ' @cContainerNo    NVARCHAR( 20) ' +
                                   ',@cStorerKey      NVARCHAR( 15) ' +
                                   ',@cKeyValue       NVARCHAR( 10) OUTPUT '

            EXEC sp_executeSQL @cSQLCustom, @cSQLCustomParam
               ,@cContainerNo = @cContainerNo
               ,@cStorerKey = @cStorerKey
               ,@cKeyValue = @cKeyValue OUTPUT

            IF ISNULL(@cKeyValue,'') = ''
            BEGIN
               SET @nErrNo = 215552
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Container Number
               GOTO Quit
            END
            ELSE
            BEGIN
               --Closed
               IF @cTableName = 'PO'
                  SET @cSQLCustom = @cSQLCustom + ' AND ExternStatus = 9'
                                                + ' ORDER BY POKey DESC'

               IF @cTableName = 'RECEIPT'
                  SET @cSQLCustom = @cSQLCustom + ' AND Status = 9'
                                                + ' ORDER BY ReceiptKey DESC'

               EXEC sp_executeSQL @cSQLCustom, @cSQLCustomParam
                  ,@cContainerNo = @cContainerNo
                  ,@cStorerKey = @cStorerKey
                  ,@cKeyValue  = @cKeyValue OUTPUT

               IF @@rowcount>0
               BEGIN
                  SET @nErrNo = 215553
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Container has been Closed
                  GOTO Quit
               END
               -- Container No already checked in
               IF EXISTS(SELECT 1 FROM TransmitLog2 WITH(NOLOCK)
                         WHERE TableName = 'WSONLOTLOG'
                           AND Key1 = @cKeyValue
                           AND Key2 = @cContainerNo
                           AND Key3 = @cStorerKey)
               BEGIN
                  SET @nErrNo = 215554
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Quit
               END
            END

         END

      END

   END

Quit:



GO