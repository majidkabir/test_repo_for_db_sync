SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: rdtGetMenu_V1                                         */
/* Creation Date: 19-Dec-2004                                              */
/* Copyright: IDS                                                          */
/* Written by: Shong                                                       */
/*                                                                         */
/* Purpose: Build the screen format for the Menu screen, which setup       */
/*          in rdtMenu table.                                              */
/*                                                                         */
/* Input Parameters: Mobile No                                             */
/*                                                                         */
/* Output Parameters: NIL                                                  */
/*                                                                         */
/* Return Status:                                                          */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/*                                                                         */
/* Called By: rdtHandle                                                    */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Ver. Author    Purposes                                    */
/* 27-Aug-2007  1.2  James     Change menu limit from 299 to 499           */
/* 23-Feb-2009  1.3  Vicky     Check whether need to display MobileNo for  */
/*                             user login.If 'N',set Option to be flexible */
/*                             instead of Line #9. This is to suit IDSUK   */
/*                             WWC series Handheld, which only has 6 row   */
/*                             (Vicky01)                                   */
/***************************************************************************/

CREATE PROC [RDT].[rdtGetMenu_V1] (
   @nMobile INT
)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cHeading    NVARCHAR(255),
           @nOption1    int,
           @nOption2    int,
           @nOption3    int,
           @nOption4    int,
           @nOption5    int,
           @nOption6    int,
           @cMenuLabel1 NVARCHAR(80),
           @cAction     NVARCHAR(80),
           @nLine       int,
           @y           NVARCHAR(2) ,
           @cErrMsg     NVARCHAR(125)

   DECLARE @nScreen     int,
           @nMenu       int,
           @cLangCode   NVARCHAR(3),
           @nMsgID      int,
           @cMsgType    NVARCHAR(3),
           @cUsername   NVARCHAR(15), -- (Vicky01)
           @cMobileDisp NVARCHAR(1)   -- (Vicky01)

   SELECT @nMenu = Menu, 
          @cErrMsg = ErrMsg , 
          @cLangCode = Lang_Code,
          @cUsername = RTRIM(UserName) -- (Vicky01)
   FROM RDT.RDTMOBREC (NOLOCK) 
   WHERE  Mobile = @nMobile

   -- (Vicky01) - Start
   SELECT @cMobileDisp = ISNULL(MobileNo_Display, 'Y')
   FROM RDT.RDTUSER (NOLOCK)
   WHERE Username = @cUsername
   -- (Vicky01) - End

   IF NOT EXISTS(SELECT 1 FROM RDT.RDTXML_Root (NOLOCK) WHERE Mobile = @nMobile)
   BEGIN
        INSERT INTO RDT.RDTXML_Root (mobile) VALUES (@nMobile)
   END
   ELSE
   BEGIN
        UPDATE RDT.RDTXML_Root WITH (ROWLOCK) SET focus = NULL WHERE Mobile = @nMobile
   END


   -- Purge all the XML data from this Mobile number
   IF EXISTS(SELECT 1 FROM RDT.RDTXML_Elm (NOLOCK) WHERE Mobile = @nMobile)
   BEGIN
        DELETE RDT.RDTXML_Elm WITH (ROWLOCK) Where mobile = @nMobile
   END

   SELECT @cHeading = Heading, @nOption1 = OP1, @nOption2 = OP2, @nOption3 = OP3,
                               @nOption4 = OP4, @nOption5 = OP5, @nOption6 = OP6
   FROM RDT.RDTMenu (NOLOCK) WHERE MenuNo = @nMenu


   -- Build Menu header
   INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
   EXEC RDT.rdtScr2XML_V1 @nMobile, '01', @cHeading

   SELECT @nLine = 1
   -- (Vicky01) - Start
   IF @cMobileDisp = 'N'
   BEGIN
      WHILE @nLine < 3
	   BEGIN
		  -- Build Menu
		  SET @nMsgID  = (CASE @nLine WHEN 1 THEN @nOption1  WHEN 2 THEN @nOption2 
	                      ELSE 0 END)

		  IF @nMsgID BETWEEN 5 AND 299
			  SET  @cMsgType = 'MNU'
		  ELSE 
			  SET  @cMsgType = 'FNC'

		  IF  @nMsgID > 0
			  SET @cMenuLabel1 = Cast (@nLine as NVARCHAR(1)) + '. ' + rdt.rdtgetmessage ( @nMsgID ,@cLangCode ,@cMsgType )

		  IF LEN(@cMenuLabel1) > 2
		  BEGIN
			  SET @y = RIGHT('0' + RTRIM(Cast( @nLine +1 as NVARCHAR(2))),2)
			  INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
			  EXEC RDT.rdtScr2XML_V1 @nMobile, @y, @cMenuLabel1
		  END

		  SET @cMenuLabel1 = ''
		  SET @nLine = @nLine + 1
	   END
   END
   ELSE
   BEGIN
   -- (Vicky01) - End
       WHILE @nLine < 7
       BEGIN
          -- Build Menu
          SET @nMsgID  = (CASE @nLine WHEN 1 THEN @nOption1  WHEN 2 THEN @nOption2 
                                      WHEN 3 THEN @nOption3  WHEN 4 THEN @nOption4
                                      WHEN 5 THEN @nOption5  WHEN 6 THEN @nOption6 ELSE 0 END)

          IF @nMsgID BETWEEN 5 AND 499
              SET  @cMsgType = 'MNU'
          ELSE 
              SET  @cMsgType = 'FNC'

          IF  @nMsgID > 0
              SET @cMenuLabel1 = Cast (@nLine as NVARCHAR(1)) + '. ' + rdt.rdtgetmessage ( @nMsgID ,@cLangCode ,@cMsgType )

          IF LEN(@cMenuLabel1) > 2
          BEGIN
              SET @y = RIGHT('0' + RTRIM(Cast( @nLine +1 as NVARCHAR(2))),2)
              INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
              EXEC RDT.rdtScr2XML_V1 @nMobile, @y, @cMenuLabel1
          END

          SET @cMenuLabel1 = ''
          SET @nLine = @nLine + 1
       END
   END

   -- Build Enter Option:
   SET @cAction = rdt.rdtgetmessage ( 801 ,@cLangCode ,'ACT')
   IF LEN(@cAction) > 0
   BEGIN
     -- (Vicky01) - Start
     IF @cMobileDisp = 'N'
     BEGIN
        SELECT @nLine =  @nLine + 1 -- has to consider Error Msg line as well
        SELECT @y = RIGHT('0' + RTRIM(Cast( @nLine as NVARCHAR(2))),2)
   
        INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
        EXEC RDT.rdtScr2XML_V1 @nMobile, @y, @cAction
     END
     ELSE 
     -- (Vicky01) - End
     BEGIN
        SELECT @nLine =  9    -- @nLine + 1
        SELECT @y = RIGHT('0' + RTRIM(Cast( @nLine as NVARCHAR(2))),2)
   
        INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
        EXEC RDT.rdtScr2XML_V1 @nMobile, @y, @cAction
        

     END
   END


   -- Build Error Message:
   IF RTRIM(@cErrMsg) IS NOT NULL AND RTRIM(@cErrMsg) <> ''
   BEGIN
        SELECT @nLine = @nLine + 1
        SELECT @y = RIGHT('0' + RTRIM(Cast( @nLine as NVARCHAR(2))),2)
        INSERT INTO RDT.[RDTXML_Elm]([mobile], [typ], [x], [y], [length], [id], [default], [type], [value])
        EXEC RDT.rdtScr2XML_V1 @nMobile, @y, @cErrMsg
   END

GO