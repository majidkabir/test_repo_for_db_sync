SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_652ExtUpd01                                        */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date        Rev  Author       Purposes                                  */
/* 2024-05-27  1.0  Cuize        FCR-242 Created                           */
/* 2024-06-13  1.2  NLT013       FCR-242 Correct the commented message     */
/***************************************************************************/

CREATE   PROCEDURE rdt.rdt_652ExtUpd01(
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cFacility           NVARCHAR( 5),
   @cContainerNo        NVARCHAR( 20), -- rdtSTDEventLog only accept 20 max
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
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 652
   BEGIN

         IF @nInputKey = 1
         BEGIN

            DECLARE @b_success               INT
            DECLARE @n_err                   INT
            DECLARE @c_errmsg                NVARCHAR(250)
            DECLARE @cKeyValue               NVARCHAR( 10)  --POKey / Receiptkey
            DECLARE @cUSContainerValidation  NVARCHAR( 30)
            DECLARE @cTableName              NVARCHAR( 20)
            DECLARE @cColumnName             NVARCHAR( 20)
            DECLARE @cSQLCustom              NVARCHAR( MAX)
            DECLARE @cSQLCustomParam         NVARCHAR( MAX)
            DECLARE @cUserName               NVARCHAR(18)

            DECLARE @t_SplitValue   TABLE
               (  RowID    INT            IDENTITY(1,1)  PRIMARY KEY
                  ,Value  NVARCHAR(255)  NOT NULL DEFAULT('')
               )

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

            --PO.userdefine05
            --Receipt.CarrierReference
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
               ,@cStorerKey   = @cStorerKey
               ,@cKeyValue       = @cKeyValue OUTPUT

            IF ISNULL(@cKeyValue, '') = ''
            BEGIN
               SET @nErrNo = 215501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPOKEYFail
               GOTO Quit
            END


            EXEC dbo.ispGenTransmitLog2 'WSONLOTLOG', @cKeyValue, @cContainerNo, @cStorerKey, ''
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF @n_err <> 0
            BEGIN
               SET @nErrNo = 215502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSTransLogFail
               GOTO Quit
            END

            SELECT @cUserName = UserName
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            UPDATE RDT.rdtSTDEventLog SET ContainerNo = @cContainerNo
            WHERE ActionType   = '3'      AND
               userID       = @cUserName  AND
               MobileNo     = @nMobile    AND
               FunctionID   = @nFunc      AND
               Facility     = @cFacility  AND
               StorerKey    = @cStorerKey AND
               refno2       = @cContainerNo

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 215503
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSEvelogFail
               GOTO Quit
            END

         END

   END

   Quit:

END

GO