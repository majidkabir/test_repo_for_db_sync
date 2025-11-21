SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: IDS                                                             */
/*                                                                            */
/* Purpose: Valid the username and password in the message queue              */
/* Updates:                                                                   */
/* Date         Author   Rev  Purposes                                        */
/* 2020-06-24   YeeKung  1.0  Created                                         */
/* 2022-11-10   yeekung  1.1  WMS-21053. Add dynamic screen(yeekung01)        */
/* 2024-07-26   Jackc    1.2  UWP-21905 Encrypt password                      */
/******************************************************************************/

CREATE   PROC [RDT].[rdtHandleMsgQueue] (
   @InMobile   INT,
   @cActionKey NVARCHAR( 3),
   @nMsgQueueNo INT            OUTPUT,
   @nErrNo     INT             OUTPUT,
   @cErrMsg    NVARCHAR( 1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE   @cVerifystatus  NVARCHAR(20),
             @cUsername     NVARCHAR(20),
             @cPassword     NVARCHAR(32), --V1.2 Jackc, extend length to 32
             @nMsgQStatus   NVARCHAR(1),
             @cUserID       NVARCHAR(20),
             @cFacility     NVARCHAR(20),
             @cStorerkey    NVARCHAR(20),
             @nFunc         NVARCHAR(10),
             @nRowCOUNT     INT

   DECLARE  @cLine01 NVARCHAR(MaX),    --(yeekung01) 
            @cLine02 NVARCHAR(MaX),    --(yeekung01) 
            @cLine03 NVARCHAR(MaX),    --(yeekung01) 
            @cLine04 NVARCHAR(MaX),    --(yeekung01) 
            @cLine05 NVARCHAR(MaX),    --(yeekung01) 
            @cLine06 NVARCHAR(MaX),    --(yeekung01) 
            @cLine07 NVARCHAR(MaX),    --(yeekung01) 
            @cLine08 NVARCHAR(MaX),    --(yeekung01) 
            @cLine09 NVARCHAR(MaX),    --(yeekung01) 
            @cLine10 NVARCHAR(MaX),    --(yeekung01) 
            @cCounter  INT = 0

   DECLARE @tPosition AS VARIABLETABLE

   SET @nErrNo=0

   SELECT @nMsgQStatus = Status,
          @cVerifystatus=line14
   FROM  RDT.rdtMsgQueue (NOLOCK)
   WHERE MsgQueueNo = @nMsgQueueNo
   AND   Mobile = @InMobile

   SET @nRowCOUNT=@@ROWCOUNT

   INSERT INTO @tPosition (Variable,value)
   SELECT 'OPSPosition',*
   FROM STRING_SPLIT(@cVerifystatus,'/')



   IF ISNULL(@cVerifystatus,'')<>'' AND @nMsgQStatus = '1'  and @cVerifystatus='1'
   BEGIN
      DECLARE @cVerify01 NVARCHAR(20)
      DECLARE @cVerify02 NVARCHAR(20)
      DECLARE @cVerify03 NVARCHAR(20)
      DECLARE @cVerify04 NVARCHAR(20)
      DECLARE @cVerify05 NVARCHAR(20)
      DECLARE @cInputVerify01  NVARCHAR(20)
      DECLARE @cInputVerify02  NVARCHAR(20)
      DECLARE @cInputVerify03  NVARCHAR(20)
      DECLARE @cInputVerify04  NVARCHAR(20)
      DECLARE @cInputVerify05  NVARCHAR(20)

      SELECT @cInputVerify01=I_FIELD16,
             @cInputVerify02=I_FIELD17,
             @cInputVerify03 = I_Field18,
             @cInputVerify04 = I_Field19,
             @cInputVerify05 = I_Field20
      FROM RDT.RDTMOBREC (NOLOCK)
      WHERE mobile=@InMobile


      SELECT @cLine01 = ISNULL(Line01, ''),     
             @cLine02 = ISNULL(Line02, ''),     
             @cLine03 = ISNULL(Line03, ''),     
             @cLine04 = ISNULL(Line04, ''),     
             @cLine05 = ISNULL(Line05, ''),     
             @cLine06 = ISNULL(Line06, ''),     
             @cLine07 = ISNULL(Line07, ''),     
             @cLine08 = ISNULL(Line08, ''),     
             @cLine09 = ISNULL(Line09, ''),     
             @cLine10 = ISNULL(Line10, '')
      FROM RDT.rdtMsgQueue WITH (NOLOCK)    
      WHERE MsgQueueNo = @nMsgQueueNo     
      AND   Status < '9'    

      IF @cLine03 ='%I_Field'
      BEGIN
         SET  @cVerify01=@cLine02
         SET  @cCounter = @cCounter+1
      END
      IF @cLine04 ='%I_Field'
      BEGIN
         SET  @cVerify01=@cLine03
         SET  @cCounter = @cCounter+1
      END
      IF @cLine05 ='%I_Field'
      BEGIN
         SET  @cVerify01=CASE WHEN @cCounter='0' THEN @cLine04 END
         SET  @cVerify02=CASE WHEN @cCounter='1' THEN @cLine04 END
         SET  @cCounter = @cCounter+1
      END
      IF @cLine06 ='%I_Field'
      BEGIN
         SET  @cVerify01=CASE WHEN @cCounter='0' THEN @cLine05 END
         SET  @cVerify02=CASE WHEN @cCounter='1' THEN @cLine05 END
         SET  @cCounter = @cCounter+1
      END
      IF @cLine07 ='%I_Field'
      BEGIN
         SET  @cVerify01=CASE WHEN @cCounter='0' THEN @cLine06 END
         SET  @cVerify02=CASE WHEN @cCounter='1' THEN @cLine06 END
         SET  @cVerify03=CASE WHEN @cCounter='2' THEN @cLine06 END
         SET  @cCounter = @cCounter+1
      END
       IF @cLine08 ='%I_Field'
      BEGIN
         SET  @cVerify01=CASE WHEN @cCounter='0' THEN @cLine07 END
         SET  @cVerify02=CASE WHEN @cCounter='1' THEN @cLine07 END
         SET  @cVerify03=CASE WHEN @cCounter='2' THEN @cLine07 END
         SET  @cVerify04=CASE WHEN @cCounter='3' THEN @cLine07 END
         SET  @cCounter = @cCounter+1
      END
      IF @cLine09 ='%I_Field'
      BEGIN
         SET  @cVerify01=CASE WHEN @cCounter='0' THEN @cLine08 END
         SET  @cVerify02=CASE WHEN @cCounter='1' THEN @cLine08 END
         SET  @cVerify03=CASE WHEN @cCounter='2' THEN @cLine08 END
         SET  @cVerify04=CASE WHEN @cCounter='3' THEN @cLine08 END
         SET  @cVerify04=CASE WHEN @cCounter='4' THEN @cLine08 END
         SET  @cCounter = @cCounter+1
      END
      IF @cLine10 ='%I_Field'
      BEGIN
         SET  @cVerify01=CASE WHEN @cCounter='0' THEN @cLine09 END
         SET  @cVerify02=CASE WHEN @cCounter='1' THEN @cLine09 END
         SET  @cVerify03=CASE WHEN @cCounter='2' THEN @cLine09 END
         SET  @cVerify04=CASE WHEN @cCounter='3' THEN @cLine09 END
         SET  @cVerify04=CASE WHEN @cCounter='4' THEN @cLine09 END
         SET  @cVerify05=CASE WHEN @cCounter='5' THEN @cLine09 END
         SET  @cCounter = @cCounter+1
      END

      IF ISNULL(@cVerify01,'')<>''
      BEGIN
         IF @cInputVerify01 <> @cVerify01
         BEGIN
            SET @nErrNo='9999'
            SET @cErrMsg='NotMatch'
            GOTO QUIT
         END

      END
      IF ISNULL(@cVerify02,'')<>''
      BEGIN
         IF @cInputVerify02 <>@cVerify02
         BEGIN
            SET @nErrNo='9999'
            SET @cErrMsg='NotMatch'
            GOTO QUIT
         END

      END
      IF ISNULL(@cVerify03,'')<>''
      BEGIN
         IF @cInputVerify03 <>@cVerify03
         BEGIN
            SET @nErrNo='9999'
            SET @cErrMsg='NotMatch'
            GOTO QUIT
         END
      END
      IF ISNULL(@cVerify04,'')<>''
      BEGIN
         IF @cInputVerify04 <>@cVerify04
         BEGIN
            SET @nErrNo='9999'
            SET @cErrMsg='NotMatch'
            GOTO QUIT
         END
      END
      IF ISNULL(@cVerify05,'')<>''
      BEGIN
         IF @cInputVerify05 <>@cVerify05
         BEGIN
            SET @nErrNo='9999'
            SET @cErrMsg='NotMatch'
            GOTO QUIT
         END
      END


      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      MsgQueueNo = 0
      WHERE  Mobile = @InMobile

      IF @@ERROR <>''
      BEGIN
         SET @nErrNo='9999'
      END

      IF @nErrNo =0
         SET @cErrMsg=''

      -- RDT 2.0 - Delete MsgQueue (Vicky01) - Start
      DELETE FROM  RDT.rdtMsgQueue
      WHERE MsgQueueNo = @nMsgQueueNo
         AND Mobile = @InMobile
      -- RDT 2.0 - Delete MsgQueue (Vicky01) - End

      SET @nMsgQueueNo = 0


   END

   ELSE IF ISNULL(@cVerifystatus,'')<>'' AND @nMsgQStatus = '1'  and @cVerifystatus<>'0'
   BEGIN
      SELECT   @cusername=I_FIELD19,
         @cPassword=I_FIELD20,
         @cUserID= username,
         @cStorerkey=storerkey,
         @cFacility=facility,
         @nFunc=Func
      FROM RDT.RDTMOBREC (NOLOCK)
      WHERE mobile=@InMobile

      IF ISNULL(@cusername,'')='' OR ISNULL(@cPassword,'')=''
      BEGIN
         SET @nErrNo='9999'
         SET @cErrMsg='INV IDPWD'
         GOTO QUIT
      END

      IF (@cActionKey = 'NO' AND @nMsgQStatus = '1')
      BEGIN
         SET @nErrNo='9999'
         SET @cErrMsg='INV IDPWD'
         GOTO QUIT
      END

      IF NOT EXISTS (SELECT *
                     FROM RDT.RDTUSER R WITH (NOLOCK) JOIN
                     @tPosition Pos ON R.OPSPosition=POS.Value
                     WHERE username= @cusername
                     AND password=@cPassword)
      BEGIN
         SET @nErrNo='9999'
         SET @cErrMsg='INV IDPWD'
         GOTO QUIT
      END

      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      MsgQueueNo = 0
      WHERE  Mobile = @InMobile

      IF @@ERROR <>''
      BEGIN
         SET @nErrNo='9999'
      END

      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '6', -- Sign-in
         @cUserID     = @cUserID,
         @nMobileNo   = @InMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @cRefno1     = @cUsername

      -- RDT 2.0 - Delete MsgQueue (Vicky01) - Start
      DELETE FROM  RDT.rdtMsgQueue
      WHERE MsgQueueNo = @nMsgQueueNo
         AND Mobile = @InMobile
      -- RDT 2.0 - Delete MsgQueue (Vicky01) - End

      IF @@ERROR <>''
      BEGIN
         SET @nErrNo='9999'
      END

      SET @nMsgQueueNo = 0


   END

   ELSE IF (@cActionKey = 'NO' AND @nMsgQStatus = '1') OR @nRowCOUNT = 0 -- ENTER
   BEGIN
      UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
         EditDate = GETDATE(),
         MsgQueueNo = 0
      WHERE  Mobile = @InMobile

      IF @@ERROR <>''
      BEGIN
         SET @nErrNo='9999'
      END

      -- RDT 2.0 - Delete MsgQueue (Vicky01) - Start
      DELETE FROM  RDT.rdtMsgQueue
      WHERE MsgQueueNo = @nMsgQueueNo
         AND Mobile = @InMobile
      -- RDT 2.0 - Delete MsgQueue (Vicky01) - End

      IF @@ERROR <>''
      BEGIN
         SET @nErrNo='9999'
      END

      SET @nMsgQueueNo = 0
   END

   GOTO QUIT

QUIT:
   UPDATE RDT.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg
   WHERE Mobile = @InMobile

GO