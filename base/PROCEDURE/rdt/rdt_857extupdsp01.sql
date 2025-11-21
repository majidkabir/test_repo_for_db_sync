SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_857ExtUpdSP01                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Call From rdtfnc_Driver_CheckIn                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2014-12-03  1.0  ChewKP   Created                                    */
/* 2019-01-02  1.1  Leong    INC0527496 - Bug Fix.                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_857ExtUpdSP01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @nStep          INT,
   @cStorerKey     NVARCHAR(15),
   @cContainerNo   NVARCHAR(20),
   @cAppointmentNo NVARCHAR(20),
   @nInputKey      INT,
   @cActionType    NVARCHAR( 10) ,
   @cInField04     NVARCHAR( 20) ,
   @cInField06     NVARCHAR( 20) ,
   @cInField08     NVARCHAR( 20) ,
   @cInField10     NVARCHAR( 20) ,
   @cOutField01    NVARCHAR( 20) OUTPUT,
   @cOutField02    NVARCHAR( 20) OUTPUT,
   @cOutField03    NVARCHAR( 20) OUTPUT,
   @cOutField04    NVARCHAR( 20) OUTPUT,
   @cOutField05    NVARCHAR( 20) OUTPUT,
   @cOutField06    NVARCHAR( 20) OUTPUT,
   @cOutField07    NVARCHAR( 20) OUTPUT,
   @cOutField08    NVARCHAR( 20) OUTPUT,
   @cOutField09    NVARCHAR( 20) OUTPUT,
   @cOutField10    NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
          ,@nCount     INT
          ,@cFieldDescr      NVARCHAR(20)
          ,@cValue           NVARCHAR(20)
          ,@cLong            NVARCHAR(20)
          ,@cExecStatements  NVARCHAR(4000)
          ,@cUserName        NVARCHAR( 18)
          ,@cFacility        NVARCHAR( 5)

   SET @nErrNo   = 0
   SET @cErrMsg  = ''
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN CheckIn85701

   IF @nFunc = 857
   BEGIN
      SELECT @cFacility = Facility
            ,@cUserName = UserName
      FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      IF NOT EXISTS (SELECT 1 FROM dbo.Booking_Out WITH (NOLOCK)
                     WHERE BookingNo = @cAppointmentNo )
      BEGIN
         SET @nErrNo = 92452
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidBookingNo'
         GOTO RollBackTran
      END

      IF @nInputKey = 1
      BEGIN
         IF @nStep = 1  -- Display Information
         BEGIN
            -- Update Information to RDT.RDTSTDEventLog
            -- Update Booking_Out

            SET @nCount = 1
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cOutField10 = ''

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

            SELECT Description , Long
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'RDTWAT'
            AND StorerKey = @cStorerKey
            AND UDF01 <> 'I'
            Order By Code

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @cValue = ''

               SELECT @cExecStatements = 'SELECT @cValue = ' + @cLong +
                                         ' FROM dbo.Booking_Out WITH (NOLOCK) ' +
                                         ' WHERE BookingNo = ' + @cAppointmentNo

               EXEC sp_executesql @cExecStatements, N'@cValue NVARCHAR(20) OUTPUT, @cAppointmentNo NVARCHAR(20) '
                                                     , @cValue OUTPUT, @cAppointmentNo

               IF @nCount = 1
               BEGIN
                  SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField04 = @cValue
               END
               ELSE IF @nCount = 2
               BEGIN
                  -- Booking DateTime
                  SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField06 = CONVERT (NVARCHAR(20)  , CAST(@cValue AS DATETIME) , 120 )  --RDT.RDTFormatDate(@cValue)
               END
               ELSE IF @nCount = 3
               BEGIN
                  SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField08 = @cValue
               END
               ELSE IF @nCount = 4
               BEGIN
                  -- Status
                  SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  --SET @cOutField10 = @cValue

                  SELECT @cOutField10 = Long
                  FROM dbo.Codelkup WITH (NOLOCK)
                  WHERE ListName = 'BKSTATUSO'
                  AND Code = @cValue
               END

               SET @nCount = @nCount + 1
               FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup

            IF ISNULL(@cContainerNo,'')  <>  ''
            BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
            END
            ELSE
            BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
            END
         END

         IF @nStep = 2  -- Get Input Information
         BEGIN
--            UPDATE dbo.Booking_Out WITH (ROWLOCK)
--            SET   DriverName = @cInField04
--                , LicenseNo  = @cInField06
--                , Status     = CASE WHEN Status = '0' THEN '1' ELSE '9' END
--            WHERE BookingNo = @cAppointmentNo
--
--            IF @@ERROR <> 0
--            BEGIN
--               SET @nErrNo = 92451
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdBookingFail'
--             GOTO RollBackTran
--            END

            SET @nCount = 1
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cOutField10 = ''

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

            SELECT Description, Long
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'RDTWAT'
            AND StorerKey = @cStorerKey
            AND UDF01 = 'I'
            Order By Code

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SET @cValue = ''
               SELECT @cExecStatements = 'SELECT @cValue = ' + @cLong +
                                         ' FROM dbo.Booking_Out WITH (NOLOCK) ' +
                                         ' WHERE BookingNo = ' + @cAppointmentNo

               EXEC sp_executesql @cExecStatements, N'@cValue NVARCHAR(20) OUTPUT, @cAppointmentNo NVARCHAR(20) '
                                                     , @cValue OUTPUT, @cAppointmentNo

               IF @nCount = 1
               BEGIN
                  SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField04 = @cValue
               END
               ELSE IF @nCount = 2
               BEGIN
                  SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField06 = @cValue
               END
               ELSE IF @nCount = 3
               BEGIN
                  SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField08 = @cValue
               END
               ELSE IF @nCount = 4
               BEGIN
                  SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField10 = @cValue
               END

               SET @nCount = @nCount + 1
               FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup

            IF ISNULL(@cContainerNo,'')  <>  ''
            BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
            END
            ELSE
            BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
            END
         END

         IF @nStep = 3
         BEGIN
            IF @cActionType <> '12'
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.Booking_Out WITH (NOLOCK)
                               WHERE BookingNo = @cAppointmentNo
                               AND Status <> '3'  )
               BEGIN
                  SET @nErrNo = 92453
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LoadingNotDone'
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.Booking_Out WITH (NOLOCK)
                               WHERE BookingNo = @cAppointmentNo
                               AND Status <> '0'  )
               BEGIN
                  SET @nErrNo = 92454
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CheckInFail'
                  GOTO RollBackTran
               END
            END

            UPDATE dbo.Booking_Out WITH (ROWLOCK)
            SET   DriverName = @cInField04
                , LicenseNo  = @cInField06
                , Status     = CASE WHEN @cActionType = '12' THEN '1' ELSE '9' END
                , ArrivedTime = CASE WHEN @cActionType = '12' THEN GetDate()  ELSE ArrivedTime END
                , DepartTime = CASE WHEN @cActionType = '12' THEN DepartTime ELSE GetDate() END
            WHERE BookingNo = @cAppointmentNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 92451
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdBookingFail'
               GOTO RollBackTran
            END

            EXEC RDT.rdt_STD_EventLog
                @cActionType   = @cActionType, -- '12', -- Check IN
                @cUserID       = @cUserName,
                @nMobileNo     = @nMobile,
                @nFunctionID   = @nFunc,
                @cFacility     = @cFacility,
                @cStorerKey    = '',
                @cContainerNo  = @cAppointmentNo, -- INC0527496
                @cRefNo4       = ''
         END
      END

      IF @nInputKey = 0
      BEGIN
         IF @nStep = 3  -- Get Input Information
         BEGIN
            SET @nCount = 1
            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''
            SET @cOutField10 = ''

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

            SELECT Description, Long
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'RDTWAT'
            AND StorerKey = @cStorerKey
            AND UDF01 <> 'I'
            Order By Code

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

            WHILE @@FETCH_STATUS <> -1
            BEGIN
               SELECT @cExecStatements = 'SELECT @cValue = ' + @cLong +
                                         ' FROM dbo.Booking_Out WITH (NOLOCK) ' +
                                         ' WHERE BookingNo = ' + @cAppointmentNo

               EXEC sp_executesql @cExecStatements, N'@cValue NVARCHAR(20) OUTPUT, @cAppointmentNo NVARCHAR(20) '
                                                     , @cValue OUTPUT, @cAppointmentNo

               IF @nCount = 1
               BEGIN
                  SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField04 = @cValue
               END
               ELSE IF @nCount = 2
               BEGIN
                  SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField06 = CONVERT (NVARCHAR(20)  , CAST(@cValue AS DATETIME) , 120 )  --RDT.RDTFormatDate(@cValue)
               END
               ELSE IF @nCount = 3
               BEGIN
                  SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField08 = @cValue
               END
               ELSE IF @nCount = 4
               BEGIN
                  SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  --SET @cOutField10 = @cValue

                  SELECT @cOutField10 = Long
                  FROM dbo.Codelkup WITH (NOLOCK)
                  WHERE ListName = 'BKSTATUSO'
                  AND Code = @cValue
               END

               SET @nCount = @nCount + 1
               FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup

            IF ISNULL(@cContainerNo,'')  <>  ''
            BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
            END
            ELSE
            BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
            END
         END
      END
   END

   GOTO QUIT

   RollBackTran:
   ROLLBACK TRAN CheckIn85701

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN CheckIn85701

Fail:
END

GO