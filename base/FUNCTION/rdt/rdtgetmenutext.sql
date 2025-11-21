SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtGetMenuText                                       */
/* Copyright      : Maersk                                         */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2023-09-21 1.0  JLC042   Created                                     */
/************************************************************************/

CREATE   FUNCTION [RDT].[rdtGetMenuText] (
  @nMobile   INT, 
  @sLang    NVARCHAR(3) = 'ENG', 
  @sMsgType NVARCHAR(3) = 'MNU' 
) 
RETURNS NVARCHAR(200)
AS
BEGIN
   DECLARE @nOption  int,  
           @nSubMenu int,  
           @nMenu    int,  
           @cLang_Code  NVARCHAR( 3),
           @cMenuText   NVARCHAR(250)

   SELECT @nOption = cast(CASE I_Field01  
             WHEN '1' THEN 1  
             WHEN '2' THEN 2  
             WHEN '3' THEN 3  
             WHEN '4' THEN 4  
             WHEN '5' THEN 5  
             WHEN '6' THEN 6  
             WHEN '7' THEN 7  
             WHEN '8' THEN 8  
             WHEN '9' THEN 9  
             ELSE 0  
             END AS int),  
          @nMenu   = Menu,  
          @cLang_Code = Lang_Code  
   FROM   RDT.RDTMOBREC (NOLOCK)  WHERE  Mobile = @nMobile  
  
   --IF @nOption BETWEEN 1 and 9  
   --BEGIN  
   --   SELECT @nSubMenu = CASE @nOption  
   --          WHEN 1 THEN OP1  
   --          WHEN 2 THEN OP2  
   --          WHEN 3 THEN OP3  
   --          WHEN 4 THEN OP4  
   --          WHEN 5 THEN OP5  
   --          WHEN 6 THEN OP6  
   --          WHEN 7 THEN OP7  
   --          WHEN 8 THEN OP8  
   --          WHEN 9 THEN OP9  
   --          END  
   --   FROM RDT.rdtMenu (NOLOCK) WHERE MenuNo = @nMenu  
  
   --   IF @nSubMenu = 0 OR @nSubMenu IS NULL  
   --   BEGIN  
   --      SET @cMenuText = 'Error'
   --   END  
   --   ELSE  
   --   BEGIN  
   --      -- Check if reach max menu level  
   --      IF (SELECT LEN( MenuStack) FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile) = 60  
   --      BEGIN  
   --         SET @cMenuText = 'Error' 
   --      END  
           
   --      -- Check SP defined  
   --      IF @nSubMenu >= 500  
   --         BEGIN
   --            SET @cMenuText = RDT.rdtGetMessageLong( @nSubMenu, @sLang, 'FNC') 
   --         END
   --   END  
   --END  
   --ELSE -- Not 1 to 6  
   --BEGIN  
   --      SET @cMenuText = 'Error'
   --END  
   SET @cMenuText = RDT.rdtGetMessageLong( @nMenu, @sLang, 'MNU') 
RETURN @cMenuText

END 


GO